local enumtype = require "enumtype"
local CMD = {}
local map_info
local msgsender
local _handle = { CMD = CMD,}

function _handle.init(info)
  map_info = info
  msgsender = map_info.msgsender
end


--添加对象到aoilist中
function CMD.addaoiobj(monstertempid,aoiobj)
  assert(map_info)
  assert(monstertempid)
  assert(aoiobj)
  local monster = map_info:get_monster(monstertempid)
  if monster:getfromaoilist(aoiobj.tempid) == nil then
    monster:addtoaoilist(aoiobj)
    if aoiobj.type == enumtype.CHAR_TYPE_PLAYER then
      local info = {
        name = monster:getname(),
        tempid = monster:gettempid(),
        pos = monster:getpos(),
      }
      --将我的信息发送给对方
      msgsender:send_request("characterupdate",{info = info},aoiobj.info)
    end
  end
end

function CMD.updateaoiinfo(enterlist,leavelist,movelist)
  local monster
  for _,v in pairs(enterlist.monsterlist) do
    monster = map_info:get_monster(v.tempid)
    if monster:getfromaoilist(enterlist.obj.tempid) == nil then
      monster:addtoaoilist(enterlist.obj)
      if enterlist.obj.type == enumtype.CHAR_TYPE_PLAYER then
        local info = {
          name = monster:getname(),
          tempid = monster:gettempid(),
          pos = monster:getpos(),
        }
        --将我的信息发送给对方
        msgsender:send_request("characterupdate",{info = info},enterlist.obj.info)
      end
    end
  end
  for _,v in pairs(leavelist.monsterlist) do
    monster = map_info:get_monster(v.tempid)
    monster:delfromaoilist(leavelist.tempid)
  end
  for _,v in pairs(movelist.monsterlist) do
    monster = map_info:get_monster(v.tempid)
    monster:updateaoiobj(movelist.obj)
  end
end

function CMD.updateaoilist(monstertempid,enterlist,leavelist)
  assert(map_info)
  assert(monstertempid)
  assert(enterlist)
  assert(leavelist)
  local monster = map_info:get_monster(monstertempid)
  for _,v in pairs(enterlist) do
      monster:addtoaoilist(v)
      local info = {
        name = monster:getname(),
        tempid = monster:gettempid(),
        pos = monster:getpos(),
      }
      --将我的信息发送给对方
      msgsender:send_request("characterupdate",{info = info},v.info)
  end
  for _,v in pairs(leavelist) do
      monster:delfromaoilist(v.tempid)
    end
end

return _handle
