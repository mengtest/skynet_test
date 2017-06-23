local skynet = require "skynet"
local handler = require "agent.handler"
local timer = require "timer"
local mfloor = math.floor

local REQUEST = {}
local RESPONSE = {}
local CMD = {}

local _handler = handler.new (REQUEST,RESPONSE,CMD)

local user
--间隔多久重新测试下网络延时
local enum_delay_test_time = (1) --5秒重新测试下延时

--最大网络延时 单位：毫秒
local enum_max_delay_time = 1000

--上次测试延时的时间
local lasttesttime = 0

--发送请求的时间
local reqtime = 0

--延迟
local delaytime = 100

--三次测试延时
local delayvalue = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
}

--测试次数
local alreadytestnum = -1

_handler:init (function (u)
	user = u
	alreadytestnum = -1
end)

_handler:release (function ()
	user = nil
end)

--延迟检测
function CMD.delay_run(nowtime)
	if nowtime - lasttesttime >= enum_delay_test_time then
		if alreadytestnum == -1 then
			alreadytestnum = 0
			reqtime = nowtime
			user.send_request("delaytest",{time = mfloor(nowtime)})
		end
	end
end

--发送个人信息
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

--client回应的延迟检测
function RESPONSE.delaytest(args)
	if alreadytestnum < 0 or
		alreadytestnum >= 3 or
		mfloor(reqtime) ~= args.time then
		return
	end

	local time = timer.get_time()
	alreadytestnum = alreadytestnum + 1
	delayvalue[alreadytestnum] = time - reqtime
	if alreadytestnum < 3 then
		user.send_request("delaytest",{time = mfloor(time)})
		return
	end

	local total = 0
	for _,v in pairs(delayvalue) do
		total = total + v
	end
	delaytime = mfloor(total / alreadytestnum)
	if delaytime > enum_max_delay_time then
		delaytime = enum_max_delay_time
	end

	alreadytestnum = -1
	lasttesttime = time

	user.send_request("delayresult",{time = delaytime})
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
		user.character:setpos(pos)
  end

	--更新writer
	user.character:writercommit()
	--通知其他对象自己坐标改变
	CMD.updateinfo()
  return { pos = pos }
end

return _handler
