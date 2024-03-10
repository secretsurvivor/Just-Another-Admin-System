JAAS = {}

do // GLua - Expansion
	local f = FindMetaTable("File")

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

	function net.WriteCompressedString(str)
		local compressedStr = util.Compress(str)
		local length = #compressedStr

		net.WriteUInt(length, 32)
		net.WriteData(compressedStr, length)
	end

	function net.ReadCompressedString()
		local length = net.ReadUInt(32)
		local data = net.ReadData(length)

		return util.Decompress(data)
	end

	function net.WriteCompressedTable(tbl)
		net.WriteCompressedString(util.TableToJSON(tbl))
	end

	function net.ReadCompressedTable()
		return util.JSONToTable(net.ReadCompressedString())
	end

	function isWhiteSpace(byte, ignoreSpace)
		return byte == 9 or byte == 10 or byte == 13 or (byte == 32 and not ignoreSpace)
	end

	function Catch(try, catch, final)
		assert(try != nil and catch != nil, "Try and Catch parameters cannot be nil")
		assert(isfunction(try) and isfunction(catch) and (final == nil or isfunction(final)), "All Parameters must be functions")

		local err,message = coroutine.resume(coroutine.create(func))

		if err then
			catch(message)
		end

		if final != nil then
			assert(isfunction(final), "All Parameters must be functions")
			final()
		end
	end

	function ClearGarbage()
		collectgarbage("collect")
	end
end

/*
	JAAS.Hook.Register(Container, Event, Identifier, Function)
	JAAS.Hook.Permission(PermissionName, Event, Identifier, Function)
*/
do -- Hook
	-- TODO Run System Hooks
	local hook_module = {}
	local hooks = {
		Permission = {},
		Command = {},
		Rank = {},
		Group = {},
		Other = {}
	}

	do // Base Hook Module
		// JAAS.Hook.Register("System", "Connect", "IDENTIFIER", function () end)
		function hook_module.Register(container, event, identifier, func)
			if hooks.Other[container] == nil then
				hooks.Other[container] = {[event] = {[identifier] = func}}

				return
			end

			if hooks.Other[container][event] == nil then
				hooks.Other[container][event] = {[identifier] = func}

				return
			end

			hooks.Other[container][event][identifier] = func
		end

		// JAAS.Hook.Call("System", "Connect", ply)
		function hook_module.Call(container, event, ...)
			if hooks.Other[container] != nil and hooks.Other[container][event] != nil then
				for identifier,func in pairs(hooks.Other[container][event]) do
					func(...)
				end
			end
		end

		// JAAS.Hook.Remove("System", "Connect", "IDENTIFIER")
		function hook_module.Remove(container, event, identifier)
			if hooks.Other[container] != nil and hooks.Other[container][event] != nil then
				hooks.Other[container][event][identifier] = nil
			end
		end

		// JAAS.Hook.Exists("System", "Connect", "IDENTIFIER")
		function hook_module.Exists(container, event, identifier)
			if hooks.Other[container] != nil and hooks.Other[container][event] != nil then
				return hooks.Other[container][event][identifier] != nil
			end

			return false
		end

		// JAAS.Hook.ContainerHook("System")
		function hook_module.ContainerHook(container)
			return function (event, identifier, func)
				hook_module.Register(container, event, identifier, func)
			end
		end

		function hook_module.ContainerCallHook(container)
			return function (event, ...)
				hook_module.Call(container, event, ...)
			end
		end
	end

	local hook_permission = {}

	do // Permission Hook Module
		// JAAS.Hook.Permission.Register("Can Noclip", "ModifiedCode", "IDENTIFIER", function () end)
		function hook_permission.Register(permission_name, event, identifier, func)
			if hooks.Permission[permission_name] == nil then
				hooks.Permission[permission_name] = {[event] = {[identifier] = func}}

				return
			end

			if hooks.Permission[permission_name][event] == nil then
				hooks.Permission[permission_name][event] = {[identifier] = func}

				return
			end

			hooks.Permission[permission_name][event][identifier] = func
		end

		// JAAS.Hook.Permission.Call("Can Noclip", "ModifiedCode", code)
		function hook_permission.Call(permission_name, event, ...)
			if hooks.Permission[permission_name] != nil and hooks.Permission[permission_name][event] != nil then
				for identifier,func in pairs(hooks.Permission[permission_name][event]) do
					func(...)
				end
			end
		end

		function hook_permission.Remove(permission_name, event, identifier)
			if hooks.Permission[permission_name] != nil and hooks.Permission[permission_name][event] != nil then
				hooks.Permission[permission_name][event][identifier] = nil
			end
		end

		function hook_permission.Exists(permission_name, event, identifier)
			if hooks.Permission[permission_name] != nil and hooks.Permission[permission_name][event] != nil then
				return hooks.Permission[permission_name][event][identifier] != nil
			end

			return false
		end
	end

	local hook_command = {}

	do // Command Hook Module
		function hook_command.Register(command_name, event, identifier, func)
			if hooks.Command[command_name] == nil then
				hooks.Command[command_name] = {[event] = {[identifier] = func}}

				return
			end

			if hooks.Command[command_name][event] == nil then
				hooks.Command[command_name][event] = {[identifier] = func}

				return
			end

			hooks.Command[command_name][event][identifier] = func
		end

		function hook_command.Call(command_name, event, ...)
			if hooks.Command[command_name] != nil and hooks.Command[command_name][event] != nil then
				for identifier,func in pairs(hooks.Command[command_name][event]) do
					func(...)
				end
			end
		end

		function hook_command.Remove(command_name, event, identifier)
			if hooks.Command[command_name] != nil and hooks.Command[command_name][event] != nil then
				hooks.Command[command_name][event][identifier] = nil
			end
		end

		function hook_command.Exists(command_name, event, identifier)
			if hooks.Command[command_name] != nil and hooks.Command[command_name][event] != nil then
				return hooks.Command[command_name][event][identifier] != nil
			end

			return false
		end
	end

	local hook_rank = {}

	do // Rank Hook Module
		function hook_rank.Register(rank_name, event, identifier, func)
			if hooks.Rank[rank_name] == nil then
				hooks.Rank[rank_name] = {[event] = {[identifier] = func}}

				return
			end

			if hooks.Rank[rank_name][event] == nil then
				hooks.Rank[rank_name][event] = {[identifier] = func}

				return
			end

			hooks.Rank[rank_name][event][identifier] = func
		end

		// JAAS.Hook.Rank.Call(Name, Event, ...)
		function hook_rank.Call(rank_name, event, ...)
			if hooks.Rank[rank_name] != nil and hooks.Rank[rank_name][event] != nil then
				for identifier,func in pairs(hooks.Rank[rank_name][event]) do
					func(...)
				end
			end
		end

		function hook_rank.Remove(rank_name, event, identifier)
			if hooks.Rank[rank_name] != nil and hooks.Rank[rank_name][event] != nil then
				hooks.Rank[rank_name][event][identifier] = nil
			end
		end

		function hook_rank.Exists(rank_name, event, identifier)
			if hooks.Rank[rank_name] != nil and hooks.Rank[rank_name][event] != nil then
				return hooks.Rank[rank_name][event][identifier] != nil
			end

			return false
		end
	end

	local hook_access = {}

	do // Group Hook Module
		// JAAS.Hook.Group.Register(Name, Event, Identifier, function () end)
		function hook_access.Register(access_name, event, identifier, func)
			if hooks.Access[access_name] == nil then
				hooks.Access[access_name] = {[event] = {[identifier] = func}}

				return
			end

			if hooks.Access[access_name][event] == nil then
				hooks.Access[access_name][event] = {[identifier] = func}

				return
			end

			hooks.Access[access_name][event][identifier] = func
		end

		function hook_access.Call(access_name, event, ...)
			if hooks.Access[access_name] != nil and hooks.Access[access_name][event] != nil then
				for identifier,func in pairs(hooks.Access[access_name][event]) do
					func(...)
				end
			end
		end

		function hook_access.Remove(access_name, event, identifier)
			if hooks.Access[access_name] != nil and hooks.Access[access_name][event] != nil then
				hooks.Access[access_name][event][identifier] = nil
			end
		end

		function hook_access.Exists(access_name, event, identifier)
			if hooks.Access[access_name] != nil and hooks.Access[access_name][event] != nil then
				return hooks.Access[access_name][event][identifier] != nil
			end

			return false
		end
	end

	hook_module.Permission = Class("JAAS_Hook_Permission", hook_permission)
	hook_module.Command = Class("JAAS_Hook_Command", hook_command)
	hook_module.Rank = Class("JAAS_Hook_Rank", hook_rank)
	hook_module.Group = Class("JAAS_Hook_Group", hook_access)
	hook_module = Class("JAAS_Hook", hook_module)

	PushJAAS("Hook", hook_module)
