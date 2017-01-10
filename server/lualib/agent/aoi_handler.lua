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

function CMD.addaoiobj(_,agent,tempid)
	log.debug("agent(%d) tempid(%d) can watch agent(%d) tempid(%d)",skynet.self(),user.character.aoiobj.tempid,agent,tempid)
	agentlist[tempid] = agent
end

function CMD.boardcast()

end

return _handler
