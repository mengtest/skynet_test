local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local host
local request 

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg,sz)
				return host:dispatch(msg,sz)
				--return skynet.tostring(msg,sz)
			end,
}

local gate
local userid, subid

local CMD = {}
local REQUEST = {}

function REQUEST:ping()
	print("Ping")
end

function CMD.login(source, uid, sid, secret)
	-- you may use secret to make a encrypted data stream
	skynet.error(string.format("%s is login", uid))
	gate = source
	userid = uid
	subid = sid
	-- you may load user data from database
	--上线
end

local function logout()
	if gate then
		skynet.call(gate, "lua", "logout", userid, subid)
	end
	skynet.exit()
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

local function recv_request(name, args, response)
	local f = assert(REQUEST[name])
	local r = f(args)
	if response then
		return response(r)
	end
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

	skynet.dispatch("client", function(_,_, type, ...)
		-- the simple echo service
		--local type, name, args, response = host:dispatch(msg)
		--这边是收到client的消息，已经解析好的消息
		if type == "REQUEST" then
			local ok, result  = pcall(recv_request, ...)
			if ok then
				if result then
					skynet.ret(msg)
				end
			else
				skynet.error(result)
			end
		end
		skynet.sleep(10)	-- sleep a while
	end)
end)
