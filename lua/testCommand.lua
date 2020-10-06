-- Shared ToDo: Convert to serverside, add secruity
if !sql.TableExists("JAAS_command") then
	sql.Query("CREATE TABLE JAAS_command(name TEXT, rank UNSIGNED BIG INT)")
end
local commandTable = {}
local command = {["add"]=true, ["exist"]=true, ["get"]=true, ["getAll"]=true} -- Local function table, initialised with variables to avoid Hash Table resizing
local categ = {["Uncategorised"] = {}} -- Command categories

function command:add(name, func, argTable, code) -- Adds command to JAAS - Name of Command, Command Function, Argument Table, Command Rank Code
	local nullCheck = name and func
	argTable = argTable or {}
	code = code or 0
	local typeName, typeFunc = type(name) == "string", type(func) == "function"
	if nullCheck and (typeName and typeFunc) then
		--ToDo: SQL implementaion along with SQL check, add categories
		table.insert(categ[self.category], name)
		commandTable[name] = {name, func, argTable, code}
	elseif not nullCheck then
		error(string.format("addCommand cannot have null %s parameter", 
			!name and "name" or "func"), 2)
	elseif not(typeName and typeFunc) then
		local eror = !typeName and {"name","string"} or {"func","function"}
		error(string.format("Parameter %s must be a %s", eror[1], eror[2]), 2)
	end
end
function command:setCategory(name) -- Set current category that added commands will be assigned to
	self.category = name
	categ[name] = {}
end
function command:clearCategory() -- Set current category as default - "Uncategorised"
	self.category = "Uncategorised"
end
function command.printCategories()
	PrintTable(categ)
end
function command.exist(name) -- Checks if command exists in the table
	local test, err = pcall(function(name) local c = commandTable[name].name end, name)
	return not(err and true)
end
function command.get(name) -- Gets command data table
	--ToDo: Deep copy the results
	return commandTable[name]
end
function command.getAll()
	local copy = {} -- deep copy and as all the tables are pointers
	for k, v in next, commandTable, nil do
		local element = {["name"] = v["name"],["func"] = v["func"],["argTable"] = v["argTable"],["code"] = v["code"]}
		copy[k] = element
	end
	return copy
end

local argTable = {["add"]=true, ["dispense"]=true}
local typeMap = { -- For quick conversation between String and Int, possibly be replaced with local function to avoid allocating memory
	["BOOL"] = 1,
	["NUM"] = 2,
	["STRING"] = 3,
	["PLAYER"] = 4,
	["PLAYERS"] = 5
}
/*
	This is the argument table used for adding commands so it can check arguments and data types
	before the command is executed. It works as any public class and is designed so that it can
	run in a single parameter. Once the table is dispensed, the internal table is reset.
	
	local cmd = JAASCommand()
	local arg = cmd.ArgumentTable()
	
	arg:add("Player", "PLAYER"):dispense()
	arg:add("Num1", 2):add("Num2", 2):dispense()
*/
function argTable:add(name, dataType, required, default)
	if name and dataType then
		if type(dataType) == "string" then
			dataType = typeMap[dataType]
		end
		required = required and true
		if type(name) == "string" and type(dataType) == "number" then
			self.internal[name] = {dataType, required, default}
			return self
		else
		end
	else
	end
end
function argTable:dispense()
	local old = self.internal
	self.internal = {}
	return old
end
setmetatable(argTable, {
	__call = function(self)
		local o = {}
		o.internal = {}
		setmetatable(o, {__index = self})
		return o
	end,
	__metatable = nil
})
function command.ArgumentTable()
	return argTable()
end

-- Metatable stuff to force interaction with functions locally --
setmetatable(command, {
	__index = function() end,
	__newindex = function() end,
	__metatable = nil
})
JAASCommand = {}
setmetatable(JAASCommand, {
	__call = function(self)
		--ToDo: Add file trace
		local cmd = {}
		cmd.category = "Uncategorised"
		setmetatable(cmd, {__index = command})
		return cmd
	end,
	__newindex = function() end,
	__metatable = nil
})

concommand.Add("JAAS", function(ply, cmdStr, args, argStr) -- Garry's Mod Command that interacts with JAAS commands
	if command.exist(args[1]) then
		local cmdArgs = {}
		local cmdArgStr = ""
		for arg = 2, #args do
			cmdArgs[#cmdArgs + 1] = args[arg]
			cmdArgStr = cmdArgStr .. " " .. args[arg]
		end
		command.get(args[1]).func(ply, cmdArgs, cmdArgStr)
	else
		ErrorNoHalt(string.format("The command \"%s\" does not exist\n", args[1]))
	end
end)