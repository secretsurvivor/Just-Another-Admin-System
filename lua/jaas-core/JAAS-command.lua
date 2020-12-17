local MODULE, log, dev, SQL = JAAS:RegisterModule "Command"
SQL = SQL"JAAS_command"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {
        name = "TEXT NOT NULL",
        category = "TEXT NOT NULL",
        code = "UNSIGNED BIGINT NOT NULL DEFAULT 0",
        access_group = "UNSIGNED INT DEFAULT 0",
        "PRIMARY KEY(name, category)"
    }
    SQL.CREATE.INDEX "JAAS_command_primary" {name, category}
end

local argTable = {["add"]=true, ["dispense"]=true} -- Argument Table Builder, for command registering and user interface

local function typeMap(typ)
    local typeCase = dev.SwitchCase()
    typeCase:case("BOOL", 0x1)
    typeCase:case("INT", 0x2)
    typeCase:case("FLOAT", 0x3)
    typeCase:case("STRING", 0x4)
    typeCase:case("PLAYER", 0x5)
    typeCase:case("PLAYERS", 0x6)
    typeCase:case("RANK", 0x7)
    typeCase:case("RANKS", 0x8)
    typeCase:case("OPTION", 0x9)
    typeCase:case("OPTIONS", 0xA)
    typeCase:default(function ()
        error("Unknown Datatype", 2)
    end)
    return typeCase:switch(typ)
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
    if isstring(dataType) then
        dataType = typeMap(dataType)
    end
    if isstring(name) and isnumber(dataType) then
        if dataType == 0x9 or dataType == 0xA then
            local option_list = {}
            for k,v in ipairs(default) do
                option_list[v] = k
            end
            default = option_list
        end
        table.insert(self.internal, {name, dataType, required and true, default})
		return self
    end
end

function argTable.typeMap(typeStr)
    return typeMap(typeStr)
end

function argTable:dispense()
	local old = self.internal
	self.internal = {} -- {Name, Datatype, Required, Default} -- If OPTION or OPTIONS then {Name, Datatype, Required, {List_of_options}}
	return old
end

setmetatable(argTable, {
	__call = function(self)
		return setmetatable({internal = {}}, {__index = self, __metatable = "jaas_argumentbuilder"})
	end,
	__metatable = nil
})

dev:isTypeFunc("ArgumentBuilder", "jaas_argumentbuilder")

local command_table = command_table or {} -- SERVER -- [category][name] = {code, funcArgs, function, access} -- CLIENT -- [category][name] = {code, funcArgs, description}

local local_command = {["getName"] = true, ["getCategory"] = true, ["getCode"] = true, ["setCode"] = true} -- Used for local functions, for command data
local command = {["registerCommand"] = true, ["setCategory"] = true, ["clearCategory"] = true, ["argumentTableBuilder"] = true} -- Used for global functions, for command table

function command:setCategory(name)
    if isstring(name) then
        self.category = name
        return true
    end
end

function command:clearCategory()
    self.category = "default"
end

function command.argumentTableBuilder()
    return argTable()
end

