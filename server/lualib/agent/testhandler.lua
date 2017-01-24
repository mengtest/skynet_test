local handler = require "agent.handler"
local log = require "base.syslog"

local user
local REQUEST = {}
local CMD = {}

local _handler = handler.new (REQUEST,nil,CMD)

_handler:init (function (u)
	user = u
end)

_handler:release (function ()
	user = nil
end)

function REQUEST.ping()
	log.debug("get ping from client")
	return {ok = true}
end

function REQUEST.quitgame()
	log.debug("query quit game")
	user.CMD.logout()
	return {ok = true}
end

function CMD.test(...)
	print(...)
end

return _handler
