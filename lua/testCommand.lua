-- Serverside
if !sql.TableExists("JAAS_command") then
	sql.Query("CREATE TABLE JAAS_command(name TEXT, rank UNSIGNED BIG INT)")
end
local commandTable = {}
local command = {["add"]=true, ["exist"]=true, ["get"]=true, ["getAll"]=true}
local categ = {["Uncategorised"] = {}}
function command:add(name, func, argTable, code)
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
function command:setCategory(name)
	self.category = name
	categ[name] = {}
end
function command:clearCategory()
	self.category = "Uncategorised"
end
function command.printCategories()
	PrintTable(categ)
end
function command.exist(name)
	local test, err = pcall(function(name) local c = commandTable[name].name end, name)
	return not(err and true)
end
function command.get(name)
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

local argTable = {true, true}
local typeMap = {
	["BOOL"] = 1,
	["NUM"] = 2,
	["STRING"] = 3,
	["PLAYER"] = 4,
	["PLAYERS"] = 5
}
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
setmetatable(command, {
	__index = function() end,
	__newindex = function() end,
	__metatable = nil
})
JAASCommand = {}
setmetatable(JAASCommand, {
	__call = function(self)
		--ToDo: Add file use log
		local cmd = {}
		cmd.category = "Uncategorised"
		setmetatable(cmd, {__index = command})
		return cmd
	end,
	__newindex = function() end,
	__metatable = nil
})

concommand.Add("JAAS", function(ply, cmdStr, args, argStr)
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