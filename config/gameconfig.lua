-- 系统配置
local config = {}

config = {
    game0 = {
        debug_port = 8124,
        log_level = 1,
        address = "0.0.0.0", -- server监听地址
        publicaddress = "127.0.0.1", -- client连接地址
        port = 8547,
        maxclient = 64,
        nodelay = true,
        servername = "game0",
        agentpool = 2
    },
    game1 = {
        debug_port = 8125,
        log_level = 1,
        address = "0.0.0.0",
        publicaddress = "127.0.0.1",
        port = 8548,
        maxclient = 64,
        nodelay = true,
        servername = "game1",
        agentpool = 2
    }
}

return config