end

include("shared/jaas__config.lua")

local function StringParserBuilder(nextToken, tokenCalc)
	local str_func = string.gmatch(str, ".")
	local endOfStr = false
	local str_char = {byte = 0, char = "", position = 1}

	local function nextChar()
		str_char = {byte = 0, char = str_func(), 1 + str_char.position}

		if str_char.char == nil then
			str_char = nil
		else
			str_char.byte = string.byte(str_char)
		end
	end

	nextChar()

	local lastToken
	local token

	while true do
		local t = nextToken(str_char, nextChar)

		lastToken = token
		token = t

		tokenCalc(token, lastToken)

		if str_char = nil then
			break
		end
	end
end

local object_metatable_lib = {}
local structure_metatable_lib = {} // {[1] Default Attributes, [2] Metatable}
local module_collection = {}

local Objects = {} // [Name] = Constructor
local Structures = {} // [Name] = {[__call] Constructor, [Read] Net Read}
local Classes = {}

local function ReadOnlyFunction()
	error("Object cannot be written to", 2)
end

local function GetStructure(name)
	return Structures[name]
end

local function PushPublic(name, obj)
	_G[name] = setmetatable({}, {__index = obj, __newindex = ReadOnlyFunction})
end

local function PushJAAS(name, obj)
	JAAS[name] = setmetatable({}, {__index = obj, __newindex = ReadOnlyFunction})
end

// RegisterObject("", tbl)
local function Object(name, t)
	name = string.Trim(name)

	assert(name != nil and name != "", "Objects must have a valid name")
	assert(object_metatable_lib[name] == nil and structure_metatable_lib[name] == nil, "Object Name must be Unique")
	assert(t.Constructor != nil, "Objects must have Constructors")

	// __tostring = ToString
	// __index = Get
	// __newindex = Set

	local m = {
		__tostring = t.ToString,
		__index = t.Get,
		__newindex = t.Set,
		__name = name,
		__metatable = name
	}

	function m:New()
		return setmetatable({}, object_metatable_lib[getmetatable(self)])
	end

	object_metatable_lib[name] = m
	Objects[name] = function (...)
		local obj = setmetatable({}, object_metatable_lib[name])

		t.Constructor(obj, ...)

		return obj
	end

	return setmetatable({}, m)
end

PushPublic("RegisterObject", Object)

local function Structure(name, attributes, t)
	name = string.Trim(name)

	assert(name != nil and name != "", "Objects must have a valid name")
	assert(structure_metatable_lib[name] == nil and object_metatable_lib[name] == nil, "Structure Name must be Unique")
	assert(t.Constructor != nil, "Objects must have Constructors")
	assert(t.Read != nil and t.Write != nil, "Structures must be accessible from the Net Library")
	assert(attributes.Write == nil, "Structure cannot have an Attribute named Write")

	// Read
	// Write

	local s = attributes
	local m = {
		__newindex = function (self, key, value)
			if !isfunction(rawget(self, key)) then
				rawset(self, key, value)
			else
				error("Object cannot be written to", 2)
			end
		end,
		__name = name,
		__metatable = name
	}

	structure_metatable_lib[name] = {s, m}
	Structures[name] = setmetatable({
		Read = function ()
			local obj = setmetatable(s, m)

			t.Read(obj)

			return obj
		end
	}, {
		__call = function (...)
			local obj = setmetatable(s, m)

			t.Constructor(obj, ...)

			return obj
		end,
		__newindex = ReadOnlyFunction
	})

	return setmetatable(s, m)
