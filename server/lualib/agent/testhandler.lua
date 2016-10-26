local handler = require "agent.handler"
local log = require "base.syslog"

local REQUEST = {}
local RESPONSE = {}
local CMD = {}

_handler = handler.create (REQUEST)

local user

_handler:init (function (u)
	user = u
end)

function REQUEST.ping()
	log.debug("get ping from client")
	return {ok = true}
end

return _handler