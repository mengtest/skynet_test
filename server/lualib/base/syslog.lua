local skynet = require "skynet"
local profile = require "skynet.profile"

local config = require "config.system"

local syslog = {
	prefix = {
		"D|",
		"I|",
		"N|",
		"W|",
		"E|",
	},
}

local level
function syslog.level (lv)
	level = lv
end

function syslog.format(priority,fmt, ...)
	skynet.error(syslog.prefix[priority] .. string.format(fmt, ...))
end

local function write (priority, ...)
	if priority >= level then
		if select("#", ...) == 1 then
			skynet.error (syslog.prefix[priority] .. ...)
		else
			syslog.format(priority, ...)
		end
	end
end

--这边看一下消耗...经常log出现endless loop提示...
function syslog.debug (...)
	profile.start()
	write (1, ...)
	local time = profile.stop()
	if time > 1 then
		print("log.debug cost time:"..time)
	end
end


function syslog.info (...)
	write (2, ...)
end


function syslog.notice (...)
	write (3, ...)
end


function syslog.warning (...)
	write (4, ...)
end

function syslog.err (...)
	write (5, ...)
end

syslog.level (tonumber (config.log_level) or 3)

return syslog
