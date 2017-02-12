local skynet = require "skynet"
local service = require "service"
local mysql = require "mysql"
local config = require "config.mysqlconf"
local log = require "syslog"

local CMD = {}
local center
local group = {}
local ngroup
local index = 1

function getconn (write)
	local db
	if write then
		db = center
	else
		if ngroup > 0 then
			db = group[index]
			index = index + 1
			if index > ngroup then
				index = 1
			end
		else
			db = center
		end
	end
	assert(db)
	return db
end

function CMD.open()
	center = mysql.connect(config.center)
	ngroup = #config.group
	for _, c in ipairs (config.group) do
		local db = mysql.connect (c)
		table.insert (group, db)
	end
end

function CMD.execute(sql, write)
	local db = getconn(write)
	return db:query(sql)
end

function CMD.close()
	log.notice("close mysqlpoll...")
	center:disconnect()
	center = nil
	for _, db in pairs(group) do
		db:disconnect()
	end
	pool = {}
end

service.init {
	command = CMD,
}
