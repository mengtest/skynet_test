local skynet = require "skynet"
local config = require "config.system"
local protopatch = require "config.protopatch"

skynet.start(function()
	skynet.error("Server start")
	skynet.newservice("debug_console",config.debug_port)
	
	--加载解析proto文件
	local proto = skynet.uniqueservice "protoloader"
	skynet.call(proto, "lua", "load", protopatch)

	skynet.uniqueservice "dbmgr"

	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated",loginserver)

	skynet.call(gate,"lua","open",config.gated)
end)