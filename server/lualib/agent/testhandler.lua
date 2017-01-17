local handler = require "agent.handler"
local log = require "base.syslog"

local REQUEST = {}
local CMD = {}

local _handler = handler.new (REQUEST,nil,CMD)

function REQUEST.ping()
	log.debug("get ping from client")
	return {ok = true}
end

function CMD.test(...)
	print(...)
end

return _handler
