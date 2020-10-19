if !sql.TableExists("JAAS_command") then
	fQuery("CREATE TABLE JAAS_command(name TEXT NOT NULL, category TEXT NOT NULL, code UNSIGNED BIG INT NOT NULL DEFAULT 0, PRIMARY KEY (name, category))")
end

local argTable = {["add"]=true, ["dispense"]=true} -- Argument Table Builder, for command registering and user interface

local function typeMap(typ)
    if typ == "BOOL" then
        return 1
    elseif typ = "NUM" then
        return 2
    elseif typ = "STRING" then
        return 3
    elseif typ = "PLAYER" then
        return 4
    elseif typ = "PLAYERS" then
        return 5
    end
end

/*
	This is the argument table used for adding commands so it can check arguments and data types
	before the command is executed. It works as any public class and is designed so that it can
	run in a single parameter. Once the table is dispensed, the internal table is reset.
	
	local cmd = JAAS.Command()
	local arg = cmd.argumentTableBuilder()
	
	arg:add("Player", "PLAYER"):dispense()
	arg:add("Num1", 2):add("Num2", 2):dispense()
*/
function argTable:add(name, dataType, required, default)
	if name and dataType then
		if type(dataType) == "string" then
			dataType = typeMap(dataType)
		end
		required = required and true
		if type(name) == "string" and type(dataType) == "number" then
            table.insert(self.internal, {name, dataType, required, default})
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

local command_table = {} -- [category][name] = {code, function, funcArgs}

local local_command = {} -- Used for local functions, for command data

function local_command:getName()
    return self.name
end

function local_command:getCategory()
    return self.category
end

function local_command:getCode()
    return command_table[self.category][self.name][1]
end

function local_command:setCode(code)
    command_table[self.category][self.name][1] = code
    return fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s', category='%s'", code, self.name, self.category)
end

function local_command:xorCode(code)
    local c = bit.bxor(command_table[self.category][self.name][1], code)
    command_table[self.category][self.name][1] = c
    return fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s', category='%s'", c, self.name, self.category)
end

function local_command:executeCommand(...)
    return command_table[self.category][self.name][2](...)
end

setmetatable(local_command, {
    __call = function(self, command_name, command_category)
        local command_object = {}
        command_object.name = command_name
        command_object.category = command_category
        setmetatable(command_object, {__index = local_command})
        return command_object
    end,
    __newindex = function() end,
	__metatable = nil
})

local command = {} -- Used for global functions, for command table

function command:registerCommand(name, func, funcArgs, code)
    local a = fQuery("SELECT code FROM JAAS_command WHERE name='%s', category='%s'", name, self.category)
    if a then
        code = a[1]["code"]
    else
        code = code or 0
    end
    local test, err = pcall(function(category) local c = command_table[category] end, category)
    if not(err and true) then
        command_table[self.category] = {[name]}
    end
    command_table[self.category][name] = {code, func, funcArgs}
    if !a then
        fQuery("INSERT INTO JAAS_command (name, category) VALUES ('%s', '%s')", name, self.category)
    end
    return local_command(name, self.category)
end

function command:setCategory(name)
    self.category = name
end

function command.clearCategory()
    self.category = "default"
end

function command.argumentTableBuilder()
    return argTable()
end

setmetatable(command, {
	__index = function() end,
	__newindex = function() end,
	__metatable = nil
})
JAAS.command = {}
setmetatable(JAAS.command, {
    __call = function(self, command_name, command_category)
		--ToDo: Add file trace
		if command_name and command_category then
            local test, err = pcall(function(category, name) local c = command_table[category][name] end, category, name)
            if not(err and true) then
                return local_command(command_name, command_category)
            end
        else
            local command_object = {}
            command_object.category = "default"
            setmetatable(command_object, {__index = command})
            return command_object
        end
	end,
	__newindex = function() end,
	__metatable = nil
})

print("JAAS Command Module Loaded")