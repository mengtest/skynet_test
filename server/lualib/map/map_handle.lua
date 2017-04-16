local log = require "syslog"
local npc = require "obj.npc"

local _map = {}

local _aoi
local _npc = {}
local _monster = {}

function _map.init(conf,aoi)
  _aoi = aoi
  log.debug("map init")

end

function _map.run()

end

function _map.destroy()

end

return _map
