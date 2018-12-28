local skynet = require "skynet"
local log = require "syslog"
local datasheet = require "skynet.datasheet"

local CMD = {}
local mapinstance = {}

-- 获取地图地址
function CMD.getmapaddressbyid(mapname)
    return mapinstance[mapname]
end

function CMD.open()
    local obj = datasheet.query "gamedata"
    local mapdata = obj["map"]
    local n = 1
    while n > 0 do
        for _, conf in pairs(mapdata) do
            local name = conf.name
            local m = skynet.newservice("map", name)
            skynet.call(m, "lua", "open", conf)
            skynet.call(m, "lua", "init", conf)
            mapinstance[name] = m
        end
        n = n - 1
    end
end

function CMD.close()
    log.notice("close mapmgr...")
    for name, map in pairs(mapinstance) do
        skynet.call(map, "lua", "close")
        mapinstance[name] = nil
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
