local log = require "syslog"
local monsterfunc = require "obj.monsterfunc"
local playerfunc = require "obj.playerfunc"

local _aoi
local _map = {}
local _npc = {}
local _monster = {}

function _map.init(conf,aoi)
  _aoi = aoi
  log.debug("map init")
  --monsterfunc.init()
end

function _map.run()

end

function _map.destroy()

end

return _map
