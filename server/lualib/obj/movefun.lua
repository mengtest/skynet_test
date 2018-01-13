local _moveobj = {}
local s_method = {__index = {}}

local function init_method(obj)
  function obj:delayrun(currenttime)

  end
end
init_method(s_method.__index)

function _moveobj.create()
  local moveobj = {
    delay = {
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
  }
end

return _moveobj
