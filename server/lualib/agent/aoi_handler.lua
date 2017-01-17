local skynet = require "skynet"
local sharemap = require "sharemap"
local handler = require "agent.handler"
local log = require "base.syslog"

local CMD = {}

local _handler = handler.new (nil,nil,CMD)

local AOI_RADIS2 = 100
local user
local agentlist
local readerlist

_handler:init (function (u)
	user = u
	user.characterwriter = sharemap.writer ("charactermovement", user.character.aoiobj.movement)
	agentlist = {}
	readerlist = {}
end)

_handler:release (function ()
	user.characterwriter = nil
	user = nil
	agentlist = nil
	readerlist = nil
end)

local function updateagentlist()
	for k,v in pairs(readerlist) do
		v:update()
		assert(v.pos)
		if v.pos.x*v.pos.x+v.pos.y*v.pos.y+v.pos.z*v.pos.z > AOI_RADIS2 then
			readerlist[k] = nil
			agentlist[k] = nil
		end
	end
end

function CMD.createreader()
	log.debug ("user(%s) create_reader",user.uid)
	assert(user.characterwriter)
	return user.characterwriter:copy()
end

function CMD.addaoiobj(_,agentinfo,agent)
	log.debug("user(%s) can watch user(%s)",user.uid,agentinfo.uid)
	skynet.fork( function ()
		local reader = skynet.call(agent,"lua","createreader")
		readerlist[agentinfo.uuid] = sharemap.reader ("charactermovement", reader)
		agentlist[agentinfo.uuid] = agentinfo
	end)
end

function CMD.boardcast(_,gate,package)
	if gate then
		updateagentlist()
		if not table.empty(agentlist) then
			for k,v in pairs(agentlist) do
				log.debug("@@@@(%s)%d,%s,%d",user.uid,k,v.uid,v.subid)
			end
			skynet.call(gate, "lua", "boardrequest", package, agentlist);
		end
	end
end

return _handler
