local skynet = require "skynet"
local basechar = require "obj.basechar"
local enumtype = require "enumtype"
local random = math.random
local _monster = {}
local s_method = {__index = {}}

local function init_method(monster)
  --获取npcid
  function monster:getid()
    return self.id
  end

  function monster:run(aoisvr)
    --视野范围内没有人的时候，不run
    if table.size(self:getaoilist()) == 0 then return end
    local pos = self:getpos()
    local n = random(10000)
    local datlex
    if n > 5000 then
      datlex = 10
    else
      datlex = -10
    end
    local y = random(10000)
    local datley
    if y > 5000 then
      datley = 10
    else
      datley = -10
    end
    pos.x = pos.x + datlex
    if  pos.x > 300 then
      pos.x = 300
    elseif pos.x < -300 then
      pos.x = -300
    end
    pos.y = pos.y + datley
    if  pos.y > 300 then
      pos.y = 300
    elseif  pos.y < -300 then
        pos.y = -300
    end
    self:setpos(pos)
    skynet.send(aoisvr,"lua","characterenter",self:getaoiobj())
  end

  basechar.expandmethod(monster)
end
init_method(s_method.__index)

--创建monster
function _monster.create(id,tempid,conf,mapobj)
  local monster = basechar.create(enumtype.CHAR_TYPE_MONSTER)
  --monster特有属性
  monster.id = 0

  monster = setmetatable(monster, s_method)

  assert(id > 0)
  assert(tempid > 0)
  --设置怪物的id
  monster.id = id

  --设置怪物的aoi对象
  local aoiobj = {
		movement = {
			mode = "m",
			pos = {
				x = conf.x,
				y = conf.y,
				z = conf.z,
			},
      map = mapobj:getmapid(),
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
