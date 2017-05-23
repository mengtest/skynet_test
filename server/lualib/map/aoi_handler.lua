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

function CMD.addaoiobj(aoiobj,tempid)
  assert(map_info)
  local monster = map_info:get_monster(tempid)
	local reader = monster:getreaderfromlist(aoiobj.tempid)
	if reader == nil then
		reader = monster:createreader(skynet.call(aoiobj.agent,"lua","getwritecopy"))
		monster:addtoreaderlist(aoiobj.tempid,reader)
		monster:addtoaoilist(aoiobj)
		--skynet.send(aoiobj.agent, "lua", "updateinfo", { aoiobj = monster:getaoiobj() })
	end
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
  msgsender:send_boardrequest("characterupdate",{ info = info },aoiobj)
end

function CMD.leaveaoiobj(objtempid, tempid)
  assert(objtempid)
  local monster = map_info:get_monster(tempid)
	monster:delfromaoilist(objtempid)
	monster:delfromreaderlist(objtempid)
end

return _handle
