local skynet_root = "./3rd/skynet/"
package.cpath = skynet_root.."luaclib/?.so;"
package.path = skynet_root.."lualib/?.lua;"

local socket = require "clientsocket"
local crypt = require "crypt"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"

--加载解析proto文件
local f = io.open("./common/proto/clientproto.lua")
if f == nil then 
	print("proto open faild")
	return
end
local t = f:read "a"
f:close()
sprotoloader.save(sprotoparser.parse(t),0)
f = io.open("./common/proto/serverproto.lua")
if f == nil then 
	print("proto open faild")
	return
end
t = f:read "a"
f:close()
sprotoloader.save(sprotoparser.parse(t),1)

--[[
--proto消息解析测试
local hostclient = sprotoloader.load(1):host "package"
local requestclient = hostclient:attach(sprotoloader.load(0))

local hostserver = sprotoloader.load(0):host "package"
local requestserver = hostserver:attach(sprotoloader.load(1))

--client发送
local str = requestclient("ping",{userid = 123456},99)
--server解析
local type, session, args,response = hostserver:dispatch(str)
print(type, session, args,response)
--server返回response
local str2 = response({ok = true})
--client解析
local type, session, args,response = hostclient:dispatch(str2)
print(type, session, args,response)

--server发送
local str3 = requestserver("heartbeat")
--client解析
local type, session, args,response = hostclient:dispatch(str3)
print(type, session, args,response)

]]

--host用来解析接受到的消息
local host = sprotoloader.load(1):host "package"
--request用来发送消息
local request = host:attach(sprotoloader.load(0))

local session_id = 0

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

--与loginserver建立连接
local fd = assert(socket.connect("127.0.0.1", 8101))

local function send_request(name, args)
	session_id = session_id + 1
	local str = request(name, args, session_id)
	local size = #str + 4
	--这里等效于
	--local str = v..string.pack(">I4", session)
	--package = string.pack(">s2",str)
	local package = string.pack(">I2", size)..str..string.pack(">I4", session_id)
	socket.send(fd, package)
	return session_id,"REQUEST",name
end

local function writeline(fd, text)
	socket.send(fd, text .. "\n")
end

local function unpack_line(text)
	local from = text:find("\n", 1, true)
	if from then
		return text:sub(1, from-1), text:sub(from+1)
	end
	return nil, text
end

local last = ""

local function unpack_f(f)
	local function try_recv(fd, last)
		local result
		result, last = f(last)
		if result then
			return result, last
		end
		local r = socket.recv(fd)
		if not r then
			return nil, last
		end
		if r == "" then
			error "Server closed"
		end
		return f(last .. r)
	end

	--每秒尝试接受来自服务器的消息
	return function()
		while true do
			local result
			result, last = try_recv(fd, last)
			if result then
				return result
			end
			socket.usleep(100)
		end
	end
end

local readline = unpack_f(unpack_line)

--获取服务器发送来的random challenge
local challenge = crypt.base64decode(readline())

--生成clientkey
local clientkey = crypt.randomkey()
--发送给服务器
writeline(fd, crypt.base64encode(crypt.dhexchange(clientkey)))

--获取serverkey，然后计算出secret
local secret = crypt.dhsecret(crypt.base64decode(readline()), clientkey)

print("sceret is ", crypt.hexencode(secret))

--回应服务器第一步握手的挑战码，确认握手正常。
local hmac = crypt.hmac64(challenge, secret)
writeline(fd, crypt.base64encode(hmac))

local token = {
	server = "sample",
	user = "hello",
	pass = "password",
}

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

--使用DES算法，以secret做key，加密传输token串
local etoken = crypt.desencode(secret, encode_token(token))
local b = crypt.base64encode(etoken)
writeline(fd, crypt.base64encode(etoken))

--收到服务器发来的确认信息
local result = readline()
print(result)
local code = tonumber(string.sub(result, 1, 3))
--当确认成功的时候，断开与服务器的连接
assert(code == 200)
socket.close(fd)

--通过确认信息获取subid
local subid = crypt.base64decode(string.sub(result, 5))

print("login ok, subid=", subid)

----- connect to game server
--连接至gameserver

local function recv_response(v)
	local size = #v - 5
	local content, ok, session = string.unpack("c"..tostring(size).."B>I4", v)
	return ok ~=0 , content, session
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end
	return text:sub(3,2+s), text:sub(3+s)
end

local readpackage = unpack_f(unpack_package)

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local index = 1

--连接到gameserver
print("connect")
fd = assert(socket.connect("127.0.0.1", 8547))
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)


send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print(readpackage())

print("disconnect")
socket.close(fd)

index = index + 1

--再次连接到gameserver
print("connect again")
fd = assert(socket.connect("127.0.0.1", 8547))
last = ""

local handshake = string.format("%s@%s#%s:%d", crypt.base64encode(token.user), crypt.base64encode(token.server),crypt.base64encode(subid) , index)
local hmac = crypt.hmac64(crypt.hashkey(handshake), secret)

send_package(fd, handshake .. ":" .. crypt.base64encode(hmac))

print(readpackage())

print("===>",send_request("ping"))
while true do
	local type, session, args, response = host:dispatch(readpackage())
	print("<===",type, session, args, response)
end

print("disconnect")
socket.close(fd)