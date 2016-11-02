local skynet = require "skynet"
local service = require "service"

local CMD = {}
local servername = {
	"redispool",
}

function CMD.open()
	for _,v in pairs(servername) do
		skynet.call(service[v],"lua","open")
	end
end

service.init {
	command = CMD,
	require = servername,
}