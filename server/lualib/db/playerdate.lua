local skynet = require "skynet"
local log = require "syslog"
local uuid = require "uuid"

local dbmgrcmd = {}
local playerdate = {}

local config = {
	tbname = "playerdate",--表名
	rediskey = "uuid",--用表中哪些字段来生成redis的key,","分割
	primarykey = "uuid",--主键，在读取所有信息的时候，会以主键排序
	columns = nil,--需要查询的字段，nil的时候全部获取
	indexkey = nil,--需要插入有序集合的时候，以该字段生成key
	row = {},--添加数据的时候，把数据写到这里
}

function playerdate.init (cmd)
	dbmgrcmd = cmd
end

local function make_key (user)
	return string.format ("%s:%s", config.rediskey,user)
end

--agent请求角色列表
function playerdate.getlist(account)
  config.columns = "uuid"
  local list = dbmgrcmd:execute_single("playerdate",account)
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
