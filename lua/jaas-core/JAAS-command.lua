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

local command_table = {} -- SERVER -- [category][name] = {code, function, funcArgs} -- CLIENT -- [category][name] = {code, funcArgs}

local command = {["registerCommand"] = true, ["setCategory"] = true, ["clearCategory"] = true, ["argumentTableBuilder"] = true} -- Used for global functions, for command table

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

if SERVER then
    local local_command = {["getName"] = true, ["getCategory"] = true, ["getCode"] = true, ["setCode"] = true} -- Used for local functions, for command data

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
        local a = dev.fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s' AND category='%s'", code, self.name, self.category) and nil
        if a then
            command_table[self.category][self.name][1] = code
        end
        return a
    end

    function local_command:xorCode(code)
        local a = dev.fQuery("UPDATE JAAS_command SET code=%u WHERE name='%s' AND category='%s'", c, self.name, self.category) and nil
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

    function command:registerCommand(name, func, funcArgs, code)
        local a = dev.fQuery("SELECT code FROM JAAS_command WHERE name='%s' AND category='%s'", name, self.category)
        if a then
            code = tonumber(a[1]["code"])
        else
            code = code or 0
        end
        if !a then
            a = dev.fQuery("INSERT INTO JAAS_command (name, category) VALUES ('%s', '%s')", name, self.category)
        end
        if a then
            funcArgs = funcArgs or {}
            if command_table[self.category] ~= nil then
                command_table[self.category][name] = {code, func, funcArgs}
                return local_command(name, self.category)
            else
                command_table[self.category] = {[name]={code, func, funcArgs}}
            end
        end
    end
elseif CLIENT then
    function command:registerCommand(name, func, funcArgs, code)
        funcArgs = funcArgs or {}
        if command_table[self.category] ~= nil then
            command_table[self.category][name] = {code, funcArgs}
        else
            command_table[self.category] = {[name]={code, funcArgs}}
        end
    end
    
    function command.executeCommand(category, name, argumentTable, t)
        if #argumentTable == #t then
            net.Start("JAAS_ClientCommand")
            net.WriteString(category)
            net.WriteString(name)
            for i,v in ipairs(t) do
                local a = argumentTable[i][2]
                if a == 1 then
                    net.WriteBool(v)
                elseif a == 2 then
                    net.WriteInt(v, 64)
                elseif a == 3 then
                    net.WriteFloat(v)
                elseif a == 4 then
                    net.WriteString(v)
                elseif a == 5 then
                    net.WriteString(v)
                elseif a == 6 then
                    net.WriteTable(v)
                end
            end
            net.SendToServer()
        end
    end
end

dev.sharedSync("JAAS_CommandCodeSync", function (_, ply)
    local command_code_table = {}
    for category, c_table in pairs(command_table) do
        for name, n_table in pairs(c_table) do
            if command_code_table[category] ~= nil then
                command_code_table[category][name] = n_table[1]
            else
                command_code_table[category] = {[name] = n_table[1]}
            end
        end
    end
    net.Start("JAAS_CommandCodeSync")
    net.WriteTable(command_code_table)
    net.Send(ply)
end, "JAAS_ClientCommand", function ()
    local code_table = net.ReadTable()
    for category, c_table in pairs(code_table) do
        for name, code in pairs(c_table) do
            command_table[category][name][1] = code
        end
    end
end)

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

if SERVER then
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
        net.WriteInt(errorCode, 4)
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
            if rankCode == 0 or bit.band(rankCode, playerData:getCode()) > 0 then -- Player has access to execute command
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
                    local a = command_table[category][name][2](ply, unpack(funcArgs_toBeExecuted))
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
                local feedback = command_table[category][name][2](ply, unpack(funcArgs_toBeExecuted))
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
elseif CLIENT then

    net.Receive("JAAS_ClientCommand", function()
        local code = net.ReadInt(4)
        local category, name, message = net.ReadString(), net.ReadString()
        if code == 4 then
            message = net.ReadString()
        end
        hook.Run("JAAS_CommandFeedback", code, category, name, message)
    end)

    hook.Add("JAAS_CommandFeedback", "JAAS_CommandFeedback_ConsoleEcho", function(code, category, name, message) -- ToDo Use Log Module
        if code == 0 then -- Successful Command Execution
            log:printLog(category.." "..name.." Successfully Executed")
        elseif code == 1 then -- Invalid Command Category or Name
            log:printLog(category.." "..name.." Unknown Category or Name")
        elseif code == 2 then -- Invalid Player Access
            log:printLog(category.." "..name.." Invalid Access")
        elseif code == 3 then -- Invalid Passed Argument
            log:printLog(category.." "..name.." Invalid Arguments")
        elseif code == 4 then -- Function Feedback
            log:printLog(category.." "..name.." - "..message)
        else -- Unknown Error Code
            log:printLog(category.." "..name.." Returned Unknown Error")
        end
    end)

    concommand.Add("JAAS", function(ply, cmd, args, argStr)
        local category, name = args[1], args[2]
        if command_table[category] ~= nil and command_table[category][name] ~= nil then
            local command_args = {}
            for i=3,#args do
                table.insert(command_args, args[i])
            end
            command.executeCommand(category, name, command_table[category][name][2], command_args)
        else
            print "Unknown Command"
        end
    end)
end

concommand.Add("JAAS_printCommands", function ()
    PrintTable(command_table)
end)

log:printLog "Module Loaded"