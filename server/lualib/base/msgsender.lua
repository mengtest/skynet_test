--与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local log = require "syslog"
local request

local _msgsender = {}
local s_method = {__index = {}}
local _sessionlen = 1024

local function init_method(func)

  function func:boardcast(package, list, obj)
    assert(self.gate)
		if list then
			assert(type(list) == "table","boardcast list is not a table")
			skynet.send(self.gate, "lua", "boardrequest", package, list);
		else
      assert(obj)
			local agentlist = obj:getsend2clientaoilist()
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

    local str, resp = request (name, args, self.session_id)
    str = str..string.pack(">BI4", 1, self.session_id)
    local package = string.pack (">s2", str)
    skynet.send(self.gate, "lua", "request", user.uid, user.subid,package);

    if resp then
      if table.size(self.session) > _sessionlen then
        log.debug("session overload!")
        for k,_ in pairs(self.session) do
          self.session[k] = nil
        end
      end
      self.session[self.session_id] = { name = name, args = args }
    end
  end

  --发送广播请求
  function func:send_boardrequest (name, args, agentlist, user)
    assert(name)
    assert(args)
    self.session_id = self.session_id + 1

    local str, resp = request (name, args, self.session_id)
    str = str..string.pack(">BI4", 1, self.session_id)
    local package = string.pack (">s2", str)
    self:boardcast(package, agentlist, user)

    if resp then
      if table.size(self.session) > _sessionlen then
        log.debug("session overload!")
        for k,_ in pairs(self.session) do
          self.session[k] = nil
        end
      end
      self.session[self.session_id] = { name = name, args = args }
    end
  end

  function func:get_host()
    return self.host
  end

  function func:init()
    self.session = {}
    self.session_id = 0

    local protoloader = skynet.uniqueservice "protoloader"
    local slot = skynet.call(protoloader, "lua", "index", "clientproto")
    self.host = sprotoloader.load(slot):host "package"
    slot = skynet.call(protoloader, "lua", "index", "serverproto")
    request = self.host:attach(sprotoloader.load(slot))
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

  return msgsender
end

return _msgsender
