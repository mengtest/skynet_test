local skynet = require "skynet"
local handler = require "agent.handler"

local REQUEST = {}
local CMD = {}

local _handler = handler.new (REQUEST,nil,CMD)

local user

_handler:init (function (u)
	user = u
end)

_handler:release (function ()
	user = nil
end)

function CMD.updateinfo(_,aoiobj)
	local info = {
		name = user.character:getname(),
		tempid = user.character:gettempid(),
		job = user.character:getjob(),
		sex = user.character:getsex(),
		level = user.character:getlevel(),
		pos = user.character:getpos(),
	}
	--这边如果不排除自己，前端会卡，具体有时间查一下
	user.send_request("characterupdate", { info = info }, true, true, aoiobj)
end

function REQUEST.moveto (args)
  local newpos = args.pos
  local oldpos = user.character:getpos()
  for k, v in pairs (oldpos) do
    if not newpos[k] then
      newpos[k] = v
    end
  end
	user.character:setpos(newpos)
  local ok, pos = skynet.call(user.map,"lua","moveto",user.character:getaoiobj())
  if not ok then
    pos = oldpos
  end
	user.character:setpos(pos)
	--更新writer
	user.character:writercommit()
	--通知其他对象自己坐标改变
	CMD.updateinfo()
  return { pos = pos }
end

return _handler
