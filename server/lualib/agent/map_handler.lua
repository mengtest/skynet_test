local skynet = require "skynet"
local handler = require "agent.handler"

local REQUEST = {}

local _handler = handler.new (REQUEST)

local user

_handler:init (function (u)
	user = u
end)

_handler:release (function ()
	user = nil
end)

function REQUEST.mapready ()
	assert(user.map)
	local ok = skynet.call (user.map, "lua", "characterready", skynet.self(),user.character.uuid,user.character.aoiobj)
	return { ok = ok }
end

return _handler