if SERVER then
    function local_command:getName()
        return self.name
    end

    function local_command:getCategory()
        return self.category
    end

    function local_command:getCode()
        return command_table[self.category][self.name][1]
    end

    function local_command:getAccess()
        return command_table[self.category][self.name][4]
    end

    function local_command:setCode(code)
        local q = SQL.UPDATE {code = code} {name = self.name, category = self.category}
        if q then
            local before = command_table[self.category][self.name][1]
            command_table[self.category][self.name][1] = code
            JAAS.Hook.Run.Command(self.category)(self.name)(before, code)
            JAAS.Hook.Run "Command" "GlobalRankChange" (self.category, self.name, code)
        end
        return q
    end

    function local_command:xorCode(code)
        local before = command_table[self.category][self.name][1]
        local c_xor = bit.bxor(before, code)
        local q = SQL.UPDATE {code = c_xor} {name = self.name, category = self.category}
        if q then
            command_table[self.category][self.name][1] = c_xor
            JAAS.Hook.Run.Command(self.category)(self.name)(before, c_xor)
            JAAS.Hook.Run "Command" "GlobalRankChange" (self.category, self.name, c_xor)
        end
        return q
    end

    function local_command:setAccess(value)
        local q = SQL.UPDATE {access_group = value} {name = self.name, category = self.category}
        if q then
            command_table[self.category][self.name][4] = value
        end
        return q
    end

    function local_command:executeCommand(...)
        return command_table[self.category][self.name][3](...)
    end

    MODULE.Handle.Server(function (jaas)
        local access = jaas.AccessGroup()

        function local_command:accessCheck(code)
            if isnumber(code) then
                return access.codeCheck(access.COMMAND, self:getAccess(), code)
            elseif dev.isPlayerObject(code) then
                return access.codeCheck(access.COMMAND, self:getAccess(), code:getCode())
            elseif dev.isPlayer(code) then
                return access.codeCheck(access.COMMAND, self:getAccess(), code:getJAASCode())
            end
        end
    end)

    setmetatable(local_command, {
        __call = function(self, command_name, command_category)
            return setmetatable({name = command_name, category = command_category}, {__index = local_command})
        end,
        __newindex = function() end,
        __metatable = "jaas_command_object"
    })

    function command:registerCommand(name, func, funcArgs, description, code, access)
        local q = SQL.SELECT "code, access_group" {name = name, category = self.category}
        if q then
            code = tonumber(q["code"])
            access = tonumber(q["access_group"])
        end
        code = code or 0
        access = access or 0
        if !q then
            q = SQL.INSERT {name = name, category = self.category, code = code, access_group = access}
        end
        if q then
            if dev.isArgumentBuilder(funcArgs) then
                funcArgs = funcArgs:dispense()
            end
            funcArgs = funcArgs or {}
            if command_table[self.category] ~= nil then
                command_table[self.category][name] = {code, funcArgs, func, access}
            else
                command_table[self.category] = {[name]={code, funcArgs, func, access}}
            end
            return local_command(name, self.category)
        end
    end
