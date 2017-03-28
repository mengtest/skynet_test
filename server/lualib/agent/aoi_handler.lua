local skynet = require "skynet"
local sharemap = require "sharemap"
local handler = require "agent.handler"
local log = require "base.syslog"

local CMD = {}

local _handler = handler.new (nil,nil,CMD)

local AOI_RADIS2 = 200 * 200 * 4
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
end)

local function DIST2(p1,p2)
	return ((p1.x - p2.x) * (p1.x  - p2.x) + (p1.y  - p2.y) * (p1.y  - p2.y) + (p1.z  - p2.z) * (p1.z  - p2.z))
end

local function updateagentlist()
	for k,v in pairs(readerlist) do
		v:update()
		assert(v.pos)
		local list = {}
		if DIST2(user.character.aoiobj.movement.pos,v.pos) > AOI_RADIS2 then
			list[k] = agentlist[k]
			readerlist[k] = nil
			agentlist[k] = nil
		end
		--移除对象
		skynet.fork( function ()
			--移除自己视野内的对象
			for kk,_ in pairs(list) do
				user.send_request("characterleave",{ tempid = kk })
			end
			--通知其他对象移除自己
			user.send_boardrequest("characterleave",{ tempid = user.character.aoiobj.tempid },list)
		end)
	end
end

function CMD.createreader()
	--log.debug ("user(%s) create_reader",user.uid)
	assert(user.characterwriter)
	return user.characterwriter:copy()
end

--离开地图的时候调用
--通知其他玩家移除自己
function CMD.delaoiobj(_,tempid)
	updateagentlist()
	if not table.empty(agentlist) then
		for _,v in pairs(agentlist) do
			skynet.call(v.agent, "lua", "leaveaoiobj", tempid);
		end
	end
	user.send_boardrequest("characterleave",{ tempid = user.character.aoiobj.tempid })
	agentlist = nil
	readerlist = nil
end

function CMD.leaveaoiobj(_,tempid)
	readerlist[tempid] = nil
	agentlist[tempid] = nil
end

function CMD.addaoiobj(_,aoiobj)
	--log.debug("user(%s) can watch user(%s)",user.character.aoiobj.tempid,aoiobj.tempid)
	skynet.fork( function ()
		if readerlist[aoiobj.tempid] == nil then
			local reader = skynet.call(aoiobj.agent,"lua","createreader")
			readerlist[aoiobj.tempid] = sharemap.reader ("charactermovement", reader)
			agentlist[aoiobj.tempid] = aoiobj
			skynet.send(aoiobj.agent, "lua", "updateinfo", { aoiobj = user.character.aoiobj });
			user.CMD.updateinfo()
		end
	end)
end

function CMD.boardcast(_, gate, package, list)
	if gate then
		if list then
			assert(type(list) == "table","boardcast list is not a table")
			skynet.call(gate, "lua", "boardrequest", package, list);
		else
			updateagentlist()
			if not table.empty(agentlist) then
				--for k,v in pairs(agentlist) do
				--	log.debug("@@@@(%s)%d,%s,%d",user.uid,k,v.uid,v.subid)
				--end
				skynet.call(gate, "lua", "boardrequest", package, agentlist);
			end
		end
	end
end

return _handler
