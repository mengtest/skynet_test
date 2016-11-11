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
function CMD:do_redis(args, uid)
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
			if not config.columns then
				sql = string.format("select * from %s where uid = %d order by %s asc limit %d, 1000", tbname, uid, pk, offset)
			else
				sql = string.format("select %s from %s where uid = %d order by %s asc limit %d, 1000", config.columns, tbname, uid, pk, offset)
			end
		end

		local rs = skynet.call(service["mysqlpool"], "lua", "execute", sql)

		if #rs <= 0 then break end

		for _, row in pairs(rs) do
			--将mysql中读取到的信息添加到redis的哈希表中
			local rediskey = make_rediskey(row, config.rediskey)
			self:do_redis({ "hmset", tbname .. ":" .. rediskey, row }, uid)
			
			--对需要排序的数据插入有序集合
			if config.indexkey then
				local indexkey = make_rediskey(row, config.indexkey)
				self:do_redis({ "zadd", tbname .. ":index:" .. indexkey, 0, rediskey }, uid) 
			end

			table.insert(data, row)
			
		end

		if #rs < 1000 then break end

		offset = offset + 1000
	end

	return data
end

-- redis中增加一行记录，默认同步到mysql
function CMD:add(config, nosync)
	local uid = config.row.uid
	local tbname = config.tbname
	local row = config.row
	local key = config.rediskey
	local indexkey = config.indexkey
	local rediskey = make_rediskey(row, key)
	self:do_redis({ "hmset", tbname .. ":" .. rediskey, row }, uid)
	if indexkey then
		local linkey = make_rediskey(row,indexkey)
		self:do_redis({ "zadd", tbname..":index:"..linkey, 0, rediskey }, uid)
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
		skynet.call(service["dbsync"], "lua", "sync", sql, true)
	end

	return true
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