local skynet = require "skynet"
local config = require "config.system"
local protopatch = require "config.protopatch"
local profile = require "skynet.profile"
local log = require "syslog"
local cluster = require "skynet.cluster"

skynet.start(
    function()
        log.debug(config.gated.servername .. " Server start")
        profile.start()
        local t = os.clock()
        -- 启动后台
        skynet.newservice("debug_console", 8124)

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", protopatch)

        -- 启动数据库
        local dbmgr = skynet.uniqueservice "dbmgr"
        skynet.call(dbmgr, "lua", "system", "open")

        -- 启动网关
        local gated = skynet.uniqueservice("gated")
        -- 注册服务名
        cluster.register("gated", gated)
        -- 注册自己
        cluster.open(config.gated.servername)

        skynet.call(gated, "lua", "open", config.gated)

        local time = profile.stop()
        local t1 = os.clock()
        log.debug("start server cost time:" .. time .. "==" .. (t1 - t))
        skynet.exit()
    end
)
