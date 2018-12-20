local conf = {}

local host = "mongodb.tbiglong.com"
local port = 27017
local database = "skynet"
local username = nil
local password = nil

local center = {
	host = host,
	port = port,
	username = username,
	password = password,
	authdb = database,
}

local ngroup = 0
local group = {}
for i = 1, ngroup do
	table.insert (group, { 
		host = host,
		port = port + i,
		username = username,
		password = password,
		authdb = database,
		})
end

conf = { center = center , group = group }

return conf