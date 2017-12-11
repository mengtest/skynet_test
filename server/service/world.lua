local skynet = require "skynet"
local log = require "syslog"
local sharedata = require "skynet.sharedata"

local CMD = {}
local mapinstance = {}
local onlinecharacter = {}
local gate

function CMD.kick (uuid)
	local a = onlinecharacter[uuid]
	if a then
		skynet.send (a, "lua", "logout")
		onlinecharacter[uuid] = nil
    log.debug("kick uuid(%d) out of world",uuid)
	end
end

function CMD.characterenter(agent, uuid)
  if onlinecharacter[uuid] ~= nil then
		log.notice ("multiple login detected, uuid %d", uuid)
		CMD.kick (uuid)
		return
	end

	onlinecharacter[uuid] = agent
	log.notice ("uuid(%d) enter world ,agent(:%08X)", uuid,agent)
  --获取玩家需要去的地图和坐标
	local map, aoiobj = skynet.call (agent, "lua", "worldenter", skynet.self ())

	local m = mapinstance[map]
	if not m then
    log.debug("uuid(%d) error map :"..map,uuid)
		CMD.kick (uuid)
		return
	end

	 return skynet.call (m, "lua", "characterenter", uuid, aoiobj)
end

function CMD.characterleave(agent,uuid)
  log.notice ("uuid(%d) leave world ,agent(:%08X)", uuid,agent)
  onlinecharacter[uuid] = nil
end

function CMD.open(source)
	gate = source
  local obj = sharedata.query "gdd"
  local mapdata = obj["map"]
	local n = 1
	while n > 0 do
	  for _, conf in pairs (mapdata) do
			local name = conf.name
			local m = skynet.newservice ("map", skynet.self (),name)
			skynet.call (m, "lua", "open", conf)
			mapinstance[name] = m
		end
		n = n - 1
	end
end

function CMD.close()
  log.notice("close world...")
  for name, map in pairs (mapinstance) do
    skynet.call (map, "lua", "close")
    mapinstance[name] = nil
  end
end

skynet.start (function ()
	skynet.dispatch ("lua", function (_, source, command, ...)
		local f = assert (CMD[command])
		skynet.retpack (f (source, ...))
	end)
end)
