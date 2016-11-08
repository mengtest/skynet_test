local skynet = require "skynet"
local account = require "db.account"

local MODULE = {}
local service = {}
local servername = {
	"redispool",
	"mysqlpool",
	"dbsync",
}

local function module_init (name, mod)
	MODULE[name] = mod
	mod.init (service)
end

skynet.start(function()
	if servername then
		local s = servername
		for _, name in ipairs(s) do
			service[name] = skynet.uniqueservice(name)
		end
	end

	for _,v in pairs(servername) do
		skynet.call(service[v],"lua","open")
	end
	
	module_init ("account", account)

	skynet.dispatch("lua", function (_,_, cmd, subcmd, ...)
		local m = MODULE[cmd]
		if not m then
			log.notice("Unknown command : [%s]", cmd)
			skynet.response()(false)
		end
		local f = m[subcmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log.notice("Unknown sub command : [%s]", subcmd)
			skynet.response()(false)
		end
	end)
end)