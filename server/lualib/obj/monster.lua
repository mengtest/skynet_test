local basechar = require "obj.basechar"

local _monster = {}
local s_method = {__index = {}}

local function init_method(monster)
  --获取npcid
  function monster:getid()
    return self.id
  end

  basechar.expandmethod(monster)
end
init_method(s_method.__index)

--创建monster
function _monster.create()
  local monster = basechar.create()
  --monster特有属性
  monster.id = 0

  monster = setmetatable(monster, s_method)

  assert(id > 0)
  monster.id = id
  return monster
end

return _monster
