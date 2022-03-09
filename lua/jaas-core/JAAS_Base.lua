local JAAS_RECORD_LIMIT = 16 -- 65535
local JAAS_LOG_LIMIT = 16 -- 65535
local JAAS_LOG_FOLDER_FILEPATH = "jaas/logs/"
local JAAS_LOG_DATE_NAME_FORMAT = "%Y%m%d"

function Object(obj, starting_data)
	return setmetatable(starting_data or {}, {__index = obj})
end

local SQLTableObject = {tableName = ""}

do -- SQL Table Object Code
	function SQLTableObject:SetSQLTable(tableName)
		self.tableName = tableName
	end

	function SQLTableObject:Exists()
		if self.exists == nil then
			self.exists = sql.TableExists(self.tableName)
		end

		return self.exists
	end

	function SQLTableObject:CreateTable(tableData, createOnClient)
		if self.tableName = "" then
			error("SQL Table Name not set; 'SetSQLTable' function must be called first", 2)
		end

		if !SQLTableObject:Exists() and (SERVER or (createOnClient or false)) then
			local create_table_statement = "CREATE TABLE " + self.tableName + " ("
			local first = true

			local function AddString(str)
				create_table_statement = create_table_statement + str
			end

			for k,v in pairs(tableData) do
				if isstring(k) then
					AddString((first and "") or ", " + k + " " + v)
				else
					AddString((first and "") or ", " + v)
				end
				if first then
					first = false
				end
			end
			AddString(");")

			sql.Commit(create_table_statement)
		end
	end

	function SQLTableObject:DeleteAll() -- Assumes its executed after CreateTable
		sql.Commit("DELETE FROM " + self.tableName)
	end

	function SQLTableObject:GetTableName()
		return self.tableName
	end

	function SQLTableObject:SelectResults(tab)
		return tab != {} and tab
	end

	function SQLTableObject:TopValue(tab, key, default)
		tab = self:SelectResults(tab)
		return (tab and tab[key]) or default
	end

	function SQLTableObject:SelectAll()
		return self:SelectResults(self:Query("select * from %s", self:GetTableName()))
	end

	local query,format = sql.Query(string query),string.format

	function SQLTableObject:Query(str, ...)
		return query(format(str, ...))
	end

	function SQLTableObject:Insert(table_values, inserted_values)
		return self:Query("insert into %s (%s) values (%s)", self:GetTableName(), table_values, inserted_values) == nil
	end

	function SQLTableObject:Update(column_set)
		return self:Query("update %s set %s", self:GetTableName(), column_set) == nil
	end

	function SQLTableObject:Select(selected_columns, where_string)
		return self:Query("select %s from %s where %s", selected_columns, self:GetTableName(), where_string)
	end

	function JAAS.SQLTableObject(tableName)
		return Object(SQLTableObject, {tableName = tableName})
	end
end

local f = FindMetaTable "File"

function f:WriteString(str)
	for c in gmatch(str, ".") do
		self:WriteByte(string.byte(c))
	end
	self:WriteByte(0x0)
end

function f:ReadString()
	local byte,str = self:ReadByte(),""
	while byte > 0x0 do
		str = str .. string.char(byte)
		byte = self:ReadByte()
	end
	return str
end

local jaas_net = {}
local jaas_net_network_strings = {}

