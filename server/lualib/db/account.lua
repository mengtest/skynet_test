
local account = {}

local connection_handler

function account.init (ch)
	connection_handler = ch
end

return account