local handler = require "agent.handler"
local skynet = require "skynet"

local CMD = {}
local map_info
local msgsender
local _handle = { CMD = CMD,}

function _handle.init(info)
  map_info = info
  msgsender = map_info.msgsender
end

function CMD.boardcast(_, gate, package, list,tempid)
  msgsender:boardcast(package, list,tempid)
end

function CMD.getwritecopy(tempid)
  assert(map_info)
  assert(tempid)
  local monster = map_info:get_monster(tempid)
	return monster:getwritecopy()
end

--通知自己的aoi信息给aoiobj
function CMD.updateinfo(aoiobj,tempid)
  assert(tempid)
  local monster = map_info:get_monster(tempid)
  local info = {
    name = monster:getname(),
    tempid = monster:gettempid(),
    level = monster:getlevel(),
    pos = monster:getpos(),
  }
  msgsender:send_boardrequest("characterupdate", { info = info }, aoiobj, monster)
end

--离开地图的时候
--通知视野内对象
function CMD.delaoiobj(tempid)
  assert(objtempid)
  local monster = map_info:get_monster(tempid)
	local agentlist = monster:getaoilist()
  --通知视野内的对象删除自己
	if not table.empty(agentlist) then
		for _,v in pairs(agentlist) do
			skynet.send(v.agent, "lua", "leaveaoiobj", tempid, v.tempid);
		end
	end
  msgsender:send_boardrequest("characterleave", { tempid = monster:gettempid() }, agentlist)
	monster:cleanaoilist()
	monster:cleanreaderlist()
end

--某个对象离开视野
--objtempid离开tempid的视野
function CMD.leaveaoiobj(objtempid, tempid)
  assert(objtempid)
  local monster = map_info:get_monster(tempid)
	monster:delfromaoilist(objtempid)
	monster:delfromreaderlist(objtempid)
end

function CMD.addaoiobj(aoiobj,tempid)
  assert(map_info)
  local monster = map_info:get_monster(tempid)
	local reader = monster:getreaderfromlist(aoiobj.tempid)
	if reader == nil then
		reader = monster:createreader(skynet.call(aoiobj.agent,"lua","getwritecopy",aoiobj.tempid))
		monster:addtoreaderlist(aoiobj.tempid,reader)
		monster:addtoaoilist(aoiobj)
	end
end

return _handle
