local math_sqrt = math.sqrt

local _aoifun = {}

local AOI_RADIS2 = 200 * 200
local LEAVE_AOI_RADIS2 = 200 * 200 * 4

local function DIST2(p1,p2)
	return ((p1.x - p2.x) * (p1.x  - p2.x) + (p1.y  - p2.y) * (p1.y  - p2.y) + (p1.z  - p2.z) * (p1.z  - p2.z))
end

--扩展方法表
function _aoifun.expandmethod(obj)
	--获取obj的agent
	function obj:getagentid()
		assert(self.aoiobj)
		return self.aoiobj.agent
	end

	--更新aoilist
	function obj:updateaoilist()
		--离开视野的列表
		local leavelist = {}
		--进入视野的列表
		local enterlist = {}
		for k,v in pairs(self.aoilist) do
			assert(v.movement.pos)
			local distance = DIST2(self:getpos(),v.movement.pos)
			if distance <= AOI_RADIS2 then
				if v.cansend == false then
					enterlist[k] = v
				end
				v.cansend = true
			elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
				v.cansend = false
				leavelist[k] = v
			else
				leavelist[k] = v
				self.aoilist[k] = nil
			end
		end
		return leavelist,enterlist
	end

	--添加对象到aoilist
	function obj:addtoaoilist(aoiobj)
		--assert(not self.aoilist[aoiobj.tempid])
		self.aoilist[aoiobj.tempid] = aoiobj
	end

	--从aoilist中移除对象
	function obj:delfromaoilist(tempid)
		assert(self.aoilist[tempid])
		self.aoilist[tempid] = nil
	end

	--设置aoilist中对象的pos
	function obj:setaoilistpos(tempid,pos)
		assert(self.aoilist[tempid])
		self.aoilist[tempid].movement.pos = pos
	end

	--清空aoilist
	function obj:cleanaoilist()
		self.aoilist = {}
	end

	--获取aoilist
	function obj:getaoilist()
		return self.aoilist
	end

	--设置aoi mode
	function obj:setaoimode(mode)
		assert(type(mode) == "string")
		self.aoiobj.mode = mode
	end

	--设置角色临时id
	function obj:settempid(id)
		assert(self.aoiobj)
		assert(id > 0)
		self.aoiobj.tempid = id
	end

	--获取角色临时id
	function obj:gettempid()
		assert(self.aoiobj)
		return self.aoiobj.tempid
	end

	--设置aoi对象
	function obj:setaoiobj(aoiobj)
		assert(aoiobj)
		self.aoiobj = aoiobj
	end

	--获取aoi对象
	function obj:getaoiobj()
		return self.aoiobj
	end

	--设置角色所在坐标点
	function obj:setpos(pos)
		assert(self.aoiobj)
		assert(pos)
		self.aoiobj.movement.pos = pos
	end

	--获取角色所在坐标点
	function obj:getpos()
		assert(self.aoiobj)
		return self.aoiobj.movement.pos
	end

	--获取移动相关数据
	function obj:getmovement()
		assert(self.aoiobj)
		return self.aoiobj.movement
	end

	--获取两个角色之间的距离
	function obj:getdistance(o)
		return math_sqrt(DIST2(self:getpos(),o:getpos()))
	end

	--获取两个角色之间的距离的平方
	function obj:getdistancesquare(o)
		return DIST2(self:getpos(),o:getpos())
	end

	--设置是否可以发送消息
	function obj:setcansend(bcan)
		assert(self.aoiobj)
		self.aoiobj.cansend = bcan
	end

	--是否可以发送消息给该角色
	function obj:cansend()
		assert(self.aoiobj)
		return self.aoiobj.cansend
	end
end

return _aoifun
