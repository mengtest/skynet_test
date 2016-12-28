local skynet = require "skynet"
local handler = require "agent.handler"
local log = require "base.syslog"

local user
local dbmgr

local REQUEST = {}

_handler = handler.new (REQUEST)

_handler:init (function (u)
	user = u
  dbmgr = skynet.uniqueservice ("dbmgr")
end)

local function load_list (account)
	local list = skynet.call (dbmgr, "lua", "playerdate", "getlist", account)
	if not list then
		list = {}
	end
	return list
end

local function check_character (account, id)

end

function REQUEST.character_list ()

end

local function create (name, race, class)

end

function REQUEST.character_create (args)

end

function REQUEST.character_pick (args)

end

function _handler.init (character)

end

function _handler.save (character)

	skynet.call (dbmgr, "lua", "playerdate", "save", character.id, data)
end


return _handler
