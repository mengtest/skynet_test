local enumtype = require "enumtype"
local CMD = {}
local map_info
local msgsender
local _handle = { CMD = CMD,}

function _handle.init(info)
  map_info = info
  msgsender = map_info.msgsender
end


--添加对象到怪物的aoilist中
--aoi callback
function CMD.addaoiobj(monstertempid,aoiobj)
  assert(map_info)
  assert(monstertempid)
  assert(aoiobj)
  local monster = map_info:getmonster(monstertempid)
  if monster:getfromaoilist(aoiobj.tempid) == nil then
    monster:addtoaoilist(aoiobj)
    if aoiobj.type == enumtype.CHAR_TYPE_PLAYER then
      local info = {
        name = monster:getname(),
        tempid = monster:gettempid(),
        pos = monster:getpos(),
      }
      --将我的信息发送给对方
      msgsender:sendrequest("characterupdate",{info = info},aoiobj.info)
    end
  end
end

--玩家移动的时候，对周围怪物的广播
function CMD.updateaoiinfo(enterlist,leavelist,movelist)
  local monster
  --进入怪物视野
  for _,v in pairs(enterlist.monsterlist) do
    monster = map_info:getmonster(v.tempid)
    if monster:getfromaoilist(enterlist.obj.tempid) == nil then
      monster:addtoaoilist(enterlist.obj)
      local info = {
        name = monster:getname(),
        tempid = monster:gettempid(),
        pos = monster:getpos(),
      }
      --将我的信息发送给对方
      msgsender:sendrequest("characterupdate",{info = info},enterlist.obj.info)
    end
  end
  --离开怪物视野
  for _,v in pairs(leavelist.monsterlist) do
    monster = map_info:getmonster(v.tempid)
    monster:delfromaoilist(leavelist.tempid)
  end
  --更新怪物视野
  for _,v in pairs(movelist.monsterlist) do
    monster = map_info:getmonster(v.tempid)
    monster:updateaoiobj(movelist.obj)
  end
end

--怪物自己移动的时候，aoi更新
function CMD.updateaoilist(monstertempid,enterlist,leavelist)
  assert(map_info)
  assert(monstertempid)
  assert(enterlist)
  assert(leavelist)
  local monster = map_info:getmonster(monstertempid)
  for _,v in pairs(enterlist) do
      monster:addtoaoilist(v)
      local info = {
        name = monster:getname(),
        tempid = monster:gettempid(),
        pos = monster:getpos(),
      }
      --将我的信息发送给对方
      msgsender:sendrequest("characterupdate",{info = info},v.info)
  end
  for _,v in pairs(leavelist) do
      monster:delfromaoilist(v.tempid)
    end
end

return _handle
