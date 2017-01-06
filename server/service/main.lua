local skynet = require "skynet"
local config = require "config.system"
local protopatch = require "config.protopatch"
local profile = require "profile"
local log = require "syslog"
--[[require "skynet.manager"

--cserver测试
local aoi = skynet.launch("test",skynet.self())
]]
skynet.start(function()
	profile.start()
	skynet.error("Server start")
	skynet.newservice("debug_console",config.debug_port)

	--加载解析proto文件
	local proto = skynet.uniqueservice "protoloader"
	skynet.call(proto, "lua", "load", protopatch)

	local dbmgr = skynet.uniqueservice "dbmgr"
	skynet.call(dbmgr,"lua","system","open")

	skynet.uniqueservice "namecheck"

	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated",loginserver)

	skynet.call(gate,"lua","open",config.gated)
	local time = profile.stop()
	log.debug("start server cost time:"..time)
end)
