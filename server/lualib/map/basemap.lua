local monster = require "obj.monster"
local idmgr = require "idmgr"
local skynet = require "skynet"

local _map = {}
local aoisvr

local s_method = {__index = {}}

local function init_method(map)

  --怪物run
  function map:monster_run()
    while true do
      for _,v in pairs(self.monster_list) do
        v:run(aoisvr)
      end
      skynet.sleep(50)
    end
  end

  --获取一个怪物
  function map:get_monster(tempid)
    assert(self.monster_list[tempid],tempid)
    return self.monster_list[tempid]
  end
  --创建一个临时id
  function map:create_tempid()
    return idmgr:createid()
  end

  --释放一个临时id
  function map:release_tempid(tempid)
    assert(tempid)
    idmgr:releaseid(tempid)
  end

  --加载地图信息
  function map:load_map_info()
    local monster_list = self.map_info.monster_list
    local obj
    local tempid
    assert(aoisvr)
    local n = 1
    while n > 0 do
      for _,v in pairs(monster_list) do
        tempid = self:create_tempid()
        obj = monster.create(v.id,tempid,v,self)
        assert(self.monster_list[tempid] == nil)
        obj:set_msgsender(self.msgsender)
        self.monster_list[tempid] = obj
        skynet.send(aoisvr,"lua","characterenter",obj:getaoiobj())
      end
      n = n - 1
    end
  end

  function map:get_map_id()
    return self.id
  end
  --获取副本id
  function map:get_dungon_id()
    return self.dungeon_id
  end

  --获取副本实例id
  function map:get_dungon_instance_id()
    return self.dungeon_instance_id
  end

  --获取地图的宽
  function map:get_width()
    return self.width
  end

  --获取地图的高
  function map:get_height()
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
