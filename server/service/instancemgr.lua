local skynet = require "skynet"
local log = require "syslog"

local CMD = {}
local instancepool = {}

-- 获取地图地址
function CMD.getinstanceaddress()
    local instance
    if #instancepool == 0 then
        instance = skynet.newservice("map")
        log.debug("instancepool is empty, new instance(:%08X) created", instance)
    else
        instance = table.remove(instancepool, 1)
    end

    return instance
end

function CMD.releaseinstance(instance)
    table.insert(instancepool, instance)
end

function CMD.open(n)
    for _ = 1, n do
        local m = skynet.newservice("map")
        skynet.call(m, "lua", "open", {maxtempid = 65535})
        table.insert(instancepool, m)
    end
end

function CMD.close()
    log.notice("close instancemgr...")
    for name, map in pairs(instancepool) do
        skynet.call(map, "lua", "close")
        instancepool[name] = nil
    end
end

skynet.start(
    function()
        skynet.dispatch(
            "lua",
            function(_, source, command, ...)
                local f = assert(CMD[command])
                skynet.retpack(f(...))
            end
        )
    end
)
