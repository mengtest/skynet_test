local skynet = require "skynet"
local dbtableconfig = require "config.dbtableconfig"
local mysqlconf = require "config.mysqlconf"
local account = require "db.account"
local playerdate = require "db.playerdate"
local log = require "syslog"

local CMD = {}
local MODULE = {}
local service = {}
local servername = {
	"redispool",
	"mysqlpool",
	"mongopool",
	"dbsync",
}
--DB表结构
--schema[tablename] = { "pk","fields" = {}}
local schema = {}

local dbname = mysqlconf.center.database

--向redis发送cmd请求
--这里的uid主要用于在redis中选择redis server
local function do_redis(args, uid)
	local cmd = assert(args[1])
	args[1] = uid
	return skynet.call(service["redispool"], "lua", cmd, table.unpack(args))
end

--获取table的主键
local function get_primary_key(tbname)
	local sql = "select k.column_name " ..
		"from information_schema.table_constraints t " ..
		"join information_schema.key_column_usage k " ..
		"using (constraint_name,table_schema,table_name) " ..
		"where t.constraint_type = 'PRIMARY KEY' " ..
		"and t.table_schema= '".. dbname .. "'" ..
		"and t.table_name = '" .. tbname .. "'"

	local t = skynet.call(service["mysqlpool"], "lua", "execute",sql)

	return t[1]["column_name"]
end

--获取table中所有的字段
local function get_fields(tbname)
	local sql = string.format("select column_name from information_schema.columns where table_schema = '%s' and table_name = '%s'", dbname, tbname)
	local rs = skynet.call(service["mysqlpool"], "lua", "execute", sql)
	local fields = {}
	for _, row in pairs(rs) do
		local name = row["column_name"]
		if name == nil then
			name = row["COLUMN_NAME"]
		end
		table.insert(fields, name)
	end

	return fields
end

--获取字段的变量类型
local function get_field_type(tbname, field)
	local sql = string.format("select data_type from information_schema.columns where table_schema='%s' and table_name='%s' and column_name='%s'",
			dbname, tbname, field)
	local rs = skynet.call(service["mysqlpool"], "lua", "execute", sql)
	return rs[1]["data_type"] or rs[1]["DATA_TYPE"]
end

--构建DB中的结构到schema中
local function load_schema_to_redis()
	local sql = "select table_name from information_schema.tables where table_schema='" .. dbname .. "'"
	local rs = skynet.call(service["mysqlpool"], "lua", "execute", sql)
	for _, row in pairs(rs) do
		local tbname
		if not row.table_name then
			tbname =row.TABLE_NAME
		else
			tbname =row.table_name
		end
		
		schema[tbname] = {}
		schema[tbname]["fields"] = {}
		schema[tbname]["pk"] = get_primary_key(tbname)

		local fields = get_fields(tbname)
		for _, field in pairs(fields) do
			local field_type = get_field_type(tbname, field)
			if field_type == "char"
			  or field_type == "varchar"
			  or field_type == "tinytext"
			  or field_type == "text"
			  or field_type == "mediumtext"
			  or field_type == "longtext" then
				schema[tbname]["fields"][field] = "string"
			else
				schema[tbname]["fields"][field] = "number"
			end
		end
	end
end

--根据数值类型转化
local function convert_record(tbname, record)
	for k, v in pairs(record) do
		if schema[tbname]["fields"][k] == "number" then
			record[k] = tonumber(v)
		end
	end

	return record
end

--将table row中的值，根据key的名称提取出来后组合成rediskey
local function make_rediskey(row, key)
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
local function make_pairs_table(t, fields)
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
function CMD.load_data_impl(config, uid)
	local tbname = config.tbname
	local pk = schema[tbname]["pk"]
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
				sql = string.format("select * from %s where uid = '%s' order by %s asc limit %d, 1000", tbname, uid, pk, offset)
			else
				sql = string.format("select %s from %s where uid = '%s' order by %s asc limit %d, 1000", config.columns, tbname, uid, pk, offset)
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
				do_redis({ "zadd", tbname .. ":index:" .. indexkey, 0, rediskey }, uid)
			end

			table.insert(data, row)
		end

		if #rs < 1000 then break end

		offset = offset + 1000
	end
	return data
end

