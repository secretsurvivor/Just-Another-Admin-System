if !sql.TableExists("JAAS_command") then
	fQuery("CREATE TABLE JAAS_command(name TEXT NOT NULL, category TEXT NOT NULL, code UNSIGNED BIG INT NOT NULL DEFAULT 0, PRIMARY KEY (name, category))")
end

local argTable = {["add"]=true, ["dispense"]=true} -- Argument Table Builder, for command registering and user interface

local function typeMap(typ)
    if typ == "BOOL" then
        return 1
    elseif typ = "INT" then
        return 2
    elseif typ = "FLOAT" then
        return 3
    elseif typ = "STRING" then
        return 4
    elseif typ = "PLAYER" then
        return 5
    elseif typ = "PLAYERS" then
        return 6
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
	self.internal = {} -- {Name, Datatype, Required, Default}
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
    local a = fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s', category='%s'", code, self.name, self.category) and nil
    if a then
        command_table[self.category][self.name][1] = code
    end
    return a
end

function local_command:xorCode(code)
    local a = fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s', category='%s'", c, self.name, self.category) and nil
    if a then
        local c = bit.bxor(command_table[self.category][self.name][1], code)
        command_table[self.category][self.name][1] = c
    end
    return a
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

function command:clearCategory()
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

util.AddNetworkString "JAAS_ClientCommand"
/*
    #0 - Successfull Command Execution
    #1 - Invalid Command
    #2 - Invalid Player Access
    #3 - Invalid Argument 
    #4 - Function Feedback
*/
local function returnCommandErrors(ply, errorCode, category, name, message)
    net.Start("JAAS_ClientCommand")
    net.WriteInt(errorCode, 3)
    net.WriteString(category)
    net.WriteString(name)
    if errorCode == 4 then
        net.WriteString(message)
    end
    net.Send(ply)
end
/*
    Category : String
    Name : String
*/
net.Receive("JAAS_ClientCommand", function(_, ply)
    local category, name = net.ReadString(), net.ReadString()
    if pcall(function(cat, nam) local c = command_table[cat][nam] end, category, name) then -- Command is valid
        local rankCode = command_table[category][name][1] or 0
        local playerData = JAAS.player(ply:SteamID()) or 0
        if bit.band(rankCode, playerData:getCode()) > 0 then -- Player has access to execute command
            local funcArgs, funcArgs_toBeExecuted = command_table[category][name][3], {}
            for i, arg in ipairs(funcArgs) do -- Read Function Arguments
                local readArg
                if arg[2] == 1 then
                    readArg = net.ReadBool()
                elseif arg[2] == 2 then
                    readArg = net.ReadInt(64)
                elseif arg[2] == 3 then
                    readArg = net.ReadFloat()
                elseif arg[2] == 4 then
                    readArg = net.ReadString()
                elseif arg[2] == 5 then
                    readArg = net.ReadString()
                elseif arg[2] == 6 then
                    readArg = net.ReadTable()
                end
                readArg = readArg or funcArgs[4]
                if !readArg and funcArgs[3] then break end
                table.insert(funcArgs_toBeExecuted, readArg)
            end
            if #funcArgs == #funcArgs_toBeExecuted then -- All checks complete, command can be executed
                local a = command_table[category][name][2](unpack(funcArgs_toBeExecuted))
                if a then
                    returnCommandErrors(ply, 4, category, name, a)
                else
                    returnCommandErrors(ply, 0, category, name)
                end
            else
                returnCommandErrors(ply, 3, category, name)
            end
        else
            returnCommandErrors(ply, 2, category, name)
        end
    else
        returnCommandErrors(ply, 1, category, name)
    end
end)

print "JAAS Command Module Loaded"