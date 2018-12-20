--系统配置
local config = {}

config.debug_port = 8123
config.log_level = 1

config.logind = {
	host = "0.0.0.0",
	port = 8101,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

config.gated = {
	address = "0.0.0.0",
	port = 8547,
	maxclient = 64,
	nodelay = true,
	servername = "game0",
	agentpool = 1
}

return config
