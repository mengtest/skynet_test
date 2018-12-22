local skynet = require"skynet"
local handler = require"agent.handler"
local timer = require"timer"
local mfloor = math.floor

local REQUEST = {}
local RESPONSE = {}
local CMD = {}

local _handler = handler.new(REQUEST, RESPONSE, CMD)

local user

_handler:init(function(u)
    user = u
    alreadytestnum = -1
end)

_handler:release(function() user = nil end)

function REQUEST.moveto(args)
    local newpos = args.pos
    local oldpos = user.character:getpos()
    for k, v in pairs(oldpos) do
        if not newpos[k] then
            newpos[k] = v
        end
    end
    user.character:setpos(newpos)
    local ok, pos = skynet.call(user.map, "lua", "moveto", user.character:getaoiobj())
    if not ok then
        pos = oldpos
        user.character:setpos(pos)
    end
    return {
        pos = pos
    }
end

return _handler
