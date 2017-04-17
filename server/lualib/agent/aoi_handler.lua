local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"

if not _G.instance then
	_G.instance = {}
end

if not _G.instance.aoi then
	_G.instance.aoi = {}
end

local CMD = {}
local _handler = handler.new (nil,nil,CMD)
local user

_handler:init (function (u)
	user = u
end)

_handler:release (function ()
	user = nil
end)

function _G.instance.aoi.updateagentlist()
	local leavelist ,enterlist = user.character:updateaoilist()
	--移除对象
	skynet.fork( function ()
		--离开视野
		if not table.empty(leavelist) then
			--移除自己视野内的对象
			for kk,_ in pairs(leavelist) do
				user.send_request("characterleave",{ tempid = kk })
			end
			--通知其他对象移除自己
			local templist = table.copy(leavelist)
			for _,vv in pairs(templist) do
				vv.cansend = true
			end
			user.send_boardrequest("characterleave",{ tempid = user.character:gettempid() },templist)
		end
		--进入视野
		if not table.empty(enterlist) then
			for _,vv in pairs(enterlist) do
				skynet.send(vv.agent, "lua", "updateinfo", { aoiobj = user.character:getaoiobj() })
			end
		end
	end)
end

--创建reader
function CMD.getwritecopy()
	--log.debug ("user(%s) create_reader",user.uid)
	return user.character:getwritecopy()
end

--离开地图的时候调用
--通知其他玩家移除自己
function CMD.delaoiobj(_,tempid)
	_G.instance.aoi.updateagentlist()
	local agentlist = user.character:getaoilist()
	if not table.empty(agentlist) then
		for _,v in pairs(agentlist) do
			skynet.send(v.agent, "lua", "leaveaoiobj", tempid);
		end
	end
	user.send_boardrequest("characterleave",{ tempid = user.character:gettempid() })
	user.character:cleanaoilist()
	user.character:cleanreaderlist()
end

function CMD.leaveaoiobj(_,tempid)
	user.character:delfromaoilist(tempid)
	user.character:delfromreaderlist(tempid)
end

function CMD.addaoiobj(_,aoiobj)
	--log.debug("user(%s) can watch user(%s)",user.character.aoiobj.tempid,aoiobj.tempid)
	local reader = user.character:getreaderfromlist(aoiobj.tempid)
	if reader == nil then
		reader = user.character:createreader(skynet.call(aoiobj.agent,"lua","getwritecopy"))
		user.character:addtoreaderlist(aoiobj.tempid,reader)
		user.character:addtoaoilist(aoiobj)
		skynet.send(aoiobj.agent, "lua", "updateinfo", { aoiobj = user.character:getaoiobj() })
		user.CMD.updateinfo()
	end
end

function CMD.boardcast(_, gate, package, list)
	if gate then
		if list then
			assert(type(list) == "table","boardcast list is not a table")
			skynet.send(gate, "lua", "boardrequest", package, list);
		else
			_G.instance.aoi.updateagentlist()
			local agentlist = user.character:getaoilist()
			if not table.empty(agentlist) then
				skynet.send(gate, "lua", "boardrequest", package, agentlist);
			end
		end
	end
end

return _handler