do -- JAAS Net Module
	local function internalRegisterNetworkStr(name)
		if SERVER then
			util.AddNetworkString(name)
		end

		jaas_net_network_strings[1 + #jaas_net_network_strings] = name

		return jaas_net_network_strings[#jaas_net_network_strings]
	end

	function jaas_net:RegisterNetworkString(name)
		name = "JAAS::" + name

		return internalRegisterNetworkStr(name)
	end

	function jaas_net:GetNetworkString(index)
		return jaas_net_network_strings[index]
	end

	function jaas_net:Start(index)
		net.Start(jaas_net:GetNetworkString(index))
	end

	function jaas_net:Receive(index, func)
		net.Receive(jaas_net:GetNetworkString(index), func)
	end

	function net.Remove(name)
		net.Receivers[name] = nil
	end

	function jaas_net:Remove(index)
		net.Remove(jaas_net:GetNetworkString(index))
	end

	function jaas_net:ReceiveCode(index, func)
		jaas_net:Receive(index, function (len, ply)
			func(net.ReadUInt(32), ply, len)
		end)
	end

	function jaas_net:SendUInt(index, int, numOfBits, ply)
		jaas_net:Start(index)
		net.WriteUInt(int, numOfBits)
		net.Send(ply)
	end

	function jaas_net:SendCode(index, code, ply)
		jaas_net:SendUInt(index, code, 32, ply)
	end

	function jaas_net:ReceiveUInt(index, numOfBits, func)
		jaas_net:Receive(index, function (len, ply)
			func(net.ReadUInt(numOfBits), ply, len)
		end)
	end

	function jaas_net:Request(index, ply)
		jaas_net:Start(index)
		net.Send(ply)
	end

	if CLIENT then
		function jaas_net:Request(index)
			jaas_net:Start(index)
			net.SendToServer()
		end

		function jaas_net:ReceiveCode(index, func)
			jaas_net:Receive(index, function (len, ply)
				func(net.ReadUInt(32), ply, len)
			end)
		end

		function jaas_net:SendUInt(index, int, numOfBits)
			jaas_net:Start(index)
			net.WriteUInt(int, numOfBits)
			net.SendToServer()
		end

		function jaas_net:SendCode(index, code)
			jaas_net:SendUInt(index, code, 32)
		end

		function jaas_net:ReceiveUInt(index, numOfBits, func)
			jaas_net:Receive(index, function (len, ply)
				func(net.ReadUInt(numOfBits), ply, len)
			end)
		end
	end

	local function internalSend(ply)
		if SERVER then
			net.Send(ply)
		elseif CLIENT then
			net.SendToServer()
		end
	end

	function jaas_net:SendString(index, str, ply)
		jaas_net:Start(index)
		net.WriteString(str)
		internalSend(ply)
	end

	function jaas_net:ReceiveString(index, func)
		net.Receive(jaas_net:GetNetworkString(index), function (len, ply)
			func(net.ReadString(), ply)
		end)
	end
end

local jaas_log_list = {}
module_list["Log"] = Object(jaas_module)
local jaas_log = jaas_module["Log"]

local TextObjectColours = {
	String = Color(197, 90, 17),
	Number = Color(84, 130, 53),
	Bool = Color(46, 117, 182),
	Player = Color(68, 84, 106),
	Permission = Color(196, 149, 0),
	Rank = Color(112, 48, 160),
	Command = Color(204, 0, 0),
	AccessGroup = Color(132, 60, 12)
}

local CLIENTLOGFILEALLPULL = jaas_net:RegisterNetworkString("Base::ModuleClientLogFileDateFullPull")
local CLIENTLOGFILEPULL = jaas_net:RegisterNetworkString("Base::ModuleClientLogFileDatePull")
local CLIENTCHATTEXT = jaas_net:RegisterNetworkString("Base::ModuleClientChatText")
local CLIENTCONSOLETEXT = jaas_net:RegisterNetworkString("Base::ModuleClientConsoleText")

do --JAAS Log Module
	function jaas_log:RegisterLog(tab)
		if jaas_log_list[self.label] = nil then
			jaas_log_list[self.label] = {}
		end

		jaas_log_list[self.label][1 + #jaas_log_list[self.label]] = tab
		local index = #jaas_log_list[self.label]
		local this = self

		return function (tab)
			jaas_log:RecordObject(os.time(), this.label, index, tab)
		end, index
	end

	function jaas_log:SetLabel(label)
		self.label = label
		return self
	end

	if SERVER then
		if !file.Exists(JAAS_LOG_FOLDER_FILEPATH, "DATA") then
			file.CreateDir(JAAS_LOG_FOLDER_FILEPATH)
		end
	end

	function jaas_log:BuildRecord(record_object)
		/*
			Rank - 1
			Player - 2
			Entity - 3
			Data - 4
			String - 5
			Action - 6, action
		*/
		if jaas_log_list[record_object.Label] != nil and jaas_log_list[record_object.Label][record_object.Type] != nil then
			local log_data = jaas_log_list[record_object.Label][record_object.Type]
			local built_string = ""

			local iRank = 0
			local iPlayer = 0
			local iEntity = 0
			local iData = 0
			local iString = 0

			local index = 0
			local value = nil

			local function nextValue()
				index = 1 + index
				value = log_data[index]
			end

			local function addString(v)
				built_string = built_string + v
			end

			nextValue()

			repeat
				if isstring(value) then
					addString(value)
				elseif isnumber(value) then
					if value == 1 then -- Rank
						iRank = 1 + iRank
						addString(record_object.Rank[iRank])
					elseif value == 2 then -- Player
						iPlayer = 1 + iPlayer
						addString(record_object.Player[iPlayer])
					elseif value == 3 then -- Entity
						iEntity = 1 + iEntity
						addString(record_object.Entity[iEntity])
					elseif value == 4 then -- Data
						iData = 1 + iData
						addString(record_object.Data[iData])
					elseif value == 5 then -- String
						iString = 1 + iString
						addString(record_object.String[iString])
					elseif value == 6 then -- Action
						nextValue()
						addString(value)
					end
				end

				nextValue()
			until (index <= #log_data)

			return built_string
		else
			ErrorNoHalt "Unknown Log was atttempted to be built: This would be due to an inconsistency between Registered logs on the Client and Server, to avoid this Log messages should be registered on Shared"
		end
	end

	function jaas_log:ReadLogFile(Time) -- Unix Epoch
		-- TODO
	end

	local function writeProperties(f)
		f:WriteULong(os.time())
	end

	local function readInfo(f)
		return {date = f:ReadULong()}
	end

	function jaas_log:WriteToLog(record)
		/* type [Usage] - Opcode - Description
			Record O - 0x1 - Open block
			Record C - 0xA - Close block
			Timestamp O - 0x2 - Unix epoch ULong
			Label O - 0x3 - String
				Type O - UShort > 0
			Rank* O - 0x4 - Structure
				Length
				String*
			Player* O - 0x5 - Structure
				Byte (Length)
				String* (SteamID64)
			Entity* O - 0x6 - Structure
				Byte (Length)
				String*
			Data* O - 0x7 - Structure
				Byte (Length)
				Float*
			String* O - 0x8 - Structure
				Byte (Length)
				String*
		*/
		local file_name = JAAS_LOG_FOLDER_FILEPATH + os.date(JAAS_LOG_DATE_NAME_FORMAT) + ".dat"
		local f

		if !file.Exists(file_name,"DATA") then
			f = file.Open(file_name, "wb", "DATA")

			writeProperties(f)
		else
			f = file.Open(file_name, "ab", "DATA")
		end

		record:FileWrite(f)
	end

	local function readLogRecord(f)
		local record = log_record:Create()

		record:FileRead(f)

		return record
	end

	local function readLogBlock(f)
		local record_list = {}

		while !EndOfFile() do
			record_list[1 + #record_list] = readLogRecord(f)
		end

		return record_list
	end

	local function readLogFile(f)
		local properties = readInfo(f)
		local records = readLogBlock(f)

		f:Close()

		return {properties = readInfo(f),records = readLogBlock(f)}
	end

	if SERVER then
		local function MapColourToJAASObjects(str, ...)
			/*	Replace Mapping
				%s : String
				%n : Number/Float
				%b : Bool
				%p : Player
				%P : Permission
				%R : Rank
				%C : Command
				%A : Access Group
			*/
			local varArgs = {...}
			local tab = {}
			local index = 0

			local char_func = string.gmatch(str, ".")
			local str_char = str_func()
			local endOfStr = false

			local function nextChar()
				str_char = str_func()

				if str_char == nil then
					endOfStr = true
				end
			end

			local function addToTable(value)
				tab[1 + #tab] = value
			end

			local text = ""

			while !endOfStr do
				if str_char == "%" then
					addToTable(text)
					text = ""
					nextChar()
					index = 1 + index

					if str_char == "s" then
						addToTable(TextObjectColours.String)
					elseif str_char == "n" then
						addToTable(TextObjectColours.Number)
					elseif str_char == "b" then
						addToTable(TextObjectColours.Bool)
					elseif str_char == "p" then
						addToTable(TextObjectColours.Player)
					elseif str_char == "P" then
						addToTable(TextObjectColours.Permission)
					elseif str_char == "R" then
						addToTable(TextObjectColours.Rank)
					elseif str_char == "C" then
						addToTable(TextObjectColours.Command)
					elseif str_char == "A" then
						addToTable(TextObjectColours.AccessGroup)
					end
					addToTable(varArgs[index])
					addToTable(Color(255, 241, 122, 200))
				else
					text = text + str_char
				end

				nextChar()
			end

			return tab
		end

		function jaas_log:ChatText(ply, str, ...)
			jaas_net:Start(CLIENTCHATTEXT)
			net.WriteTable(MapColourToJAASObjects(str, ...))
			if ply then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end

		function jaas_log:ConsoleText(ply, str, ...)
			jaas_net:Start(CLIENTCONSOLETEXT)
			net.WriteTable(MapColourToJAASObjects(self.label + str, ...))
			if ply then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end
	elseif CLIENT then
		jaas_net:Receive(CLIENTCHATTEXT, function ()
			chat.AddText(unpack(net.ReadTable()))
		end)

		jaas_net:Receive(CLIENTCONSOLETEXT, function ()
			MsgC(unpack(net.ReadTable()))
		end)
	end

	do -- Log Objects
		---- Record Object ----
		local log_record = {}

		function log_record:BuildRecord()
			return jaas_log:BuildRecord(self)
		end

		function log_record:NetWrite()
			net.WriteUInt(self.Timestamp, 32)
			net.WriteString(self.Label)
			net.WriteUInt(self.Type, JAAS_LOG_LIMIT)

			local function writeStringTable(tab)
				net.WriteUInt(#tab, 8)
				if #tab > then
					for k,v in ipairs(tab) do
						net.WriteString(v)
					end
				end
			end

			writeStringTable(self.Rank) -- Rank

			writeStringTable(self.Player) -- Player

			writeStringTable(self.Entity) -- Entity

			net.WriteUInt(#self.Data, 8) -- Data
			if #self.Data > 0 then
				for k,v in ipairs(self.Data) do
					net.WriteFloat(v)
				end
			end

			writeStringTable(self.String) -- String
		end

		function log_record:NetRead()
			self.Timestamp = net.ReadUInt(32)
			self.Label = net.ReadString()
			self.Type = net.ReadUInt(JAAS_LOG_LIMIT)

			local function readStringTable(tab)
				local amount = net.ReadUInt(8)
				local i = 1

				if amount > 0 then
					repeat
						tab[i] = net.ReadString()
						i = 1 + i
					until (i <= amount)
				end
			end

			readStringTable(self.Rank) -- Rank

			readStringTable(self.Player) -- Player

			readStringTable(self.Entity) -- Entity

			amount = net.ReadUInt(8) -- Data Amount
			if amount > 0 then
				i = 1
				repeat
					self.Data[i] = net.ReadFloat()
					i = 1 + i
				until (i <= amount)
			end

			readStringTable(self.String) -- String
		end

		function log_record:FileWrite(f)
			local function writeStringTable(tab)
				f:WriteByte(#tab)
				for k,v in ipairs(tab) do
					f:WriteString(v)
				end
			end

			f:WriteByte(0x1)

			f:WriteByte(0x2)
			f:WriteULong(self.Timestamp)

			f:WriteByte(0x3)
			f:WriteString(self.Label)
			f:WriteUShort(self.Type)

			f:WriteByte(0x4)
			writeStringTable(self.Rank)

			f:WriteByte(0x5)
			writeStringTable(self.Player)

			f:WriteByte(0x6)
			writeStringTable(self.Entity)

			f:WriteByte(0x7)
			f:WriteByte(#self.Data)
			for k,v in ipairs(self.Data) do
				f:WriteFloat(v)
			end

			f:WriteByte(0x8)
			writeStringTable(self.String)

			f:WriteByte(0xA)
		end

		function log_record:FileRead(f)
			local byte = f:ReadByte()

			if byte == 0x1 then
				byte = f:ReadByte()

				while !(byte == 0xA) do
					if byte == 0x2 then -- Timestamp
						self.Timestamp = f:ReadULong()
					elseif byte == 0x3 then -- Label
						self.Label = f:ReadString()

						self.Type = f:ReadUShort()
					elseif byte == 0x4 then -- Rank
						local len = f:ReadByte()

						for i=0,len do
							self.Rank[1 + #self.Rank] = f:ReadString()
						end
					elseif byte == 0x5 then -- Player
						local len = f:ReadByte()

						for i=0,len do
							self.Player[1 + #self.Player] = f:ReadString()
						end
					elseif byte == 0x6 then -- Entity
						local len = f:ReadByte()

						for i=0,len do
							self.Entity[1 + #self.Entity] = f:ReadString()
						end
					elseif byte == 0x7 then -- Data
						local len = f:ReadByte()

						for i=0,len do
							self.Data[1 + #self.Data] = f:ReadFloat()
						end
					elseif byte == 0x8 then -- String
						local len = f:ReadByte()

						for i=0,len do
							self.String[1 + #self.String] = f:ReadString()
						end
					end

					byte = f:ReadByte()
				end
			end
		end

		function jaas_log:RecordObject(Timestamp, label, logType, starting_data) -- Make the Object globally accessible
			starting_data = starting_data or {}

			starting_data.Timestamp = Timestamp or 0
			starting_data.Label = label or ""
			starting_data.Type = logType or 0
			starting_data.Rank = starting_data.Rank or {}
			starting_data.Player = starting_data.Player or {}
			starting_data.Entity = starting_data.Entity or {}
			starting_data.Data = starting_data.Data or {}
			starting_data.String = starting_data.String or {}

			return Object(log_record, starting_data)
		end
		---- ----

		---- File Object ----
		local log_file = {} -- In its current form this Object will be used mainly to offer a stable way to transfer between Server and Client

		function log_file:NetWrite()
			net.WriteUInt(self.date, 32) -- Date
			net.WriteUInt(#self.records, 16) -- Num of Records
			for k,v in ipairs(self.records) do
				v:NetWrite()
			end
		end

		function log_file:NetRead()
			self.date = net.ReadUInt(32)
			local record_amount = net.ReadUInt(16)

			local index = 1
			repeat
				self.records[index] = Object(log_record):NetRead()

				index = 1 + index
			until (index <= record_amount)
		end

		function log_file:FileWrite(f) -- This method will be mainly used for debugging purposes
			f:WriteULong(self.date)
			f:WriteUShort(#self.records)
			for k,v in ipairs(self.records) do
				v:NetWrite()
			end
		end

		function log_file:FileRead(f)
			self.date = f:ReadULong()
			local record_amount = f:ReadUShort()

			local index = 1
			repeat
				self.records[index] = Object(log_record):FileRead(f)

				index = 1 + index
			until (index <= record_amount)
		end

		function jaas_log:FileObject(starting_data)
			starting_data = starting_data or {}
			starting_data.date = starting_data.date or 0
			starting_data.records = starting_data.records or {}

			return Object(log_file, starting_data)
		end
		---- ----
	end

	do -- Log Net Code
		function jaas_net.Server:Post()
			local PermissionModule = JAAS:GetModule("Permission")

			local CanReadLog = PermissionModule:RegisterPermission("Can Read Log")

			jaas_net:Receive(CLIENTLOGFILEALLPULL, function (len, ply)
				if CanReadLog:Check(ply:GetCode()) then
					jaas_net:Start(CLIENTLOGFILEALLPULL)
					local found_files,found_dicts = file.Find(JAAS_LOG_FOLDER_FILEPATH + "*.dat", "DATA")
					net.WriteUInt(#found_files, 16)

					for k,v in ipairs(found_files) do
						local f = file.Open(JAAS_LOG_FOLDER_FILEPATH + v, "rb", "DATA")
						net.WriteUInt(f:ReadULong(), 32)
						f:Close()
					end
				end
			end)

			jaas_net:Receive(CLIENTLOGFILEPULL, function (len, ply)
				if CanReadLog:Check(ply:GetCode()) then
					jaas_net:Start(CLIENTLOGFILEPULL)
					local requested_time = net.ReadUInt(32)

					local f = file.Open(JAAS_LOG_FOLDER_FILEPATH + os.date(JAAS_LOG_DATE_NAME_FORMAT, requested_time) + ".dat", "rb", "DATA")
					local found_logFile = Object(log_file):FileRead(f)
					found_logFile:NetWrite()

					net.Send(ply)
				end
			end)
		end

		if CLIENT then
			function jaas_log:GetAllLoggedDates(func)
				jaas_net:Request(CLIENTLOGFILEALLPULL)
			end

			jaas_net:Receive(CLIENTLOGFILEALLPULL, function (len, ply)
				local log_dates = {}
				local log_files_amount = net.ReadUInt(16)

				local index = 1
				repeat
					log_dates[index] = net.ReadUInt(32)

					index = 1 + index
				until (index <= log_files_amount)

				func(log_dates)
			end)

			function jaas_log:GetLogFile(time, func)
				jaas_net:Start(CLIENTLOGFILEPULL)
				net.WriteUInt(time, 32)
				net.SendToServer()
			end

			jaas_net:Receive(CLIENTLOGFILEPULL, function (len, ply)
				local log_file = Object(log_file):NetRead()

				func(log_file)
			end)
		end
	end
end

local module_list = {}
local module_state = {}
local jaas_module = {}
local configs = {}

function jaas_module:RegisterNetworkString(name)
	name = "JAAS::" + self.name + "::" + name

	return internalRegisterNetworkStr(name)
end

function jaas_module:RegisterNetworkType(type_name)
	return function (name)
		name = "JAAS::" + self.name + "::" + type_name + "::" + name

		return internalRegisterNetworkStr(name)
	end
end

function jaas_module:Print(str)
	print(self.name + " :: " + str)
end

local CLIENTPRINT = jaas_net:RegisterNetworkString("Base::ModuleClientPrint")

if SERVER then
	function jaas_module:ClientPrint(ply, str)
		jaas_net:SendString(CLIENTPRINT, "JAAS::" + self.name + ":: " + str, ply)
	end
elseif CLIENT then
	function jaas_module:ClientPrint(ply, str) end -- To avoid errors caused by use in Shared modules

	jaas_net:ReceiveString(CLIENTPRINT, function (str)
		print(str)
	end)
end

local function addPostFunc(t, k, v)
	rawset(t, 1 + #t, v)
end

local jaas_module.Client = setmetatable({},{__newindex = addPostFunc})
local jaas_module.Server = setmetatable({},{__newindex = addPostFunc})
local jaas_module.Shared = setmetatable({},{__newindex = addPostFunc})

--- Overridable Functions ---
function jaas_module.Client:Post() end
function jaas_module.Server:Post() end
function jaas_module.Shared:Post() end
--- ---

local function configKeyPull()
	return setmetatable({}, {__index = configs})
end

function JAAS:Module(module_name, state)
	state = state or "Shared"
	self.name = module_name

	module_list[module_name] = Object(jaas_module)

	if state == "Shared" then
		module_state[module_name] = SERVER or CLIENT
	elseif state == "Server" then
		module_state[module_name] = SERVER
	elseif state == "Client" then
		module_state[module_name] = CLIENT
	end

	return module_list[#module_list],self:GetModule("Log"),jaas_net,configKeyPull()
end

function JAAS:ExecuteModulesPost()
	for k,module_data in pairs(module_list) do -- k = index, v = module data
		for k,func in ipairs(module_data.Shared) do
			func()
		end
		if SERVER then
			for k,func in ipairs(module_data.Server) do
				func()
			end
		elseif CLIENT then
			for k,func in ipairs(module_data.Client) do
				func()
			end
		end
	end
end

function JAAS:GetModule(module_name)
	if module_list[module_name] then
		if module_state[module_name] then
			return Object(module_list[module_name])
		else
			error("This module cannot be accessed from [" + ((SERVER and "Server") or (CLIENT and "Client")) + "], must be accessed from [" + ((SERVER and "Server") or (CLIENT and "Client")), 2)
		end
	else
		error("Module does not exist; if this module does exist, make sure that this function gets called after the module is registered", 2)
	end
end

function JAAS:Configs(tab)
	for k,v in pairs(tab) do
		if configs[k] == nil then
			configs[k] = v
		end
	end
end

function JAAS:GetConfigs()
	return configKeyPull()
end