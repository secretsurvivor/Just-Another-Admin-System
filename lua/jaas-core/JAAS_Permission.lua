local MODULE,LOG,J_NET = JAAS:Module("Permission")

local PermissionTable = JAAS.SQLTableObject()

do -- SQL Permission Table Code
	PermissionTable:SetSQLTable("JAAS_Permission")

	PermissionTable:CreateTable {
		Name = "TEXT NOT NULL PRIMARY KEY",
		Code = "UNSIGNED BIG INT DEFAULT 0",
		AccessGroup = "UNSIGNED INT DEFAULT 0"
	}

	function PermissionTable:Select(name)
		return self:SelectResults(self:Query("select Code,AccessGroup from JAAS_Permission where Name='%s'", name))
	end

	function PermissionTable:Insert(name)
		return self:Query("insert into JAAS_Permission (Name) values ('%s')", name) == nil
	end

	function PermissionTable:UpdateCode(name, code)
		return self:Query("update JAAS_Permission set Code=%s where Name='%s'", code, name) == nil
	end

	function PermissionTable:UpdateAccessGroup(name, access_group)
		return self:Query("update JAAS_Permission set AccessGroup where Name='%s'", access_group, name) == nil
	end
end

local Permission_Hook = JAAS.Hook("Permission")
local Permission_Hook_Run = JAAS.Hook.Run("Permission")

local PermissionDataManipulation_NetType = MODULE:RegisterNetworkType("Modify")
local Modify_PushChange = PermissionDataManipulation_NetType("ClientPush")

local permission_table = permission_table or {} -- [Name] = {1 = Code, 2 = AccessGroup}

local PermissionObject = {Name = ""}

do -- Permission Object Code
	function PermissionObject:GetName()
		return self.Name
	end

	function PermissionObject:GetCode()
		return permission_table[self:GetName()][1]
	end

	function PermissionObject:SetCode(code)
		if PermissionTable:UpdateCode(self:GetName(), code) then
			local old_value = permission_table[self:GetName()][1]
			permission_table[self:GetName()][1] = code
			Permission_Hook_Run("OnCodeChange")(self, code, old_value)
			return true
		end
		return false
	end

	function PermissionObject:XorCode(code)
		return self:SetCode(bit.bxor(self:GetCode(), code))
	end

	function PermissionObject:GetAccessCode()
		return permission_table[self:GetName()][2]
	end

	function PermissionObject:SetAccessCode(access_group)
		if PermissionTable:UpdateAccessGroup(self:GetName(), access_group) then
			local old_value = permission_table[self:GetName()][2]
			permission_table[self:GetName()][2] = access_group
			Permission_Hook_Run("OnAccessChange")(self, access_group, old_value)
			return true
		end
		return true
	end

	function PermissionObject:Check(code)
		return bit.band(self:GetCode(), code) > 0
	end

	function MODULE.Shared:Post()
		local AccessModule = JAAS:GetModule("AccessGroup")

		function PermissionObject:AccessCheck(code)
			return AccessModule:Check("Permission", self:GetAccessCode(), code)
		end

		function PermissionObject:GetPlayers() -- Get All Players that have this permission
			local playersWithPermission = {}

			for k,v in ipairs(player.GetAll()) do
				if self:Check(v:GetCode()) then
					playersWithPermission[1 + #playersWithPermission] = v
				end
			end

			return playersWithPermission
		end
	end

	function PermissionObject:NetWrite()
		net.WriteString(self:GetName())
		net.WriteUInt(self:GetCode(), 32)
		net.WriteUInt(self:GetAccessCode(), 16)
	end

	function PermissionObject:NetRead()
		self.Name = net.ReadString()
		self:SetCode(net.ReadUInt(32))
		self:SetAccessCode(net.ReadUInt(16))
	end

	if CLIENT then
		function PermissionObject:SetCode(code)
			permission_table[self:GetName()][1] = code
		end

		function PermissionObject:SetAccessCode(access_group)
			permission_table[self:GetName()][2] = access_group
		end

		function PermissionObject:PushChanges()
			J_NET:Start(Modify_PushChange)
			self:NetWrite()
			net.SendToServer()
		end
	end
end

function MODULE:RegisterPermission(name)
	local found_data = PermissionTable:Select(name)

	if found_data == nil then
		if PermissionTable:Insert(name) then
			permission_table[name] = {[1] = 0, [2] = 0}
			return Object(PermissionObject, {Name = name})
		else
			error("Invalid Permission Name", 2)
		end
	else
		permission_table[name] = {[1] = found_data.Code, [2] = found_data.AccessGroup}
		return Object(PermissionObject, {Name = name})
	end
end

function MODULE:GetPermission(name)
	if permission_table[name] then
		return Object(PermissionObject, {Name = name})
	else
		error("Permission does not exist", 2)
	end
end

local PermissionDataSync_NetType = MODULE:RegisterNetworkType "Sync"

local Sync_BroadcastUpdate = PermissionDataSync_NetType "BroadcastUpdate"
local Sync_OnConnect = PermissionDataSync_NetType "OnConnect"

local CanModifyPermission = MODULE:RegisterPermission("CanModifyPermission")

do -- Permission Net Code
	if SERVER then
		function Permission_Hook.OnCodeChange["PermissionModule::UpdateClients"](permission, new_value, old_value)
			J_NET:Start(PermissionDataSync_NetType)
			permission:NetWrite()
			net.Broadcast()
		end
	end

	hook.Add("PlayerAuthed", J_NET:GetNetworkString(Sync_OnConnect), function (ply)
		J_NET:Start(Sync_OnConnect)

		local NotDefaultPermissions = {}
		local permission_amount = 0
		for k,v in pairs(permission_table) do
			if v[1] > 0 then
				permission_amount = 1 + permission_amount
				NotDefaultPermissions[1 + #NotDefaultPermissions] = k
			end
		end

		net.WriteUInt(permission_amount, 16)
		for k,v in ipairs(NotDefaultPermissions) do
			Object(PermissionObject, {Name = v}):NetWrite()
		end

		net.Send(ply)
	end)

	function MODULE.Server:Post()
		J_NET:Receive(Modify_PushChange, function (len, ply)
			if CanModifyPermission:Check(ply:GetCode()) then
				Object(PermissionObject):NetRead()
			end
		end)
	end

	if CLIENT then
		J_NET:Receive(Sync_BroadcastUpdate, function ()
			local updated_object = Object(PermissionObject)
			updated_object:NetRead()
			Permission_Hook_Run("OnCodeChange")(updated_object, updated_object:GetCode())
			Permission_Hook_Run("OnAccessChange")(updated_object, updated_object:GetAccessCode())
		end)

		J_NET:Receive(Sync_OnConnect, function ()
			local permission_amount = net.ReadUInt(16)

			local index = 1
			repeat
				Object(PermissionObject):NetRead()

				index = 1 + index
			until (index <= permission_amount)
		end)
	end
end