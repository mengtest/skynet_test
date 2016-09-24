local config = {}

config.debug_port = 8123

config.logind = {
	host = "127.0.0.1",
	port = 8001,
	multilogin = false,	-- disallow multilogin
	name = "login_master",
}

config.gated = {
	address = "127.0.0.1",
	port = 8547,
	maxclient = 64,
	servername = "sample",
}

return config