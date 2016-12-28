local skynet = require "skynet"
local config = require "config.system"
local protopatch = require "config.protopatch"
require "skynet.manager"

--[[cserver测试
local aoi = skynet.launch("test",skynet.self())
print(aoi)
]]

skynet.start(function()
	skynet.error("Server start")
	skynet.newservice("debug_console",config.debug_port)

	--加载解析proto文件
	local proto = skynet.uniqueservice "protoloader"
	skynet.call(proto, "lua", "load", protopatch)

	--试试将在启动logind的时候，将dbmgr的地址传过去
	--影响中貌似尝试过，但是失败了？有时间再次尝试一下
	skynet.uniqueservice "dbmgr"

	local loginserver = skynet.newservice("logind")
	local gate = skynet.newservice("gated",loginserver)

	skynet.call(gate,"lua","open",config.gated)
end)
