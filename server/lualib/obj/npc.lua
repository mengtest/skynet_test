local basechar = require "obj.basechar"
local enumtype = require "enumtype"

local _npc = {}
local s_method = {__index = {}}

local function init_method(npc)
  --获取npcid
  function npc:getid()
    return self.id
  end

  basechar.expandmethod(npc)
end
init_method(s_method.__index)

--创建npc
function _npc.create(id,agent)
  local npc = basechar.create(enumtype.CHAR_TYPE_NPC,agent)
  --npc 特有属性
  npc.id = 0

  npc = setmetatable(npc, s_method)

  assert(id > 0)
  npc.id = id
  return npc
end

return _npc
