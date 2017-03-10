local skynet = require "skynet"
require "skynet.manager"
local socket = require "socket"
local crypt = require "crypt"
local sprotoloader = require "sprotoloader"
local table = table
local string = string
local assert = assert

--[[

Protocol:

	line (\n) based text protocol

	1. Server->Client : base64(8bytes random challenge)
	2. Client->Server : base64(8bytes handshake client key)
	3. Server: Gen a 8bytes handshake server key
	4. Server->Client : base64(DH-Exchange(server key))
	5. Server/Client secret := DH-Secret(client key/server key)
	6. Client->Server : base64(HMAC(challenge, secret))
	7. Client->Server : DES(secret, base64(token))
	8. Server : call auth_handler(token) -> server, uid (A user defined method)
	9. Server : call login_handler(server, uid, secret) ->subid (A user defined method)
	10. Server->Client : 200 base64(subid)

Error Code:
	400 Bad Request . challenge failed
	401 Unauthorized . unauthorized by auth_handler
	403 Forbidden . login_handler failed
	406 Not Acceptable . already in login (disallow multi login)

Success:
	200 base64(subid)
]]
local host
local request
local socket_error = {}
local function assert_socket(service, v, fd)
	if v then
		return v
	else
		skynet.error(string.format("%s failed: socket (fd = %d) closed", service, fd))
		error(socket_error)
	end
end

local function write(service, fd, text,session)
	local str = text..string.pack(">I4", session)
	local package = string.pack (">s2", str)
	assert_socket(service, socket.write(fd, package), fd)
end

local function read (fd, size)
	return socket.read (fd, size) or error ()
end

local function read_msg(fd)
	local s = read (fd, 2)
	local size = s:byte(1) * 256 + s:byte(2)
	local msg = read (fd, size)
	local session = string.unpack(">I4", msg, -4)
	msg = msg:sub(1,-5)
	return session,host:dispatch(msg)
end

local session_id = 0
--local session = {}

local function send_request (service, fd, name, args)
	session_id = session_id + 1
	local str = request (name, args, session_id)
	write (service, fd, str, session_id)
	--session[session_id] = { name = name, args = args }
end

local function launch_slave(auth_handler)
	local function auth(fd, addr)
		--和client握手，生成token
		-- set socket buffer limit (8K)
		-- If the attacker send large package, close the socket
		socket.limit(fd, 8192)

		--将challenge发送给client
		local challenge = crypt.randomkey()
		local serverkey = crypt.randomkey()
		local clientkey
		--获取client的handshake
		local session, type, name, args, response = read_msg (fd)
		assert (type == "REQUEST")

		if name == "handshake" then
			assert (args and args.clientkey, "invalid handshake request")
			clientkey = crypt.base64decode(args.clientkey)
			if #clientkey ~= 8 then
				error "Invalid client key"
			end
			local msg = response{
				challenge = crypt.base64encode(challenge),
				serverkey = crypt.base64encode(crypt.dhexchange(serverkey))
			}
			write("handshake",fd,msg,session)
		end

		local secret = crypt.dhsecret(clientkey, serverkey)

		session, type, name, args, response = read_msg (fd)
		assert (type == "REQUEST")
		if name == "challenge" then
			assert (args and args.hmac, "invalid challenge request")
			local hmac = crypt.hmac64(challenge, secret)
			--对比两边利用 challenge 和 secret 生成的结果
			if hmac ~= crypt.base64decode(args.hmac) then
				local msg = response {
					result = "400 Bad Request"
				}
				write("auth",fd,msg)
				error "challenge failed"
			else
				local msg = response {
						result = "challenge success"
					}
				write("auth",fd,msg,session)
			end
		end
		--这里是前端发过来的 token
		--里面是按照约定的格式生成的账号、密码和需要登录的区服组成的字符串
		local token
		session, type, name, args, response = read_msg (fd)
		assert (type == "REQUEST")
		if name == "auth" then
			assert (args and args.etokens, "invalid auth request")
			--利用 secret 解密
			token = crypt.desdecode(secret, crypt.base64decode(args.etokens))
		end

		--call logind中的auth_handler
		--返回了要登录的服务器和账号
		local ok, server, uid =  pcall(auth_handler,token)

		return ok, server, uid, secret
	end

	local function ret_pack(ok, err, ...)
		if ok then
			return skynet.pack(err, ...)
		else
			if err == socket_error then
				return skynet.pack(nil, "socket error")
			else
				return skynet.pack(false, err)
			end
		end
	end

	local function auth_fd(fd, addr)
		skynet.error(string.format("connect from %s (fd = %d)", addr, fd))
		--开始接受client的消息
		socket.start(fd)	-- may raise error here
		local msg, len = ret_pack(pcall(auth, fd, addr))
		socket.abandon(fd)	-- never raise error here
		return msg, len
	end

	--接受来自login master的认证请求
	skynet.dispatch("lua", function(_,_,...)
		local ok, msg, len = pcall(auth_fd, ...)
		if ok then
			skynet.ret(msg,len)
		else
			skynet.ret(skynet.pack(false, msg))
		end
	end)