elseif CLIENT then
    function command:registerCommand(name, func, funcArgs, description, code, access)
        if dev.isArgumentBuilder(funcArgs) then
            funcArgs = funcArgs:dispense()
        end
        funcArgs = funcArgs or {}
        description = description or ""
        if isstring(name) and istable(funcArgs) then
            if command_table[self.category] ~= nil then
                command_table[self.category][name] = {code, funcArgs, description}
            else
                command_table[self.category] = {[name]={code, funcArgs, description}}
            end
        end
    end

    local function getPlyFromNick(str)
        for _,ply in ipairs(player.GetAll()) do
            if string.find(ply:Nick(), str) then
                return ply
            end
        end
    end

    function command.executeCommand(category, name, argumentTable, t)
        net.Start("JAAS_ClientCommand")
        net.WriteString(category)
        net.WriteString(name)
        for i,v in ipairs(t) do
            local a = argumentTable[i][2]
            if a == 1 then -- Bool
                if isstring(v) then
                    v = v == "true"
                end
                net.WriteBool(v)
            elseif a == 2 then -- Int
                if isstring(v) then
                    v = tonumber(v)
                end
                net.WriteInt(v, 64)
            elseif a == 3 then -- Float
                if isstring(v) then
                    v = tonumber(v)
                end
                net.WriteFloat(v)
            elseif a == 4 then -- String
                net.WriteString(v)
            elseif a == 5 then -- Player
                if isstring(v) then
                    v = getPlyFromNick(v)
                end
                if IsValid(v) then
                    net.WriteEntity(v)
                end
            elseif a == 6 then -- Players
                if isstring(v) then
                    v = string.ToTable(v)
                end
                for i,p in ipairs(v) do
                    v[i] = getPlyFromNick(p)
                end
                net.WriteTable(v)
            elseif a == 7 then -- Rank
                net.WriteString(v)
            elseif a == 8 then -- Ranks
                if isstring(v) then
                    v = string.ToTable(v)
                end
                net.WriteTable(v)
            elseif a == 9 then -- Option
                if isstring(v) then
                    v = argumentTable[i][4][v] or 1
                end
                if isnumber(v) then
                    net.WriteInt(v, math.ceil(math.log(#argumentTable[i][4], 2)))
                end
            elseif a == 10 then -- Options
                if isstring(v) then
                    v = string.ToTable(v)
                end
                for k,va in ipairs(v) do
                    if isstring(va) then
                        v[k] = argumentTable[i][4][v] or 1
                    end
                end
                net.WriteTable(v)
            end
        end
        net.SendToServer()
    end
end

local RefreshClientCodes = dev.SharedSync("JAAS_CommandCodeSync", function (_, ply)
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
    return command_code_table
end, "JAAS_ClientCommand", function (_, ply, code_table)
    for category, c_table in pairs(code_table) do
        for name, code in pairs(c_table) do
            command_table[category][name][1] = code
        end
    end
end)

MODULE.Access(function (command_name, command_category)
    if SERVER and command_name and command_category then
        if command_table[category] ~= nil and command_table[category][name] ~= nil then
            return local_command(command_name, command_category)
        end
    else
        return setmetatable({category = "default"}, {__index = command, __newindex = function () end, __metatable = "jaas_command_library"})
    end
end)

dev:isTypeFunc("CommandObject","jaas_command_object")
dev:isTypeFunc("CommandLibrary","jaas_command_library")

MODULE.Handle.Server(function (jaas)
    local modify_command = jaas.Permission().registerPermission("Can Modify Commands", "Player will be able to change what command ranks have access to")

    util.AddNetworkString "JAAS_CommandModify_Channel"
    /* Command feedback codes :: 2 Bits
        0 :: Command Change was a success
        1 :: Code could not be changed
        2 :: Unknown Command identifier
        3 :: Not part of Access Group
    */
    local sendFeedback = dev.sendUInt("JAAS_CommandModify_Channel", 2)
    net.Receive("JAAS_CommandModify_Channel", function (len, ply)
        if modify_command:codeCheck(ply) then
            local category = net.ReadString()
            local name = net.ReadString()
            local code = net.ReadUInt(64)
            local cmd, sendCode = jaas.Command(name, category), sendFeedback(ply)
            if dev.isCommandObject(cmd) then
                if cmd:accessCheck(ply) then
                    if cmd:xorCode(code) then
                        sendCode(0)
                    else
                        sendCode(1)
                    end
                else
                    sendCode(3)
                end
            else
                sendCode(2)
            end
        end
    end)
end)

local function commandAutoComplete(cmd, args_str)
    local args = string.Explode(" ", string.Trim(args_str))
    local autocomplete = {}
    for category,t in pairs(command_table) do
        local a = string.match(category, args[1])
        if a then
            if (#args) == 2 or args[1] == category then
                for name,t in pairs(t) do
                    if args[2] and string.find(name, args[2]) then
                        if (#args) > 2 then -- cmd arguments
                            autocomplete = {}
                            local cmd_args = ""
                            for i=3, #args do
                                if i > 3 then
                                    cmd_args = cmd_args.." "..args[i-1]
                                end
                                local arg_type = t[2][i-2][2]
                                local autocompleteCase = dev.SwitchCase()
                                autocompleteCase:case(1, function () -- Bool
                                    table.insert(autocomplete, "JAAS "..category.." "..name..cmd_args.." true")
                                    table.insert(autocomplete, "JAAS "..category.." "..name..cmd_args.." false")
                                end)
                                autocompleteCase:case(5, function () -- Player
                                    for _,ply in ipairs(player.GetAll()) do
                                        if string.find(ply:Nick(), args[i]) then
                                            table.insert(autocomplete, "JAAS "..category.." "..name..cmd_args.." \""..ply:Nick().."\"")
                                            break
                                        else
                                            table.insert(autocomplete, "JAAS "..category.." "..name..cmd_args.." \""..ply:Nick().."\"")
                                        end
                                    end
                                end)
                                autocomplete:case(6, function () -- Players
                                end)
                                autocomplete:case(7, function () -- Rank
                                end)
                                autocomplete:case(8, function () -- Ranks
                                end)
                                autocomplete:case(9, function () -- Option
                                    for k,_ in pairs(t[2][i-2][4]) do
                                        table.insert(autocomplete, "JAAS "..category.." "..name..cmd_args.." "..k)
                                    end
                                end)
                                autocomplete:case(10, function () -- Options
                                end)
                                autocompleteCase:switch(arg_type)
                            end
                            break
                        else
                            table.insert(autocomplete, "JAAS "..category.." "..name)
                        end
                        break
                    else
                        table.insert(autocomplete, "JAAS "..category.." "..name)
                    end
                end
            else
                table.insert(autocomplete, "JAAS "..category)
            end
            break
        else
            table.insert(autocomplete, "JAAS "..category)
        end
    end
    return autocomplete
end

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
        if errorCode >= 4 then
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
            local playerData = JAAS.Player(ply) or 0
            if rankCode == 0 or bit.band(rankCode, playerData:getCode()) > 0 then -- Player has access to execute command
                local funcArgs, funcArgs_toBeExecuted = command_table[category][name][2], {}
                for i, arg in ipairs(funcArgs) do -- Read Function Arguments
                    local readArg
                    local readArgCase = dev.SwitchCase()
                    readArgCase:case(1, function ()
                        return net.ReadBool()
                    end)
                    readArgCase:case(2, function ()
                        return net.ReadInt(64)
                    end)
                    readArgCase:case(3, function ()
                        return net.ReadFloat()
                    end)
                    readArgCase:case(4, function ()
                        return net.ReadString()
                    end)
                    readArgCase:case(5, function ()
                        return net.ReadEntity()
                    end)
                    readArgCase:case(6, function ()
                        return net.ReadTable()
                    end)
                    readArgCase:case(7, function ()
                        local rank_name = net.ReadString()
                        return JAAS.Rank(rank_name)
                    end)
                    readArgCase:case(8, function ()
                        local rank_table = net.ReadTable()
                        local t = {}
                        for k,v in ipairs(rank_table) do
                            t[k] = JAAS.Rank(v)
                        end
                        return t
                    end)
                    readArgCase:case(9, function ()
                        return net.ReadInt(math.ceil(math.log(#arg[4], 2)))
                    end)
                    readArgCase:case(10, function ()
                        return net.ReadTable()
                    end)
                    readArgCase:default(arg[4])
                    readArg = readArgCase:switch(arg[2])
                    if !readArg and arg[3] then break end
                    table.insert(funcArgs_toBeExecuted, readArg)
                end
                if #funcArgs == #funcArgs_toBeExecuted then -- All checks complete, command can be executed
                    local a = command_table[category][name][3](ply, unpack(funcArgs_toBeExecuted))
                    if a then
                        returnCommandErrors(ply, 4, category, name, a) -- Function Feedback
                    else
                        returnCommandErrors(ply, 0, category, name) -- Executed Successfully
                    end
                else
                    returnCommandErrors(ply, 3, category, name) -- Invalid Argument
                end
            else
                returnCommandErrors(ply, 2, category, name) -- Player is not authorised
            end
        else
            returnCommandErrors(ply, 1, category, name) -- Category or name is invalid
        end
    end)

    local function argumentTypeToTypeFunction(num)
        if num == 1 then return isbool , tobool
        elseif num == 2 or num == 3 then return isnumber , tonumber
        elseif num == 4 or num == 5 then return isstring , tostring
        elseif num == 5 then return isentity, function (str)
                for _,ply in ipairs(player.GetAll()) do
                    if string.find(ply:Nick(),str) then
                        return ply
                    end
                end
            end
        elseif num == 6 then return istable , string.ToTable
        elseif num == 7 then return isstring, function (var)
                return JAAS.Rank(var)
            end
        end
    end

    local function typeFix(type_, var)
        local from,to = argumentTypeToTypeFunction(type_)
        if !from(var) then
            var = to(var)
        end
        return var
    end

    concommand.Add("JAAS", function (ply, cmd, args, argStr) -- Not updated
        local category, name = args[1], args[2]
        if command_table[category] ~= nil and command_table[category][name] ~= nil then
            if IsValid(ply) then
                local rankCode = command_table[category][name][1] or 0
                local playerData = JAAS.Player(ply) or 0
                if not bit.band(rankCode, playerData:getCode()) > 0 then
                    return
                end
            end
            local funcArgs, funcArgs_toBeExecuted = command_table[category][name][2], {}
            for i, arg in ipairs(funcArgs) do
                local value = typeFix(arg[2], args[i + 2])
                value = value or funcArgs[4]
                if !value and funcArgs[3] then
                    break
                end
                table.insert(funcArgs_toBeExecuted, value)
            end
            if #funcArgs == #funcArgs_toBeExecuted then
                local feedback = command_table[category][name][3](ply, unpack(funcArgs_toBeExecuted))
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
    end, commandAutoComplete)

    JAAS.Hook "Rank" "RemovePosition" ["Command_module"] = function (func)
        sql.Begin()
        for category, c_t in pairs(command_table) do
            for name, n_t in pairs(c_t) do
                local new_code = func(n_t[1])
                n_t[1] = new_code
                SQL.UPDATE {code = new_code} {name = name, category = category}
            end
        end
        sql.Commit()
        for _,ply in ipairs(player.GetAll()) do
            RefreshClientCodes(_,ply)
        end
    end

    JAAS.Hook "Command" "GlobalRankChange" ["ClientUpdate"] = function (category, name, code)
        for _,ply in ipairs(player.GetAll()) do
            net.Start("JAAS_ClientCommand")
            net.WriteTable({[category] = {[name] = code}})
            net.Send(ply)
        end
    end
elseif CLIENT then
    net.Receive("JAAS_ClientCommand", function()
        local code = net.ReadInt(4)
        local category, name, message = net.ReadString(), net.ReadString()
        if code == 4 then
            message = net.ReadString()
        end
        JAAS.Hook.run "Command" "CommandFeedback" (code, category, name, message)
    end)

    JAAS.Hook "Command" "CommandFeedback" ["ConsoleEcho"] = function(code, category, name, message)
        local logCase = dev.SwitchCase()
        logCase:case(0, function () -- Successful Command Execution
            log:printLog(category.." "..name.." Successfully Executed")
        end)
        logCase:case(1, function () -- Invalid Command Category or Name
            log:printLog(category.." "..name.." Unknown Category or Name")
        end)
        logCase:case(2, function () -- Invalid Player Access
            log:printLog(category.." "..name.." Invalid Access")
        end)
        logCase:case(3, function () -- Invalid Passed Argument
            log:printLog(category.." "..name.." Invalid Arguments")
        end)
        logCase:case(4, function () -- Function Feedback
            log:printLog(category.." "..name.." - "..message)
        end)
        logCase:default(function () -- Unknown Error Code
            log:printLog(category.." "..name.." Returned Unknown Error")
        end)
        logCase:switch(code)
    end

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
    end, commandAutoComplete)
end

concommand.Add("JAAS_printCommands", function ()
    PrintTable(command_table)
end)

log:printLog "Module Loaded"