local skynet = require "skynet"
local handler = require "agent.handler"

local REQUEST = {}

local _handler = handler.new(REQUEST)

local user

_handler:init(
    function(u)
        user = u
    end
)

_handler:release(
    function()
        user = nil
    end
)

-- client通知地图加载成功
function REQUEST.mapready()
    user.character:setaoimode("wm")
    local ok = skynet.call(user.character:getmapaddress(), "lua", "characterenter", user.character:getaoiobj())
    return {
        ok = ok
    }
end

-- 请求改变地图
function REQUEST.changemap(args)
    assert(args.mapid)
    local ok = false
    local mapaddress = skynet.call(mapmgr, "lua", "getmapaddressbyid", args.mapid)
    if mapaddress ~= nil then
        user.character:setaoimode("w")
        local tempid = skynet.call(mapaddress, "lua", "gettempid")
        if tempid > 0 then
            skynet.send(user.character:getmapaddress(), "lua", "characterleave", user.character:getaoiobj())
            user.character:setmapaddress(mapaddress)
            user.character:settempid(tempid)
            user.character:setmapid(args.mapid)
            ok = true
            log.debug("change map and set tempid:" .. user.character:gettempid())
        else
            log.debug("player change map failed:" .. user.character:getmapid())
        end
    else
        log.debug("player get change map address failed:" .. user.character:getmapid())
    end
    return {
        ok = ok
    }
end

return _handler
