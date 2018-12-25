local skynet = require "skynet"
local service = require "service"
local builder = require "skynet.datasheet.builder"
local gamedata = require "gamedata.gamedata"

local function init()
    builder.new("gamedata", gamedata)
end

service.init {
    init = init
}
