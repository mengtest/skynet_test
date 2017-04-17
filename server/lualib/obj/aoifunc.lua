local sharemap = require "sharemap"
local math_sqrt = math.sqrt

local _aoifun = {}

local AOI_RADIS2 = 200 * 200
local LEAVE_AOI_RADIS2 = 200 * 200 * 4

local function DIST2(p1,p2)
	return ((p1.x - p2.x) * (p1.x  - p2.x) + (p1.y  - p2.y) * (p1.y  - p2.y) + (p1.z  - p2.z) * (p1.z  - p2.z))
end

--扩展方法表
function _aoifun.expandmethod(obj)

	--添加reader到list
	function obj:addtoreaderlist(tempid,reader)
		assert(self.readerlist[tempid] == nil)
		assert(self.aoilist[tempid] == nil)
		self.readerlist[tempid] = reader
	end

	--从readerlist中移除
	function obj:delfromreaderlist(tempid)
		assert(self.readerlist[tempid])
		self.readerlist[tempid] = nil
	end

	--获取list中的reader
	function obj:getreaderfromlist(tempid)
		return self.readerlist[tempid]
	end

	--清理readerlist
	function obj:cleanreaderlist()
		self.readerlist = {}
	end

	--提交改变
	function obj:writercommit()
		assert(self.characterwriter)
		self.characterwriter:commit()
	end

	--创建writer
	function obj:createwriter()
		assert(self.characterwriter == nil )
		self.characterwriter = sharemap.writer ("charactermovement", self:getmovement())
	end

	--获取reader副本
	function obj:getwritecopy()
		assert(self.characterwriter)
		return self.characterwriter:copy()
	end

	--创建reader
	function obj:createreader(writer)
		assert(writer)
		return sharemap.reader ("charactermovement", writer)
	end

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
		for k,v in pairs(self.readerlist) do
			v:update()
			assert(v.pos)
			assert(self.aoilist[k].movement.pos)
			self.aoilist[k].movement.pos = v.pos
			local distance = DIST2(self:getpos(),v.pos)
			if distance <= AOI_RADIS2 then
				if self.aoilist[k].cansend == false then
					enterlist[k] = self.aoilist[k]
				end
				self.aoilist[k].cansend = true
			elseif distance > AOI_RADIS2 and distance <= LEAVE_AOI_RADIS2 then
				self.aoilist[k].cansend = false
				leavelist[k] = self.aoilist[k]
			else
				leavelist[k] = self.aoilist[k]
				self.aoilist[k] = nil
				self.readerlist[k] = nil
			end
		end
		return leavelist,enterlist
	end

	--添加对象到aoilist
	function obj:addtoaoilist(aoiobj)
		assert(self.readerlist[aoiobj.tempid])
		assert(self.aoilist[aoiobj.tempid] == nil)
		self.aoilist[aoiobj.tempid] = aoiobj
	end

	--从aoilist中移除对象
	function obj:delfromaoilist(tempid)
		assert(self.aoilist[tempid])
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
		for k,v in pairs(aoiobj) do
			self.aoiobj[k] = v
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
