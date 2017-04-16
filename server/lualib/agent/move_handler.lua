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
	user.send_boardrequest("characterupdate",{ info = info },aoiobj)
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

	--通知其他对象自己坐标改变
	skynet.fork(function ()
		_G.instance.aoi.updateagentlist()
		local agentlist = user.character:getaoilist()
		if not table.empty(agentlist) then
			local info = {
				name = user.character:getname(),
				tempid = user.character:gettempid(),
				job = user.character:getjob(),
				sex = user.character:getsex(),
				level = user.character:getlevel(),
				pos = user.character:getpos(),
			}
			for _,v in pairs(agentlist) do
				if v.cansend then
					skynet.call(v.agent, "lua", "updatepos", info);
				end
			end
		end
	end)
  return { pos = pos }
end

return _handler