end

PushPublic("RegisterStructure", Structure)

local function Class(name, t, constructor)
	name = string.Trim(name)

	assert(name != nil and name != "", "Objects must have a valid name")

	local m = {
		__index = t,
		__newindex = ReadOnlyFunction,
		__name = name,
		__metatable = name
	}

	if constructor == nil then
		return setmetatable({}, {m})
	end

	return function (...)
		local obj = setmetatable({}, {m})

		constructor(obj, ...)

		return obj
	end
end

PushPublic("RegisterClass", Class)

local function DataStructure(methods)
	methods.BeforeIndex = methods.BeforeIndex or function (key) return end
	methods.BeforeNewIndex = methods.BeforeNewIndex or function (key, value) return end
	methods.AfterIndex = methods.AfterIndex or function (key) end
	methods.AfterNewIndex = methods.AfterNewIndex or function (key, new_value, old_value) end

	/* Supported Methods:
		BeforeIndex
		AfterIndex
		BeforeNewIndex
		AfterNewIndex
	*/

	local m = {
		__index = function (self, key)
			key = methods.BeforeIndex(key) or key // Use BeforeIndex or given Key
			local g = rawget(self, key)
			methods.AfterIndex(key)
			return g
		end,
		__newindex = function (self, key, value)
			local k,v = methods.BeforeNewIndex(key, value)
			key = k or key
			value = v or value
			local old_value = rawget(self, key)
			local s = rawset(self, key, value)
			methods.AfterNewIndex(key, value, old_value)
			return s
		end
	}

	return setmetatable({}, m)
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////// Net Module

local net_module = {}

