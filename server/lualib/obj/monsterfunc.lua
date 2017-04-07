local log = require "syslog"
local objfunc = require "obj.objfunc"

local _monster = {}

objfunc:register(_monster)

function _monster.init()
  print("monster cmd init")
  _monster.run()
end

function _monster.aaa()

end

return _monster
