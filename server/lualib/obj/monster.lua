local basechar = require "obj.basechar"
local enumtype = require "enumtype"

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
function _monster.create(id,agent)
  local monster = basechar.create(enumtype.CHAR_TYPE_MONSTER,agent)
  --monster特有属性
  monster.id = 0

  monster = setmetatable(monster, s_method)

  assert(id > 0)
  monster.id = id
  return monster
end

return _monster
