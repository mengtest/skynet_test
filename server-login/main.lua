local skynet = require "skynet"
local config = require "config.system"
local protopatch = require "config.protopatch"
local profile = require "skynet.profile"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug("Login Server start")
        profile.start()
        local t = os.clock()
        -- 启动后台
        skynet.newservice("debug_console", config.debug_port)

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", protopatch)

        -- 启动数据库
        local dbmgr = skynet.uniqueservice "dbmgr"
        skynet.call(dbmgr, "lua", "system", "open")

        -- 启动登录服务器
        local loginservice = skynet.uniqueservice("logind")
        -- 注册服务名
        cluster.register("loginservice", loginservice)

        -- 注册节点
        cluster.open("login")

        local time = profile.stop()
        local t1 = os.clock()
        log.debug("start server cost time:" .. time .. "==" .. (t1 - t))
        skynet.exit()
    end
)
