--系统配置
local config = {}

config.debug_port = 8123
config.log_level = 1

config.logind = {
	host = "127.0.0.1",
	port = 8101,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

config.gated = {
	address = "127.0.0.1",
	port = 8547,
	maxclient = 64,
	servername = "sample",
	agentpool = 1
}

return config
