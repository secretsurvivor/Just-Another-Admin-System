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

local Command_OnCodeUpdate = Command_Hook("OnCodeUpdate")
local Command_OnAccessUpdate = Command_Hook("OnAccessUpdate")

local Command_Hook_Run = JAAS.Hook.Run("Command")

local Rank_Hook_OnRemove = JAAS.Hook("Rank")("OnRemove")
local Player_Hook_OnConnect = JAAS.Hook("Player")("OnConnect")

local command_table = {} -- [Category][Name] = {1 = Code, 2 = AccessGroup, 3 = function, 4 = Parameters, 5 = Flags}

function Rank_Hook_OnRemove.CommandModule_RankCodeUpdate(isMulti, rank_name, remove_func)
	for category,name_table in pairs(command_table) do
		for name,v in pairs(name_table) do
			command_table[category][name][1] = remove_func(command_table[category][name][1])
			CommandTable:UpdateCode(name, category, command_table[category][name][1])
		end
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

	function CommandObject:GetParameters()
		return command_table[self.category][self.name][4]
	end

	function CommandObject:IsPresent()
		return command_table[self.category][self.name] != nil
	end

	function CommandObject:GetCode()
		return command_table[self.category][self.name][1]
	end

	function CommandObject:Setcode(code)
		if CommandTable:UpdateCode(self.name, self.category, code) then
			local old_value = self:GetCode()
			command_table[self.category][self.name][1] = code
			Command_Hook_Run("OnCodeUpdate")(self, code, old_value)
			return true
		end
		return false
	end

	function CommandObject:XorCode(code)
		return self:SetCode(bit.bxor(self:GetCode(), code))
	end

	function CommandObject:IsGlobalAccess()
		return self:GetCode() == 0
	end

	function CommandObject:GetAccessCode()
		return command_table[self.category][self.name][2]
	end

	function CommandObject:SetAccessCode(value)
		if CommandTable:UpdateAccessGroup(self.name, self.category, value) then
			local old_value = self:GetAccessCode()
			command_table[self.category][self.name][2] = value
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

	function CommandObject:CheckFlags(flag)
		return bit.band(command_table[self.category][self.name][5], flag) > 0
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
		return command_table[self.category][self.name][3](...)
	end

	if SERVER then
		function CommandObject:NetExecute()
			local parameters = command_table[self.category][self.name][4]
			local read_parameter_values = {}

			for index,info in ipairs(parameters) do
				read_parameter_values[index] = info:NetRead()
			end

			self:Execute(unpack(read_parameter_values))
		end
	end
end

local function CreateCommandObject(name, category)
	return Object(CommandObject, {name = name, category = category})
end

JAAS.CommandObject = CreateCommandObject

local ParameterTable = {}
local ParameterObject = {
	BoolObject = {}, -- 1
	IntObject = {}, -- 2
	FloatObject = {}, -- 3
	StringObject = {}, -- 4
	PlayerObject = {}, -- 5
	PlayersObject = {}, -- 6
	OptionObject = {}, -- 7
	OptionsObject = {}, -- 8
	RankObject = {}, -- 9
	PermissionObject = {}, -- 10
	AccessGroupObject = {}, -- 11
	CommandObject = {} -- 12
}

