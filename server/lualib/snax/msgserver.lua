local skynet = require "skynet"
local gateserver = require "snax.gateserver"
local netpack = require "skynet.netpack"
local crypt = require "skynet.crypt"
local socketdriver = require "skynet.socketdriver"
local sprotoloader = require "sprotoloader"
local assert = assert
local b64encode = crypt.base64encode
local b64decode = crypt.base64decode

--[[

Protocol:

	All the number type is big-endian

	Shakehands (The first package)

	Client -> Server :

	base64(uid)@base64(server)#base64(subid):index:base64(hmac)

	Server -> Client

	XXX ErrorCode
		404 User Not Found
		403 Index Expired
		401 Unauthorized
		400 Bad Request
		200 OK

	Req-Resp

	Client -> Server : Request
		word size (Not include self)
		string content (size-4)
		dword session

	Server -> Client : Response
		word size (Not include self)
		string content (size-5)
		byte ok (1 is ok, 0 is error)
		dword session

API:
	server.userid(username)
		return uid, subid, server

	server.username(uid, subid, server)
		return username

	server.login(username, secret)
		update user secret

	server.logout(username)
		user logout

	server.ip(username)
		return ip when connection establish, or nil

	server.start(conf)
		start server

Supported skynet command:
	kick username (may used by loginserver)
	login username secret  (used by loginserver)
	logout username (used by agent)

Config for server.start:
	conf.expired_number : the number of the response message cached after sending out (default is 128)
	conf.login_handler(uid, secret) -> subid : the function when a new user login, alloc a subid for it. (may call by login server)
	conf.logout_handler(uid, subid) : the functon when a user logout. (may call by agent)
	conf.kick_handler(uid, subid) : the functon when a user logout. (may call by login server)
	conf.request_handler(username, session, msg) : the function when recv a new request.
	conf.register_handler(servername) : call when gate open
	conf.disconnect_handler(username) : call when a connection disconnect (afk)
]]
local server = {}

skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT
}

-- 在线玩家， logind 那边验证成功的玩家
-- 在gated那边已经为该玩家启动了msgagent
local user_online = {}
-- 正在认证中的玩家
local handshake = {}
-- 通过msgserver认证的玩家
local connection = {}

local host

-- 向指定玩家发送信息
function server.request(username, msg)
    local u = user_online[username]
    local fd = u.fd
    if fd then
        if connection[fd] then
            socketdriver.send(u.fd, msg)
        end
    end
end

-- 解析username
function server.userid(username)
    -- base64(uid)@base64(server)#base64(subid)
    local uid, servername, subid = username:match "([^@]*)@([^#]*)#(.*)"
    return b64decode(uid), b64decode(subid), b64decode(servername)
end

-- 合成username
function server.username(uid, subid, servername)
    return string.format("%s@%s#%s", b64encode(uid), b64encode(servername), b64encode(tostring(subid)))
end

-- 玩家下线
function server.logout(username)
    local u = user_online[username]
    user_online[username] = nil
    if u.fd then
        gateserver.closeclient(u.fd)
        connection[u.fd] = nil
    end
end

-- 玩家登陆
function server.login(username, secret)
    assert(user_online[username] == nil)
    user_online[username] = {
        secret = secret,
        version = 0,
        index = 0,
        username = username,
        response = {} -- response cache
    }
end

-- 获取玩家ip
function server.ip(username)
    local u = user_online[username]
    if u and u.fd then
        return u.ip
    end
end

-- 获取所有在线玩家的信息
local function getalluser()
    local userlist = {}
    local _uid
    local _subid
    for k, _ in pairs(user_online) do
        _uid, _subid = server.userid(k)
        userlist[_uid] = _subid
    end
    return userlist
end

