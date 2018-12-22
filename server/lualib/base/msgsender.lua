-- 与客户端的消息通讯
local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local socketdriver = require "skynet.socketdriver"
local string = string
local request

local _msgsender = {}
local s_method = {
    __index = {}
}

local function init_method(func)
    function func:boardcast(package, list, obj)
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
    function func:sendrequest(name, args, user)
        assert(name)
        assert(args)
        local str = request(name, args)
        local package = string.pack(">s2", str)
        socketdriver.send(user.fd, package)
    end

    -- 发送广播请求
    function func:sendboardrequest(name, args, agentlist, user)
        assert(name)
        assert(args)
        local str, resp = request(name, args)
        local package = string.pack(">s2", str)
        self:boardcast(package, agentlist, user)
    end

    function func:gethost()
        return self.host
    end

    function func:init()
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
        host = nil
    }

    setmetatable(msgsender, s_method)
    return msgsender
end

return _msgsender
