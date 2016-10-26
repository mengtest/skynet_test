local skynet = require "skynet"

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

function syslog.debug (...)
	write (1, ...)
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


--[[
local function treaverse_global_env(curtable,level,withEnd)
    for key,value in pairs(curtable or {}) do
	    local prefix = string.rep("\t",level)
	    if type(value)~="table" then
		    print(string.format("%s%s = %s [%s]",prefix,key,tostring(value),type(value)))
		else
		    print(string.format("%s%s = \n %s\t{",prefix,key,prefix))
		end
	    if (type(value) == "table" ) and key ~= "_G" and (not value.package) then
	        treaverse_global_env(value,level + 1,true)
	    elseif (type(value) == "table" ) and (value.package) then
	        print(string.format("%sSKIPTABLE:%s",prefix,key))
	    end 
    end 
    if withEnd then
	    local prefix = string.rep("\t",level)
		print(string.format("%s}",prefix))
    end
end

cclog = function(...)
    if type(...) == "table" then
		local tconcat = table.concat
		local tinsert = table.insert
		local srep = string.rep

		print("-----------↓表数据输入↓--------") 
        treaverse_global_env(...,0)
        print("-----------↑表数据输入↑--------")
	else
	    print(...)
	end
end
]]