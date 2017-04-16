local skynet = require "skynet"

if not _G.instance then
	_G.instance = {}
end

if not _G.instance.util then
	_G.instance.util = {}
end

--设置定时器，返回函数
--调用返回的函数可以取消定时器
function _G.instance.util.set_timeout(ti, f)
  local function t()
    if f then
      f()
    end
  end
 skynet.timeout(ti, t)
 return function() f=nil end
end
