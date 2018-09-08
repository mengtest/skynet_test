local _moveobj = {}
local s_method = {__index = {}}

--间隔多久重新测试下网络延时
local enum_delay_test_time = (5) --5秒重新测试下延时

--最大网络延时 单位：毫秒
local enum_max_delay_time = 1000

local function init_method(obj)

  --延迟检测
  function obj:delayrun(nowtime)
    if nowtime - self.lasttesttime >= enum_delay_test_time then
      if self.alreadytestnum == -1 then
        self.alreadytestnum = 0
        self.reqtime = nowtime
        --user.sendrequest("delaytest",{time = mfloor(nowtime)})
      end
    end
  end

  function obj:delaytest(time)
    if self.alreadytestnum < 0 or
      self.alreadytestnum >= 3 or
      mfloor(self.reqtime) ~= time then
      return
    end

    local time = timer.gettime()
    self.alreadytestnum = self.alreadytestnum + 1
    self.delayvalue[self.alreadytestnum] = time - self.reqtime
    if self.alreadytestnum < 3 then
      --user.sendrequest("delaytest",{time = mfloor(time)})
      return
    end

    local total = 0
    for _,v in pairs(self.delayvalue) do
      total = total + v
    end
    self.delaytime = mfloor(total / self.alreadytestnum)
    if self.delaytime > enum_max_delay_time then
      self.delaytime = enum_max_delay_time
    end

    self.alreadytestnum = -1
    self.lasttesttime = time

    --user.sendrequest("delayresult",{time = self.delaytime})
  end
end
init_method(s_method.__index)

function _moveobj.create()
  local moveobj = {
    --上次测试延时的时间
    lasttesttime = 0,

    --发送请求的时间
    reqtime = 0,

    --延迟
    delaytime = 100,

    --三次测试延时
    delayvalue = {
      [1] = 0,
      [2] = 0,
      [3] = 0,
    },

    --测试次数
    alreadytestnum = -1,
  }

  moveobj = setmetatable(moveobj, s_method)
  return moveobj
end

return _moveobj
