local skynet = require "skynet"
local log = require "syslog"
local uuid = require "uuid"

local dbmgrcmd = {}
local account = {}

function account.init (cmd)
	dbmgrcmd = cmd
end

--logind请求认证
function account.auth(uid, password)
	log.debug("auth:%s\t%s",uid, password)
	local result = dbmgrcmd:execute_single("account",uid)
	if not table.empty(result) then
		log.debug("find account:%s",uid)
		if result["uid"] == uid then
			log.debug("account:%s update login time",uid)
			local row = { }
			row.uid = uid
			row.logintime = os.time()
			dbmgrcmd:update("account",row)
		else
			log.debug("find account:%s in DB,but result['uid'] = %s",uid,result["uid"])
		end
	else
		log.debug("add account:%s to redis and mysql",uid)
		--不存在于redis中的时候，添加记录
		local row = { }
		row.uid = uid
		row.createtime = os.time()
		row.logintime = row.createtime
		dbmgrcmd:add("account",row)
	end
	return true
end

return account
