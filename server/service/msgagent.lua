local skynet = require "skynet"
local sprotoloader = require "sprotoloader"
local log = require "base.syslog"

local host
local request 
local session = {}
local session_id = 0
local gate

local user

local function send_msg (msg)
	local package = string.pack (">s2", msg)
	if gate then
		skynet.call(gate, "lua", "request", user.userid, user.subid,package);
	end
end

local function send_request (name, args)
	session_id = session_id + 1
	local str = request (name, args, session_id)
	send_msg (str)
	session[session_id] = { name = name, args = args }
end

local function logout()
	if gate then
		skynet.call(gate, "lua", "logout", user.userid, user.subid)
	end
	skynet.exit()
end

local last_heartbeat_time = 0
local HEARTBEAT_TIME_MAX = 0 -- 60 * 100
local function heartbeat_check ()
	if HEARTBEAT_TIME_MAX <= 0 then return end

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
function REQUEST:ping()
	print("ping")
	return { ok = true}
end
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
local RESPONSE
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
			local result = handle_request (...)
			if result then 
				skynet.ret(result)
			end
		elseif type == "RESPONSE" then
			handle_response (...)
		else
			syslog.warningf ("invalid message type : %s", type) 
			logout()
		end
		skynet.sleep(10)
	end,
}

local CMD = {}

function CMD.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	skynet.error(string.format("%s is login", uid))
	gate = source
	skynet.fork(function()
		while true do
			send_request("heartbeat")
			skynet.sleep(500)
		end
	end)

	user = { 
		userid = uid,
		subid = sid,
		REQUEST = {},
		RESPONSE = {},
		CMD = CMD,
		send_request = send_request,
	}
	REQUEST = user.REQUEST
	RESPONSE = user.RESPONSE
	-- you may load user data from database

	--心跳检测
	last_heartbeat_time = skynet.now ()
	heartbeat_check ()
end

function CMD.logout(source)
	--下线
	-- NOTICE: The logout MAY be reentry
	skynet.error(string.format("%s is logout", userid))
	logout()
end

function CMD.afk(source)
	-- the connection is broken, but the user may back
	skynet.error(string.format("AFK"))
end

skynet.start(function()
	-- If you want to fork a work thread , you MUST do it in CMD.login
	--加载proto
	local protoloader = skynet.uniqueservice "protoloader"
	local slot = skynet.call(protoloader, "lua", "index", "clientproto")
	host = sprotoloader.load(slot):host "package"
	slot = skynet.call(protoloader, "lua", "index", "serverproto")
	request = host:attach(sprotoloader.load(slot))

	skynet.dispatch("lua", function(session, source, command, ...)
		local f = assert(CMD[command])
		skynet.ret(skynet.pack(f(source, ...)))
	end)
end)
