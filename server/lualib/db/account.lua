local log = require "syslog"
local skynet require "skynet"

local account = {}
local service = {}
local redispool
local connection_handler

function account.init (service)
	redispool = service["redispool"]
end

local function make_key (user)
	return string.format ("user:%s", user)
end

--logind请求认证
function account.auth(user, password)
	log.debug("auth:%s\t%s",user, password)
	--do_redis(redispool,{"hset",make_key(user),"password",password},user)
	local result = do_redis(redispool,{"hget",make_key(user),"password"},user)
	if result == password then
		return true
	else
		return false
	end
end

function account.load (name)
	assert (name)

	local acc = { name = name }

	local connection, key = make_key (name)
	if connection:exists (key) then
		acc.id = connection:hget (key, "account")
		acc.salt = connection:hget (key, "salt")
		acc.verifier = connection:hget (key, "verifier")
	else
		acc.salt, acc.verifier = srp.create_verifier (name, constant.default_password)
	end

	return acc
end

function account.create (id, name, password)
	assert (id and name and #name < 24 and password and #password < 24, "invalid argument")
	
	local connection, key = make_key (name)
	assert (connection:hsetnx (key, "account", id) ~= 0, "create account failed")

	local salt, verifier = srp.create_verifier (name, password)
	assert (connection:hmset (key, "salt", salt, "verifier", verifier) ~= 0, "save account verifier failed")

	return id
end

return account