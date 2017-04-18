local skynet = require "skynet"
local log = require "syslog"
local mapfun = require "map.map_handle"
local idmgr = require "idmgr"

local CMD = {}
local onlinecharacter = {}
local pendingcharacter = {}
local aoi

local world = ...
world = tonumber(world)
local config

--角色请求进入地图
function CMD.characterenter(uuid,aoiobj)
  log.debug("uuid(%d) enter map(%s)",uuid,config.name)
  assert(aoi)
  aoiobj.tempid = idmgr:createid()
  pendingcharacter[aoiobj.agent] = uuid
  skynet.send (aoiobj.agent, "lua", "mapenter", skynet.self (),aoiobj.tempid)
  skynet.send(aoi,"lua","characterenter",aoiobj)
  return true
end

--角色离开地图
function CMD.characterleave(aoiobj)
  local uuid = onlinecharacter[aoiobj.agent] or pendingcharacter[aoiobj.agent]
  if uuid ~=nil then
    log.debug("uuid(%d) leave map(%s)",uuid,config.name)
    skynet.call(aoi,"lua","characterleave",aoiobj)
  else
    log.debug("uuid(%d) leave map(%s) BUT cannot find !",uuid,config.name)
  end
  idmgr:releaseid(aoiobj.tempid)
  onlinecharacter[aoiobj.agent] = nil
  pendingcharacter[aoiobj.agent] = nil
end

--角色加载地图完成，正式进入地图
function CMD.characterready(uuid,aoiobj)
  if pendingcharacter[aoiobj.agent] == nil then
    log.debug("user(%s) post load map ready,BUT not find in pendingcharacter",aoiobj.info.uid)
    return false
  end
  onlinecharacter[aoiobj.agent] = pendingcharacter[aoiobj.agent]
  pendingcharacter[aoiobj.agent] = nil
  log.debug("uuid(%d) load map ready",uuid)
  skynet.send(aoi,"lua","characterenter",aoiobj)
  --skynet.call(agent,"lua","updateinfo")
  return true
end

--角色移动
function CMD.moveto(aoiobj)
  if onlinecharacter[aoiobj.agent] == nil then
    log.debug("user(%d) post load map ready,BUT not find in pendingcharacter",aoiobj.info.uid)
    return false
  end
  --TODO 这边应该检查pos的合法性
  skynet.send(aoi,"lua","characterenter",aoiobj)
  return true, aoiobj.movement.pos
end

function CMD.open(conf)
  config = conf
  idmgr:setmaxid(config.maxtempid)
  aoi = skynet.newservice("aoi")
  skynet.call(aoi,"lua","open",config.name)
  mapfun.init(conf,aoi)
end

function CMD.close()
  log.notice("close map(%s)...",config.name)
  skynet.call(aoi,"lua","close",config.name)
  for k,_ in pairs(onlinecharacter) do
    skynet.call(k,"lua","close")
  end
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
end)