-- 加user类型表单行数据到redis
function CMD.load_user_single(tbname, uid)
	local config = dbtableconfig[tbname]
	local data = CMD.load_data_impl(config, uid)
	assert(#data <= 1)
	if #data == 1 then
		return data[1]
	end

	return data			-- 这里返回的一定是空表{}
end

-- 加user类型表多行数据到redis
function CMD.load_user_multi(tbname, uid)
	local config = dbtableconfig[tbname]
	local data = {}
	local t = CMD.load_data_impl(config, uid)

	local pk = schema[tbname]["pk"]
	for _, v in pairs(t) do
		data[v[pk]] = v
	end

	return data
end

-- 到redis中查询，没有的话到mysql中查询
-- 在mysql中查询的时候，如果查到了，会同步到redis中去的
-- redis和mysql中都没有找到的时候返回空的table
-- 单条查询
function CMD.execute_single(tbname, uid, fields)
	local result
	local rediskey = tbname .. ":" .. uid
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
		local t = CMD.load_user_single(tbname, uid)
		if fields and not table.empty(t) then
			result = {}
			for _, v in pairs(fields) do
				result[v] = t[v]
			end
		else
			result = t
		end
	end

	result = convert_record(tbname, result)

	return result
end

-- 到redis中查询，没有的话到mysql中查询
-- 在mysql中查询的时候，如果查到了，会同步到redis中去的
-- redis和mysql中都没有找到的时候返回空的table
-- 多条查询,当有id的时候，只提取多条中的一条
function CMD.execute_multi(tbname, uid, id, fields)
	local result
	local rediskey = tbname .. ":index:" .. uid
	local ids = do_redis({ "zrange", rediskey, 0, -1 }, uid)

	if not table.empty(ids) then
		if id then
			--获取一条数据
			if fields then
				result = do_redis({ "hmget", tbname .. ":" .. id, table.unpack(fields) }, uid)
				result = make_pairs_table(result,fields)
				result = convert_record(tbname,result)
			else
				result = do_redis({ "hgetall", tbname .. ":" .. id }, uid)
				result = make_pairs_table(result)
				result = convert_record(tbname,result)
			end

		else
			--获取全部数据
			result = {}
			if fields then
				for _, _id in pairs(ids) do
					local t = do_redis({ "hmget", tbname .. ":" .. _id, table.unpack(fields)}, uid)
					t = make_pairs_table(t,fields)
					t = convert_record(tbname, t)
					result[tonumber(_id)] = t
				end
			else
				for _, _id in pairs(ids) do
					local t = do_redis({ "hgetall", tbname .. ":" .. _id }, uid)
					t = make_pairs_table(t)
					t = convert_record(tbname, t)
					result[tonumber(_id)] = t
				end
			end
		end
	else
		-- mysql查询
		local t = CMD.load_user_multi(tbname, uid)

		if id then
			if fields then
				result = {}
				for _, v in pairs(fields) do
					result[v] = t[id][v]
				end
			else
				result = t[id]
			end
		else
			if fields then
				result = {}
				for k, _ in pairs(t) do
					result[k] = {}
					setmetatable(result, { __mode = "k" })

					for i=1, #fields do
						result[k][fields[i]] = t[k][fields[i]]
					end
				end
			else
				result = t
			end
		end
	end

	return result
end

--！！这边的add、update都会导致uid这个字段跟着更新...可能需要调整一下
-- redis中增加一行记录，默认同步到mysql
function CMD.add(tbname, row, immed, nosync)
	local config = dbtableconfig[tbname]
	local uid = row.uid
	local key = config.rediskey
	local indexkey = config.indexkey

	local rediskey = make_rediskey(row, key)
	do_redis({ "hmset", tbname .. ":" .. rediskey, row }, uid)
	if indexkey then
		local linkey = make_rediskey(row,indexkey)
		do_redis({ "zadd", tbname..":index:"..linkey, 0, rediskey }, uid)
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
		return skynet.call(service["dbsync"], "lua", "sync", sql, immed)
	end
	return true
end

-- redis中更新一行记录，并同步到mysql
function CMD.update(tbname, row, nosync)
	local config = dbtableconfig[tbname]
	local uid = row.uid
	local key = config.rediskey
	local indexkey = config.indexkey

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
		local pk = schema[tbname]["pk"]
		local sql = "update " .. tbname .. " set " .. setvalues .. " where " .. pk .. "='" .. row[pk] .. "'"
		skynet.call(service["dbsync"], "lua", "sync", sql)
	end
end

local function module_init (name, mod)
	MODULE[name] = mod
	mod.init (CMD)
	CMD.load_data_impl(dbtableconfig[name])
end
local system = {}

function system.open()
	for _, name in ipairs(servername) do
		service[name] = skynet.uniqueservice(name)
	end

	for _,v in pairs(servername) do
		skynet.call(service[v],"lua","open")
	end

	load_schema_to_redis()
	module_init ("account", account)
	module_init ("playerdate", playerdate)
end

function system.close()
	log.notice("close dbmgr...")
	for _,v in pairs(servername) do
		skynet.call(service[v],"lua","close")
	end
end

MODULE["system"] = system

skynet.start(function()
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