do -- Parameter Object Code
	do -- Bool Object Code
		function ParameterObject.BoolObject:Set(name, default)
			self.name = name
			self.default = default
			return self
		end

		function ParameterObject.BoolObject:GetName()
			return self.name
		end

		function ParameterObject.BoolObject:GetType()
			return 1
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

		function ParameterObject.IntObject:GetName()
			return self.name
		end

		function ParameterObject.IntObject:GetType()
			return 2
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

		function ParameterObject.FloatObject:GetName()
			return self.name
		end

		function ParameterObject.FloatObject:GetType()
			return 3
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

		function ParameterObject.StringObject:GetName()
			return self.name
		end

		function ParameterObject.StringObject:GetType()
			return 4
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

		function ParameterObject.PlayerObject:GetName()
			return self.name
		end

		function ParameterObject.PlayerObject:GetType()
			return 5
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

		function ParameterObject.PlayersObject:GetName()
			return self.name
		end

		function ParameterObject.PlayersObject:GetType()
			return 6
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
			until (index >= amount)
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

		function ParameterObject.OptionObject:GetName()
			return self.name
		end

		function ParameterObject.OptionObject:GetDefault()
			return self.default
		end

		function ParameterObject.OptionsObject:GetOptionList()
			return self.option_list
		end

		function ParameterObject.OptionObject:GetType()
			return 7
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

		function ParameterObject.OptionsObject:GetName()
			return self.name
		end

		function ParameterObject.OptionsObject:GetType()
			return 8
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
			until (index >= amount)
			self.value = read_options
			return self:GetValue()
		end
	end

	local function OptionsObject(tab)
		return Object(ParameterObject.OptionsObject, tab)
	end

	do -- Rank Object Code
		function ParameterObject.RankObject:Set(name)
			self.name = name
			return self
		end

		function ParameterObject.RankObject:GetName()
			return self.name
		end

		function ParameterObject.RankObject:GetType()
			return 9
		end

		function ParameterObject.RankObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.RankObject:GetValue()
			return self.value
		end

		function ParameterObject.RankObject:NetWrite()
			self.value:NetWrite()
		end

		function ParameterObject.RankObject:NetRead()
			self.value = JAAS.RankObject():NetRead()
			return self:GetValue()
		end
	end

	local function RankObject(tab)
		return Object(ParameterObject.RankObject, tab)
	end

	do -- Permission Object Code
		function ParameterObject.PermissionObject:Set(name)
			self.name = name
			return self
		end

		function ParameterObject.PermissionObject:GetName()
			return self.name
		end

		function ParameterObject.PermissionObject:GetType()
			return 10
		end

		function ParameterObject.PermissionObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.PermissionObject:GetValue()
			return self.value
		end

		function ParameterObject.PermissionObject:NetWrite()
			self.value:NetWrite()
		end

		function ParameterObject.PermissionObject:NetRead()
			self.value = JAAS.PermissionObject():NetRead()
			return self:GetValue()
		end
	end

	local function PermissionObject(tab)
		return Object(ParameterObject.PermissionObject, tab)
	end

	do -- Access Group Object Code
		function ParameterObject.AccessGroupObject:Set(name)
			self.name = name
			return self
		end

		function ParameterObject.AccessGroupObject:GetName()
			return self.name
		end

		function ParameterObject.AccessGroupObject:GetType()
			return 11
		end

		function ParameterObject.AccessGroupObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.AccessGroupObject:GetValue()
			return self.value
		end

		function ParameterObject.AccessGroupObject:NetWrite()
			self.value:NetWrite()
		end

		function ParameterObject.AccessGroupObject:NetRead()
			self.value = JAAS.AccessGroupObject():NetRead()
			return self:GetValue()
		end
	end

	local function AccessGroupObject(tab)
		return Object(ParameterObject.AccessGroupObject, tab)
	end

	do -- Command Object Code
		function ParameterObject.CommandObject:Set(name)
			self.name = name
			return self
		end

		function ParameterObject.CommandObject:GetName()
			return self.name
		end

		function ParameterObject.CommandObject:GetType()
			return 12
		end

		function ParameterObject.CommandObject:SetValue(value)
			self.value = value
		end

		function ParameterObject.CommandObject:GetValue()
			return self.value
		end

		function ParameterObject.CommandObject:NetWrite()
			self.value:NetWrite()
		end

		function ParameterObject.CommandObject:NetRead()
			self.value = JAAS.CommandObject():NetRead()
			return self:GetValue()
		end
	end

	local function CommandObject(tab)
		return Object(ParameterObject.CommandObject, tab)
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

		-- function ParameterTable:AddPlayers(name, default)
		-- 	self.internal[1 + #self.internal] = PlayersObject():Set(name, filter_func)
		-- end

		function ParameterTable:AddOption(name, default, option_list)
			self.internal[1 + #self.internal] = OptionObject():Set(name, option_list, default, filter_func)
		end

		-- function ParameterTable:AddOptions(name, default, option_list)
		-- 	self.internal[1 + #self.internal] = OptionsObject():Set(name, option_list, default, filter_func)
		-- end

		function ParameterTable:AddRank(name)
			self.internal[1 + #self.internal] = RankObject():Set(name)
		end

		function ParameterTable:AddPermission(name)
			self.internal[1 + #self.internal] = PermissionObject():Set(name)
		end

		function ParameterTable:AddAccessGroup(name)
			self.internal[1 + #self.internal] = AccessGroupObject():Set(name)
		end

		function ParameterTable:AddCommand(name)
			self.internal[1 + #self.internal] = CommandObject():Set(name)
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

J_CMD_SERVER = 1

function MODULE:RegisterCommand(name, parameters, func, flags)
	flags = flags or 0
	if CommandTable:Insert(name, self.category) then
		command_table[self.category] = {[name] = {0, 0, func, parameters}}
		return CreateCommandObject(name, self.category)
	else
		local found_command = CommandTable:Select(name, self.category)

		if found_command then
			found_command = found_command[1]
			command_table[self.category] = {[name] = {tonumber(found_command.Code), tonumber(found_command.AccessGroup), func, parameters}}
			return CreateCommandObject(name, self.category)
		else
			error("An error occurred whilst registering Command", 2)
		end
	end
end

if CLIENT then
	function MODULE:RegisterCommand(name, parameters, func, flags)
		if command_table[self.category] == nil and command_table[self.category][name] == nil and bit.band(flags, J_CMD_SERVER) == 0 then
			command_table[self.category] = {[name] = {0, 0, func, parameters}}
			return CreateCommandObject(name, self.category)
		end
	end
end

function MODULE:iCommand()
	local category_prev_key, category_prev_value, command_prev_key
	return function ()
		if command_prev_key == nil then
			category_prev_key, category_prev_value = next(command_table, category_prev_key)
		else
			command_prev_key = next(category_prev_value, command_prev_key)
		end

		if command_prev_key != nil and category_prev_key != nil then
			return CreateCommandObject(command_prev_key, category_prev_key)
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
		self.command_object = CreateCommandObject():NetRead()

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

	local Command_Net_Sync = MODULE:RegisterNetworkType("Sync")
	local Sync_OnConnect = Command_Net_Sync("OnConnect")

	local Command_Net_Update = MODULE:RegisterNetworkType("Update")
	local Update_Code = Command_Net_Update("Code")
	local Update_AccessGroup = Command_Net_Update("AccessGroup")

	local Command_Net_Client = MODULE:RegisterNetworkType("Client")
	local Client_Modify = Command_Net_Client("Modify")
	local Client_Execute = Command_Net_Client("Execute")
	local Client_ExecuteResponse = Command_Net_Client("ExecuteResponse")

	do -- On Connect Sync (Send)
		function Player_Hook_OnConnect.CommandModule_SyncOnConnect(ply)
			local not_default_commands = {}
			local command_amount = 0

			for category,name_table in pairs(command_table) do
				for name,info in pairs(name_table) do
					if bit.band(info[5], J_CMD_SERVER) == 0 then
						command_amount = 1 + command_amount
						not_default_commands[category] = {[name_table] = info}
					end
				end
			end

			J_NET:Start(Sync_OnConnect)
			net.WriteUInt(command_amount, 16)

			for category,name_table in pairs(not_default_commands) do
				for name,info in pairs(name_table) do
					net.WriteString(category)
					net.WriteString(name)
					net.WriteUInt(v[1], 32)
					net.WriteUInt(v[2], 8)
				end
			end

			net.Send(ply)
		end
	end

	do -- On Update Code (Send)
		function Command_OnCodeUpdate.CommandModule_UpdateCode(command, new_value, old_value)
			J_NET:Start(Update_Code)
			command:NetWrite()
			net.Broadcast()
		end
	end

	do -- On Update Access Group (Send)
		function Command_OnAccessUpdate.CommandModule_UpdateValue(command, new_value, old_value)
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

			local ReceiveCommandMinorChatLogs = PermissionModule:RegisterPermission("Receive Minor Command Chat Logs")
			local ReceiveCommandMajorChatLogs = PermissionModule:RegisterPermission("Receive Major Command Chat Logs")
			local ReceiveCommandUpdatesByConsole = PermissionModule:RegisterPermission("Receive Command Updates in Console")

			local CommandAddRank_Log = LOG:RegisterLog {"Command", 3, "was", 6, "added", "to", 1, "by", 2} -- Command Kill was added to VIP by secret_survivor
			local CommandRemoveRank_Log = LOG:RegisterLog {"Command", 3, "was", 6, "removed", "from", 1, "by", 2} -- Command Kill was removed from VIP by secret_survivor
			local CommandGlobalAccess_Log = LOG:RegisterLog {"Command", 3, "was given", 6, "global access", "by", 2}
			local CommandAttemptToModify_Log = LOG:RegisterLog {2, 6, "attempted", "to modify Command", 3}
			local CommandAccessValueSet_Log = LOG:RegisterLog {"Command", 3, "was", 6, "added", "to Access Group", 3, "by", 2}
			local CommandAccessValueReset_Log = LOG:RegisterLog {"Command", 3, "was", 6, "reset", "by", 2}

			J_NET:Receive(Client_Modify, function (len, ply)
				local msg = ModificationMessage():NetRead()

				if msg:IsModifyCode() then
					local command_object = msg:GetCommandObject()
					if CanModifyCode:Check(ply:GetCode()) then
						local rank_object = msg:GetRankObject()
						if command_object:AccessCheck(ply:GetCode()) then
							if command_object:XorCode(rank_object:GetCode()) then
								if command_object:IsGlobalAccess() then
									LOG:ChatText(ReceiveCommandMajorChatLogs:GetPlayers(), "%p made %C have Global Access", ply:Nick(), command_object:GetName())
									LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p made %C have Global Access", ply:Nick(), command_object:GetName())
									CommandGlobalAccess_Log{Entity = {command_object:GetName()}, Player = {ply:SteamID64()}}
								else
									if command_object:Check(rank_object:GetCode()) then
										LOG:ChatText(ReceiveCommandMajorChatLogs:GetPlayers(), "%p added %C to %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
										LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p added %C to %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
										CommandAddRank_Log{Entity = {command_object:GetName()}, Rank = {rank_object:GetName()}, Player = {ply:SteamID64()}}
									else
										LOG:ChatText(ReceiveCommandMajorChatLogs:GetPlayers(), "%p removed %C from %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
										LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p removed %C from %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
										CommandRemoveRank_Log{Entity = {command_object:GetName()}, Rank = {rank_object:GetName()}, Player = {ply:SteamID64()}}
									end
								end
							else
								LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p failed to modify %C's code with %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
							end
						else
							LOG:ChatText(ReceiveCommandMinorChatLogs:GetPlayers(), "%p attempted to modify %C's code with %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
							LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p attempted to modify %C's code with %R", ply:Nick(), command_object:GetName(), rank_object:GetName())
						end
					else
						CommandAttemptToModify_Log{Entity = {command_object:GetName()}, Player = {ply:SteamID64()}}
					end
				elseif msg:IsModifyValue() then
					local command_object = msg:GetCommandObject()
					if CanModifyAccessGroup:Check(ply:GetCode()) then
						if command_object:AccessCheck(ply:GetCode()) then
							local access_group_object = msg:GetAccessGroup()
							if command_object:GetAccessCode() == access_group_object:GetValue() then
								if command_object:SetAccessCode(0) then
									LOG:ChatText(ReceiveCommandMinorChatLogs:GetPlayers(), "%p reset %C's Access Code", ply:Nick(), command_object:GetName())
									LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p reset %C's Access Code", ply:Nick(), command_object:GetName())
									CommandAccessValueReset_Log{Entity = {command_object:GetName()}, Player = {ply:SteamID64()}}
								else
									LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p failed to reset %C's Access Code", ply:Nick(), command_object:GetName())
								end
							else
								if command_object:SetAccessCode(access_group_object:GetValue()) then
									LOG:ChatText(ReceiveCommandMinorChatLogs:GetPlayers(), "%p added %C to %A", ply:Nick(), command_object:GetName(), access_group_object:GetName())
									LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p added %C to %A", ply:Nick(), command_object:GetName(), access_group_object:GetName())
									CommandAccessValueSet_Log{Entity = {command_object:GetName()}, access_group_object:GetName(), Player = {ply:SteamID64()}}
								else
									LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p failed to add %C to %A", ply:Nick(), command_object:GetName(), access_group_object:GetName())
								end
							end
						else
							LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p attempted to modify %C's Access Value with %A", ply:Nick(), command_object:GetName(), access_group_object:GetName())
						end
					else
						LOG:ConsoleText(ReceiveCommandUpdatesByConsole:GetPlayers(), "%p attempted to modify %C's Access Value", ply:Nick(), command_object:GetName())
					end
				else
				end
			end)
		end
	end

	do -- Execute Command (Receive) | Execute Response (Send)
		J_NET:Receive(Client_Execute, function (len, ply)
			local command_object = CreateCommandObject():NetRead()

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
				local parameters = command_table[self:GetCategory()][self:GetName()][4]

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
				local read_command = CreateCommandObject():NetRead()
				local response_code = net.ReadUInt(8)
				local msg = net.ReadString()

				Command_Hook_Run("OnExecuteResponse")(read_command, response_code, msg)
			end)
		end

		do -- On Connect Sync (Receive)
			J_NET:Receive(Sync_OnConnect, function ()
				local command_amount = net.ReadUInt(16)
				local index = 1

				if !isnumber(command_amount) then
					error("Something went wrong")
				end
				if command_amount > 0 then
					repeat
						local category = net.ReadString()
						local name = net.ReadString()
						local code = net.ReadUInt(32)
						local access_value = net.ReadUInt(8)

						command_table[category][name][1] = code
						command_table[category][name][2] = access_value

						index = 1 + index
					until (index >= command_amount)
				end
			end)
		end

		do -- On Update Code (Receive) + Hook
			J_NET:Receive(Update_Code, function ()
				local command_object = CreateCommandObject():NetRead()
				command_object:SaveLocal()
				Command_Hook_Run("OnCodeUpdate")(command_object, command_object:GetCode())
			end)
			-- Command_Hook_Run("OnCodeUpdate")(self, code, old_value)
		end

		do -- On Update Access Group (Receive) + Hook
			J_NET:Receive(Update_Code, function ()
				local command_object = CreateCommandObject():NetRead()
				command_object:SaveLocal()
				Command_Hook_Run("OnAccessUpdate")(command_object, command_object:GetAccessCode())
			end)
			-- Command_Hook_Run("OnAccessUpdate")(self, value, old_value)
		end
	end
end

local function Objectify_String(str) -- TODO : Use a parsed gmatch function
	/*	String Conversion Mapping
		Bool : T/F
		Number : 0-9*
		Float : 0-9*.0-9*
		String : 'Char*'
		Player SteamID : (Char*)
		Player UserID : (0-9*)
		Players : (Char*,*)
		Option : [Char*]
		Options : [Char*,*]
		Rank : R{Char*}
		Permission : P{Char*}
		AccessGroup : A{Char*}
		Command : C{Char*}
	*/

	local str_func = string.gmatch(str, ".")
	local endOfStr = false
	local str_char = str_func()

	local function nextChar()
		str_char = str_func()

		if str_char == nil then
			endOfStr = true
		else
			str_char = string.byte(str_char)
		end
	end

	local text = ""
	local value = nil

	local function repeatAddText(endChar)
		repeat
			text = text + string.char(str_char)
			nextChar()
		until (str_char == endChar and endOfStr)
	end

	local function repeatMultiAddText(endChar)
		local multi = false

		repeat
			if multi then
				text[#text] = text[#text] + string.char(str_char)
			else
				text = text + string.char(str_char)
			end
			nextChar()
			if str_char == 44 then
				if !multi then
					multi = true
					text = {text}
				end
				text[1 + #text] = ""
			end
		until (str_char == endChar and endOfStr)

		return multi
	end

	while !endOfStr do
		if str_char == 39 then -- ' String Open
			nextChar()
			repeatAddText(39)
			value = text

		elseif str_char == 40 then -- ( Player Open
			nextChar()
			local isUserID = false

			if str_char >= 48 and str_char <= 57 then
				isUserID = true
			end

			local multi = repeatMultiAddText(41)

			if multi then
				value = {}
				local index = 1
				repeat
					if isUserID then
						value[index] = player.GetByID(text[index])
					else
						value[index] = player.GetBySteamID(text[index])
					end
					index = 1 + index
				until (index >= #text)
			else
				if isUserID then
					value = player.GetByID(text)
				else
					value = player.GetBySteamID(text)
				end
			end

		elseif str_char >= 48 and str_char <= 57 then -- Number
			repeatAddText(0)
			value = tonumber(text)

		elseif str_char == 91 then -- Option | Options
			nextChar()

			local multi = repeatMultiAddText(93)

			if multi then
				value = {}
				local index = 1
				repeat
					value[index] = text[index]
					index = 1 + index
				until (index >= #text)
			else
				value = text
			end

		elseif str_char == 82 then -- Rank
			nextChar()
			if str_char == 123 then
				nextChar()
				repeatAddText(125)
			end
			value = JAAS.RankObject(text)

		elseif str_char == 80 then -- Permission
			nextChar()
			if str_char == 123 then
				nextChar()
				repeatAddText(125)
			end
			value = JAAS.PermissionObject(text)

		elseif str_char == 65 then -- Access Group
			nextChar()
			if str_char == 123 then
				nextChar()
				repeatAddText(125)
			end
			value = JAAS.AccessGroupObject(text)

		elseif str_char == 67 then -- Command
			nextChar()
			if str_char == 123 then
				nextChar()
				repeatAddText(125)
			end
			value = JAAS.CommandObject(text)

		elseif str_char == 84 then
			value = true
		elseif str_char == 70 then
			value = false
		end
	end

	return value
end

concommand.Add("J", function (ply, cmd, args, argStr)
	local command_object = CreateCommandObject(args[1], args[2])
	if command_object:IsPresent() and (ply == nil or command_object:Check(ply:GetCode())) then
		local parameters = command_object:GetParameters()
		if #args - 2 == #parameters then
			local read_parameter_values = {}

			for index,v in ipairs(parameters) do
				v:SetValue(Objectify_String(args + 2)) -- TODO : Convert post 2 arguments into a single string to be ran through
				read_parameter_values[index] = v:GetValue()
			end

			command_object:Execute(unpack(read_parameter_values))
		else
			ErrorNoHalt("Incorrect amount of parameters were parsed")
		end
	else
		error("Command does not exist", 2)
	end
end, nil, "Execute JAAS Commands") -- Autocomplete nil for now

if CLIENT then
	local CommandSelectElement = {}

	function CommandSelectElement:Init()
		for category,command_table in pairs(command_table) do
			for name,info in pairs(command_table) do
				self:AddChoice(string.format("%s : %s", category, name), CreateCommandObject(name, category))
			end
		end
	end

	derma.DefineControl("JCommandComboBox", "Automatic Command List ComboBox", CommandSelectElement, "DComboBox")
end