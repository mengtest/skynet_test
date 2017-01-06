local skynet = require "skynet"
local log = require "syslog"

local CMD = {}
local onlinecharacter = {}
local aoi

local world = tonumber(...)
local config

function CMD.characterenter(agent, uuid,pos)
  if onlinecharacter[uuid] then
    log.debug("uuid(%d) alreday in map(%s)",uuid,config.name)
    return
  end
  log.debug("uuid(%d) enter map(%s)",uuid,config.name)
  onlinecharacter[uuid] = agent
end

function CMD.characterlevel(agent,uuid)
  log.debug("uuid(%d) level map(%s)",uuid,config.name)
  onlinecharacter[uuid] = nil
end

function CMD.open(conf)
  config = conf
  aoi = skynet.newservice("aoi")
  skynet.call(aoi,"lua","open",config)
  log.debug("map(%s) open",config.name)
end

function CMD.close()
  log.debug("map(%s) close",config.name)
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, _, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (...))
	end)
end)
