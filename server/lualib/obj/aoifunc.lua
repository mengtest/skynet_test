local enumtype = require "enumtype"
local math_sqrt = math.sqrt

local _aoifun = {}

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

	--更新对象的aoiobj信息
	function obj:updateaoiobj(aoiobj)
		assert(self.aoilist[aoiobj.tempid], aoiobj.tempid)
		self.aoilist[aoiobj.tempid] = aoiobj
	end

	--添加对象到aoilist
	function obj:addtoaoilist(aoiobj)
		assert(self.aoilist[aoiobj.tempid] == nil, aoiobj.tempid)
		self.aoilist[aoiobj.tempid] = aoiobj
	end

	--从aoilist中获取对象
	function obj:getfromaoilist(tempid)
		return self.aoilist[tempid]
	end

	--从aoilist中移除对象
	function obj:delfromaoilist(tempid)
		assert(self.aoilist[tempid],self.aoilist)
		self.aoilist[tempid] = nil
	end

	--清空aoilist
	function obj:cleanaoilist()
		self.aoilist = {}
	end

	--获取aoilist
	function obj:getaoilist()
		return self.aoilist
	end

	--获取aoilist是否为空
	function obj:getifaoilistempty()
		return table.empty(self.aoilist)
	end

	--获取可以发送信息的给前段的aoilist
	function obj:getsend2clientaoilist()
		local fdlist = {}
		for _,v in pairs(self.aoilist) do
			if v.type == enumtype.CHAR_TYPE_PLAYER then
				table.insert(fdlist,v.info)
			end
		end
		return fdlist
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

	--获取角色posdata key
	--agent-tempid
	function obj:getposdatakey()
		assert(self.aoiobj)
		assert(self.aoiobj.agent)
		assert(self.aoiobj.tempid)
		return self.aoiobj.agent.."-"..self.aoiobj.tempid
	end

	--设置aoi对象
	function obj:setaoiobj(aoiobj)
		assert(aoiobj)
		for k,v in pairs(aoiobj) do
			for kk,vv in pairs(v) do
				if self.aoiobj[k] == nil then
					self.aoiobj[k] = { kk }
				end
				self.aoiobj[k][kk] = vv
			end
		end
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

	--设置对象删除信息
	function obj:set_aoi_del(del)
		assert(self.aoiobj)
		self.aoiobj.movement.del = del
	end

	--获取对象是否已经被删除
	function obj:get_aoi_del()
		assert(self.aoiobj)
		return self.aoiobj.movement.del
	end
end

return _aoifun
