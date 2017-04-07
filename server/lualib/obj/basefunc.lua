local basefunc = {}
local mt = { __index = basefunc }

function basefunc.new (cmd)
	return setmetatable ({
		init_func = {},
		release_func = {},
		cmd = cmd,
	}, mt)
end

function basefunc:init (f)
	table.insert (self.init_func, f)
end

function basefunc:release (f)
	table.insert (self.release_func, f)
end

local function merge (dest, t)
	if not dest or not t then return end
	for k, v in pairs (t) do
		dest[k] = v
	end
end

function basefunc:register (obj)
	for _, f in pairs (self.init_func) do
		f (obj)
	end

	merge (obj, self.cmd)
end

local function clean (dest, t)
	if not dest or not t then return end
	for k, _ in pairs (t) do
		dest[k] = nil
	end
end

function basefunc:unregister (obj)
	for _, f in pairs (self.release_func) do
		f ()
	end

	clean (obj, self.cmd)
end

return basefunc
