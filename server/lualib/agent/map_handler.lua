local skynet = require"skynet"
local handler = require"agent.handler"

local REQUEST = {}

local _handler = handler.new(REQUEST)

local user

_handler:init(function(u) user = u end)

_handler:release(function() user = nil end)

-- client通知地图加载成功
function REQUEST.mapready()
    assert(user.map)
    user.character:setaoimode("wm")
    local ok = skynet.call(user.map, "lua", "characterready", user.character:getuuid(), user.character:getaoiobj())
    return {
        ok = ok
    }
end

return _handler
