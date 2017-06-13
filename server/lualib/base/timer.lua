local skynet = require "skynet"

local _timer = {}

function _timer.get_time()
  return skynet.time()
end

return _timer
