local skynet = require "skynet"
local config = require "config.system"
local protopatch = require "config.protopatch"
local profile = require "profile"
local log = require "syslog"

skynet.start(function()
	profile.start()
	local t = os.clock()
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
	local t1 = os.clock()
	log.debug("start server cost time:"..time.."=="..(t1-t))
	skynet.exit()
end)
