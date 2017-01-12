local skynet = require "skynet"
local queue = require "skynet.queue"
local sprotoloader = require "sprotoloader"
local log = require "syslog"

local testhandler = require "agent.testhandler"
local character_handler = require "agent.character_handler"
local map_handler = require "agent.map_handler"
local aoi_handler = require "agent.aoi_handler"
local move_handler = require "agent.move_handler"

local requestqueue = queue()
local responsequeue = queue()
local luaqueue = queue()
local host
local request
local session = {}
local session_id = 0
local gate
local CMD = {}

local running = false
local user

local function send_msg (msg,sessionid)
	local str = msg..string.pack(">I4", sessionid)
	local package = string.pack (">s2", str)
	if gate then
		skynet.call(gate, "lua", "request", user.uid, user.subid,package);
	end
end

local function send_boardmsg (msg,sessionid)
	local str = msg..string.pack(">I4", sessionid)
	local package = string.pack (">s2", str)
	assert(CMD.boardcast)
	CMD.boardcast(gate,package)
end

local function send_request (name, args)
	session_id = session_id + 1
	local str = request (name, args, session_id)
	send_msg (str,session_id)
	session[session_id] = { name = name, args = args }
end

local function send_boardrequest (name, args)
	--session_id = session_id + 1
	local str = request (name, args, 0)
	send_boardmsg (str,0)
	--session[session_id] = { name = name, args = args }
end

local function logout()
	if not user then return end
	if gate then
		skynet.call(gate, "lua", "logout", user.uid, user.subid)
	end

	if user.map then
		skynet.call(user.map, "lua", "characterleave", skynet.self(),user.character.aoiobj)
	end
	if user.world then
		skynet.call(user.world, "lua", "characterleave", user.character.uuid,user.character.aoiobj)
	end

	map_handler:unregister(user)
	aoi_handler:unregister(user)
	move_handler:unregister(user)
	testhandler:unregister(user)
	running = false
	user = nil
	session = {}
	gate = nil
	--不退出，在这里清理agent的数据就行了
	--会在gated里面将该agent加到agentpool中
	--skynet.exit()
end

--心跳检测
local last_heartbeat_time = 0
local HEARTBEAT_TIME_MAX = 0 * 100
local function heartbeat_check ()
	if HEARTBEAT_TIME_MAX <= 0 or not running then return end

	local t = last_heartbeat_time + HEARTBEAT_TIME_MAX - skynet.now ()
	if t <= 0 then
		log.warning ("heatbeat check failed")
		logout()
	else
		skynet.timeout (t, heartbeat_check)
	end
end

local traceback = debug.traceback
--接受到的请求
local REQUEST = {}
local function handle_request (name, args, response)
	local f = REQUEST[name]
	if f then
		local ok, ret = xpcall (f, traceback, args)
		if not ok then
			log.warning ("handle message(%s) failed : %s", name, ret)
			logout()
		else
			last_heartbeat_time = skynet.now ()
			if response and ret then
				return response (ret)
			end
		end
	else
		log.warning ("unhandled message : %s", name)
		logout()
	end
end

--接受到的回应
local RESPONSE = {}
local function handle_response (id, args)
	local s = session[id]
	if not s then
		log.warning ("session %d not found", id)
		logout()
		return
	end

	local f = RESPONSE[s.name]
	if not f then
		log.warning ("unhandled response : %s", s.name)
		logout()
		return
	end

	local ok, ret = xpcall (f, traceback, s.args, args)
	if not ok then
		log.warning ("handle response(%d-%s) failed : %s", id, s.name, ret)
		logout()
	end
end

--处理client发来的消息
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch (msg, sz)
	end,
	dispatch = function (_, _, type, ...)
		if type == "REQUEST" then
			local result = requestqueue(handle_request, ...)
			if result then
				skynet.ret(result)
			end
		elseif type == "RESPONSE" then
			responsequeue(handle_response, ...)
		else
			log.warning("invalid message type : %s", type)
			logout()
		end
		skynet.sleep(10)
	end,
}

function CMD.worldenter(_,world)
	character_handler.init(user.character)
	user.world = world
	character_handler:unregister (user)
	return user.character.map,user.character.aoiobj
end

function CMD.mapenter(_,map,tempid)
	user.map = map
	user.character.aoiobj.tempid = tempid

	log.debug("enter map and set tempid:"..user.character.aoiobj.tempid)
	map_handler:register(user)
	aoi_handler:register(user)
	move_handler:register(user)
end

function CMD.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	log.notice("%s is login",uid)
	gate = source

	user = {
		uid = uid,
		subid = sid,
		REQUEST = {},
		RESPONSE = {},
		CMD = CMD,
		send_request = send_request,
		send_boardrequest = send_boardrequest,
	}

	REQUEST = user.REQUEST
	RESPONSE = user.RESPONSE
	-- you may load user data from database
	testhandler:register(user)
	character_handler:register(user)
	running = true
	--心跳检测
	last_heartbeat_time = skynet.now ()
	heartbeat_check ()
end

function CMD.logout(_)
	--下线
	-- NOTICE: The logout MAY be reentry
	log.notice("%s is logout ,agent(%d)",user.uid,skynet.self())
	logout()
end

function CMD.afk(_)
	-- the connection is broken, but the user may back
	log.notice("%s AFK",user.uid)
end

skynet.start(function()
	-- If you want to fork a work thread , you MUST do it in CMD.login
	--加载proto
	local protoloader = skynet.uniqueservice "protoloader"
	local slot = skynet.call(protoloader, "lua", "index", "clientproto")
	host = sprotoloader.load(slot):host "package"
	slot = skynet.call(protoloader, "lua", "index", "serverproto")
	request = host:attach(sprotoloader.load(slot))

	skynet.dispatch("lua", function(_, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(luaqueue(f,source, ...)))
	end)
end)
