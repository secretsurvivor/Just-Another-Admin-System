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

function JAAS.Hook("Rank")("OnRemove")["PermissionModule::RankCodeUpdate"](isMulti, rank_name, remove_func)
	for k,v in pairs(permission_table) do
		permission_table[k][1] = remove_func(permission_table[k][1])
		PermissionTable:UpdateCode(k, permission_table[k][1])
	end
end

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
			local old_value = self:GetCode()
			permission_table[self:GetName()][1] = code
			Permission_Hook_Run("OnCodeUpdate")(self, code, old_value)
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
			local old_value = self:GetAccessCode()
			permission_table[self:GetName()][2] = access_group
			Permission_Hook_Run("OnAccessUpdate")(self, access_group, old_value)
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
		return self
	end

	function PermissionObject:NetRead()
		self.Name = net.ReadString()
		self.Code = net.ReadUInt(32)
		self.AccessGroup = net.ReadUInt(16)
		return self
	end

	if CLIENT then
		function PermissionObject:SetCode(code)
			permission_table[self:GetName()][1] = code
		end

		function PermissionObject:SetAccessCode(access_group)
			permission_table[self:GetName()][2] = access_group
		end

		function PermissionObject:NetRead()
			self.Name = net.ReadString()
			permission_table[self.Name] = {}
			self:SetCode(net.ReadUInt(32))
			self:SetAccessCode(net.ReadUInt(16))
			return self
		end
	end

	function JAAS.PermissionObject(tab)
		return Object(PermissionObject, tab)
	end
end

local function PermissionObject(tab)
	return Object(PermissionObject, tab)
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

local net_modification_message = {}

do -- Modification Net Message
	function net_modification_message:ModifyCode(permission_object, rank_object)
		self.opcode = 1
		self.permission = permission_object
		self.rank = rank_object
	end

	function net_modification_message:ModifyAccessValue(permission_object, access_group_object)
		self.opcode = 2
		self.permission = permission_object
		self.access_group_object = access_group_object
	end

	function net_modification_message:IsModifyCode()
		return self.opcode == 1
	end

	function net_modification_message:IsModifyAccessGroup()
		return self.opcode == 2
	end

	function net_modification_message:GetPermissionObject()
		return self.permission
	end

	function net_modification_message:GetRankObject()
		return self.rank
	end

	function net_modification_message:GetAccessGroup()
		return self.access_group_object
	end

	function net_modification_message:NetWrite()
		net.WriteUInt(self.opcode, 2)
		self.permission:NetWrite()

		if self.opcode == 1 then
			self.rank:NetWrite()
		elseif self.opcode == 2 then
			self.access_group_object:NetWrite()
		end
	end

	function net_modification_message:NetRead()
		self.code = net.ReadUInt(2)
		self.permission = JAAS.PermissionObject():NetRead()

		if self.opcode == 1 then
			self.rank = JAAS.RankObject():NetRead()
		elseif self.opcode == 2 then
			self.access_group_object = JAAS.AccessGroundObject():NetRead()
		end
	end

	function net_modification_message:SendToServer(index)
		J_NET:Start(index)
		self:NetWrite()
		net.SendToServer()
	end
end

local function ModificationMessage(tab)
	return Object(net_modification_message, tab)
end

MODULE.ModificationMessage = ModificationMessage

local Permission_Net_Sync = MODULE:RegisterNetworkType("Sync")
local Sync_OnConnect = Permission_Net_Sync("OnConnect")

local Permission_Net_Client = MODULE:RegisterNetworkType("Client")
local Client_Modify = Permission_Net_Client("Modify")

local Permission_Net_Update = MODULE:RegisterNetworkType("Update")
local Update_Code = Permission_Net_Update("Code")
local Update_AccessGroup = Permission_Net_Update("AccessGroup")

local CanModifyPermission = MODULE:RegisterPermission("Can Modify Permission")
local CanModifyPermissionValue = MODULE:RegisterPermission("Can Modify Permission Access Group")

do -- Permission Net Code
	/*	Net Code Checklist
		(X = Not Present, O = Present)
		Server:
			On Connect Client Sync (Send) : O

			::Update on {1 = Code, 2 = AccessGroup}::
			On Code Update (Send) : O
			On Access Group Update (Send) : O

			::Support Client Modification::
			Modify Code (Receive) : O
			Modify Access Group (Receive) : O
		Client:
			On Connect Client Sync (Receive) :

			::Update on {1 = Code, 2 = AccessGroup}::
			On Code Update (Receive) : O
				Hook : O
			On Access Group Update (Receive) : O
				Hook : O

			::Support Client Modification::
			Modify Code (Send) : O
			Modify Access Group (Send) : O
	*/
	if SERVER then
		do -- On Code Update (Send)
			function Permission_Hook("OnCodeUpdate")["PermissionModule::UpdateClients"](permission, new_value, old_value)
				J_NET:Start(Update_Code)
				permission:NetWrite()
				net.Broadcast()
			end
		end

		do -- On Access Group Update (Send)
			function Permission_Hook("OnAccessUpdate")["PermissionModule::UpdateClients"](permission, new_value, old_value)
				J_NET:Start(Update_AccessGroup)
				permission:NetWrite()
				net.Broadcast()
			end
		end

		do -- On Connect Client Sync (Send)
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
					PermissionObject{Name = v}:NetWrite()
				end

				net.Send(ply)
			end)
		end

		do -- Modify Code (Receive) | Modify Access Group (Receive)
			J_NET:Receive(Client_Modify, function (len, ply)
				local msg = ModificationMessage():NetRead()

				if msg:IsModifyCode() then
					if CanModifyPermission:Check(ply:GetCode()) then
						if CanModifyPermission:AccessCheck(ply:GetCode()) then
							local permission_object = msg:GetPermissionObject()
							local rank_object = msg:GetRankObject()

							if permission_object:XorCode(rank_object:GetCode()) then
							else
							end
						else
						end
					else
					end
				elseif msg:IsModifyValue() then
					if CanModifyPermissionValue:Check(ply:GetCode()) then
						if CanModifyPermissionValue:AccessCheck(ply:GetCode()) then
							local permission_object = msg:GetPermissionObject()
							local access_group = msg:GetAccessGroup()

							if permission_object:SetAccessCode(access_group:GetValue()) then
							else
							end
						else
						end
					else
					end
				end
			end)
		end
	end

	if CLIENT then
		do -- Modify Code (Send)
			function MODULE:ModifyCode(permission_object, rank_object)
				ModificationMessage():ModifyCode(permission_object, rank_object):SendToServer()
			end
		end

		do -- Modify Access Group (Send)
			function MODULE:ModifyAccessValue(permission_object, access_group_object)
				ModificationMessage():ModifyAccessValue(permission_object, access_group_object):SendToServer()
			end
		end

		do -- On Code Update (Receive) + Hook
			J_NET:Receive(Update_Code, function ()
				local updated_object = PermissionObject():NetRead()
				Permission_Hook_Run("OnCodeUpdate")(updated_object, updated_object:GetCode())
			end)
		end

		do -- On Access Group Update (Receive) + Hook
			J_NET:Receive(Update_AccessGroup, function ()
				local updated_object = PermissionObject():NetRead()
				Permission_Hook_Run("OnAccessUpdate")(updated_object, updated_object:GetCode())
			end)
		end

		do -- On Connect Client Sync (Receive)
			J_NET:Receive(Sync_OnConnect, function ()
				local permission_amount = net.ReadUInt(16)

				local index = 1
				repeat
					PermissionObject():NetRead()

					index = 1 + index
				until (index <= permission_amount)
			end)
		end
	end
end