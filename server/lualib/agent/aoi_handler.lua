local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"
local enumtype = require "enumtype"

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

--创建reader
function CMD.getwritecopy()
	--log.debug ("user(%s) create_reader",user.uid)
	return user.character:getwritecopy()
end

--离开地图的时候调用
--通知其他玩家移除自己
function CMD.delaoiobj(_,tempid)
	local agentlist = user.character:getaoilist()
	if not table.empty(agentlist) then
		for _,v in pairs(agentlist) do
			skynet.send(v.agent, "lua", "leaveaoiobj", tempid, v.tempid);
		end
	end
	user.send_request("characterleave",{ tempid = user.character:gettempid() }, true)
	user.character:cleanaoilist()
	user.character:cleanreaderlist()
end

function CMD.leaveaoiobj(_,tempid)
	user.character:delfromaoilist(tempid)
	user.character:delfromreaderlist(tempid)
end

--添加一个新的对象到自己的aoilist中
function CMD.addaoiobj(_,aoiobj)
	--log.debug("user(%s) can watch user(%s)",user.character.aoiobj.tempid,aoiobj.tempid)
	local reader = user.character:getreaderfromlist(aoiobj.tempid)
	if reader == nil then
		reader = user.character:createreader(skynet.call(aoiobj.agent,"lua","getwritecopy",aoiobj.tempid))
		user.character:addtoreaderlist(aoiobj.tempid,reader)
		user.character:addtoaoilist(aoiobj)
		--通知对方发送aoi信息给自己
		skynet.send(aoiobj.agent, "lua", "updateinfo", { aoiobj = user.character:getaoiobj() },aoiobj.tempid)
		user.CMD.updateinfo()
	end
end

return _handler