-- gated调用了start函数
-- 将gated中注册的函数通过conf传递给msgserver
function server.start(conf)
    local expired_number = conf.expired_number or 128

    local handler = {}

    local CMD = {
        getalluser = getalluser,
        -- 这边主要是gated那边定义的函数
        login = assert(conf.login_handler),
        logout = assert(conf.logout_handler),
        kick = assert(conf.kick_handler),
        request = assert(conf.send_request_handler),
        boardrequest = assert(conf.send_board_request_handler),
        close = assert(conf.close_handler),
        auth_handler = assert(conf.auth_handler)
    }

    function handler.command(cmd, _, ...)
        local f = assert(CMD[cmd], cmd)
        return f(...)
    end

    function handler.open(_, gateconf)
        local protoloader = skynet.uniqueservice "protoloader"
        local slot = skynet.call(protoloader, "lua", "index", "clientproto")
        host = sprotoloader.load(slot):host "package"
        return conf.register_handler(gateconf)
    end

    -- 一个新的连接建立后，此处会被调用
    function handler.connect(fd, addr)
        handshake[fd] = addr
        gateserver.openclient(fd)
    end

    function handler.disconnect(fd)
        handshake[fd] = nil
        local c = connection[fd]
        if c then
            c.fd = nil
            connection[fd] = nil
            if conf.disconnect_handler then
                conf.disconnect_handler(c.username)
            end
        end
    end

    handler.error = handler.disconnect

    -- atomic , no yield
    local function do_auth(fd, message, addr)
        local username, index, hmac = string.match(message, "([^:]*):([^:]*):([^:]*)")
        local u = user_online[username]
        if u == nil then
            return "404 User Not Found"
        end
        local idx = assert(tonumber(index))
        hmac = b64decode(hmac)

        if idx <= u.version then
            return "403 Index Expired"
        end

        local text = string.format("%s:%s", username, index)
        local v = crypt.hmac_hash(u.secret, text) -- equivalent to crypt.hmac64(crypt.hashkey(text), u.secret)
        if v ~= hmac then
            return "401 Unauthorized"
        end

        u.version = idx
        u.fd = fd
        u.ip = addr
        connection[fd] = u

        CMD.auth_handler(username, fd)
    end

    local function auth(fd, addr, msg, sz)
        local message = netpack.tostring(msg, sz)
        local type, name, args, response = host:dispatch(message)
        assert(type == "REQUEST")
        if name == "login" then
            assert(args and args.handshake, "invalid login gameserver handshake request")
        end

        local ok, result = pcall(do_auth, fd, args.handshake, addr)
        if not ok then
            skynet.error(result)
            result = "400 Bad Request"
        end

        local close = result ~= nil

        if result == nil then
            result = "200 OK"
        end
        local package =
            response {
            result = result
        }
        socketdriver.send(fd, netpack.pack(package))

        if close then
            gateserver.closeclient(fd)
        end
    end

    assert(conf.request_handler)

    -- u.response is a struct { return_fd , response, version, index }
    local function retire_response(u)
        if u.index >= expired_number * 2 then
            local max = 0
            local response = u.response
            for k, p in pairs(response) do
                if p[1] == nil then
                    -- request complete, check expired
                    if p[4] < expired_number then
                        response[k] = nil
                    else
                        p[4] = p[4] - expired_number
                        if p[4] > max then
                            max = p[4]
                        end
                    end
                end
            end
            u.index = max + 1
        end
    end

    -- 这边会把response全部存起来，只有再完全重新登录才会清理掉，重新连接不会清理，只会有版本号的改变
    -- 暂时不启用
    local function do_request(fd, message)
        local u = assert(connection[fd], "invalid fd")

        local p = {fd}
        local ok, result = pcall(conf.request_handler, u.username, message)
        -- NOTICE: YIELD here, socket may close.
        result = result or ""
        if not ok then
            skynet.error(result)
        else
            result = result
        end
        p[2] = string.pack(">s2", result)
        p[3] = u.version
        p[4] = u.index

        u.index = u.index + 1
        -- the return fd is p[1] (fd may change by multi request) check connect
        fd = p[1]
        if connection[fd] then
            socketdriver.send(fd, p[2])
        end
        p[1] = nil
        -- retire_response(u)
    end

    local function request(fd, msg, sz)
        local message = netpack.tostring(msg, sz)
        local ok, err = pcall(do_request, fd, message)
        -- not atomic, may yield
        if not ok then
            skynet.error(string.format("Invalid package %s : %s", err, message))
            if connection[fd] then
                gateserver.closeclient(fd)
            end
        end
    end

    function handler.message(fd, msg, sz)
        local addr = handshake[fd]
        -- 当存在addr的时候，代表该连接需要认证
        -- 否则就是client发来的请求了
        if addr then
            auth(fd, addr, msg, sz)
            handshake[fd] = nil
        else
            request(fd, msg, sz)
        end
    end

    return gateserver.start(handler)
end

return server
