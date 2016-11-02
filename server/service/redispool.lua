local skynet = require "skynet"
local service = require "service"
local redis = require "redis"
local config = require "config.redisconf"
local account = require "db.account"

local CMD = {}
local center
local group = {}
local ngroup

local function hash_str (str)
	local hash = 0
	string.gsub (str, "(%w)", function (c)
		hash = hash + string.byte (c)
	end)
	return hash
end

local function hash_num (num)
	local hash = num << 8
	return hash
end

function connection_handler (key)
	local hash
	local t = type (key)
	if t == "string" then
		hash = hash_str (key)
	else
		hash = hash_num (assert (tonumber (key)))
	end
	if ngroup > 0 then
		return group[hash % ngroup + 1]
	else
		return center
	end
end

local CMD = {}
local function module_init (name, mod)
	CMD[name] = mod
	mod.init (connection_handler)
end

function CMD.open()
	module_init ("account", account)

	center = redis.connect(config.center)
	ngroup = #config.group
	for _, c in ipairs (config.group) do
		table.insert (group, redis.connect (c))
	end
end

service.init {
	command = CMD,
}