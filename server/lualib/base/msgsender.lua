--与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local request

local _msgsender = {}
local s_method = {__index = {}}

local function init_method(func)

  function func:boardcast(package, list, tempid, obj)
    assert(self.gate)
		if list then
			assert(type(list) == "table","boardcast list is not a table")
			skynet.send(self.gate, "lua", "boardrequest", package, list);
		else
      assert(obj)
			local agentlist = obj:getaoilist()
			if not table.empty(agentlist) then
				skynet.send(self.gate, "lua", "boardrequest", package, agentlist);
			end
		end
  end

  --发送请求
  function func:send_request (name, args, user)
    assert(name)
    assert(args)
    assert(self.gate)
    self.session_id = self.session_id + 1

  	local str = request (name, args, self.session_id)
    str = str..string.pack(">I4", self.session_id)
    local package = string.pack (">s2", str)
    skynet.send(self.gate, "lua", "request", user.uid, user.subid,package);

  	self.session[self.session_id] = { name = name, args = args }
  end

  --发送广播请求
  function func:send_boardrequest (name, args, agentlist, user)
    assert(name)
    assert(args)
    --广播这边session_id暂时使用0，看需不需要也增加
  	local session_id = 0
  	local str = request (name, args, 0)
    str = str..string.pack(">I4", session_id)
    local package = string.pack (">s2", str)
    self:boardcast(package, agentlist, nil, user)
  	--session[session_id] = { name = name, args = args }
  end

  function func:get_host()
    return self.host
  end

  function func:init()
    self.session = {}
  	self.session_id = 0
  end
end

init_method(s_method.__index)

function _msgsender.create(gate)
  local msgsender = {
    gate = nil,
    host = nil,
    session = {},
    session_id = 0,
  }

  setmetatable(msgsender, s_method)

  assert(gate)
  msgsender.gate = gate

  local protoloader = skynet.uniqueservice "protoloader"
  local slot = skynet.call(protoloader, "lua", "index", "clientproto")
  msgsender.host = sprotoloader.load(slot):host "package"
  slot = skynet.call(protoloader, "lua", "index", "serverproto")
  request = msgsender.host:attach(sprotoloader.load(slot))

  return msgsender
end

return _msgsender
