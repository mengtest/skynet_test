local skynet = require "skynet"
local handler = require "agent.handler"

local REQUEST = {}

local _handler = handler.new (REQUEST)

local user

_handler:init (function (u)
	user = u
end)

function REQUEST.moveto (args)
  local newpos = args.pos
  local oldpos = user.character.aoiobj.pos
  for k, v in pairs (oldpos) do
    if not newpos[k] then
      newpos[k] = v
    end
  end
  user.character.aoiobj.pos = newpos
  local ok, pos = skynet.call(user.map,"lua","moveto",skynet.self(),user.character.aoiobj)
  if not ok then
    pos = oldpos
  end
  return { pos = pos }
end

return _handler
