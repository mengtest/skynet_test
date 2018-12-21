local skynet = require "skynet"
local monster = require "obj.monster"
local enumtype = require "enumtype"

local _monstermgr = {}

local s_method = {__index = {}}

local function init_method(mgr)

  --添加对象到怪物的aoilist中
  --aoi callback
  function mgr:addaoiobj(monstertempid,aoiobj)
      assert(monstertempid)
      assert(aoiobj)
      local monster = self:getmonster(monstertempid)
      if monster:getfromaoilist(aoiobj.tempid) == nil then
      monster:addtoaoilist(aoiobj)
      if aoiobj.type == enumtype.CHAR_TYPE_PLAYER then
          local info = {
          name = monster:getname(),
          tempid = monster:gettempid(),
          pos = monster:getpos(),
          }
          --将我的信息发送给对方
          self.msgsender:sendrequest("characterupdate",{info = info},aoiobj.info)
      end
      end
    end
  
  --玩家移动的时候，对周围怪物的广播
  function mgr:updatemonsteraoiinfo(enterlist,leavelist,movelist)
    local monster
    --进入怪物视野
    for _,v in pairs(enterlist.monsterlist) do
      monster = self:getmonster(v.tempid)
      if monster:getfromaoilist(enterlist.obj.tempid) == nil then
        monster:addtoaoilist(enterlist.obj)
        local info = {
          name = monster:getname(),
          tempid = monster:gettempid(),
          pos = monster:getpos(),
        }
        --将我的信息发送给对方
        self.msgsender:sendrequest("characterupdate",{info = info},enterlist.obj.info)
      end
    end
    --离开怪物视野
    for _,v in pairs(leavelist.monsterlist) do
      monster = self:getmonster(v.tempid)
      monster:delfromaoilist(leavelist.tempid)
    end
    --更新怪物视野
    for _,v in pairs(movelist.monsterlist) do
      monster = self:getmonster(v.tempid)
      monster:updateaoiobj(movelist.obj)
    end
  end
  
  --怪物自己移动的时候，aoi更新
  function mgr:updateaoilist(monstertempid,enterlist,leavelist)
    assert(monstertempid)
    assert(enterlist)
    assert(leavelist)
    local monster = self:getmonster(monstertempid)
    for _,v in pairs(enterlist) do
        monster:addtoaoilist(v)
        local info = {
          name = monster:getname(),
          tempid = monster:gettempid(),
          pos = monster:getpos(),
        }
        --将我的信息发送给对方
        self.msgsender:sendrequest("characterupdate",{info = info},v.info)
    end
    for _,v in pairs(leavelist) do
        monster:delfromaoilist(v.tempid)
      end
  end

  --怪物run
  function mgr:monsterrun()
    for k,v in pairs(self.monster_list) do
      v:run(self.aoimgr)
    end
  end

  --获取一个怪物
  function mgr:getmonster(tempid)
    assert(self.monster_list[tempid],tempid)
    return self.monster_list[tempid]
  end

  function mgr:createmonster()
    local obj
    local tempid
    local n = 5
    while n > 0 do
      for _,v in pairs(self.monsterlist) do
        tempid = self.map:createtempid()
        obj = monster.create(v.id,tempid,v,self.map)
        assert(self.monster_list[tempid] == nil)
        obj:set_msgsender(self.msgsender)
        self.monster_list[tempid] = obj
        self.aoimgr:characterenter(obj:getaoiobj())
      end
      n = n - 1
    end
  end
end

init_method(s_method.__index)

function _monstermgr.create(msgsender, monsterlist, aoimgr, map)
    local monstermgr = {
        msgsender = msgsender,
        --怪物列表
        monster_list = {},

        monsterlist = monsterlist,

        aoimgr = aoimgr,

        map = map,
    }

    setmetatable(monstermgr, s_method)

    return monstermgr
end

return _monstermgr