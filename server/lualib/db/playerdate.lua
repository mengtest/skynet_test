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
	local row = {"uuid","rolename","createtime","job","level","sex"}
  local list = dbmgrcmd:execute_multi("playerdate",uid,nil,row)
	return list
end

--加载角色信息
function playerdate.load(uid,uuid)
	local list = dbmgrcmd:execute_multi("playerdate",uid,uuid,row)
	return list
end

--保存角色信息
function playerdate.save(uid,character)
	return dbmgrcmd:add("playerdate",character)
end

return playerdate