do // Net Code
	local net_functions = {}

	function net_module:RegisterNet(identifier)
		identifier = "JAAS__" .. self.Name .. "__" .. identifier

		if SERVER then
			util.AddNetworkString(identifier)
		end

		return setmetatable({netString = identifier}, {__index = net_functions})
	end

	if SERVER then
		function net_functions:Send(ply, func)
			net.Start(self.netString)

			if func != nil then
				func()
			end

			if net.BytesWritten() >= 64000 then
				ErrorNoHaltWithStack("Message reached max Net Limit on '" .. self.netString .. "'")
			end

			net.Send(ply)
		end

		function net_functions:Broadcast(func)
			net.Start(self.netString)

			if func != nil then
				func()
			end

			if net.BytesWritten() >= 64000 then
				ErrorNoHaltWithStack("Message reached max Net Limit '" .. self.netString .. "'")
			end

			net.Broadcast()
		end

		function net_functions:SendOmit(ply, func)
			net.Start(self.netString)

			if func != nil then
				func()
			end

			if net.BytesWritten() >= 64000 then
				ErrorNoHaltWithStack("Message reached max Net Limit '" .. self.netString .. "'")
			end

			net.SendOmit(ply)
		end

		function net_functions:SendPAS(vec, func)
			net.Start(self.netString)

			if func != nil then
				func()
			end

			if net.BytesWritten() >= 64000 then
				ErrorNoHaltWithStack("Message reached max Net Limit '" .. self.netString .. "'")
			end

			net.SendPAS(vec)
		end

		function net_functions:SendPVS(vec, func)
			net.Start(self.netString)

			if func != nil then
				func()
			end

			if net.BytesWritten() >= 64000 then
				ErrorNoHaltWithStack("Message reached max Net Limit '" .. self.netString .. "'")
			end

			net.SendPVS(vec)
		end

		function net_functions:SendString(ply, str)
			self:Send(ply, function ()
				net.WriteString(str)
			end)
		end

		function net_functions:SendTable(ply, tbl)
			self:Send(ply, function ()
				net.WriteTable(tbl)
			end)
		end

		function net_functions:BroadcastTable(tbl)
			self:Broadcast(function ()
				net.WriteTable(tbl)
			end)
		end

		function net_functions:SendInteger(ply, num)
			self:Send(ply, function ()
				net.WriteInt(num, 32)
			end)
		end

		function net_functions:SendFloat(ply, dec)
			self:Send(ply, function ()
				net.WriteFloat(dec)
			end)
		end

		function net_functions:SendRequest(ply)
			self:Send(ply)
		end

		function net_functions:BroadcastRequest()
			self:Broadcast()
		end

		function net_functions:SendStructure(ply, structure)
			self:Send(ply, function ()
				net.WriteString(getmetatable(structure))
				structure:Write()
			end)
		end

		function net_functions:BroadcastStructure(structure)
			self:Broadcast(function ()
				net.WriteString(getmetatable(structure))
				structure:Write()
			end)
		end

		function net_functions:SendCompressedString(ply, str)
			self:Send(ply, function ()
				net.WriteCompressedString(str)
			end)
		end

		function net_functions:SendCompressedTable(ply, tbl)
			self:SendCompressedString(ply, util.TableToJSON(tbl))
		end

		function net_functions:BroadcastCompressedString(str)
			self:Broadcast(function ()
				net.WriteCompressedString(str)
			end)
		end

		function net_functions:BroadcastCompressedTable(tbl)
			self:BroadcastCompressedString(util.TableToJSON(tbl))
		end
	end

	if CLIENT then
		function net_functions:SendToServer(func)
			net.Start(self.netString)

			if func != nil then
				func()
			end

			if net.BytesWritten() >= 64000 then
				ErrorNoHaltWithStack("Message reached max Net Limit '" .. self.netString .. "'")
			end

			net.SendToServer()
		end

		function net_functions:SendString(str)
			self:SendToServer(function ()
				net.WriteString(str)
			end)
		end

		function net_functions:SendTable(tbl)
			self:SendToServer(function ()
				net.WriteTable(tbl)
			end)
		end

		function net_functions:SendInteger(num)
			self:SendToServer(function ()
				net.WriteInt(num, 32)
			end)
		end

		function net_functions:SendFloat(dec)
			self:SendToServer(function ()
				net.WriteFloat(dec)
			end)
		end

		function net_functions:SendRequest()
			self:SendToServer()
		end

		function net_functions:SendStructure(structure)
			self:SendToServer(function ()
				net.WriteString(getmetatable(structure))
				structure:Write()
			end)
		end

		function net_functions:SendCompressedString(str)
			self:SendToServer(function ()
				net.WriteCompressedString(str)
			end)
		end

		function net_functions:SendCompressedTable(tbl)
			self:SendCompressedString(util.TableToJSON(tbl))
		end
	end

	function net_functions:ReplaceReceiveParams(func)
		self.ReceiveFunc = func
	end

	function net_functions:HasReceiveParams()
		return self.ReceiveFunc != nil
	end

	function net_functions:Receive(func)
		if self.HasReceive then
			error("Cannot have more than one Receive function", 2)
		end

		net.Receive(self.netString, function(len, ply)
			if self.ReceiveFunc == nil then
				func(len, ply)
			else
				func(self.ReceiveFunc(len, ply))
			end
		end)

		self.HasReceive = true
	end

	function net_functions:ReceiveString(func)
		if self:HasReceiveParams() then
			error("Cannot replace Receive Parameters", 2)
		end

		self:Receive(function (len, ply)
			func(net.ReadString(), len, ply)
		end)
	end

	function net_functions:ReceiveTable(func)
		if self:HasReceiveParams() then
			error("Cannot replace Receive Parameters", 2)
		end

		self:Receive(function (len, ply)
			func(net.ReadTable(), len, ply)
		end)
	end

	function net_functions:ReceiveInteger(func)
		if self:HasReceiveParams() then
			error("Cannot replace Receive Parameters", 2)
		end

		self:Receive(function (len, ply)
			func(net.ReadInt(32), len, ply)
		end)
	end

	function net_functions:ReceiveFloat(func)
		if self:HasReceiveParams() then
			error("Cannot replace Receive Parameters", 2)
		end

		self:Receive(function (len, ply)
			func(net.ReadFloat(), len, ply)
		end)
	end

	function net_functions:ReceiveStructure(func)
		if self:HasReceiveParams() then
			error("Cannot replace Receive Parameters", 2)
		end

		self:Receive(function (len, ply)
			local name = net.ReadString()
			func(Structures[name]:Read(), len, ply)
		end)
	end

	function net_functions:ReceiveCompressedString(func)
		if self:HasReceiveParams() then
			error("Cannot replace Receive Parameters", 2)
		end

		self:Receive(function (len, ply)
			func(net.ReadCompressedString(), len, ply)
		end)
	end

	function net_functions:ReceiveCompressedTable(func)
		self:ReceiveCompressedString(function (str, len, ply)
			func(util.JSONToTable(str), len, ply)
		end)
	end

	/*
		The use of these two functions may not be obvious
		They sync the server-side and client-side tables when the user first connects to the server

		Usually tables can only be populated server-side but usually the client needs that data as well
		so this function syncs the server and client tables automatically
	*/
	function net_functions:InitialSyncStockTable(identifier, tbl, func)
		if SERVER then
			local this = self
			identifier = "__JAAS__NETMODULE__TBL__SYNC_" .. identifier

			if JAAS.Hook:Exists("System", "Connect", identifier) then
				error("Identity already exists", 2)
			end

			JAAS.Hook:Register("System", "Connect", identifier, function (ply)
				this:Send(ply, function ()
					net.WriteTable(tbl)
				end)
			end)
		elseif CLIENT then
			if self:HasReceiveParams() then
				error("Cannot replace Receive Parameters", 2)
			end

			self:Receive(function (len, ply)
				func(net.ReadTable())
			end)
		end
	end

	function net_functions:InitialSyncTable(identifier, methods)
		assert(methods.Write != nil, "Expected Write Method") // Server Write
		assert(methods.Read != nil, "Expected Read Method") // Client Read

		if SERVER then
			local this = self
			identifier = "__JAAS__NETMODULE__TBL__SYNC_" .. identifier

			if JAAS.Hook:Exists("System", "Connect", identifier) then
				error("Identity already exists", 2)
			end

			JAAS.Hook:Register("System", "Connect", identifier, function (ply)
				this:Send(ply, function ()
					methods.Write()
				end)
			end)
		elseif CLIENT then
			if self:HasReceiveParams() then
				error("Cannot replace Receive Parameters", 2)
			end

			self:Receive(function (len, ply)
				methods.Read()
			end)
		end
	end

	net_module = Class("NET", net_module, function (self, name)
		self.Name = name
	end)
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-------------------------------------------------------------------------------------------------------------------------------

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////// SQL Module

local sql_module = {}

do // Sql Code
	local format,query,query_value,query_row = string.format,sql.Query,sql.QueryValue,sql.QueryRow

	local function fQuery(str, ...)
		return query(format(str, ...))
	end

	function sql_module:Exists()
		return sql.TableExists(self.Name)
	end

	function sql_module:Create(table_string)
		if !self:Exists() then
			return fQuery("create table %s (%s)", self.Name, table_string) == nil
		end
	end

	function sql_module:Drop()
		return query("drop table " .. self.Name) == nil
	end

	function sql_module:CreateIndex(index_name, column_string)
		return fQuery("create index %s on %s (%s)", self.Name .. "__" .. index_name, self.Name, column_string) == nil
	end

	function sql_module:CreateUniqueIndex(index_name, column_string)
		return fQuery("create unique index %s on %s (%s)", self.Name .. "__" .. index_name, self.Name, column_string) == nil
	end

	function sql_module:DropIndex(index_name)
		return query("drop index " .. index_name) == nil
	end

	function sql_module:Select(column_string, where_string)
		if where_string == nil then
			return fQuery("select %s from %s", column_string, self.Name)
		else
			return fQuery("select %s from %s where %s", column_string, self.Name, where_string)
		end
	end

	function sql_module:SelectScalar(column_string, where_string)
		if where_string == nil then
			return query_value(format("select %s from %s", column_string, self.Name))
		else
			return query_value(format("select %s from %s where %s", column_string, self.Name, where_string))
		end
	end

	function sql_module:SelectRow(column_string, where_string)
		if where_string == nil then
			return query_row(format("select %s from %s", column_string, self.Name))
		else
			return query_row(format("select %s from %s where %s", column_string, self.Name, where_string))
		end
	end

	function sql_module:Insert(column_string, value_string) // SQL:Insert("Name", name)
		return fQuery("insert into %s (%s) values (%s)", self.Name, column_string, value_string) == nil
	end

	function sql_module:Update(update_string, where_string) // SQL:Update("Code", "Name = " .. name)
		return fQuery("update %s set %s where %s", self.Name, update_string, where_string) == nil
	end

	function sql_module:Delete(where_string)
		if where_string == nil then
			return fQuery("delete from %s", self.Name) == nil
		else
			return fQuery("delete from %s where %s", self.Name, where_string) == nil
		end
	end

	function sql_module:New(name)
		return sql_module(name)
	end

	sql_module.fQuery = fQuery

	sql_module = Class("SQL", sql_module, function (self, name)
		self.Name = name
	end)
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-------------------------------------------------------------------------------------------------------------------------------

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////// Module

