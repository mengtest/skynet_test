local basechar = require "obj.basechar"
local enumtype = require "enumtype"

local _player = {}
local s_method = {__index = {}}

local function init_method(player)

  --给自己客户端发消息
  function player:sendrequest(name, args)
    self.msgsender:sendrequest(name, args,self.aoiobj.info)
  end

  --设置玩家所在地图id
  function player:setmapid(mapid)
    self.mapid = mapid
  end

  --获取玩家当前所在地图id
  function player:getmapid()
    return self.mapid
  end

  --设置玩家uuid
  function player:setuuid(uuid)
    assert(self.objinfo)
    assert(uuid > 0)
    self.objinfo.uuid = uuid
  end

  --获取玩家uuid
  function player:getuuid()
    assert(self.objinfo)
    return self.objinfo.uuid
  end

  --获取角色职业
  function player:getjob()
    assert(self.objinfo)
    return self.objinfo.job
  end

  --获取角色性别
  function player:getsex()
    assert(self.objinfo)
    return self.objinfo.sex
  end

  --设置玩家数据
  function player:setdata(data)
    self.data = data
  end

  --获取玩家指定类型的数据
  function player:getdatabytype(ntype)
    assert(self.data)
    return self.data[ntype]
  end

  basechar.expandmethod(player)
end
init_method(s_method.__index)

--创建player
function _player.create()
  local player = basechar.create(enumtype.CHAR_TYPE_PLAYER)
  --player 特有属性

  --所在地图
  player.mapid = 0
  --玩家数据
  player.data = {}
  --玩家信息
  player.playerinfo = {}

  player = setmetatable(player, s_method)

  return player
end

return _player
