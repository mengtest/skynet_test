--与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local socketdriver = require "skynet.socketdriver"
local log = require "syslog"
local request

local _msgsender = {}
local s_method = {__index = {}}
local _sessionlen = 1024

local function init_method(func)

  function func:boardcast(package, list, obj)
    if list == nil then
      assert(obj)
      list = obj:getsend2clientaoilist()
    end
    assert(type(list) == "table","boardcast list is not a table")
    for _,v in pairs(list) do
      socketdriver.send(v.fd, package)
    end
  end

  --发送请求
  function func:sendrequest (name, args, user)
    assert(name)
    assert(args)
    self.session_id = self.session_id + 1

    local str, resp = request (name, args, self.session_id)
    str = str..string.pack(">BI4", 1, self.session_id)
    local package = string.pack (">s2", str)

    socketdriver.send(user.fd, package)

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
  function func:sendboardrequest (name, args, agentlist, user)
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

  function func:gethost()
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

function _msgsender.create()
  local msgsender = {
    host = nil,
    session = {},
    session_id = 0,
  }

  setmetatable(msgsender, s_method)
  return msgsender
end

return _msgsender
