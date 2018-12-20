local conf = {}

local host = "127.0.0.1"
local port = 3306
local database = "skynet"
local user = "root"
local password = "123456qi"
local max_packet_size = 1024 * 1024

local function on_connect(db)
	db:query("set charset utf8");
end

local center = {
	host = host,
	port = port,
	database = database,
	user = user,
	password = password,
	max_packet_size = max_packet_size,
	on_connect = on_connect
}

local ngroup = 0
local group = {}
for i = 1, ngroup do
	table.insert (group, { host = host, port = port + i, database = database, 
		user = user, password = password,max_packet_size = max_packet_size,})
end

conf = { center = center , group = group }

return conf