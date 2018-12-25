-- 系统配置
local config = {}

config = {
    debug_port = 8124,
    log_level = 1,
    address = "0.0.0.0",
    port = 8547,
    maxclient = 64,
    nodelay = true,
    servername = "game0",
    agentpool = 2
}

return config
