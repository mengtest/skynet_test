local skynet = require "skynet"

function do_redis(redispool,args, uid)
	local cmd = assert(args[1])
	args[1] = uid
	return skynet.call(redispool, "lua", cmd, table.unpack(args))
end

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
function load_data_impl(config, uid)
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

		local rs = skynet.call(config.mysqlpool, "lua", "execute", sql)

		if #rs <= 0 then break end

		for _, row in pairs(rs) do
			--将mysql中读取到的信息添加到redis的哈希表中
			local rediskey = make_rediskey(row, config.rediskey)
			do_redis(config.redispool,{ "hmset", tbname .. ":" .. rediskey, row }, uid)
			
			--对需要排序的数据插入有序集合
			if config.indexkey then
				local indexkey = make_rediskey(row, config.indexkey)
				do_redis(config.redispool,{ "zadd", tbname .. ":index:" .. indexkey, 0, rediskey }, uid) 
			end

			table.insert(data, row)
			
		end

		if #rs < 1000 then break end

		offset = offset + 1000
	end

	return data
end