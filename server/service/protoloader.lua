local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local service = require "service"
local log = require "base.syslog"

local loader = {}
local data = {}

local function load(name)
	local filename = string.format("./common/proto/%s.lua", name)
	local f = assert(io.open(filename), "Can't open " .. name)
	local t = f:read "a"
	f:close()
	return sprotoparser.parse(t)
end

function loader.load(list)
	for i, name in ipairs(list) do
		local p = load(name)
		log.notice("load proto [%s] in slot %d", name, i)
		data[name] = i
		sprotoloader.save(p, i)
	end

end

function loader.index(name)
	return data[name]
end

function loader.get()
	local host = sprotoloader.load (self.index("clientproto")):host "package"
	local request = host:attach (sprotoloader.load (self.index("serverproto")))
	return host, request
end

service.init {
	command = loader,
	info = data
}