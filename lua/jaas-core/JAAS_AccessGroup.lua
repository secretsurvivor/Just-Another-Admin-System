local MODULE,LOG,J_NET = JAAS:Module("AccessGroup")

local AccessGroupTable = JAAS.SQLTableObject()

do -- Access Group SQL Table
	AccessGroupTable:SetSQLTable("JAAS_AccessGroup")

	AccessGroupTable:CreateTable {
		Name = "TEXT NOT NULL", -- Required
		Code = "UNSIGNED BIG INT DEFAULT 0",
		AccessGroupValue = "UNSIGNED INT DEFAULT 0",
		AccessType = "TEXT NOT NULL", -- Required
		"PRIMARY KEY(Name, AccessType)"
	}

	function AccessGroupTable:Select(name, accessType)
		return self:SelectResults(self:Query("select Code,AccessGroupValue from JAAS_AccessGroup where Name='%s' and AccessType='%s'", name, accessType))
	end

	function AccessGroupTable:SelectAllByGroupType(accessType)
		return self:SelectResults(self:Query("select Name,Code,AccessGroupValue from JAAS_AccessGroup where AccessType='%s'", accessType))
	end

	function AccessGroupTable:SelectAllGroupTypes()
		return self:SelectResults(self:Query("select distinct AccessType from JAAS_AccessGroup"))
	end

	function AccessGroupTable:Insert(name, accessType)
		return self:Query("insert into JAAS_AccessGroup (Name,AccessType) values ('%s','%s')", name, accessType) == nil
	end

	function AccessGroupTable:UpdateCode(name, accessType, code)
		return self:Query("update JAAS_AccessGroup set Code=%s where Name='%s' and AccessType='%s'", code, name, accessType) == nil
	end

	function AccessGroupTable:UpdateGroupValue(name, accessType, value)
		return self:Query("update JAAS_AccessGroup set AccessGroupValue=%s where Name='%s' and AccessType='%s'", value, name, accessType) == nil
	end

	function AccessGroupTable:Delete(name, accessType)
		return self:Query("delete from JAAS_AccessGroup where Name='%s' and AccessType='%s'", name, accessType) == nil
	end
end

local AccessGroup_Hook = JAAS.Hook("AccessGroup")
local AccessGroup_Hook_Run = JAAS.Hook.Run("AccessGroup")

local dirty = true
local access_group_table = {} -- [AccessType][Name] = {1 = Code, 2 = AccessGroupValue}

local check_dirty = true
local check_value_cache = {}

local access_group_manager = {}

do -- Table Manager Functions
	if SERVER then
		function access_group_manager:Get(name, accessType)
			if dirty then
				access_group_table = {}
				dirty = false
			end

			if access_group_table[accessType] == nil then
				access_group_table[accessType] = {[name] = {}}
			end

			if access_group_table[accessType][name] == nil then
				local data = AccessGroupTable:Select(name, accessType)
				if data then
					access_group_table[accessType][name] = {data.Code, data.AccessGroupValue}
				else
					error("Access Group not found")
				end
			end

			return access_group_table[accessType][name]
		end
	elseif CLIENT then
		function access_group_manager:Get(name, accessType)
			if access_group_table[accessType] == nil then
				access_group_table[accessType] = {[name] = {}}
				error("Access Group not found")
			end

			if access_group_table[accessType][name] == nil then
				error("Access Group not found")
			end

			return access_group_table[accessType][name]
		end
	end

	function access_group_manager:MakeDirty()
		dirty = true
		check_dirty = true
	end
end

local AccessGroupObject = {}

