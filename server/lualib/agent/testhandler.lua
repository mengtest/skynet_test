local handler = require "agent.handler"
local log = require "base.syslog"

local REQUEST = {}

local _handler = handler.new (REQUEST)

function REQUEST.ping()
	log.debug("get ping from client")
	return {ok = true}
end

return _handler
