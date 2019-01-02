local conf = {}

-- rediskey 用于生产单条redis数据的key
-- indexkey 用于生产redis集合数据的key
-- indexvalue 用于集合排序的值
-- columns 数据表字段
conf["account"] = {
    rediskey = "uid",
    indexkey = nil,
    columns = nil
}

conf["playerdate"] = {
    rediskey = "uuid",
    indexkey = "uid",
    indexvalue = nil
}

for k, v in pairs(conf) do
    v["tbname"] = k
end

return conf
