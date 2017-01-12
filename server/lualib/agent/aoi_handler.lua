local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"

local CMD = {}

local _handler = handler.new (nil,nil,CMD)

local user
local agentlist = {}

_handler:init (function (u)
	user = u
end)

function CMD.addaoiobj(_,agentinfo)
	log.debug("====user(%s) can watch user(%s)",user.uid,agentinfo.uid)
	agentlist[agentinfo.subid] = agentinfo
end

function CMD.boardcast(gate,package)
	if gate then
		if not table.empty(agentlist) then
			skynet.call(gate, "lua", "boardrequest", package, agentlist);
		end
	end
end

return _handler
