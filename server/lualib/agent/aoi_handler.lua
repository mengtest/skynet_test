local enumtype = require "enumtype"
local handler = require "agent.handler"
local skynet = require "skynet"

local CMD = {}
local _handler = handler.new (nil,nil,CMD)
local user
local running

_handler:init (function (u)
	user = u
	running = u.running
end)

_handler:release (function ()
	user = nil
end)

--添加对象到aoilist中
function CMD.addaoiobj(_,aoiobj)
	assert(user,{_,skynet.self(),running,aoiobj})
	if not user.character:getfromaoilist(aoiobj.tempid) then
		user.character:addtoaoilist(aoiobj)
		if aoiobj.type == enumtype.CHAR_TYPE_PLAYER then
			local info = {
				name = user.character:getname(),
				tempid = user.character:gettempid(),
				pos = user.character:getpos(),
			}
			--将我的信息发送给对方
			user.send_request("characterupdate",{info = info},nil,nil,{aoiobj.info})
		end
	end
end

--更新对象的aoiobj信息
function CMD.updateaoiobj(_,aoiobj)
	assert(user,{_,skynet.self(),running,aoiobj})
	user.character:updateaoiobj(aoiobj)
	local character_move = {
		tempid = aoiobj.tempid,
		pos = aoiobj.movement.pos,
	}
	user.send_request("moveto",{move = {character_move}})
end

--从自己的aoilist中移除对象
function CMD.delaoiobj(_,tempid)
	user.character:delfromaoilist(tempid)
	user.send_request("characterleave",{tempid = {tempid}})
end

--进入和离开我视野的列表
function CMD.updateaoilist(_,enterlist,leavelist)
	for _,v in pairs(enterlist) do
		for _,vv in pairs(v) do
			user.character:addtoaoilist(vv)
			if vv.type == enumtype.CHAR_TYPE_PLAYER then
				local info = {
					name = user.character:getname(),
					tempid = user.character:gettempid(),
					pos = user.character:getpos(),
				}
				--将我的信息发送给对方
				user.send_request("characterupdate",{info = info},nil,nil,{vv.info})
			end
		end
	end
	local leaveid = {}
	for _,v in pairs(leavelist) do
		for _,vv in pairs(v) do
			user.character:delfromaoilist(vv.tempid)
			table.insert( leaveid, vv.tempid )
		end
	end
	user.send_request("characterleave",{tempid = leaveid})
end

return _handler
