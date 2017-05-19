local basechar = require "obj.basechar"
local enumtype = require "enumtype"

local _monster = {}
local s_method = {__index = {}}

local function init_method(monster)
  --获取npcid
  function monster:getid()
    return self.id
  end

  function monster:run()
    
  end

  basechar.expandmethod(monster)
end
init_method(s_method.__index)

--创建monster
function _monster.create(id,tempid,conf)
  local monster = basechar.create(enumtype.CHAR_TYPE_MONSTER)
  --monster特有属性
  monster.id = 0

  monster = setmetatable(monster, s_method)

  monster:createwriter()
  --设置为不发送消息
  monster:setcansend(false)
  assert(id > 0)
  assert(tempid > 0)
  --设置怪物的id
  monster.id = id

  --设置怪物的aoi对象
  local aoiobj = {
		movement = {
			mode = "wm",
			pos = {
				x = conf.x,
				y = conf.y,
				z = conf.z,
			},
		}
	}
  monster:setaoiobj(aoiobj)
  monster:settempid(tempid)
  --设置怪物信息
  local monsterinfo = {
		name = conf.name,
		sex = conf.sex,
		level = conf.level,
	}
	monster:setobjinfo(monsterinfo)
  return monster
end

return _monster
