local skynet = require "skynet"
local log = require "syslog"
local uuid = require "uuid"

local dbmgrcmd = {}
local playerdate = {}

function playerdate.init (cmd)
	dbmgrcmd = cmd
end

--agent请求角色列表
function playerdate.getlist(uid)
	local row = {"uuid","rolename","createtime","job","level"}
  local list = dbmgrcmd:execute_multi("playerdate",uid,nil,row)
	return list
end

function playerdate.load(account)

end

--请求创建角色
function playerdate.create()

end

--保存角色信息
function playerdate.save()

end

--保存角色列表
function playerdate.sevalist()

end

return playerdate
