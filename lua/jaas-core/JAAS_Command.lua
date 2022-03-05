local MODULE,LOG,J_NET = JAAS:Module("Command")

local CommandTable = JAAS.SQLTableObject()

do -- Command SQL Table
	CommandTable:SetSQLTable("JAAS_Command")

	CommandTable:CreateTable{
		Name = "TEXT NOT NULL",
		Category = "TEXT NOT NULL",
		Code = "UNSIGNED BIG INT DEFAULT 0",
		AccessGroup = "UNSIGNED INT DEFAULT 0",
		"PRIMARY KEY(Name, Category)"
	}

	function CommandTable:Select(name, category)
		return self:SelectResults(self:Query("select Code,AccessGroup from JAAS_Command where Name='%s' and Category='%s'", Name, Category))
	end

	function CommandTable:Insert(name, category)
		return self:Query("insert into JAAS_Command (Name, Category) values ('%s', '%s')", Name, Category) == nil
	end

	function CommandTable:UpdateCode(name, category, code)
		return self:Query("update JAAS_Command set Code=%s where Name='%s' and Category='%s'", code, name, category) == nil
	end

	function CommandTable:UpdateAccessGroup(name, category, value)
		return self:Query("update JAAS_Command set AccessGroup=%s where Name='%s' and Category='%s'", value, name, category) == nil
	end
end

local Command_Hook = JAAS.Hook("Command")
local Command_Hook_Run = JAAS.Hook.Run("Command")

local command_table = {} -- [Category:Name] = {1 = Code, 2 = AccessGroup, 3 = function, 4 = Parameters}

function JAAS.Hook("Rank")("OnRemove")["CommandModule::RankCodeUpdate"](isMulti, rank_name, remove_func)
	for k,v in pairs(command_table) do
		command_table[k][1] = remove_func(command_table[k][1])
		local split = string.Explode(":", k)
		CommandTable:UpdateCode(split[2], split[1], command_table[k][1])
	end
end

local CommandObject = {}

do -- Command Object Code
	function CommandObject:GetName()
		return self.name
	end

	function CommandObject:GetCategory()
		return self.category
	end

	function CommandObject:BuildKey()
		return self.category + ":" + self.name
	end

	function CommandObject:IsPresent()
		return command_table[self:BuildKey()] != nil
	end

	function CommandObject:GetCode()
		return command_table[self:BuildKey()][1]
	end

	function CommandObject:Setcode(code)
		if CommandTable:UpdateCode(self.name, self.category, code) then
			local old_value = self:GetCode()
			command_table[self:BuildKey()][1] = code
			Command_Hook_Run("OnCodeUpdate")(self, code, old_value)
			return true
		end
		return false
	end

	function CommandObject:GetAccessCode()
		return command_table[self:BuildKey()][2]
	end

	function CommandObject:SetAccessCode(value)
		if CommandTable:UpdateAccessGroup(self.name, self.category, value) then
			local old_value = self:GetAccessCode()
			command_table[self:BuildKey()][2] = value
			Command_Hook_Run("OnAccessUpdate")(self, value, old_value)
			return true
		end
		return false
	end

	function CommandObject:Check(code)
		return bit.band(self:GetCode(), code) > 0
	end

	function MODULE.Shared:Post()
		local AccessModule = JAAS:GetModule("AccessGroup")

		function CommandObject:AccessCheck(code)
			return AccessModule:Check("Command", self:GetAccessCode(), code)
		end
	end

	function CommandObject:NetWrite()
		net.WriteString(self:GetName())
		net.WriteString(self:GetCategory())
		net.WriteUInt(self:GetCode(), 32)
		net.WriteUInt(self:GetAccessCode(), 8)
	end

	function CommandObject:NetRead()
		self.name = net.ReadString()
		self.category = net.ReadString()
		self.code = net.ReadUInt(32)
		self.value = net.ReadUInt(8)
	end

	function CommandObject:SaveLocal() -- Should be executed post NetRead
		self:SetCode(self.code)
		self:SetAccessCode(self.value)
	end

	function CommandObject:Execute(...)
		return command_table[self:BuildKey()][3](...)
	end

	if SERVER then
		function CommandObject:NetExecute()
			local parameters = command_table[self:BuildKey()][4]
			local read_parameter_values = {}

			for index,info in ipairs(parameters) do
				read_parameter_values[index] = info:NetRead()
			end

			self:Execute(unpack(read_parameter_values))
		end
	end
