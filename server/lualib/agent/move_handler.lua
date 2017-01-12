local skynet = require "skynet"
local handler = require "agent.handler"

local REQUEST = {}
local CMD = {}

local _handler = handler.new (REQUEST,nil,CMD)

local user

_handler:init (function (u)
	user = u
end)

function CMD.updateinfo()
	local info = {
		name = user.character.name,
		tempid = user.character.aoiobj.tempid,
		job = user.character.job,
		sex = user.character.sex,
		level = user.character.level,
		pos = user.character.aoiobj.pos,
	}
	user.send_boardrequest("characterupdate",{ info = info })
end

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
	CMD.updateinfo()
  return { pos = pos }
end

return _handler
