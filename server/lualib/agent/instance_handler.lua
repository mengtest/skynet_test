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

        end
    end
)

-- 请求进入副本
function REQUEST.enterinstance(args)
    assert(args.instanceid)
    assert(user.mapaddress)
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
            user.character:setaoimode("w")
            local tempid = skynet.call(instanceaddress, "lua", "gettempid")
            if tempid > 0 then
                skynet.send(instanceaddress, "lua", "characterleave", user.character:getaoiobj())
                user.mapaddress = instanceaddress
                user.character:settempid(tempid)
                user.character:setinstanceaddress(instanceaddress)
                --user.character:setmapid(args.mapid)
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