do -- Access Group Object Code
	function AccessGroupObject:GetName()
		return self.name
	end

	function AccessGroupObject:GetAccessType()
		return self.type
	end

	function AccessGroupObject:GetCode()
		return access_group_manager:Get(self.name, self.type)[1]
	end

	function AccessGroupObject:SetCode(code)
		if AccessGroupTable:UpdateCode(self.name, self.type, code) then
			local old_value = self:GetCode()
			access_group_manager:MakeDirty()
			AccessGroup_Hook_Run("OnCodeChange")(self, code, old_value)
		end
	end

	function AccessGroupObject:XorCode(code)
		return self:SetCode(bit.bxor(self:GetCode(), code))
	end

	function AccessGroupObject:GetValue()
		return access_group_manager:Get(self.name, self.type)[2]
	end

	function AccessGroupObject:SetValue(value)
		if AccessGroupTable:UpdateGroupValue(self.name, self.type, value) then
			local old_value = self:GetValue()
			access_group_manager:MakeDirty()
			AccessGroup_Hook_Run("OnValueChange")(self, value, old_value)
		end
	end

	function AccessGroupObject:NetWrite()
		net.WriteString(self:GetName())
		net.WriteString(self:GetAccessType())
		net.WriteUInt(self:GetCode(), 32)
		net.WriteUInt(self:GetValue(), 8)
	end

	function AccessGroupObject:NetRead()
		self.name = net.ReadString()
		self.type = net.ReadString()
		self.code = net.ReadUInt(32)
		self.value = net.ReadUInt(8)
	end

	if CLIENT then
		function AccessGroupObject:SetCode(code)
			if access_group_table[self.type] == nil then
				access_group_table[self.type] = {[self.name] = {code}}
			else
				if access_group_table[self.type][self.name] == nil then
					access_group_table[self.type][self.name] = {code}
				else
					access_group_table[self.type][self.name][1] = code
				end
			end
		end

		function AccessGroupObject:SetValue(value)
			if access_group_table[self.type] == nil then
				access_group_table[self.type] = {[self.name] = {value}}
			else
				if access_group_table[self.type][self.name] == nil then
					access_group_table[self.type][self.name] = {value}
				else
					access_group_table[self.type][self.name][2] = value
				end
			end
		end

		function AccessGroupObject:NetRead()
			self.name = net.ReadString()
			self.type = net.ReadString()
			self:SetCode(net.ReadUInt(32))
			self:SetValue(net.ReadUInt(8))
		end
	end

	function JAAS.AccessGroundObject(tab)
		return Object(AccessGroupObject, tab)
	end
end

local function AccessGroundObject(tab)
	return Object(AccessGroupObject, tab)
end

function MODULE:AddAccessGroup(name, accessType)
	if AccessGroupTable:Insert(name, accessType) then
		check_dirty = true
		local obj = AccessGroundObject({name = name, type = accessType})
		AccessGroup_Hook_Run("OnAdd")(obj)

		return obj
	end
	return false
end

function MODULE:RemoveAccessGroup(name, accessType)
	if AccessGroupTable:Delete(name, accessType) then
		check_dirty = true
		AccessGroup_Hook_Run("OnRemove")(name, accessType)

		return true
	end
	return false
end