end

--正在登陆的玩家list
local user_login = {}

local function accept(conf, s, fd, addr)
	-- call slave auth
	-- 去 slave 认证
	local ok, server, uid, secret = skynet.call(s, "lua",  fd, addr)
	-- slave will accept(start) fd, so we can write to fd later
	--根据认证结果
	if not ok then
		if ok ~= nil then
			send_request("response 401",fd,"subid",{result = "401 Unauthorized"})
		end
		error(server)
	end

	if not conf.multilogin then
		if user_login[uid] then
			send_request("response 406",fd,"subid",{result = "406 Not Acceptable"})
			error(string.format("User %s is already login", uid))
		end

		user_login[uid] = true
	end

	--通知gameserver登陆
	local ok, err = pcall(conf.login_handler, server, uid, secret)
	-- unlock login
	user_login[uid] = nil

	if ok then
		err = err or ""
		send_request("response 200",fd,"subid",{result = "200 "..crypt.base64encode(err)})
	else
		send_request("response 403",fd,"subid",{result = "403 Not Forbidden"})
		error(err)
	end
end

local function launch_master(conf)
	local instance = conf.instance or 8
	assert(instance > 0)
	local host = conf.host or "0.0.0.0"
	local port = assert(tonumber(conf.port))
	local slave = {}
	local balance = 1

	--login master 收到的lua类消息，处理logind中CMD命令
	skynet.dispatch("lua", function(_,source,command, ...)
		skynet.ret(skynet.pack(conf.command_handler(command, ...)))
	end)

	--根据配置中conf.instance的的数量启动login slave
	--其实就是在启动loginserver，但是在start中会检测是否有master
	--当有master存在的时候，就是启动slave了
	for _ = 1,instance do
		table.insert(slave, skynet.newservice(SERVICE_NAME))
	end

	skynet.error(string.format("login server listen at : %s %d", host, port))
	--login server启动监听
	local id = socket.listen(host, port)
	--接收到新的socket连接的时候，就会触发这里
	socket.start(id , function(fd, addr)
		local s = slave[balance]
		balance = balance + 1
		if balance > #slave then
			balance = 1
		end
		--让连接去slave中认证
		local ok, err = pcall(accept, conf, s, fd, addr)
		if not ok then
			if err ~= socket_error then
				skynet.error(string.format("invalid client (fd = %d) error = %s", fd, err))
			end
		end
		socket.close_fd(fd)	-- We haven't call socket.start, so use socket.close_fd rather than socket.close.
	end)
end

--在logind中调用,将logind中的方法注册到这里来
--调用的时候,启动了launch_master
local function login(conf)
	local name = "." .. (conf.name or "login")
	skynet.start(function()
		local protoloader = skynet.uniqueservice "protoloader"
		local slot = skynet.call(protoloader, "lua", "index", "clientproto")
		host = sprotoloader.load(slot):host "package"
		slot = skynet.call(protoloader, "lua", "index", "serverproto")
		request = host:attach(sprotoloader.load(slot))
		--查询launch_master是否启动
		local loginmaster = skynet.localname(name)
		if loginmaster then
			--已经启动了launch_master的时候
			--启动launch_slave
			--用于与客户端握手校验
			local auth_handler = assert(conf.auth_handler)
			launch_master = nil
			conf = nil
			launch_slave(auth_handler)
		else
			--启动launch_master
			--用于登录到login
			launch_slave = nil
			conf.auth_handler = nil
			assert(conf.login_handler)
			assert(conf.command_handler)
			skynet.register(name)
			launch_master(conf)
		end
	end)
end

return login
