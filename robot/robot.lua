local skynet = require "skynet"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local sprotoloader = require "sprotoloader"
local util = require "util"
local robot_handler = require "robot.robot_handler"
local log = require "base.syslog"

local _robot = {}
local s_method = {
    __index = {}
}

local function unpack_package(text)
    local size = #text
    if size < 2 then
        return nil, text
    end
    local s = text:byte(1) * 256 + text:byte(2)
    if size < s + 2 then
        return nil, text
    end
    return text:sub(3, 2 + s), text:sub(3 + s)
end

local function recv_response(v)
    local content, ok = string.unpack("c" .. tostring(#v), v)
    return ok ~= 0, content
end

local function init_method(robot)
    function robot:send_request(name, args)
        self.session_id = self.session_id + 1
        local str = self.request(name, args, self.session_id)
        local package = string.pack(">s2", str)
        socket.write(self.fd, package)
        self.session[self.session_id] = {
            name = name,
            args = args
        }
    end

    function robot:unpack_f(f)
        local function try_recv(fd, last)
            local result
            result, last = f(last)
            if result then
                return result, last
            end
            local ok, r = socket.read(fd,2)
            if not ok then
                error "Server closed"
            end
            if not ok then
                return nil, last..r
            end
            
            last = last .. ok
            local s = ok:byte(1) * 256 + ok:byte(2)

            ok, r = socket.read(fd,s)
            if not ok then
                error "Server closed"
            end
            if not ok then
                return nil, last..r
            end
            
            return f(last .. ok)
        end

        -- 每秒尝试接受来自服务器的消息
        return function()
            while true do
                local result
                result, self.last = try_recv(self.fd, self.last)
                if result then
                    return result
                end
                skynet.sleep(1)
            end
        end
    end

    function robot:dispatch_message()
        local ok, content = recv_response(self.readpackage())
        assert(ok)
        local type, id, args, response = self.host:dispatch(content)
        if type == "RESPONSE" then
            local s = assert(self.session[id])
            self.session[id] = nil
            local f = self.RESPONSE[s.name]
            if f then
                f(self, args)
            else
                print("RESPONSE : " .. s.name)
            end
        elseif type == "REQUEST" then
            local f = self.REQUEST[id]
            if f then
                local r = f(self, args)
                if response then
                    local str = response(r)
                    local package = string.pack(">s2", str)
                    socket.write(self.fd, package)
                end
            else
                print("REQUEST : " .. id)
            end
        end
    end

    function robot:start()
        self.fd = assert(socket.open(self.loginserverip, self.loginserverport))

        self.clientkey = crypt.randomkey()
        self:send_request(
            "handshake",
            {
                clientkey = crypt.base64encode(crypt.dhexchange(self.clientkey))
            }
        )

        self.dispatchmessage_thread = util.fork(self.dispatch_message, self)
    end
    function robot:close()
        self.dispatchmessage_thread()
        socket.close(self.fd)
    end
end
init_method(s_method.__index)

function _robot.create(mapid, server, ip, port, robotindex)
    local obj = {
        REQUEST = {},
        RESPONSE = {},
        last = "",
        readpackage = nil,
        loginserverip = ip,
        loginserverport = port,
        gateip = nil,
        gateport = nil,
        fd = nil,
        account = "Robot_" .. robotindex,
        name = "Robot_" .. robotindex,
        session = {},
        session_id = 0,
        token = {
            server = server,
            user = "Robot_" .. robotindex,
            pass = "password"
        },
        challenge = nil,
        clientkey = nil,
        serverkey = nil,
        secret = nil,
        dispatchmessage_thread = nil,
        host = nil,
        request = nil,
        index = 1,
        mapid = mapid + 1
    }
    obj = setmetatable(obj, s_method)

    obj.readpackage = obj:unpack_f(unpack_package)

    robot_handler:register(obj)

    local protoloader = skynet.uniqueservice "protoloader"
    local slot = skynet.call(protoloader, "lua", "index", "serverproto")
    obj.host = sprotoloader.load(slot):host "package"
    slot = skynet.call(protoloader, "lua", "index", "clientproto")
    obj.request = obj.host:attach(sprotoloader.load(slot))

    return obj
end

return _robot
