local skynet = require "skynet"
local handler = require "agent.handler"
local datasheet = require "skynet.datasheet"

local REQUEST = {}

local _handler = handler.new(REQUEST)

local user
local instanceaddress

_handler:init(
    function(u)
        user = u
    end
)

_handler:release(
    function()
        user = nil
        if instanceaddress ~= nil then
            skynet.send(instancemgr, "lua", "releaseinstance", instanceaddress)
            instanceaddress = nil
        end
    end
)

-- 请求进入副本
function REQUEST.enterinstance(args)
    assert(args.instanceid)
    local ok = false
    local obj = datasheet.query "gamedata"
    local insatncedata = obj["insatnce"][args.instanceid]
    if insatncedata ~= nill then
        if instanceaddress = nil then
            local instancemgr = skynet.uniqueservice("instancemgr")
            instanceaddress = skynet.call(instancemgr, "lua", "getinstanceaddress")
        end
        
        if instanceaddress ~= nil then
            skynet.call(instanceaddress, "lua", "init", insatncedata)
            local tempid = skynet.call(instanceaddress, "lua", "gettempid")
            if tempid > 0 then
                user.character:setaoimode("w")
                skynet.send(user.character:getmapaddress(), "lua", "characterleave", user.character:getaoiobj())
                user.character:setmapaddress(instanceaddress)
                user.character:settempid(tempid)
                --user.character:setmapid(args.mapid)
                ok = true
                log.debug("enterinstance and set tempid:" .. user.character:gettempid())
            else
                log.debug("player enterinstance failed:" .. args.instanceid)
            end
        else
            log.debug("player get enterinstance address failed:" .. args.instanceid)
        end
    else
        log.debug("player enter instance failed, cannot find instance id:" .. args.instanceid)
    end
    return {
        ok = ok
    }
end

return _handler
