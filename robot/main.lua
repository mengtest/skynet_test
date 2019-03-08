local skynet = require "skynet"
local protopatch = require "config.protopatch"
local profile = require "skynet.profile"
local log = require "syslog"

skynet.start(
    function()
        log.debug("Robot Server start")
        profile.start()
        local t = os.clock()

        -- 加载解析proto文件
        local proto = skynet.uniqueservice "protoloader"
        skynet.call(proto, "lua", "load", protopatch)

        local totalmgr = 10
        local robotcount = 200
        local robotmgr = {}
        -- 启动N个服务
        for _ = 1, totalmgr do
            table.insert(robotmgr, skynet.newservice("robotmgr"))
        end

        --每个服务生成N个机器人
        for k, v in pairs(robotmgr) do
            skynet.call(v, "lua", "init", k - 1, robotcount, "game1", "192.168.0.191", 8101)
        end

        --机器人Run
        for _, v in pairs(robotmgr) do
            skynet.call(v, "lua", "start")
        end

        local time = profile.stop()
        local t1 = os.clock()
        log.debug("start server cost time:" .. time .. "==" .. (t1 - t))
        skynet.exit()
    end
)
