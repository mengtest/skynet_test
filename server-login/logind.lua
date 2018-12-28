local login = require "snax.loginserver"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local config = require "config.loginconfig"
local log = require "syslog"
local cluster = require "skynet.cluster"

local server = config

local dbmgrserver

-- 服务器列表
local server_list = {}
-- 在线玩家列表
local user_online = {}

-- 认证
-- 在这个方法内做远程调用（skynet.call）是安全的。
function server.auth_handler(token)
    -- the token is base64(user)@base64(server):base64(password)
    local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
    user = crypt.base64decode(user)
    server = crypt.base64decode(server)
    password = crypt.base64decode(password)
    assert(password == "password", "Invalid password")
    log.debug("%s@%s is auth, password is %s", user, server, password)
    if not dbmgrserver then
        dbmgrserver = skynet.uniqueservice "dbmgr"
    end

    -- 数据库查询账号信息
    -- 没有就创建
    local result = skynet.call(dbmgrserver, "lua", "account", "auth", user, password)
    local str = "auth false"
    if result then
        str = "auth success"
    end
    log.debug("%s " .. str, user)
    return server, user
end

-- 登陆到游戏服务器
function server.login_handler(server, uid, secret)
    log.notice("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret))
    -- 校验要登陆的服务器是否存在
    -- gate启动的时候注册到server_list了
    local gameserver = assert(server_list[server], "Unknown server :" .. server)
    -- only one can login, because disallow multilogin
    local last = user_online[uid]
    -- 已经登陆了的话，把上次登录的踢下线
    if last then
        skynet.call(last.address, "lua", "kick", uid, last.subid)
    end
    if user_online[uid] then
        log.warning("user %s is already online", uid)
    end
    -- 向服务器发送登陆请求
    local subid, gateip, gateport = skynet.call(gameserver, "lua", "login", uid, secret)
    subid = tostring(subid)
    user_online[uid] = {
        address = gameserver,
        subid = subid,
        server = server
    }
    return subid, gateip, gateport
end

-- login启动的时候，尝试获取所有gate的地址
function server.register_gate()
    local config_name = skynet.getenv "cluster"
    local tmp = {}
    if config_name then
        local f = assert(io.open(config_name))
        local source = f:read "*a"
        f:close()
        assert(load(source, "@" .. config_name, "t", tmp))()
    end
    for k, _ in pairs(tmp) do
        if string.find(k, "game") ~= nil then
            local gated = cluster.proxy(k, "@gated")
            server_list[k] = gated
            local ok, userlist = pcall(cluster.call, k, "@gated", "getalluser")
            if ok then
                for uid, _subid in pairs(userlist) do
                    user_online[uid] = {
                        address = gated,
                        subid = _subid,
                        server = k
                    }
                end
            end
        end
    end
end

local CMD = {}

-- 玩家下线
function CMD.logout(uid, subid)
    local u = user_online[uid]
    if u then
        log.notice("%s@%s is logout", uid, u.server)
        user_online[uid] = nil
    end
end

function server.command_handler(command, ...)
    local f = assert(CMD[command])
    return f(...)
end

login(server)