end

local function CommandObject(name, category)
	return Object(CommandObject, {name = name, category = category})
end

local ParameterTable = {}
local ParameterObject = {
	BoolObject = {},
	IntObject = {},
	FloatObject = {},
	StringObject = {},
	PlayerObject = {},
	PlayersObject = {},
	OptionObject = {},
	OptionsObject = {}
}

do -- Parameter Object Code
	do -- Bool Object Code
		function ParameterObject.BoolObject:Set(name, default)
			self.name = name
			self.default = default
			return self
		end

		function ParameterObject.BoolObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.BoolObject:GetValue()
			return self.value
		end

		function ParameterObject.BoolObject:NetWrite()
			net.WriteBool(self.value)
		end

		function ParameterObject.BoolObject:NetRead()
			self.value = net.ReadBool()
			return self.value
		end
	end

	local function BoolObject(tab)
		return Object(ParameterObject.BoolObject, tab)
	end

	do -- Int Object Code
		function ParameterObject.IntObject:Set(name, default, min, max)
			self.name = name
			self.default = default
			self.min = min
			self.max = max
			return self
		end

		function ParameterObject.IntObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.IntObject:GetValue()
			return self.value
		end

		function ParameterObject.IntObject:NetWrite()
			net.WriteInt(self.value, 32)
		end

		function ParameterObject.IntObject:NetRead()
			self.value = net.ReadInt(32)
			return self.value
		end
	end

	local function IntObject(tab)
		return Object(ParameterObject.IntObject, tab)
	end

	do -- Float Object Code
		function ParameterObject.FloatObject:Set(name, default, min, max)
			self.name = name
			self.default = default
			self.min = min
			self.max = max
			return self
		end

		function ParameterObject.FloatObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.FloatObject:GetValue()
			return self.value
		end

		function ParameterObject.FloatObject:NetWrite()
			net.WriteFloat(self.value)
		end

		function ParameterObject.FloatObject:NetRead()
			self.value = net.ReadFloat()
			return self.value
		end
	end

	local function FloatObject(tab)
		return Object(ParameterObject.FloatObject, tab)
	end

	do -- String Object Code
		function ParameterObject.StringObject:Set(name, default)
			self.name = name
			self.default = default
			return self
		end

		function ParameterObject.StringObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.StringObject:GetValue()
			return self.value
		end

		function ParameterObject.StringObject:NetWrite()
			net.WriteString(self.value)
		end

		function ParameterObject.StringObject:NetRead()
			self.value = net.ReadString()
			return self.value
		end
	end

	local function StringObject(tab)
		return Object(ParameterObject.StringObject, tab)
	end

	do -- Player Object Code
		function ParameterObject.PlayerObject:Set(name, filter_func)
			self.name = name
			self.filter_func = filter_func
			return self
		end

		function ParameterObject.PlayerObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.PlayerObject:GetValue()
			return self.value
		end

		function ParameterObject.PlayerObject:NetWrite()
			net.WriteUInt(self.value:UserID(), 32)
		end

		function ParameterObject.PlayerObject:NetRead()
			self.value = player.GetByID(net.ReadUInt(32))
			return self.value
		end
	end

	local function PlayerObject(tab)
		return Object(ParameterObject.PlayerObject, tab)
	end

	do -- Players Object Code
		function ParameterObject.PlayersObject:Set(name, filter_func)
			self.name = name
			self.filter_func = filter_func
			return self
		end

		function ParameterObject.PlayersObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.PlayersObject:GetValue()
			return self.value
		end

		function ParameterObject.PlayersObject:NetWrite()
			net.WriteUInt(#self.value, 8)
			for k,v in ipairs(self.value) do
				net.WriteUInt(v:UserID(), 32)
			end
		end

		function ParameterObject.PlayersObject:NetRead()
			local amount = net.ReadUInt(8)
			local read_plyers = {}
			local index = 1
			repeat
				read_plyers[index] = player.GetByID(net.ReadUInt(32))
				index = 1 + index
			until (index <= amount)
			self.value = read_plyers
			return self.value
		end
	end

	local function PlayersObject(tab)
		return Object(ParameterObject.PlayersObject, tab)
	end

	do -- Option Object Code
		function ParameterObject.OptionObject:Set(name, option_list, default, filter_func)
			self.name = name
			self.option_list = option_list
			self.default = default
			self.filter_func = filter_func
			return self
		end

		function ParameterObject.OptionObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.OptionObject:GetValue()
			return option_list[self.value]
		end

		function ParameterObject.OptionObject:NetWrite()
			net.WriteUInt(self.value, 8)
		end

		function ParameterObject.OptionObject:NetRead()
			self.value = net.ReadUInt(8)
			return self:GetValue()
		end
	end

	local function OptionObject(tab)
		return Object(ParameterObject.OptionObject, tab)
	end

	do -- Options Object Code
		function ParameterObject.OptionsObject:Set(name, option_list, default, filter_func)
			self.name = name
			self.option_list = option_list
			self.default = default
			self.filter_func = filter_func
			return self
		end

		function ParameterObject.OptionsObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.OptionsObject:GetValue()
			local convert_options = {}
			for k,v in ipairs(self.value) do
				convert_options[k] = option_list[v]
			end
			return convert_options
		end

		function ParameterObject.OptionsObject:NetWrite()
			net.WriteUInt(#self.value, 8)
			for k,v in ipairs(self.value) do
				net.WriteUInt(v, 8)
			end
		end

		function ParameterObject.OptionsObject:NetRead()
			local amount = net.ReadUInt(8)
			local read_options = {}
			local index = 1
			repeat
				read_options[index] = net.ReadUInt(8)
				index = 1 + index
			until (index <= amount)
			self.value = read_options
			return self:GetValue()
		end
	end

	local function OptionsObject(tab)
		return Object(ParameterObject.OptionsObject, tab)
	end

	do -- Parameter Table Object
		function ParameterTable:AddBool(name, default)
			self.internal[1 + #self.internal] = BoolObject():Set(name, default)
		end

		function ParameterTable:AddInt(name, default)
			self.internal[1 + #self.internal] = IntObject():Set(name, default, min, max)
		end

		function ParameterTable:AddFloat(name, default)
			self.internal[1 + #self.internal] = FloatObject():Set(name, default, min, max)
		end

		function ParameterTable:AddString(name, default)
			self.internal[1 + #self.internal] = StringObject():Set(name, filter_func)
		end

		function ParameterTable:AddPlayer(name, default)
			self.internal[1 + #self.internal] = PlayerObject():Set(name, filter_func)
		end

		function ParameterTable:AddPlayers(name, default)
			self.internal[1 + #self.internal] = PlayersObject():Set(name, filter_func)
		end

		function ParameterTable:AddOption(name, default, option_list)
			self.internal[1 + #self.internal] = OptionObject():Set(name, option_list, default, filter_func)
		end

		function ParameterTable:AddOptions(name, default, option_list)
			self.internal[1 + #self.internal] = OptionsObject():Set(name, option_list, default, filter_func)
		end

		function ParameterTable:BuildTable()
			return self.internal
		end

		function ParameterTable:Push()
			local tab = self:BuildTable()
			self.internal = {}
			return tab
		end
	end
end

function MODULE:SetCategory(category)
	self.category = category
end

function MODULE:ParameterBuilder()
	return Object(ParameterTable, {internal = {}})
end

function MODULE:RegisterCommand(name, parameters, func)
	if CommandTable:Insert(name, self.category) then
		command_table[self.category + ":" + name] = {0, 0, func, parameters}
		return CommandObject(name, self.category)
	else
		local found_command = CommandTable:Select(name, self.category)

		if found_command then
			command_table[self.category + ":" + name] = {found_command.Code, found_command.AccessGroup, func, parameters}
			return CommandObject(name, self.category)
		else
			error("An error occurred whilst registering Command", 2)
		end
	end
end

local net_modification_message = {}

do -- Modification Net Message Code
	function net_modification_message:ModifyCode(command_object, rank_object)
		self.opcode = 1
		self.command_object = command_object
		self.rank_object = rank_object
	end

	function net_modification_message:ModifyAccessValue(command_object, access_group_object)
		self.opcode = 2
		self.command_object = command_object
		self.access_group_object = access_group_object
	end

	function net_modification_message:IsModifyCode()
		return self.opcode == 1
	end

	function net_modification_message:IsModifyValue()
		return self.opcode == 2
	end

	function net_modification_message:GetCommandObject()
		return self.command_object
	end

	function net_modification_message:GetRankObject()
		return self.rank_object
	end

	function net_modification_message:GetAccessGroup()
		return self.access_group_object
	end

	function net_modification_message:NetWrite()
		net.WriteUInt(self.opcode, 2)
		self.command_object:NetWrite()

		if self.opcode == 1 then
			self.rank_object:NetWrite()
		elseif self.opcode == 2 then
			self.access_group_object:NetWrite()
		end
		return self
	end

	function net_modification_message:NetRead()
		self.opcode = net.ReadUInt(2)
		self.command_object = CommandObject():NetRead()

		if self.opcode == 1 then
			self.rank_object = JAAS.RankObject:NetRead()
		elseif self.opcode == 2 then
			self.access_group_object = JAAS.AccessGroup:NetRead()
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

do -- Net Code
	/*	Net Code Checklist
		(X = Not Present, O = Present)
		Server:
			On Connect Sync (Send) : O
			Execute Command (Receive) : O
			Execute Response (Send) : O

			::Update On {1 = Code, 2 = AccessGroup}::
			On Update Code (Send) : O
			On Update Access Group (Send) : O

			::Support Client Modification::
			Code Modify (Receive) : O
			Code Access Group (Receive) : O
		Client:
			On Connect Sync (Receive) : O
			Execute Command (Send) : O
			Execute Response (Receive) : O
				Hook : O

			::Update On {1 = Code, 2 = AccessGroup}::
			On Update Code (Receive) : O
				Hook : O
			On Update Access Group (Receive) : O
				Hook : O

			::Support Client Modification::
			Code Modify (Send) : O
			Code Access Group (Send) : O
	*/

	local Command_Net_Sync = MODULE:RegisterNetworkString("Sync")
	local Sync_OnConnect = Command_Net_Sync("OnConnect")

	local Command_Net_Update = MODULE:RegisterNetworkString("Update")
	local Update_Code = Command_Net_Update("Code")
	local Update_AccessGroup = Command_Net_Update("AccessGroup")

	local Command_Net_Client = MODULE:RegisterNetworkString("Client")
	local Client_Modify = Command_Net_Client("Modify")
	local Client_Execute = Command_Net_Client("Execute")
	local Client_ExecuteResponse = Command_Net_Client("ExecuteResponse")

	do -- On Connect Sync (Send)
		hook.Add("PlayerAuthed", J_NET:GetNetworkString(Sync_OnConnect), function (ply)
			local not_default_commands = {}
			local command_amount = 0

			for k,v in pairs(command_table) do
				if v[1] > 0 then
					command_amount = 1 + command_amount
					not_default_commands[k] = v
				end
			end

			J_NET:Start(Sync_OnConnect)
			net.WriteUInt(command_amount, 16)

			for k,v in pairs(not_default_commands) do
				net.WriteString(k)
				net.WriteUInt(v[1], 32)
				net.WriteUInt(v[2], 8)
			end

			net.Send(ply)
		end)
	end

	do -- On Update Code (Send)
		function Command_Hook("OnCodeUpdate")("CommandModule::UpdateCode")(command, new_value, old_value)
			J_NET:Start(Update_Code)
			command:NetWrite()
			net.Broadcast()
		end
	end

	do -- On Update Access Group (Send)
		function Command_Hook("OnAccessUpdate")("CommandModule::UpdateValue")(command, new_value, old_value)
			J_NET:Start(Update_Code)
			command:NetWrite()
			net.Broadcast()
		end
	end

	do -- Code Modify (Receive) | Code Access Group (Receive)
		function MODULE.Server:Post()
			local PermissionModule = JAAS:GetModule("Permission")

			local CanModifyCode = PermissionModule:RegisterPermission("Can Modify Permission Code")
			local CanModifyAccessGroup = PermissionModule:RegisterPermission("Can Modify Permission Access Group")

			J_NET:Receive(Client_Modify, function (len, ply)
				local msg = ModificationMessage():NetRead()

				if msg:IsModifyCode() then
					if CanModifyCode:Check(ply:GetCode()) then
						local command_object = msg:GetCommandObject()
						if command_object:AccessCheck(ply:GetCode()) then
							local rank_object = msg:GetRankObject()
							if command_object:SetCode(rank_object:GetCode()) then
							else
							end
						else
						end
					else
					end
				elseif msg:IsModifyValue() then
					if CanModifyAccessGroup:Check(ply:GetCode()) then
						local command_object = msg:GetCommandObject()
						if command_object:AccessCheck(ply:GetCode()) then
							local access_group_object = msg:GetAccessGroup()
							if command_object:SetAccessCode(access_group_object:GetValue()) then
							else
							end
						else
						end
					else
					end
				else
				end
			end)
		end
	end

	do -- Execute Command (Receive) | Execute Response (Send)
		J_NET:Receive(Client_Execute, function (len, ply)
			local command_object = CommandObject():NetRead()

			if command_object:Check(ply:GetCode()) then
				local response_code, msg = command_object:NetExecute()

				J_NET:Start(Client_ExecuteResponse)
				command_object:NetWrite()
				net.WriteUInt(response_code, 8)
				net.WriteString(msg)
				net.Send(ply)
			end
		end)
	end

	if CLIENT then
		do -- Code Modify (Send)
			function MODULE:SetPermissionCode(permission_object, rank_object)
				ModificationMessage():ModifyCode(permission_object, rank_object):SendToServer(Client_Modify)
			end
		end

		do -- Code Access Group (Send)
			function MODULE:SetPermissionAccessGroup(permission_object, access_group_object)
				ModificationMessage():ModifyAccessValue(permission_object, access_group_object):SendToServer(Client_Modify)
			end
		end

		do -- Execute Command (Send)
			function CommandObject:Execute(...)
				local args = {...}
				local parameters = command_table[self:BuildKey()][4]

				J_NET:Start(Client_Execute)

				self:NetWrite()
				for k,v in ipairs(parameters) do
					v:SetValue(args[k])
					v:NetWrite()
				end

				net.SendToServer()
			end
		end

		do -- Execute Response (Receive) + Hook
			J_NET:Receive(Client_ExecuteResponse, function ()
				local read_command = CommandObject():NetRead()
				local response_code = net.ReadUInt(8)
				local msg = net.ReadString()

				Command_Hook_Run("OnExecuteResponse")(read_command, response_code, msg)
			end)
		end

		do -- On Connect Sync (Receive)
			J_NET:Receive(Sync_OnConnect, function ()
				local command_amount = net.ReadUInt(16)
				local index = 1

				repeat
					local key = net.ReadString()
					local code = net.ReadUInt(32)
					local access_value = net.ReadUInt(8)

					command_table[key][1] = code
					command_table[key][2] = access_value

					index = 1 + index
				until (index <= command_amount)
			end)
		end

		do -- On Update Code (Receive) + Hook
			J_NET:Receive(Update_Code, function ()
				local command_object = CommandObject():NetRead()
				command_object:SaveLocal()
				Command_Hook_Run("OnCodeUpdate")(command_object, command_object:GetCode())
			end)
			-- Command_Hook_Run("OnCodeUpdate")(self, code, old_value)
		end

		do -- On Update Access Group (Receive) + Hook
			J_NET:Receive(Update_Code, function ()
				local command_object = CommandObject():NetRead()
				command_object:SaveLocal()
				Command_Hook_Run("OnAccessUpdate")(command_object, command_object:GetAccessCode())
			end)
			-- Command_Hook_Run("OnAccessUpdate")(self, value, old_value)
		end
	end
end