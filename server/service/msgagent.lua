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
local session
local session_id
local gate
local CMD = {}

local agentstatus = {
	AGENT_INIT = 1,
	AGENT_RUNNING = 2,
	AGENT_QUIT = 3,
}

local running = agentstatus.AGENT_INIT
local user

local function send_msg (msg,sessionid)
	local str = msg..string.pack(">I4", sessionid)
	local package = string.pack (">s2", str)
	if gate then
		skynet.call(gate, "lua", "request", user.uid, user.subid,package);
	end
end

local function send_boardmsg (msg, sessionid, agentlist)
	local str = msg..string.pack(">I4", sessionid)
	local package = string.pack (">s2", str)
	assert(CMD.boardcast)
	CMD.boardcast(nil, gate, package, agentlist)
end

local function send_request (name, args)
	session_id = session_id + 1
	local str = request (name, args, session_id)
	send_msg (str,session_id)
	session[session_id] = { name = name, args = args }
end

local function send_boardrequest (name, args, agentlist)
	--session_id = session_id + 1
	local str = request (name, args, 0)
	send_boardmsg (str, 0, agentlist)
	--session[session_id] = { name = name, args = args }
end

--当请求退出和被T出的时候
--因为请求消息在requestqueue，而被T的消息在luaqueue中
--这边可能重入
local function logout(type)
	if not user or running ~= agentstatus.AGENT_RUNNING then return end
	running = agentstatus.AGENT_QUIT
	log.notice("logout, agent(:%08X) type(%d) subid(%d)",skynet.self(),type,user.subid)

	if gate then
		skynet.send(gate, "lua", "logout", user.uid, user.subid)
	end

	if user.map then
		local map = user.map
		user.map = nil
		if map then
			skynet.call(map, "lua", "characterleave", skynet.self(),user.character:getaoiobj())
			CMD.delaoiobj(nil,user.character:gettempid())
			--在玩家被挤下线的时候，这边可能还没有init
			--所以要放在这边release
			map_handler:unregister(user)
			aoi_handler:unregister(user)
			move_handler:unregister(user)
		end
	end
	if user.world then
		local world = user.world
		user.world = nil
		if world then
			skynet.call(world, "lua", "characterleave", user.character:getuuid())
		end
	end

	testhandler:unregister(user)
	character_handler:unregister (user)
	user = nil
	session = nil
	session_id = nil
	if gate then
		skynet.send(gate, "lua", "addtoagentpool", skynet.self())
	end
	gate = nil
	running = agentstatus.AGENT_INIT
	--不退出，在这里清理agent的数据就行了
	--会在gated里面将该agent加到agentpool中
	--skynet.exit()
end

--心跳检测
local last_heartbeat_time = 0
local HEARTBEAT_TIME_MAX = 0 * 100
local function heartbeat_check ()
	if HEARTBEAT_TIME_MAX <= 0 or running ~= agentstatus.AGENT_RUNNING then return end

	local t = last_heartbeat_time + HEARTBEAT_TIME_MAX - skynet.now ()
	if t <= 0 then
		log.warning ("heatbeat check failed")
		logout(1)
	else
		skynet.timeout (t, heartbeat_check)
	end
end

local traceback = debug.traceback
--接受到的请求
local REQUEST = {}
local function handle_request (name, args, response)
	--log.warning ("get handle_request from client: %s", name)
	local f = REQUEST[name]
	if f then
		local ok, ret = xpcall (f, traceback, args)
		if not ok then
			log.warning ("handle message(%s) failed : %s", name, ret)
			logout(2)
		else
			last_heartbeat_time = skynet.now ()
			if response and ret then
				return response (ret)
			end
		end
	else
		log.warning ("unhandled message : %s", name)
		logout(3)
	end
end

--接受到的回应
local RESPONSE = {}
local function handle_response (id, args)
	local s = session[id]
	if not s then
		log.warning ("session %d not found", id)
		logout(4)
		return
	end

	local f = RESPONSE[s.name]
	if not f then
		log.warning ("unhandled response : %s", s.name)
		logout(5)
		return
	end

	local ok, ret = xpcall (f, traceback, s.args, args)
	if not ok then
		log.warning ("handle response(%d-%s) failed : %s", id, s.name, ret)
		logout(6)
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
			logout(7)
		end
		skynet.sleep(10)
	end,
}

function CMD.worldenter(_,world)
	character_handler.init(user.dbdata)
	user.dbdata = nil
	--print(user)
	user.world = world
	character_handler:unregister (user)
	user.character:setaoimode("w")
	return user.character:getmapid(),user.character:getaoiobj()
end

function CMD.mapenter(_,map,tempid)
	user.map = map
	user.character:settempid(tempid)

	log.debug("enter map and set tempid:"..user.character:gettempid())
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
	session = {}
	session_id = 0
	-- you may load user data from database
	testhandler:register(user)
	character_handler:register(user)
	running = agentstatus.AGENT_RUNNING
	--心跳检测
	last_heartbeat_time = skynet.now ()
	heartbeat_check ()
end

function CMD.logout(_)
	--下线
	-- NOTICE: The logout MAY be reentry
	logout(0)
end

function CMD.afk(_)
	-- the connection is broken, but the user may back
	log.notice("%s AFK",user.uid)
end

function CMD.close()
	log.notice("close agent(:%08X)",skynet.self())
	logout(8)
	skynet.exit()
end

skynet.memlimit(1 * 1024 * 1024)

skynet.start(function()
	-- If you want to fork a work thread , you MUST do it in CMD.login
	--加载proto
	local protoloader = skynet.uniqueservice "protoloader"
	local slot = skynet.call(protoloader, "lua", "index", "clientproto")
	host = sprotoloader.load(slot):host "package"
	slot = skynet.call(protoloader, "lua", "index", "serverproto")
	request = host:attach(sprotoloader.load(slot))

	skynet.dispatch("lua", function(_, source, command, ...)
		local f = assert(CMD[command],command)
		skynet.ret(skynet.pack(luaqueue(f,source, ...)))
	end)
end)
