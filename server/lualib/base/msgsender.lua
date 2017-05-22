--与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local host
local request

local _msgsender = {}
local s_method = {__index = {}}

local function init_method(func)
  function func:send_msg (msg,sessionid)
  	local str = msg..string.pack(">I4", sessionid)
  	local package = string.pack (">s2", str)
  	assert(self.gate)
  	skynet.send(self.gate, "lua", "request", user.uid, user.subid,package);
  end

  function func:boardcast(package, list,tempid)
  	assert(self.gate)
		if list then
			assert(type(list) == "table","boardcast list is not a table")
			skynet.send(self.gate, "lua", "boardrequest", package, list);
		else
      local monster = map_info:get_monster(tempid)
			_G.instance.aoi.updateagentlist()
			local agentlist = monster:getaoilist()
			if not table.empty(agentlist) then
				skynet.send(self.gate, "lua", "boardrequest", package, agentlist);
			end
		end
  end

  function func:send_boardmsg (msg, sessionid, agentlist)
  	local str = msg..string.pack(">I4", sessionid)
  	local package = string.pack (">s2", str)
  	self:boardcast(package, agentlist)
  end

  function func:send_request (name, args)
  	session_id = session_id + 1
  	local str = request (name, args, session_id)
  	send_msg (str,session_id)
  	session[session_id] = { name = name, args = args }
  end

  function func:send_boardrequest (name, args, agentlist)
  	--session_id = session_id + 1
  	local str = request (name, args, 0)
  	self:send_boardmsg (str, 0, agentlist)
  	--session[session_id] = { name = name, args = args }
  end
end

init_method(s_method.__index)

function _msgsender.create(gate)
  local msgsender = {
    gate = nil,
    session = 0,
    session_id = 0,
  }

  setmetatable(msgsender, s_method)

  assert(gate)
  msgsender.gate = gate

  local protoloader = skynet.uniqueservice "protoloader"
  local slot = skynet.call(protoloader, "lua", "index", "clientproto")
  host = sprotoloader.load(slot):host "package"
  slot = skynet.call(protoloader, "lua", "index", "serverproto")
  request = host:attach(sprotoloader.load(slot))

  return msgsender
end

return _msgsender
