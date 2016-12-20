local skynet = require "skynet"
local log = require "syslog"
local uuid = require "uuid"

local dbmgrcmd = {}
local account = {}

local config = {
	tbname = "account",--表名
	rediskey = "account",--用表中哪些字段来生成redis的key,","分割
	primarykey = "account",--主键，在读取所有信息的时候，会以主键排序
	columns = nil,--需要查询的字段，nil的时候全部获取
	indexkey = nil,--需要插入有序集合的时候，以该字段生成key
	row = {},--添加数据的时候，把数据写到这里
}

function account.init (cmd)
	dbmgrcmd = cmd
	--从mysql中加载数据，存储到redis
	dbmgrcmd:load_data_impl(config)
end

local function make_key (user)
	return string.format ("%s:%s", config.rediskey,user)
end

--logind请求认证
function account.auth(user, password)
	log.debug("auth:%s\t%s",user, password)
	local result = dbmgrcmd:execute(config,make_key(user),user)
	if result["account"] ~= nil then
		log.debug("find account:%s",user)
		if result["account"] == user then
			log.debug("account:%s update login time",user)
			-- TODO update login time
		else
			log.debug("find account:%s in DB,but result['account'] = %s",user,result["account"])
		end
		return 0
	else
		log.debug("add account to redis and mysql")
		--不存在于redis中的时候，添加记录
		local row = { }
		row.account = user
		row.createtime = os.time()
		row.logintime = row.createtime
		row.uuid = uuid.gen()
		config.row = row
		dbmgrcmd:add(config)
	end
end

return account