local basechar = require "obj.basechar"

local _player = {}
local s_method = {__index = {}}

local function init_method(player)


  basechar.expandmethod(player)
end
init_method(s_method.__index)

--创建player
function _player.create()
  local player = basechar.create()
  --player 特有属性

  player = setmetatable(player, s_method)

  return player
end

return _player
