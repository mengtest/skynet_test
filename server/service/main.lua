local skynet = require "skynet"
local config = require "config.system"

skynet.start(function()
	skynet.error("Server start")
	skynet.newservice("debug_console",config.debug_port)
	
	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated",loginserver)

	skynet.call(gate,"lua","open",config.gated)
end)