local skynet = require "skynet"
local service = require "service"
local aoi = require "aoi.core"
local log = require "syslog"

local CMD = {}
local OBJ = {}

function _G.aoicallback(w,m)
  assert(OBJ[w])
  assert(OBJ[m])
  log.debug("AOI CALLBACK:%d(%d,%d) => %d(%d,%d)",w,OBJ[w].movement.pos.x,OBJ[w].movement.pos.y,m,OBJ[m].movement.pos.x,OBJ[m].movement.pos.y)
  --将视野内的玩家通知agent
  assert(OBJ[w].agent)
  skynet.send(OBJ[w].agent,"lua","addaoiobj",OBJ[m].info,OBJ[m].agent)
end

--添加到aoi
function CMD.characterenter(agent,obj)
  assert(agent)
  assert(obj)
  log.debug("AOI ENTER %d %s %d %d %d",obj.tempid,obj.movement.mode,obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
  OBJ[obj.tempid] = obj
  OBJ[obj.tempid].agent = agent
  aoi.update(obj.tempid,obj.movement.mode,obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
  aoi.message()
end

--从aoi中移除
function CMD.characterleave(obj)
  assert(obj)
  log.debug("%d leave aoi",obj.tempid)
  aoi.update(obj.tempid,"d",obj.movement.pos.x,obj.movement.pos.y,obj.movement.pos.z)
  aoi.message()
  OBJ[obj.tempid] = nil
end

function CMD.open()
  aoi.init()
end

function CMD.close()
  aoi.release()
end

service.init {
    command = CMD,
}