function MODULE:GetAllGroupTypes()
	local found_types = {}

	for k,v in ipairs(AccessGroupTable:SelectAllGroupTypes()) do
		found_types[1 + #found_types] = AccessGroundObject({name = v.Name})
	end

	return found_types
end

function MODULE:GetAllAccessGroupsByType(accessType)
	local found_groups = {}

	for k,v in ipairs(AccessGroupTable:SelectAllByGroupType(accessType)) do
		found_groups[1 + #found_groups] = AccessGroundObject({name = v.Name})
	end

	return found_groups
end

if SERVER then
	local function checkValue(type, value, code)
		local found_groups = AccessGroupTable:Query("select Code from JAAS_AccessGroup where AccessGroupValue >= %s and AccessType = '%s'", value, type)

		if found_groups then
			for k,v in ipairs(found_groups) do
				if bit.band(v.Code, code) > 0 then
					return true
				end
			end
		end

		return false or (AccessGroupTable:Query("select count(Name) from JAAS_AccessGroup where AccessType='%s'", type) == 0)
	end

	function MODULE:Check(type, value, code)
		if check_dirty then
			check_dirty = false
			check_value_cache = {[type] = {[value] = checkValue(type, value, code)}}
		end

		if check_value_cache[type] == nil then
			check_value_cache[type] = {[value] = checkValue(type, value, code)}
		end

		if check_value_cache[type][value] != nil then
			check_value_cache[type][value] = checkValue(type, value, code)
		end

		return check_value_cache[type][value]
	end
end

local net_modification_message = {}

do -- Modification Net Message
	function net_modification_message:AddAccessGroup(name, accessType)
		self.opcode = 1
		self.name = name
		self.accessType = accessType
	end

	function net_modification_message:ModifyAccessGroupCode(access_group, rank_object)
		self.opcode = 2
		self.access_group = access_group
		self.rank_object = rank_object
	end

	function net_modification_message:ModifyAccessGroupValue(access_group, value)
		self.opcode = 3
		self.access_group = access_group
		self.value = value
	end

	function net_modification_message:RemoveAccessGroup(access_group)
		self.opcode = 4
		self.access_group = access_group
	end

	function net_modification_message:IsAdd()
		return self.opcode == 1
	end

	function net_modification_message:IsModifyCode()
		return self.opcode == 2
	end

	function net_modification_message:IsModifyValue()
		return self.opcode == 3
	end

	function net_modification_message:IsRemove()
		return self.opcode == 4
	end

	function net_modification_message:GetAddParameters()
		return self.name,self.accessType
	end

	function net_modification_message:GetAccessGroup()
		return self.access_group
	end

	function net_modification_message:GetRankObject()
		return self.rank_object
	end

	function net_modification_message:GetValue()
		return self.value
	end

	function net_modification_message:NetWrite()
		net.WriteUInt(self.opcode, 3)
		if self.opcode == 1 then
			net.WriteString(self.name)
			net.WriteString(self.accessType)
		else
			self.access_group:NetWrite()

			if self.opcode == 2 then
				self.rank_object:NetWrite()
			elseif self.opcode == 3 then
				net.WriteUInt(self.value, 8)
			end
		end
	end

	function net_modification_message:NetRead()
		self.opcode = net.ReadUInt(3)
		if self.opcode == 1 then
			self.name = net.ReadString()
			self.accessType = net.ReadString()
		else
			self.access_group = JAAS.AccessGroundObject():NetRead()

			if self.opcode == 2 then
				self.rank_object = JAAS.RankObject():NetWrite()
			elseif self.opcode == 3 then
				self.value = net.ReadUInt(8)
			end
		end
	end
end

local function ModificationMessage(tab)
	return Object(net_modification_message, tab)
end

MODULE.ModificationMessage = ModificationMessage

do -- Access Group Net Code
	local AccessGroup_Net_Update = MODULE:RegisterNetworkType("ClientUpdate")
	local Update_Added = AccessGroup_Net_Update("Added")
	local Update_Removed = AccessGroup_Net_Update("Removed")

	local AccessGroup_Net_Client = MODULE:RegisterNetworkType("Client")
	local Client_Modify = AccessGroup_Net_Client("Modify")
	local Client_GetType = AccessGroup_Net_Client("GetType")
	local Client_Get = AccessGroup_Net_Client("Get")

	function MODULE.Server:Post()
		local PermissionModule = JAAS:GetModule("Permission")

		local CanAddAccessGroup = PermissionModule:RegisterPermission("Can Add Access Group")
		local CanModifyAccessGroupCode = PermissionModule:RegisterPermission("Can Modify Access Group Code")
		local CanModifyAccessGroupValue = PermissionModule:RegisterPermission("Can Modify Access Group Value")
		local CanRemoveAccessGroup = PermissionModule:RegisterPermission("Can Remove Access Group")

		J_NET:Receive(Client_Modify, function (len, ply)
			local msg = ModificationMessage():NetRead()

			if msg:IsAdd() then
				if CanAddAccessGroup:Check(ply:GetCode()) then
					if MODULE:AddAccessGroup(msg:GetAddParameters()) then
					else
					end
				else
				end
			elseif msg:IsModifyCode() then
				if CanModifyAccessGroupCode:Check(ply:GetCode()) then
					local access_group = msg:GetAccessGroup()
					local rank_object = msg:GetRankObject()

					if access_group:XorCode(rank_object:GetCode()) then
					else
					end
				else
				end
			elseif msg:IsModifyValue() then
				if CanModifyAccessGroupValue:Check(ply:GetCode()) then
					local access_group = msg:GetAccessGroup()
					local value = msg:GetValue()

					if access_group:SetValue(value) then
					else
					end
				else
				end
			elseif msg:IsRemove() then
				if CanRemoveAccessGroup:Check(ply:GetCode()) then
					local access_group = msg:GetAccessGroup()
				else
				end
			end
		end)

		local CanViewAccessGroups = PermissionModule:RegisterPermission("Can View Access Groups")

		function AccessGroup_Hook.OnAdd["AccessGroup::UpdateClientAdd"](obj)
			J_NET:Start(Update_Added)
			obj:NetWrite()
			net.Send(CanViewAccessGroups:GetPlayers())
		end

		function AccessGroup_Hook.OnRemove["AccessGroup::UpdateClientRemove"](name, accessType)
			J_NET:Start(Update_Removed)
			net.WriteString(name)
			net.WriteString(accessType)
			net.Send(CanViewAccessGroups:GetPlayers())
		end

		J_NET:Receive(Client_GetType, function (len, ply)
			if CanViewAccessGroups:Check(ply:GetCode()) then
				local found_types = MODULE:GetAllGroupTypes()

				J_NET:Start(Client_GetType)

				net.WriteUInt(#found_types, 8)
				for k,v in ipairs(found_types) do
					v:NetWrite()
				end

				net.Send(ply)
			end
		end)

		J_NET:ReceiveString(Client_Get, function (str, ply)
			if CanViewAccessGroups:Check(ply:GetCode()) then
				local found_groups = MODULE:GetAllAccessGroupsByType(str)

				J_NET:Start(Client_Get)

				net.WriteUInt(#found_groups, 8)
				for k,v in ipairs(found_groups) do
					v:NetWrite()
				end

				net.Send(ply)
			end
		end)
	end

	if CLIENT then
		---- Overridden Module Functions for Client ----
		function MODULE:GetAllGroupTypes()
			J_NET:Request(Client_GetType)
		end

		function MODULE:GetAllAccessGroupsByType(accessType)
			J_NET:SendString(Client_Get, accessType)
		end
		---- ----

		J_NET:Receive(Update_Added, function ()
			local obj = AccessGroundObject():NetRead()
			AccessGroup_Hook_Run("OnAdd")(obj)
		end)

		J_NET:Receive(Update_Removed, function ()
			local name = net.ReadString()
			local accessType = net.ReadString()

			AccessGroup_Hook_Run("OnRemove")(name, accessType)
		end)

		J_NET:Receive(Client_GetType, function ()
			local retrieved_types = {}
			local type_amount = net.ReadUInt(8)

			local index = 1
			repeat
				retrieved_types[index] = AccessGroundObject():NetRead()
				index = 1 + index
			until (index <= type_amount)

			AccessGroup_Hook_Run("OnRetrievedAllTypes")(retrieved_types)
		end)

		J_NET:Receive(Client_Get, function ()
			local retrieved_groups = {}
			local group_amount = net.ReadUInt(8)

			local index = 1
			repeat
				retrieved_groups[index] = AccessGroundObject():NetRead()
				index = 1 + index
			until (index <= type_amount)

			AccessGroup_Hook_Run("OnRetrievedGroups")(retrieved_groups)
		end)
	end

end