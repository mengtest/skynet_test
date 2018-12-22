local skynet = require"skynet"

local _timer = {}

function _timer.gettime() return skynet.time() end

return _timer
