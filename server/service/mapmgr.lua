local skynet = require "skynet"
local log = require "syslog"
local datasheet = require "skynet.datasheet"

local CMD = {}
local mapinstance = {}

-- 获取地图地址
function CMD.getmapaddressbyid(mapid)
    return mapinstance[mapid]
end

function CMD.open()
    local obj = datasheet.query "gamedata"
    local mapdata = obj["map"]
    local n = 1
    while n > 0 do
        for mapid, conf in pairs(mapdata) do
            local m = skynet.newservice("map", conf.name)
            skynet.call(m, "lua", "open", conf)
            skynet.call(m, "lua", "init", conf)
            mapinstance[mapid] = m
        end
        n = n - 1
    end
end

function CMD.close()
    log.notice("close mapmgr...")
    for mapid, mapaddress in pairs(mapinstance) do
        skynet.call(mapaddress, "lua", "close")
        mapinstance[mapid] = nil
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
