local skynet = require "skynet"
local log = require "syslog"

local account = {}
local service = {}
local redispool
local mysqlpool

local config = {
	tbname = "account",
	rediskey = "account",
	primarykey = "account",
	columns = nil,
	indexkey = nil,
}

function account.init (service)
	redispool = service["redispool"]
	mysqlpool = service["mysqlpool"]
	--从mysql中加载数据，存储到redis
	config.redispool = redispool
	config.mysqlpool = mysqlpool	
	load_data_impl(config)
end

local function make_key (user)
	return string.format ("user:%s", user)
end

--logind请求认证
function account.auth(user, password)
	log.debug("auth:%s\t%s",user, password)
	local result = do_redis(redispool,{ "hmget", config.tbname .. ":" .. user ,"account"}, user)
	if result[1] then
		return true
	else
		return false
	end

end

return account