local conf = {}

--DB的table表名，和对应的rediskey
--如需插入到有序集合中，还需要有indexkey
--为nil的可以不用填写，这边第一个作为示例
conf["account"] = {
  rediskey = "uid",
  indexkey = nil,
  columns = nil,
}

conf["playerdate"] = {
  rediskey = "uuid",
  indexkey = "uid",
}

for k,v in pairs(conf) do
  v["tbname"] = k
end

return conf