local shared_posts = {SHARED = {}, SERVER = {}, CLIENT = {}}

local function AddPost(state, func)
	shared_posts[state][1 + #shared_posts] = func
end

local shared_net_module = net_module("_SHARED__NET_")
local client_console_net = shared_net_module:RegisterNet("_SHARED__CONSOLE__PRINT_")
local client_chat_net = shared_net_module:RegisterNet("_SHARED__CHAT__PRINT_")

local module_module = {}

do // Module Code
	local format = string.format

	function module_module:fPrint(str, ...)
		print(format(str, ...))
	end

	local module_client_print_net = net_module("_SHARED__MODULE_"):RegisterNet("_SHARED__MODULE__CLIENT__PRINT_")

	if SERVER then
		function module_module:ClientPrint(ply, str, ...)
			module_client_print_net:SendString(ply, format(str, ...))
		end
	elseif CLIENT then
		function module_module:ClientPrint(ply, str, ...) end // Added to avoid a Clientside error in Shared execution

		module_client_print_net:ReceiveString(function (str)
			print(str)
		end)
	end

	local defaultTextColour = JAAS.Config.Color("DefaultTextColour", Color(255, 241, 122, 200))

	local function ColouredParser(str, ...) // "This should ^(1)not^0 happen"
		local args = {...}
		local obj = {defaultTextColour}

		local function AddValue(value)
			obj[1 + #obj] = value
		end

		StringParserBuilder(function (charTable, nextChar) // NextToken
			if charTable != nil then // EOS
				/*
					Base : 1
					Colour : 2
				*/
				local token = {id = 0, value = ""}

				local function setToken(id, value)
					token.id = id
					token.value = value
				end

				if charTable.byte == 94 then
					nextChar()

					if (charTable.byte >= 48 and charTable.byte <= 57) or charTable.byte == 40 then
						if charTable.byte == 40 then
							nextChar()
							local index = ""

							while true do
								if charTable.byte >= 48 and charTable.byte <= 57 then // Numbers
									index = index .. charTable.char
								elseif charTable.byte == 41 then // Closing Bracket
									break
								elseif charTable == nil then
									error("Expected closing symbol ')'", 3)
								else
									error("Unexpected symbol; accepted symbols include numbers and closing bracket at Character position '" .. charTable.position .. "'", 3)
								end
							end

							index = tonumber(index)

							if args[index] == nil then
								error("Index specified at '" .. charTable.position .. "' is invalid", 3)
							end

							setToken(2, args[index])
						else
							if charTable.byte == 48 then
								setToken(2, defaultTextColour)
							else
								setToken(2, args[tonumber(charTable.char)])
							end
						end
					else
						setToken(1, "^" .. charTable.char)
					end
				else
					token.id = 1

					while charTable.byte != 47 and charTable.byte != 35 do
						token.value = token.value .. charTable.char
						nextChar()
					end
				end

				return token
			end
		end, function (token, lastToken) // Calculate Token
			if token != nil then // EOS
				if token.id == 1 then // Base
					if lastToken.id == 1 then
						obj[#obj] = obj[#obj] .. token.value
					else
						AddValue(token.value)
					end
				else // Colour
					AddValue(token.value)
				end
			end
		end)

		return obj
	end

	function module_module:SendColouredConsole(ply, str, ...) // "^1Warning:^0 Invalid Parameter", Color(192, 0, 0)
		client_console_net:SendTable(ply, ColouredParser(str, ...))
	end

	function module_module:SendColouredChat(ply, str, ...) // "^1Warning:^0 Invalid Parameter", Color(192, 0, 0)
		client_chat_net:SendTable(ply, ColouredParser(str, ...))
	end

	function module_module:BroadcastColouredConsole(str, ...)
		client_console_net:BroadcastTable(ColouredParser(str, ...))
	end

	function module_module:BroadcastColouredChat(str, ...)
		client_chat_net:BroadcastTable(ColouredParser(str, ...))
	end

	if CLIENT then
		client_console_net:ReceiveTable(function (tbl)
			MsgC(unpack(tbl))
		end)

		client_chat_net:ReceiveTable(function (tbl)
			chat.AddText(unpack(tbl))
		end)
	end

	function module_module:CreateType(name, metatable_name)
		_G["Is" .. name] = function (obj)
			return istable(obj) and getmetatable(obj) == metatable_name
		end
	end

	module_module = Class("MODULE", module_module, function (self, name)
		self.Name = name
		self.Hook = JAAS.Hook.ContainerCallHook(name)

		if SERVER and CLIENT then
			self.Shared = setmetatable({}, {
				__newindex = function (t, k, v)
					if k == "Post" then
						rawset(t, 1 + #t, v)
					else
						rawset(t, k, v)
					end
				end
			})
		elseif SERVER then
			self.Server = setmetatable({}, {
				__newindex = function (t, k, v)
					if k == "Post" then
						rawset(t, 1 + #t, v)
					else
						rawset(t, k, v)
					end
				end
			})
		elseif CLIENT then
			self.Client = setmetatable({}, {
				__newindex = function (t, k, v)
					if k == "Post" then
						rawset(t, 1 + #t, v)
					else
						rawset(t, k, v)
					end
				end
			})
		end
	end)
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-------------------------------------------------------------------------------------------------------------------------------

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/////////// Log Module

local log_module = {}
/*
	This Module can be described as the most straight forward and also the most complex module of the bunch
	Designed to do a lot of the heavy lifting, the module only has one function that returns an object
*/

do // Log Code
	// RegisterLog("%P has %*Connected%") -> secret_survivor has Connected
	// %P : Player
	// %c : Command
	// %r : Rank
	// %a : Access Group
	// $p : Permission
	// %*...% : Action
	// %% : %
	// %d : Decimal
	// %s : String

	// LOG:RegisterLog("%P has %*Connected%")
	function log_module:RegisterLog(str)
		local t = {LogData = LogParser(str)}
		local m = {}

		if SERVER then
			function m:Write(...)
				WriteLog(self.Name, self.LogData, ...)
				self:PostLog(...)
			end

			// Designed to be overwritten
			function m:PostLog(...)
				//self:BroadcastConsoleText(...)
			end

			function m:SendConsoleText(ply, ...)
				local console_obj = {{0x1A, self.Name .. " - "}}

				for k,v in ipairs(self.LogData) do
					console_obj[1 + k] = v
				end

				client_console_net:SendTable(ply, ColourLog(console_obj, ...))
			end

			function m:SendChatText(ply, ...)
				client_chat_net:SendTable(ply, ColourLog(self.LogData, ...))
			end

			function m:BroadcastConsoleText(...)
				local console_obj = {{0x1A, self.Name .. " - "}}

				for k,v in ipairs(self.LogData) do
					console_obj[1 + k] = v
				end

				client_console_net:BroadcastTable(ColourLog(console_obj, ...))
			end

			function m:BroadcastChatText(...)
				client_chat_net:BroadcastTable(ColourLog(self.LogData, ...))
			end
		else
			function m:Write(...)
			end
		end

		return setmetatable(t, {__index = m})
	end

	local LOG_FLAGS = {
		HEADER = 0x1A,
		END = 0xA,
		PLAYER = 0x1,
		COMMAND = 0x2,
		RANK = 0x3,
		ACCESSGROUP = 0x4,
		PERMISSION = 0x5,
		ACTION = 0x6,
		STRING = 0x7,
		DECIMAL = 0x8,
		BASE = 0x9
	}

	local LOG_OBJECT_COLOURS = {
		[LOG_FLAGS.PLAYER] = JAAS.Config.Color("LogPlayerColour", Color(68, 84, 106)),
		[LOG_FLAGS.COMMAND] = JAAS.Config.Color("LogCommandColour", Color(204, 0, 0)),
		[LOG_FLAGS.RANK] = JAAS.Config.Color("LogRankColour", Color(112, 48, 160)),
		[LOG_FLAGS.ACCESSGROUP] = JAAS.Config.Color("LogAccessGroupColour", Color(132, 60, 12)),
		[LOG_FLAGS.PERMISSION] = JAAS.Config.Color("LogPermissionColour", Color(196, 149, 0)),
		[LOG_FLAGS.ACTION] = JAAS.Config.Color("LogActionColour", Color(192, 0, 0)),
		[LOG_FLAGS.STRING] = JAAS.Config.Color("LogStringColour", Color(197, 90, 17)),
		[LOG_FLAGS.DECIMAL] = JAAS.Config.Color("LogDecimalColour", Color(84, 130, 53)),
		[LOG_FLAGS.BASE] = JAAS.Config.Color("LogBaseColour", Color(255, 241, 122, 200)),
		[LOG_FLAGS.HEADER] = JAAS.Config.Color("LogHeaderColour", Color(112, 173, 71)) // Internal Colouring for Console
	}

	local function LogParser(str)

		local obj = {}

		local function AddObj(v)
			obj[1 + #obj] = v
		end

		StringParserBuilder(function (charTable, nextChar) // NextToken
			/*
				1 : Player
				2 : Command
				3 : Rank
				4 : Access Group
				5 : Permission
				6 : Action
				7 : String
				8 : Decimal
				9 : Base
				-1 : EOS (End of String)
			*/
			local token = {id = 0, value = ""}

			local function setToken(id, value)
				token.id = id
				token.value = value
			end

			if charTable == nil then
				setToken(-1)
			else
				if charTable.byte == 37 then
					nextChar()

					if charTable.byte == 37 then
						setToken(LOG_FLAGS.BASE, "%")
					elseif charTable.byte == 42 then
						setToken(LOG_FLAGS.ACTION)

						while charTable.byte != 37 do
							token.value = token.value .. charTable.char

							nextChar()
						end
					else
						if charTable.byte == 80 then // Player
							setToken(LOG_FLAGS.PLAYER)
						elseif charTable.byte == 99 then // Command
							setToken(LOG_FLAGS.COMMAND)
						elseif charTable.byte == 114 then // Rank
							setToken(LOG_FLAGS.RANK)
						elseif charTable.byte == 97 then // Access Group
							setToken(LOG_FLAGS.ACCESSGROUP)
						elseif charTable.byte == 112 then // Permission
							setToken(LOG_FLAGS.PERMISSION)
						elseif charTable.byte == 115 then // String
							setToken(LOG_FLAGS.STRING)
						elseif charTable.byte == 100 then // Decimal
							setToken(LOG_FLAGS.DECIMAL)
						else
							error("Unrecognised symbol at '%" .. string.char(str_char) .. "'", 2)
						end
					end
				else
					setToken(LOG_FLAGS.BASE)

					while true do
						if charTable.byte != 37 then
							token.value = token.value .. charTable.char
						else
							break
						end

						nextChar()
					end
				end
			end

			return token
		end, function (token, lastToken) // Calculate Token
			if token.id > -1 then
				if token.id == LOG_FLAGS.BASE then
					if lastToken.id == LOG_FLAGS.BASE then
						obj[#obj] = obj[#obj] .. token.value
					else
						AddObj(token.value)
					end
				else
					if token.id == LOG_FLAGS.ACTION then
						AddObj{LOG_FLAGS.ACTION, token.value}
					else
						AddObj{token.id}
					end
				end
			end
		end)

		return obj
	end

	local function LogBuilder(func, obj, ...)
		local args = {...}
		local index = 1

		for k,v in ipairs(obj) do
			if isstring(v) then
				func(LOG_FLAGS.BASE, v)
			elseif istable(v) then
				local arg = args[index]

				if v[1] = LOG_FLAGS.PLAYER then -- Player
					if !IsPlayer(arg) then
						error("Argument '" .. index .. "' must be a Player", 3)
					end
				elseif v[1] = LOG_FLAGS.COMMAND then -- Command
					if !IsCommand(arg) then
						error("Argument '" .. index .. "' must be a Command Object", 3)
					end
				elseif v[1] = LOG_FLAGS.RANK then -- Rank
					if !IsRank(arg) then
						error("Argument '" .. index .. "' must be a Rank Object", 3)
					end
				elseif v[1] = LOG_FLAGS.ACCESSGROUP then -- Access Group
					if !IsAccessGroup(arg) then
						error("Argument '" .. index .. "' must be an Access Group Object", 3)
					end
				elseif v[1] = LOG_FLAGS.PERMISSION then -- Permission
					if !IsPermission(arg) then
						error("Argument '" .. index .. "' must be a Permission Object", 3)
					end
				elseif v[1] = LOG_FLAGS.ACTION or v[1] = LOG_FLAGS.HEADER then -- Action
					index = index - 1 // Minus Index to counteract later increment
				elseif v[1] = LOG_FLAGS.STRING then -- String
					if !isstring(arg) then
						error("Argument '" .. index .. "' must be a String", 3)
					end
				elseif v[1] = LOG_FLAGS.DECIMAL then -- Decimal
					if !isnumber(arg) then
						error("Argument '" .. index .. "' must be a Number", 3)
					end
				else
					error("Unknown Symbol; Build Log Objects with the RegisterLog function", 3)
				end

				if v[1] = LOG_FLAGS.ACTION or v[1] = LOG_FLAGS.HEADER then
					func(v[1], v[2])
				else
					func(v[1], arg)
				end

				index = 1 + index
			else
				error("Unknown Symbol")
			end
		end
	end

	local function ColourLog(obj, ...)
		local log = {}

		local function AddData(v)
			log[1 + #log] = v
		end

		LogBuilder(function (id, value)
			AddData(LOG_OBJECT_COLOURS[id])
			AddData(value)
		end, obj, ...)
	end

	local log_file_structure = {
		logs = {
			header = "",
			timestamp = 0,
			contents = {} // {[1] ID, [2] Value}
		},
		AddLog = function (self, header, timestamp, contents)
			self.logs[1 + #self.logs] = {
				header = header,
				timestamp = timestamp,
				contents = contents
			}
		end
	}

	local log_file_structure_methods = {}

	do // Structure Methods
		function log_file_structure_methods:Constructor()
		end

		function log_file_structure_methods:Read()
			local log_amount = net.ReadUInt(32)

			for i=1,log_amount do
				local header = net.ReadString()
				local timestamp = net.ReadUInt(32)
				local content_amount = net.ReadUInt(8)
				local contents = {}

				for j=1, content_amount do
					local id = net.ReadUInt(4)
					local value

					if id == LOG_FLAGS.DECIMAL then
						value = net.ReadFloat()
					else
						value = net.ReadString()
					end

					if id < LOG_FLAGS.BASE then
						value = {id, value}
					end

					contents[j] = value
				end

				log_file_structure[i] = {
					header = header,
					timestamp = timestamp,
					contents = contents
				}
			end
		end

		function log_file_structure_methods:Write()
			net.WriteUInt(#self.logs, 32) -- Amount of Logs

			for k,log in ipairs(self.logs) do
				net.WriteString(log.header)
				net.WriteUInt(log.timestamp, 32)
				net.WriteUInt(#log.contents, 8) -- Limits Logs to 255 separate objects inside the log

				for j,content in ipairs(log.contents) do
					if istable(content) then
						net.WriteUInt(content[1], 4)

						if content[1] == LOG_FLAGS.DECIMAL then
							net.WriteFloat(content[2])
						else
							net.WriteString(content[2])
						end
					else
						net.WriteUInt(LOG_FLAGS.BASE, 4)
						net.WriteString(content)
					end
				end
			end
		end
	end

	log_file_structure = Structure("LogCollection", log_file_structure, log_file_structure_methods)

	if SERVER then
		local log_folder_path = Config("LogFolder", "jaas/logs", function (value)
			local first = string.byte(string.Left(value, 1))

			if !((first >= 97 and first <= 122) or (first >= 48 and first <= 57)) then
				return false,"Invalid Directory Name"
			end

			local last = string.Right(value, 1)

			if last == "/" then
				return false,"Cannot end with '/'"
			end

			return true
		end)

		local function GetLogFiles()
			local found = file.Find(log_folder_path .. "/*.dat", "DATA", "dateasc")

			return found
		end

		local function GetLatestLogFile()
			if !file.Exists(log_folder_path) then
				file.CreateDir(log_folder_path)
			end

			local path = log_folder_path .. "/" .. os.date("%d-%m-%y") .. ".dat"

			if file.Exists(path, "DATA") then
				return file.Open(path, "a", "DATA")
			else
				return file.Open(path, "w", "DATA")
			end
		end

		local function WriteLog(header, obj, ...) // "%P has %*Connected%", ply {{1, ply}, " has ", {6, "Connected"}}
			local f = GetLatestLogFile()

			/*
				0x1A -> 32-bit -> string -> (0x1 -> string) | (0x2 -> string) | (0x3 -> string) | (0x4 -> string) | (0x5 -> string) | (0x6 -> string) | (0x7 -> string) | (0x8 -> Float) | (0x9 -> string) -> 0xA

				[0x1A] Log Header - Flag
				[0xA] Log End - Flag
				[0x1] Player - Flag
				[0x2] Command - Flag
				[0x3] Rank - Flag
				[0x4] Access Group - Flag
				[0x5] Permission - Flag
				[0x6] Action - Flag
				[0x7] String - Flag
				[0x8] Decimal - Flag
				[0x9] Base - Flag
			*/

			f:WriteByte(LOG_FLAGS.HEADER) -- Start Log
			f:WriteULong(os.time())
			f:WriteString(header)

			LogBuilder(function (id, value)
				f:WriteByte(id)

				if id == LOG_FLAGS.PLAYER then
					value = vale:SteamID64()
				elseif id == LOG_FLAGS.COMMAND or id == LOG_FLAGS.RANK or id == LOG_FLAGS.ACCESSGROUP or id == LOG_FLAGS.PERMISSION then
					value = value.Name
				end

				if id == LOG_FLAGS.DECIMAL then
					f:WriteFloat(value)
				else
					f:WriteString(value)
				end
			end, obj, ...)

			f:WriteByte(LOG_FLAGS.END)
		end

		local function ReadLog(file_name) // As "%d-%m-%y"; Same as the file names
			local path = log_folder_path .. "/" .. file_name .. ".dat"
			if !file.Exists(path) then
				return false, "Log File does not Exist"
			end

			local f = file.Open(path, "r", "lsv")
			local byte = f:ReadByte()

			local function NextChar()
				byte = f:ReadByte()
			end

			local lastToken
			local token

			local function NextToken()
				lastToken = token
				token = {id = 0, value = ""}

				if f:EndOfFile() then
					token.id = 99
					return
				elseif byte == LOG_FLAGS.HEADER then // Log Header
					token.id = LOG_FLAGS.HEADER

					local timestamp = f:ReadULong()
					local header = f:ReadString()

					token.value = {header, timestamp}
				elseif byte == LOG_FLAGS.END then // Log End
					token.id = LOG_FLAGS.END
				elseif byte == LOG_FLAGS.DECIMAL then
					token.id = LOG_FLAGS.DECIMAL
					token.value = f:ReadFloat()
				else
					if byte >= LOG_FLAGS.PLAYER and byte <= LOG_FLAGS.BASE then
						token.id = byte
					else
						token = {id = -1} // Instead of throwing error, return unknown Token to properly handle it
						NextChar()
						return
					end

					token.value = f:ReadString()
				end

				NextChar()
			end

			local has_corrupted = false
			local corrupted_logs = {}

			local function TokenAssert(expression, message, nextToken)
				expression = !expression

				if expression then
					has_corrupted = true
					corrupted_logs[1 + #corrupted_logs] {f:Tell(), message}

					if nextToken != nil then
						while token.id != nextToken and token.id != 99 do
							NextToken()
						end
					end
				end

				return expression
			end

			local log_collection = GetStructure("LogCollection")

			local function NextLog()
				local header,timestamp

				if TokenAssert(token.id == LOG_FLAGS.HEADER, "Expected Log Header", LOG_FLAGS.HEADER) then
					return false
				end

				header = token.value[1]
				timestamp = token.value[2]

				NextToken()

				local contents = {}

				local function AddContent(id, value)
					if id == LOG_FLAGS.BASE then
						contents[1 + #contents] = value
					else
						contents[1 + #contents] = {id, value}
					end
				end

				while true do
					if TokenAssert(token.id >= LOG_FLAGS.PLAYER and token.id <= LOG_FLAGS.END, "Expected Log Message Flags", LOG_FLAGS.HEADER) then
						if token.id == LOG_FLAGS.END then
							log_collection.AddLog(header, timestamp, contents)
							return true
						end

						AddContent(token.id, token.value)
					else
						break
					end
				end

				return false
			end

			while !f:EndOfFile() do
				NextLog()
			end

			return log_collection,has_corrupted,corrupted_logs
		end
	end

	AddPost("SERVER", function (accessor)
		local PermissionModule = accessor:GetModule("Permission")

		--TODO Create function to Receive Request for Logs
		--TODO Create function to Receive Request for Log File List
	end)

	AddPost("CLIENT", function (accessor)
		local PanelModule = accessor:GetModule("Panel")

		--TODO Create Client Panel to Render Logs
	end)

	log_module = Class("MODULE", log_module, function (self, name)
		self.Name = name
	end)
end

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


function JAAS.RegisterModule(name, alt)
	name = "JAAS__" + name

	module_collection[name] = module_module

	if alt == nil then
		return module_collection[name], log_module(alt), net_module(alt), sql_module(alt)
	else
		return module_collection[name], log_module(name), net_module(name), sql_module(name)
	end
end

local function ExecutePostModules()
	local a = {}

	function a:Exists(name)
		return module_collection[name] != nil
	end

	function a:GetModule(name)
		return setmetatable({}, {__index = module_collection[name]})
	end

	local accessor = setmetatable({}, {__index = a})

	for k,func in ipairs(shared_posts.SHARED) do
		func(accessor)
	end

	if SERVER then
		for k,func in ipairs(shared_posts.SERVER) do
			func(accessor)
		end
	elseif CLIENT then
		for k,func in ipairs(shared_posts.CLIENT) do
			func(accessor)
		end
	end

	for k,module in pairs(module_collection) do
		for k,Post in ipairs(module.Shared) do
			Post(accessor)
		end

		if SERVER then
			for k,Post in ipairs(module.Server) do
				Post(accessor)
			end
		elseif CLIENT then
			for k,Post in ipairs(module.Client) do
				Post(accessor)
			end
		end

		// Clear Shared Functions
		module.Shared = nil
		module.Server = nil
		module.Client = nil
	end
end

PushJAAS("Objects", Objects)
PushJAAS("Structures", Structures)
PushJAAS("RegisterModule", BaseModule)