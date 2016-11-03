local skynet = require "skynet"

function do_redis(redispool,args, uid)
	local cmd = assert(args[1])
	args[1] = uid
	return skynet.call(redispool, "lua", cmd, table.unpack(args))
end