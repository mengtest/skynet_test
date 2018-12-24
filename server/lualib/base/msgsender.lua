-- 与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local socketdriver = require "skynet.socketdriver"
local string = string
local request

local msgsender = {}

local host

function msgsender.boardcast(package, list, obj)
    if list == nil then
        assert(obj)
        list = obj:getsend2clientaoilist()
    end
    assert(type(list) == "table", "boardcast list is not a table")
    for _, v in pairs(list) do
        socketdriver.send(v.fd, package)
    end
end

-- 发送请求
function msgsender.sendrequest(name, args, user)
    assert(name)
    assert(args)
    local str = request(name, args)
    local package = string.pack(">s2", str)
    socketdriver.send(user.fd, package)
end

-- 发送广播请求
function msgsender.sendboardrequest(name, args, agentlist, user)
    assert(name)
    assert(args)
    local str, resp = request(name, args)
    local package = string.pack(">s2", str)
    msgsender.boardcast(package, agentlist, user)
end

function msgsender.gethost()
    return host
end

function msgsender.init()
    local protoloader = skynet.uniqueservice "protoloader"
    local slot = skynet.call(protoloader, "lua", "index", "clientproto")
    host = sprotoloader.load(slot):host "package"
    slot = skynet.call(protoloader, "lua", "index", "serverproto")
    request = host:attach(sprotoloader.load(slot))
end

return msgsender
