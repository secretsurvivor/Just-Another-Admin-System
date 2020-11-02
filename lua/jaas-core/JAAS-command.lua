if JAAS.Command then return end
local dev = JAAS.Dev()
local log = JAAS.Log("Command")
if !sql.TableExists("JAAS_command") then
	dev.fQuery("CREATE TABLE JAAS_command(name TEXT NOT NULL, category TEXT NOT NULL, code UNSIGNED BIG INT NOT NULL DEFAULT 0, PRIMARY KEY (name, category))")
end

local argTable = {["add"]=true, ["dispense"]=true} -- Argument Table Builder, for command registering and user interface

local function typeMap(typ)
    if        typ == "BOOL" then return    1
    elseif     typ == "INT" then return    2
    elseif   typ == "FLOAT" then return    3
    elseif  typ == "STRING" then return    4
    elseif  typ == "PLAYER" then return    5
    elseif typ == "PLAYERS" then return    6
    end
end

/*
	This is the argument table used for adding commands so it can check arguments and data types
	before the command is executed. It works as any public class and is designed so that it can
	run in a single line. Once the table is dispensed, the internal table is reset.
	
	local cmd = JAAS.Command()
	local arg = cmd.argumentTableBuilder()
	
	arg:add("Player", "PLAYER"):dispense()
	arg:add("Num1", 2):add("Num2", 2):dispense()
*/
function argTable:add(name, dataType, required, default)
    if dev.dataTypeCheck("string", dataType) then
        dataType = typeMap(dataType)
    end
    if dev.dataTypeCheck("string", name, "number", dataType) then
        table.insert(self.internal, {name, dataType, required and true, default})
		return self
    end
end

function argTable:dispense()
	local old = self.internal
	self.internal = {} -- {Name, Datatype, Required, Default}
	return old
end

setmetatable(argTable, {
	__call = function(self)
		return setmetatable({internal = {}}, {__index = self})
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
    local a = dev.fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s', category='%s'", code, self.name, self.category) and nil
    if a then
        command_table[self.category][self.name][1] = code
    end
    return a
end

function local_command:xorCode(code)
    local a = dev.fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s', category='%s'", c, self.name, self.category) and nil
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
        return setmetatable({name = command_name, category = command_category}, {__index = local_command})
    end,
    __newindex = function() end,
	__metatable = nil
})

local command = {} -- Used for global functions, for command table

function command:registerCommand(name, func, funcArgs, code)
    local a = dev.fQuery("SELECT code FROM JAAS_command WHERE name='%s', category='%s'", name, self.category)
    if a then
        code = a[1]["code"]
    else
        code = code or 0
    end
    if command_table[category] ~= nil then
        command_table[self.category] = {[name]=true}
    end
    command_table[self.category][name] = {code, func, funcArgs}
    if !a then
        dev.fQuery("INSERT INTO JAAS_command (name, category) VALUES ('%s', '%s')", name, self.category)
    end
    return local_command(name, self.category)
end

function command:setCategory(name)
    if dev.dataTypeCheck("string", name) then
        self.category = name
    end
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
JAAS.Command = setmetatable({}, {
    __call = function(self, command_name, command_category)
		local f_str, id = log:executionTraceLog("Command")
        if !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
            log:removeTraceLog(id)
            return
        end
		if command_name and command_category then
            if command_table[category] ~= nil and command_table[category][name] ~= nil then
                return local_command(command_name, command_category)
            end
        else
            return setmetatable({category = "default"}, {__index = command, __newindex = function () end, __metatable = nil})
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
    if command_table[category] ~= nil and command_table[category][name] ~= nil then -- Command is valid
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
                elseif arg[2] == 4 or arg[2] == 5 then
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
                if a then returnCommandErrors(ply, 4, category, name, a) -- Function Feedback
                else returnCommandErrors(ply, 0, category, name) -- Executed Successfully
                end
            else returnCommandErrors(ply, 3, category, name) -- Invalid Argument
            end
        else returnCommandErrors(ply, 2, category, name) -- Player is not authorised
        end
    else  returnCommandErrors(ply, 1, category, name) -- Category or name is invalid
    end
end)

local function argumentTypeToTypeFunction(num)
    if num == 1 then return isbool , tobool
    elseif num == 2 or num == 3 then return isnumber , tonumber
    elseif num == 4 or num == 5 then return isstring , tostring
    elseif num == 6 then return istable , string.ToTable
    end
end

local function typeFix(type_, var)
    local from,to = argumentTypeToTypeFunction(type_)
    if !from(var) then
        var = to(var)
    end
    return var
end

concommand.Add("JAAS", function (ply, cmd, args, argStr)
    local category, name = args[1], args[2]
    if command_table[category] ~= nil and command_table[category][name] ~= nil then
        if IsValid(ply) then
            local rankCode = command_table[category][name][1] or 0
            local playerData = JAAS.player(ply:SteamID()) or 0
            if not bit.band(rankCode, playerData:getCode()) > 0 then
                return
            end
        end
        local funcArgs, funcArgs_toBeExecuted = command_table[category][name][3], {}
        for i, arg in ipairs(funcArgs) do
            local value = typeFix(arg[2], args[i + 2])
            value = value or funcArgs[4]
            if !value and funcArgs[3] then 
                break 
            end
            table.insert(funcArgs_toBeExecuted, value)
        end
        if #funcArgs == #funcArgs_toBeExecuted then
            local feedback = command_table[category][name][2](unpack(funcArgs_toBeExecuted))
            if feedback then
                if istable(feedback) then
                    PrintTable(feedback)
                else
                    print(feedback)
                end
            end
        end
    else
        Error("Command invalid\n") -- Replace with Log Module error
    end
end)

log:printLog "Module Loaded"