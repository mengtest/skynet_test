local handler = require "agent.handler"
local skynet = require "skynet"

local CMD = {}
local map_info
local _handle = { CMD = CMD,}

function _handle.init(info)
  map_info = info
end

function CMD.boardcast(_, gate, package, list,tempid)
	if gate then
		if list then
			assert(type(list) == "table","boardcast list is not a table")
			skynet.send(gate, "lua", "boardrequest", package, list);
		else
      --local monster = map_info:get_monster(tempid)
			--_G.instance.aoi.updateagentlist()
			--local agentlist = user.character:getaoilist()
			--if not table.empty(agentlist) then
			--	skynet.send(gate, "lua", "boardrequest", package, agentlist);
			--end
		end
	end
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
  map_info.CMD.send_boardrequest("characterupdate",{ info = info },aoiobj)
end

return _handle
