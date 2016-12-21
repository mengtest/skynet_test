local skynet = require "skynet"
local account = require "db.account"
local log = require "syslog"

local CMD = {}
local MODULE = {}
local service = {}
local servername = {
	"redispool",
	"mysqlpool",
	"dbsync",
}

--向redis发送cmd请求
--这里的uid主要用于在redis中选择redis server
function do_redis(args, uid)
	local cmd = assert(args[1])
	args[1] = uid
	return skynet.call(service["redispool"], "lua", cmd, table.unpack(args))
end

--将table row中的值，根据key的名称提取出来后组合成rediskey
function make_rediskey(row, key)
	local rediskey = ""
	local fields = string.split(key, ",")
	for i, field in pairs(fields) do
		if i == 1 then
			rediskey = row[field]
		else
			rediskey = rediskey .. ":" .. row[field]
		end
	end

	return rediskey
end

--通过fields提供的k将t中的数据格式化
function make_pairs_table(t, fields)
	assert(type(t) == "table", "make_pairs_table t is not table")

	local data = {}

	if not fields then
		for i=1, #t, 2 do
			data[t[i]] = t[i+1]
		end
	else
		for i=1, #t do
			data[fields[i]] = t[i]
		end
	end

	return data
end

--在mysql中根据config指定的信息读取数据，并写入到redis
--如果有uid，那么只读该玩家的信息并写入redis
--返回的data为table，为结果集
--集合中table中值的类型和数据库中的类型相符
function CMD:load_data_impl(config, uid)
	local tbname = config.tbname
	local pk = config.primarykey
	local offset = 0
	local sql
	local data = {}
	while true do
		if not uid then
			if not config.columns then
				sql = string.format("select * from %s order by %s asc limit %d, 1000", tbname, pk, offset)
			else
				sql = string.format("select %s from %s order by %s asc limit %d, 1000", config.columns, tbname, pk, offset)
			end
		else
			--这边看是不是要修改一下，account = '%s'，尽量用数字ID查询？
			if not config.columns then
				sql = string.format("select * from %s where account = '%s' order by %s asc limit %d, 1000", tbname, uid, pk, offset)
			else
				sql = string.format("select %s from %s where account = '%s' order by %s asc limit %d, 1000", config.columns, tbname, uid, pk, offset)
			end
		end

		local rs = skynet.call(service["mysqlpool"], "lua", "execute", sql)
		if #rs <= 0 then break end

		for _, row in pairs(rs) do
			--将mysql中读取到的信息添加到redis的哈希表中
			local rediskey = make_rediskey(row, config.rediskey)
			do_redis({ "hmset", tbname .. ":" .. rediskey, row }, uid)
			
			--对需要排序的数据插入有序集合
			if config.indexkey then
				local indexkey = make_rediskey(row, config.indexkey)
				do_redis({ "zadd", tbname .. ":index:" .. indexkey, row[indexkey], rediskey }, uid) 
			end

			table.insert(data, row)
			
		end

		if #rs < 1000 then break end

		offset = offset + 1000
	end

	return data
end

-- 到redis中查询，没有的话到mysql中查询
-- 在mysql中查询的时候，如果查到了，会同步到redis中去的
-- redis和mysql中都没有找到的时候返回空的table
-- 目前为单条查询
function CMD:execute(config,rediskey,uid,fields)
	local result
	if fields then
		result = do_redis({ "hmget", rediskey, table.unpack(fields) }, uid)
		result = make_pairs_table(result, fields)
	else
		result = do_redis({ "hgetall", rediskey }, uid)
		result = make_pairs_table(result)
	end

	-- redis没有数据返回，则从mysql加载
	if table.empty(result) then
		log.debug("load data from mysql:"..uid)
		local t = self:load_data_impl(config, uid)
		if fields and not table.empty(t) then
			result = {}
			for k, v in pairs(fields) do
				result[v] = t[v]
			end
		elseif  not table.empty(t) then
			result = t[1]
		end
	end
	return result
end

-- redis中增加一行记录，默认同步到mysql
function CMD:add(config, nosync)
	local uid = config.row.uid
	local tbname = config.tbname
	local row = config.row
	local key = config.rediskey
	local indexkey = config.indexkey
	local rediskey = make_rediskey(row, key)
	do_redis({ "hmset", tbname .. ":" .. rediskey, row }, uid)
	if indexkey then
		local linkey = make_rediskey(row,indexkey)
		do_redis({ "zadd", tbname..":index:"..linkey, row[indexkey], rediskey }, uid)
	end

	if not nosync then
		local columns
		local values
		for k, v in pairs(row) do
			if not columns then
				columns = k
			else
				columns = columns .. "," .. k
			end
			
			if not values then
				values = "'" .. v .. "'"
			else
				values = values .. "," .. "'" .. v .. "'"
			end
		end

		local sql = "insert into " .. tbname .. "(" .. columns .. ") values(" .. values .. ")"
		skynet.call(service["dbsync"], "lua", "sync", sql)
	end
end

-- redis中更新一行记录，并同步到mysql
function CMD:update(config, nosync)
	local uid = config.row.uid
	local tbname = config.tbname
	local row = config.row
	local key = config.rediskey
	local indexkey = config.indexkey
	local pk = config.primarykey
	local rediskey = make_rediskey(row, key)
	do_redis({ "hmset", tbname .. ":" .. rediskey, row }, uid)
	if indexkey then
		local linkey = make_rediskey(row,indexkey)
		do_redis({ "zadd", tbname..":index:"..linkey, row[indexkey], rediskey }, uid)
	end

	if not nosync then
		local setvalues = ""

		for k, v in pairs(row) do
			setvalues = setvalues .. k .. "='" .. v .. "',"
		end
		setvalues = setvalues:trim(",")

		local sql = "update " .. tbname .. " set " .. setvalues .. " where " .. pk .. "='" .. row[pk] .. "'"
		skynet.call(service["dbsync"], "lua", "sync", sql)
	end
end

local function module_init (name, mod)
	MODULE[name] = mod
	mod.init (CMD)
end

skynet.start(function()
	if servername then
		local s = servername
		for _, name in ipairs(s) do
			service[name] = skynet.uniqueservice(name)
		end
	end

	for _,v in pairs(servername) do
		skynet.call(service[v],"lua","open")
	end
	
	module_init ("account", account)

	skynet.dispatch("lua", function (_,_, cmd, subcmd, ...)
		local m = MODULE[cmd]
		if not m then
			log.notice("Unknown command : [%s]", cmd)
			skynet.response()(false)
		end
		local f = m[subcmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log.notice("Unknown sub command : [%s]", subcmd)
			skynet.response()(false)
		end
	end)
end)