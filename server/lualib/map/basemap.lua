local monster = require "obj.monster"
local idmgr = require "idmgr"
local skynet = require "skynet"
local random = math.random

local _map = {}
local aoisvr

local s_method = {__index = {}}

local function init_method(map)

  --怪物run
  function map:monsterrun()
    while true do
      for k,v in pairs(self.monster_runlist) do
        self.monster_list[k]:run(aoisvr)
      end
      skynet.sleep(10)
    end
  end

  function map:monsterrunlistadd(tempid)
    assert(not self.monster_runlist[tempid])
    self.monster_runlist[tempid] = true
  end

  function map:monsterrunlistdel(tempid)
    assert(self.monster_runlist[tempid])
    self.monster_runlist[tempid] = nil
  end

  --获取一个怪物
  function map:getmonster(tempid)
    assert(self.monster_list[tempid],tempid)
    return self.monster_list[tempid]
  end
  --创建一个临时id
  function map:createtempid()
    return idmgr:createid()
  end

  --释放一个临时id
  function map:releasetempid(tempid)
    assert(tempid)
    idmgr:releaseid(tempid)
  end

  --加载地图信息
  function map:loadmapinfo()
    local monster_list = self.map_info.monster_list
    local obj
    local tempid
    assert(aoisvr)
    local n = 100
    while n > 0 do
      for _,v in pairs(monster_list) do
        tempid = self:createtempid()
        obj = monster.create(v.id,tempid,v,self)
        assert(self.monster_list[tempid] == nil)
        obj:set_msgsender(self.msgsender)
        self.monster_list[tempid] = obj
        skynet.send(aoisvr,"lua","characterenter",obj:getaoiobj())
      end
      n = n - 1
    end
  end

  function map:getmapid()
    return self.id
  end
  --获取副本id
  function map:getdungonid()
    return self.dungeon_id
  end

  --获取副本实例id
  function map:getdungoninstanceid()
    return self.dungeon_instance_id
  end

  --获取地图的宽
  function map:getwidth()
    return self.width
  end

  --获取地图的高
  function map:getheight()
    return self.height
  end
end

init_method(s_method.__index)

function _map.create(id, type, map_info,aoi)
  local map = {
    --地图id
    id = 0,

    --副本id
    dungeon_id = 0,

    --副本实例id
    dungeon_instance_id = 0,

    --地图类型
    type = 0,

    --地图宽、高
    width = 0, height = 0,

    --地图信息
    map_info = {},

    --玩家列表
    player_list = {},

    --怪物列表
    monster_list = {},

    --需要run的怪物列表
    monster_runlist = {},

    --npc列表
    npc_list = {},
  }

  map = setmetatable(map, s_method)
  map.id = id
  map.type = type
  assert(map_info)
  map.map_info = map_info
  idmgr:setmaxid(map_info.maxtempid)
  assert(aoi)
  aoisvr = aoi
  return map
end

return _map
