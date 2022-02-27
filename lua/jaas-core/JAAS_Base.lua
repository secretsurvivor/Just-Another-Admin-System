local JAAS_RECORD_LIMIT = 16 -- 65535
local JAAS_LOG_LIMIT = 16 -- 65535
local JAAS_LOG_FOLDER_FILEPATH = "jaas/logs/"
local JAAS_LOG_DATE_NAME_FORMAT = "%Y%m%d"

local Object = setmetatable({__inherits = {[1] = "Object"}}, {__metatable = "Object"})

function Object:Default()
	return {__inherits = {[1] = "Object"}}
end

function Object:New(obj)
	obj = obj or self:Default()
	setmetatable(obj, {__index = self, __call = self.New, __metatable = getmetatable(self)})
	return obj
end

function Object:Inherit(obj, obj_name)
	obj = obj or self:Default()

	setmetatable(obj, {__index = self, __call = self.New, __metatable = obj_name or getmetatable(self)})

	obj.__inherits = self.__inherits
	obj.__inherits[1 + #self.__inherits] = obj_name

	return obj
end

JAAS.Object = Object

local SQLRecord = {}

function SQLRecord:SetPrimaryKey(key_name, key_value)
	self.primaryKeyName = key_name
	self.primaryKeyValue = key_value
end

function SQLRecord:Update()
	error("Function not implemented", 2)
end

function SQLRecord:Insert()
	error("Function not implemented", 2)
end

function SQLRecord:Delete()
	error("Function not implemented", 2)
end

SQLRecord = Object:Inherit(SQLRecord, "SQLRecord")

local SQLTableObject = {tableName = ""}

function SQLTableObject:SetSQLTable(tableName)
	self.tableName = tableName
end

function SQLTableObject:Exists()
	if self.exists == nil then
		self.exists = sql.TableExists(self.tableName)
	end

	return self.exists
end

function SQLTableObject:CreateTable(tableData)
	if self.tableName = "" then
		error("SQL Table Name not set; 'SetSQLTable' function must be called first", 2)
	end

	if !SQLTableObject:Exists() and SERVER then
		local create_table_statement = "CREATE TABLE " + self.tableName + " ("

		for k,v in pairs(tableData) do
			create_table_statement = create_table_statement + ", " + k + " " + v
		end

		create_table_statement = create_table_statement + ");"

		sql.Commit(create_table_statement)
	end
end

function SQLTableObject:DeleteAll() -- Assumes its executed after CreateTable
	sql.Commit("DELETE FROM " + self.tableName)
end

function SQLTableObject:GetSQLRecord()
	return SQLRecord:New {tableName = self.tableName}
end

SQLTableObject = Object:Inherit(SQLTableObject, "SQLTableObject")

JAAS.SQLTableObject = SQLTableObject

local FileObject = {}

function FileObject:FileWrite(f)
	error("Function not implemented", 2)
end

function FileObject:FileRead(f)
	error("Function not implemented", 2)
end

FileObject = Object:Inherit(FileObject, "FileObject")

JAAS.FileObject = FileObject

local jaas_net_network_strings = {}
local jaas_net = {}

local NetObject = {}

function NetObject:NetWrite()
	error("Function not implemented", 2)
end

function NetObject:NetRead()
	error("Function not implemented", 2)
end

function NetObject:NetBroadcast() end

if SERVER then
	function NetObject:NetBroadcast()
		net.Start(jaas_net_network_strings[index])
		self:NetWrite()
		net.Broadcast()
	end

	function NetObject:NetSend(index, ply)
		net.Start(jaas_net_network_strings[index])
		self:NetWrite()
		net.Send(ply)
	end
elseif CLIENT then
	function NetObject:NetSend(index)
		net.Start(jaas_net_network_strings[index])
		self:NetWrite()
		net.SendToServer()
	end
end

function NetObject:NetReceive(index, func)
	net.Receive(jaas_net_network_strings[index], function (len, ply)
		local received_object = self:New():NetRead()
		func(received_object, ply)
	end)
end

function NetObject:RegisterNetFuncs()
	net["Write" + getmetatable(self)] = self.NetWrite
	net["Read" + getmetatable(self)] = self.NetRead
end

NetObject = Object:Inherit(NetObject, "NetObject")

JAAS.NetObject = NetObject

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

if SERVER then
	function jaas_net:Request(index, ply)
		jaas_net:Start(index)
		net.Send(ply)
	end
elseif CLIENT then
	function jaas_net:Request(index)
		jaas_net:Start(index)
		net.SendToServer()
	end
end

function jaas_net:SendDataLoad(index, tab, net_write_func, ply)
end

function jaas_net:ReceiveDataLoad(index, net_read_func, func)
	net.Receive(jaas_net:GetNetworkString(index), function (len, ply)
		local data_load = {}
		local data_amount = net.ReadInt(JAAS_RECORD_LIMIT)

		for i=0,data_amount do
			data_load[1 + #data_load] = net_read_func()
		end

		func(data_load, ply, len)
	end)
end

function jaas_net:BroadcastCustomDataType(net_write_func)
end

if SERVER then
	function jaas_net:SendDataLoad(index, tab, net_write_func, ply)
		jaas_net:Start(index)
		net.WriteUInt(#tab, JAAS_RECORD_LIMIT)
		for k,v in ipairs(tab) do
			net_write_func(v)
		end
		net.Send(ply)
	end

	function jaas_net:BroadcastCustomDataType(net_write_func)
		return function (index, data)
			jaas_net:Start(index)
			net_write_func(data)
			net.Broadcast()
		end
	end
end

local function internalSend()
	if SERVER then
		net.Send(ply)
	elseif CLIENT then
		net.SendToServer()
	end
end

function jaas_net:SendCustomDataType(net_write_func)
	return function (index, data, ply)
		jaas_net:Start(index)
		net_write_func(data)
		internalSend()
	end
end

function jaas_net:ReceiveCustomDataType(net_read_func)
	return function (index, func)
		net.Receive(jaas_net:GetNetworkString(index), function (len, ply)
			func(net_read_func(), ply)
		end)
	end
end

function jaas_net:SendString(index, str, ply)
	jaas_net:Start(index)
	net.WriteString(str)
	internalSend()
end

function jaas_net:ReceiveString(index, func)
	net.Receive(jaas_net:GetNetworkString(index), function (len, ply)
		func(net.ReadString(), ply)
	end)
end

local jaas_log_list = {}
local jaas_log = {}

local CLIENTPRINT = jaas_net:RegisterNetworkString("Base::ModuleClientLog")

function jaas_log:Register(label)
	return setmetatable({label = label}, {__index = jaas_log})
end

function jaas_log:RegisterLog(tab) end

if SERVER then
	if !file.Exists(JAAS_LOG_FOLDER_FILEPATH, "DATA") then
		file.CreateDir(JAAS_LOG_FOLDER_FILEPATH)
	end

	function jaas_log:RegisterLog(tab)
		if jaas_log_list[self.label] = nil then
			jaas_log_list[self.label] = {}
		end

		jaas_log_list[self.label][1 + #jaas_log_list[self.label]] = tab
		local index = #jaas_log_list[self.label]
		local this = self

		return function (self, tab)
			this:WriteToLog(index, tab)
		end, index
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

local log_file = {date = 0, records = {}} -- In its current form this Object will be used mainly to offer a stable way to transfer between Server and Client

log_file = NetObject:Inherit(log_file, "LogFile")

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
		self.records[index] = log_record:New():NetRead()

		index = 1 + index
	until (index <= record_amount)
end

log_file = FileObject:Inherit(log_file, "LogFile")

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
		self.records[index] = log_record:New():FileRead(f)

		index = 1 + index
	until (index <= record_amount)
end

function log_file:Default()
	return {records = {}}
end

JAAS.LogFile = log_file

function jaas_log:ReadLogFile(Time) -- Unix Epoch

end

local CLIENTLOGFILEALLPULL = jaas_net:RegisterNetworkString("Base::ModuleClientLogFileDateFullPull")
local CLIENTLOGFILEPULL = jaas_net:RegisterNetworkString("Base::ModuleClientLogFileDatePull")

if SERVER then
	net.Receive(jaas_net:GetNetworkString(CLIENTLOGFILEALLPULL), function (len, ply)
		-- TODO : Check Permission
		-- For now it'll remain as it is whilst I still decide how module dependant code will look like in the future
		jaas_net:Start(CLIENTLOGFILEALLPULL)
		local found_files,found_dicts = file.Find(JAAS_LOG_FOLDER_FILEPATH + "*.dat", "DATA")
		net.WriteUInt(#found_files, 16)

		for k,v in ipairs(found_files) do
			local f = file.Open(JAAS_LOG_FOLDER_FILEPATH + v, "rb", "DATA")
			net.WriteUInt(f:ReadULong(), 32)
			f:Close()
		end
	end)

	net.Receive(jaas_net:GetNetworkString(CLIENTLOGFILEALLPULL), function (len, ply)
		-- TODO : Check Permission

		jaas_net:Start(CLIENTLOGFILEALLPULL)
		local requested_time = net.ReadUInt(32)

		local f = file.Open(JAAS_LOG_FOLDER_FILEPATH + os.date(JAAS_LOG_DATE_NAME_FORMAT, requested_time) + ".dat", "rb", "DATA")
		local found_logFile = log_file:New():FileRead(f)
		found_logFile:NetWrite()

		net.Send(ply)
	end)
elseif CLIENT then
	function jaas_log:GetAllLoggedDates(func)
		jaas_net:Request(CLIENTLOGFILEALLPULL)

		net.Receive(jaas_net:GetNetworkString(CLIENTLOGFILEALLPULL), function (len, ply)
			local log_dates = {}
			local log_files_amount = net.ReadUInt(16)

			local index = 1
			repeat
				log_dates[index] = net.ReadUInt(32)

				index = 1 + index
			until (index <= log_files_amount)

			func(log_dates)
		end)
	end

	function jaas_log:GetLogFile(time, func)
		jaas_net:Start(CLIENTLOGFILEALLPULL)
		net.WriteUInt(time, 32)
		net.SendToServer()

		net.Receive(jaas_net:GetNetworkString(CLIENTLOGFILEALLPULL), function (len, ply)
			local log_file = log_file:New():NetRead()

			func(log_file)
		end)
	end
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

local log_record = {Timestamp = nil, Label = nil, Type = nil, Rank = {}, Player = {}, Entity = {}, Data = {}, String = {}}

function log_record:BuildRecord()
	return jaas_log:BuildRecord(self)
end

log_record = NetObject:Inherit(log_record, "LogRecord")

function log_record:Default()
	return {Rank = {}, Player = {}, Entity = {}, Data = {}, String = {}}
end

function log_record:NetWrite()
	net.WriteUInt(self.Timestamp, 32)
	net.WriteString(self.Label)
	net.WriteUInt(self.Type, JAAS_LOG_LIMIT)

	net.WriteUInt(#self.Rank, 8) -- Rank
	if #self.Rank > 0 then
		for k,v in ipairs(self.Rank) do
			net.WriteRank(v)
		end
	end

	net.WriteUInt(#self.Player, 8) -- Player
	if #self.Player > 0 then
		for k,v in ipairs(self.Player) do
			net.WriteString(v)
		end
	end

	net.WriteUInt(#self.Entity, 8) -- Entity
	if #self.Entity > 0 then
		for k,v in ipairs(self.Entity) do
			net.WriteString(v)
		end
	end

	net.WriteUInt(#self.Data, 8) -- Data
	if #self.Data > 0 then
		for k,v in ipairs(self.Data) do
			net.WriteFloat(v)
		end
	end

	net.WriteUInt(#self.String, 8) -- String
	if #self.String > 0 then
		for k,v in ipairs(self.String) do
			net.WriteString(v)
		end
	end
end

function log_record:NetRead()
	self.Timestamp = net.ReadUInt(32)
	self.Label = net.ReadString()
	self.Type = net.ReadUInt(JAAS_LOG_LIMIT)

	local amount = net.ReadUInt(8) -- Rank Amount
	local i = 1
	if amount > 0 then
		repeat
			self.Rank[i] = net.ReadRank()
			i = 1 + i
		until (i <= amount)
	end

	amount = net.ReadUInt(8) -- Player Amount
	if amount > 0 then
		i = 1
		repeat
			self.Player[i] = net.ReadString()
			i = 1 + i
		until (i <= amount)
	end

	amount = net.ReadUInt(8) -- Entity Amount
	if amount > 0 then
		i = 1
		repeat
			self.Entity[i] = net.ReadString()
			i = 1 + i
		until (i <= amount)
	end

	amount = net.ReadUInt(8) -- Data Amount
	if amount > 0 then
		i = 1
		repeat
			self.Data[i] = net.ReadString()
			i = 1 + i
		until (i <= amount)
	end

	amount = net.ReadUInt(8) -- String Amount
	if amount > 0 then
		i = 1
		repeat
			self.String[i] = net.ReadString()
			i = 1 + i
		until (i <= amount)
	end
end

log_record:RegisterNetFuncs()

log_record = FileObject:Inherit(log_record, "LogRecord")

function log_record:FileWrite(f)
	local function writeStringTable(tab)
		f:WriteByte(#tab)
		for k,v in ipairs(tab) do
			f:WriteString(v)
		end
	end

	f:WriteByte(0x1)

	f:WriteByte(0x2)
	f:WriteULong(os.time())

	f:WriteByte(0x3)
	f:WriteString(record.Label)
	f:WriteUShort(record.Type)

	f:WriteByte(0x4)
	writeStringTable(record.Rank)

	f:WriteByte(0x5)
	writeStringTable(record.Player)

	f:WriteByte(0x6)
	writeStringTable(record.Entity)

	f:WriteByte(0x7)
	f:WriteByte(#record.Data)
	for k,v in ipairs(record.Data) do
		f:WriteFloat(v)
	end

	f:WriteByte(0x8)
	writeStringTable(record.String)

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
					self.Rank[1 + #self.Rank] = f:ReadString()
				end
			elseif byte == 0x6 then -- Entity
				local len = f:ReadByte()

				for i=0,len do
					self.Rank[1 + #self.Rank] = f:ReadString()
				end
			elseif byte == 0x7 then -- Data
				local len = f:ReadByte()

				for i=0,len do
					self.Rank[1 + #self.Rank] = f:ReadFloat()
				end
			elseif byte == 0x8 then -- String
				local len = f:ReadByte()

				for i=0,len do
					self.Rank[1 + #self.Rank] = f:ReadString()
				end
			end

			byte = f:ReadByte()
		end
	end
end

JAAS.LogRecord = log_record

local CLIENTLOGFILEPULL = jaas_net:RegisterNetworkString("Base::ModuleClientLogFile")

local module_list = {}
local module_dependencies = {}

local jaas_module = {}

function JAAS:NewModule(module_name)
	self.name = module_name
	module_list[1 + #module_list] = setmetatable({}, {__index = jaas_module, __metatable = "Module"})
	module_dependencies[module_name] = {}

	return module_list[#module_list],jaas_log,jaas_net
end

function JAAS:ExecuteModules()
	for k,module_data in ipairs(module_list) do -- k = index, v = module data
		if module_dependencies[module_data.name] == nil then
			module_data.Shared:Pre()
			module_data.Shared:Init()
			module_data.Shared:Post()

			if SERVER then
				module_data.Server:Pre()
				module_data.Server:Init()
				module_data.Server:Post()
			end

			if CLIENT then
				module_data.Client:Pre()
				module_data.Client:Init()
				module_data.Client:Post()
			end
		else
			module_data.Shared:Pre()
			module_data.Shared:Init()
			module_data.Shared:Post()

			for k,v in ipairs(module_dependencies[module_data.name]) do -- name,module_name
				module_list[v].Shared["Post" + module_data.name](setmetatable({}, {__index = module_data}))
			end

			if SERVER then
				module_data.Server:Pre()
				module_data.Server:Init()
				module_data.Server:Post()

				for k,v in ipairs(module_dependencies[module_data.name]) do -- name,module_name
					module_list[v].Server["Post" + module_data.name](setmetatable({}, {__index = module_data}))
				end
			end

			if CLIENT then
				module_data.Client:Pre()
				module_data.Client:Init()
				module_data.Client:Post()

				for k,v in ipairs(module_dependencies[module_data.name]) do -- name,module_name
					module_list[v].Client["Post" + module_data.name](setmetatable({}, {__index = module_data}))
				end
			end
		end
	end
end

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

function jaas_module:SetDependency(module_name)
	module_dependencies[module_name][1 + #module_dependencies[module_name]] = self.name

	self.Client["Post" + module_name] = function () end
	self.Server["Post" + module_name] = function () end
	self.Shared["Post" + module_name] = function () end
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

local jaas_module.Client = {}
local jaas_module.Server = {}
local jaas_module.Shared = {}

--- Overridable Functions ---
function jaas_module:ClientPull(ply)
end

function jaas_module.Client:Pre() end
function jaas_module.Client:Init() end
function jaas_module.Client:Post() end

function jaas_module.Server:Pre() end
function jaas_module.Server:Init() end
function jaas_module.Server:Post() end

function jaas_module.Shared:Pre() end
function jaas_module.Shared:Init() end
function jaas_module.Shared:Post() end
--- ---