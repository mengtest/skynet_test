local skynet = require "skynet"
local service = require "service"
local log = require "syslog"

local mysqlpool
local CMD = {}

--检查角色名是否重复
function CMD.playernamecheck(name)
  local sql = string.format("select name from playerdate where name = '%s' limit 0,1", name)
  local result = skynet.call(mysqlpool,"lua","execute",sql)
  if not result.badresult then
    if table.empty(result) then
      return true
    else
      return false
    end
  else
    log.error("errno:"..result.errno.." sqlstate:"..result.sqlstate.." err:"..result.err.."\nsql:"..sql)
    return false
  end
end

function CMD.close()
  log.notice("close namecheck...")
end

local function init()
  mysqlpool = skynet.uniqueservice("mysqlpool")
end

service.init {
	command = CMD,
  init = init,
}
