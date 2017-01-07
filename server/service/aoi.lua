local skynet = require "skynet"
local service = require "service"
local aoi = require "aoi.core"
local log = require "syslog"

local CMD = {}
local config
local OBJ = {}

function aoicallback(w,m)
  assert(OBJ[w])
  assert(OBJ[m])
  log.debug("AOI CALLBACK:%d(%d,%d) => %d(%d,%d)",w,OBJ[w].pos.x,OBJ[w].pos.y,m,OBJ[m].pos.x,OBJ[m].pos.y)
  --将视野内的玩家通知agent
  skynet.send(OBJ[w].agent,"lua","addaoiobj",OBJ[m].agent,OBJ[m].tempid)
end

--添加到aoi
function CMD.characterenter(agent,obj)
  assert(obj)
  log.debug("!!!AOI ENTER %d %s %d %d %d",obj.tempid,obj.mode,obj.pos.x,obj.pos.y,obj.pos.z)
  OBJ[obj.tempid] = obj
  OBJ[obj.tempid].agent = agent
  aoi.update(obj.tempid,obj.mode,obj.pos.x,obj.pos.y,obj.pos.z)
  aoi.message()
end

--从aoi中移除
function CMD.characterleave(obj)
  assert(obj)
  log.debug("%d leave aoi",obj.tempid)
  aoi.update(obj.tempid,"d",obj.pos.x,obj.pos.y,obj.pos.z)
  aoi.message()
  OBJ[obj.tempid] = nil
end

function CMD.open(conf)
  config = conf
  log.debug("aoi open")
  aoi.init()
  --test()
end

function CMD.close()
  aoi.release()
end

service.init {
    command = CMD,
}
