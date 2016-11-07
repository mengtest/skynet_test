local log = require "syslog"
local skynet require "skynet"

local account = {}
local service = {}
local redispool
local mysqlpool

function account.init (service)
	redispool = service["redispool"]
	mysqlpool = service["mysqlpool"]
end

local function make_key (user)
	return string.format ("user:%s", user)
end

--logind请求认证
function account.auth(user, password)
	log.debug("auth:%s\t%s",user, password)
	local result = do_redis(redispool,{"hget",make_key(user),"password"},user)
	if result == password then
		return true
	else
		return false
	end
end

return account