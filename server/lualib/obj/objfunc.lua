local basefunc = require "obj.basefunc"
local log = require "syslog"

local CMD = {}
local _obj = basefunc.new(CMD)

_obj:init(function (o)
  print("_obj init")
end)
_obj:release(function (o)

end)

function CMD.init()
  print("base init")
end

function CMD.run()
  print("run")
end

return _obj
