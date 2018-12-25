-- 系统配置
local config = {}

config = {
    debug_port = 8123,
    log_level = 1,
    host = "0.0.0.0",
    port = 8101,
    multilogin = false, -- disallow multilogin
    name = "login_master",
    instance = 8
}

return config
