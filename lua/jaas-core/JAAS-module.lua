local function readOnlyFunction()
    error("Class Cannot be modified", 2)
end

local function class(table, metatable, readonly, properties)
    if properties then
        if isstring(properties) then
            return setmetatable({}, {__call = function (self, p)
                local o = {}
                o[properties] = p
                if readonly then
                    return setmetatable(o, {__index = table, __newindex = readOnlyFunction, __metatable = metatable})
                else
                    return setmetatable(o, {__index = table, __newindex = table, __metatable = metatable})
                end
            end, __newindex = function () end, __index = table})
        elseif istable(properties) then
            return setmetatable({}, {__call = function (self, ...)
                local o,varArgs = {},{...}
                for k,v in ipairs(properties) do
                    if varArgs[k] then
                        o[v] = varArgs[k]
                    else
                        error("Class Initialisation missing property: " .. v, 2)
                    end
                end
                if readonly then
                    return setmetatable(o, {__index = table, __newindex = readOnlyFunction, __metatable = metatable})
                else
                    return setmetatable(o, {__index = table, __newindex = table, __metatable = metatable})
                end
            end, __newindex = function () end, __index = table})
        end
    else
        return setmetatable({}, {__call = function ()
            if readonly then
                return setmetatable({}, {__index = table, __newindex = readOnlyFunction, __metatable = metatable})
            else
                return setmetatable({}, {__index = table, __newindex = table, __metatable = metatable})
            end
        end, __newindex = function () end, __index = table})
    end
end

local delayedHandles = {}

local dev
do -- Developer Module Initialisation
    local query, format, type = sql.Query, string.format, type
    local ipairs, gmatch, net = ipairs, string.gmatch, net
    local devFunctions = {["fQuery"] = true, ["verifyFilepath"] = true, ["verifyFilepath_table"] = true, ["sharedSync"] = true, ["mergeSort"] = true}

    function devFunctions.fQuery(s, ...)
        if {...} == nil then
            return query(s)
        end
        return query(format(s, ...))
    end

    function devFunctions.VerifyFilepath(filepath, verify_str)
        -- Verify String example: addons/*/lua/jaas/*
        if filepath and verify_str then
            local filepath_func = gmatch(filepath, ".")
            local verify_func = gmatch(verify_str, ".")
            local count = 0
            local wild_card,verified,incorrect = false, false, false
            local f_c, v_c = filepath_func(), verify_func()
            while !verified and !incorrect do
                if wild_card then
                    if v_c == "*" then
                        v_c = verify_func()
                        count = 1 + count
                    end
                    if v_c == nil then
                        verified = true
                    end
                    if f_c == "/" then
                        wild_card = false
                        v_c = verify_func()
                        count = 1 + count
                    end
                    if count == (#verify_str) + 1 then
                        verified = true
                    end
                else
                    if f_c == v_c then
                    elseif v_c == "*" then
                        wild_card = true
                    else
                        incorrect = true
                    end
                    v_c = verify_func()
                    count = 1 + count
                end
                f_c = filepath_func()
                if f_c == nil then
                    incorrect = true
                end
            end
            return verified
        end
    end

    /*function devFunctions.verifyFilepath2(filepath, verify_pattern)
        if istable(verify_pattern) then
            for _,v in ipairs(verify_pattern)
                if filepath == string.match(filepath, v)
            end
            return false
        else
            return filepath == string.match(filepath, verify_pattern)
        end
    end*/

    function devFunctions.VerifyFilepath_table(filepath, verify_str_table)
        for _, v_str in ipairs(verify_str_table) do
            if verifyFilepath(filepath, v_str) then
                return true
            end
        end
        return false
    end

    if SERVER then -- SHARED -> dev.sharedSync(networkString, server_func, hook_identifier, client_func)
        function devFunctions.SharedSync(networkString, server_func)
            util.AddNetworkString(networkString)
            local receive_func = function (_, ply)
                local table_ = server_func(_, ply)
                if table_ then
                    net.Start(networkString)
                    net.WriteTable(table_)
                    net.Send(ply)
                end
            end
            net.Receive(networkString, receive_func)
            return receive_func
        end
    elseif CLIENT then
        function devFunctions.SharedSync(networkString, _, hook_identifier, client_func)
            net.Receive(networkString, function (_, ply)
                client_func(_, ply, net.ReadTable())
            end)
            hook.Add("InitPostEntity", hook_identifier, function ()
                net.Start(networkString)
                net.SendToServer()
            end)
        end
    end

    function devFunctions:Cache()
        return setmetatable({
            __internal = {},
            __dirty = true
        }, {__index = function (self, k)
            if rawget(self, "__dirty") then
                rawset(self, "__internal", {})
                rawset(self, "__dirty", false)
            end
            return rawget(self, "__internal")[k]
        end,
        __newindex = function (self, k, v)
            if rawget(self, "__dirty") then
                rawset(self, "__internal", {})
                rawset(self, "__dirty", false)
            end
            rawget(self, "__internal")[k] = v
        end,
        __call = function (self)
            rawset(self, __dirty, true)
        end})
    end

    local e,v = isentity,IsValid
    function devFunctions.isPlayer(v)
        return e(v) and v(v) and v:IsPlayer()
    end

    function devFunctions.isBot(v)
        return e(v) and v(v) and v:IsBot()
    end

    if SERVER then
        function devFunctions.sendString(networkString)
            return function (ply)
                return function (string)
                    net.Start(networkString)
                    net.WriteString(string)
                    net.Send(ply)
                end
            end
        end

        function devFunctions.sendUInt(networkString, bits)
            return function (ply)
                return function (code)
                    net.Start(networkString)
                    net.WriteUInt(code, bits)
                    net.Send(ply)
                end
            end
        end
    end

    function devFunctions.ReceiveTable(networkString)
        return function (func)
            if isfunction(func) then
                net.Receive(networkString, function (len, ply)
                    func(ply, net.ReadTable(), len)
                end)
            end
        end
    end

    function devFunctions.SwitchCase()
        local t = setmetatable({
            case = function (self, value, func)
                if isnumber(value) then
                    self.internal[1 + value] = func
                else
                    self.internal[value] = func
                end
            end,
            default = function (self, func)
                self.default = func
            end,
            switch = function (self, value)
                local r
                if isnumber(value) then
                    r = self.internal[1 + value]
                else
                    r = self.internal[value]
                end
                if r ~= nil then
                    if isfunction(r) then
                        return r()
                    else
                        return r
                    end
                else
                    if isfunction(self.default) then
                        return self.default()
                    else
                        return self.default
                    end
                end
            end
        },{})
        return setmetatable({default = function () end, internal = {}}, {__index = t})
    end

    function devFunctions.WhiteSpace(str)
        local str_func = gmatch(str, ".")
        local c,whitespace = str_func(),false
        local whitespaceCase = devFunctions.SwitchCase()
        whitespaceCase:case(" ", true)
        whitespaceCase:case("\t", true)
        whitespaceCase:case("\n", true)
        whitespaceCase:default(false)
        while c != nil and not whitespace do
            whitespace = whitespaceCase:switch(c)
            c = str_func()
        end
        return whitespace
    end

    function devFunctions:isTypeFunc(name, metatable)
        self["is" .. name] = function (v)
            return getmetatable(v) == metatable
        end
    end

    devFunctions:isTypeFunc("DevLibrary", "jaas_developer_library")
    devFunctions:isTypeFunc("LogLibrary", "jaas_log_library")
    devFunctions:isTypeFunc("SQLInterface", "jaas_sql_interface")
    devFunctions:isTypeFunc("HookRemoveLibrary", "jaas_hook_remove")
    devFunctions:isTypeFunc("HookRunLibrary", "jaas_hook_run")
    devFunctions:isTypeFunc("HookLibrary", "jaas_hook")
    devFunctions:isTypeFunc("GlobalVarLibrary", "jaas_globalvar")

    function math.PercentageDif(a, b)
        return (math.abs(a - b) / ((a + b) / 2)) * 100
    end

    local f = FindMetaTable "File"
    function f:ReadU64Int()
        return self:ReadULong() + bit.lshift(self:ReadULong(), 32)
    end

    function f:WriteU64Int(v)
        self:WriteULong(bit.band(v, 0xFFFF))
        self:WriteULong(bit.rshift(v, 32))
    end

    function f:Read64Int()
        return self:ReadLong() + bit.lshift(self:ReadLong(), 32)
    end

    function f:Write64Int(v)
        self:WriteLong(bit.band(v, 0xFFFF))
        self:WriteLong(bit.rshift(v, 32))
    end

    function net.ReadLong() -- Actual legnth of Long; 64 bits (8 bytes)
        return net.ReadInt(32) + bit.lshift(net.ReadInt(32), 32)
    end

    function net.WriteLong(v)
        net.WriteInt(bit.band(v, 0xFFFF), 32)
        net.WriteInt(bit.rshift(v, 32), 32)
    end

    function net.ReadULong()
        return net.ReadUInt(32) + bit.lshift(net.ReadUInt(32), 32)
    end

    function net.WriteULong(v)
        net.WriteUInt(bit.band(v, 0xFFFF), 32)
        net.WriteUInt(bit.rshift(v, 32), 32)
    end

    dev = class(devFunctions, "jaas_developer_library")
end

local log
do -- Log Module Initialisation
    local logFunctions = {["getLogFile"] = true, ["writeToLogFile"] = true, ["printLog"] = true, ["silentLog"] = true}

    function logFunctions:print(str) -- [JAAS::Rank] - Module Loaded
        print("[JAAS::"..self.label.."] - "..str)
    end

    delayedHandles.log = {}
    if SERVER then
        local registeredLogs = {} -- [Label][] = Log Display
        function logFunctions:registerLog(t) -- {1, was, 6, killed, by, 1, using, 3} {1, 6, added, 1, to, 2}
            /*
                Player - 1
                Rank - 2
                Entity - 3
                Data - 4
                String - 5
                Action - 6, action
            */
            if registeredLogs[self.label] then
                registeredLogs[self.label][1 + #registeredLogs[self.label]] = t
            else
                registeredLogs[self.label] = {t}
            end
            return #registeredLogs[self.label]
        end

        function logFunctions.IGetLogToken(date) -- 05-09-1999
            if istable(date) then
                date = date.day.."-"..date.month.."-"..date.year
            elseif isnumber(date) then -- Unix Epoch
                date = ox.date("%d-%m-%Y", date)
            end
            local f = file.Open("jslogs/"..date..".dat", "rb", "DATA")
            /* type [Usage] - Opcode - Description
                Record O - 0x1 - Open block
                Record C - 0xA - Close block
                Timestamp O - 0x2 - Unix epoch ULong
                Label O - 0x3 - String
                    Type O - 0x4 - UShort > 0
                Rank* O/C - 0x5 - String
                Player* O/C - 0x6 - ULong ULong (SteamID64)
                Entity* O/C - 0x7 - String
                Data* O/C - 0x8 - Float
                String* O/C - 0x9 - String
                Seperator - 0x0
            */
            local function readToken()
                local byte,value = f:ReadByte()
                if byte == 0x1 then -- Open Record
                    return 0x1,nil
                elseif byte == 0xA then -- Close Record
                    return 0xA,nil
                elseif byte == 0x2 then -- Timestamp
                    return 0x2,f:ReadULong()
                elseif byte == 0x3 then -- Label
                    return 0x3,f:ReadString()
                elseif byte == 0x4 then -- Type
                    return 0x4,f:ReadUShort()
                elseif byte == 0x5 then -- Rank
                    byte,value = f:ReadByte(),{}
                    while byte != 0x5 do
                        if byte == 0x0 then
                            value[1 + #value] = ""
                        else
                            value[#value] = f:ReadString()
                        end
                        byte = f:ReadByte()
                    end
                    return 0x5,value
                elseif byte == 0x6 then -- Player
                    byte,value = f:ReadByte(),{}
                    while byte != 0x6 do
                        if byte == 0x0 then
                            if !istable(value) then
                                value = {value}
                            end
                        end
                        value[1 + #value] = f:Read64Int()
                        byte = f:ReadByte()
                    end
                    return 0x6,value
                elseif byte == 0x7 then -- Entity
                    byte,value = f:ReadByte(),{}
                    while byte != 0x7 do
                        if byte == 0x0 then
                            value[1 + #value] = ""
                        else
                            value[#value] = f:ReadString()
                        end
                        byte = f:ReadByte()
                    end
                    return 0x7,value
                elseif byte == 0x8 then -- Data
                    byte,value = f:ReadByte(),{}
                    while byte != 0x8 do
                        if byte == 0x0 then
                            if !istable(value) then
                                value = {value}
                            end
                        end
                        if istable(value) then
                            value[1 + #value] = f:ReadFloat()
                        else
                            value = f:ReadFloat()
                        end
                        byte = f:ReadByte()
                    end
                    return 0x8,value
                elseif byte == 0x9 then -- String
                    byte,value = f:ReadByte(),{}
                    while byte != 0x9 do
                        if byte == 0x0 then
                            value[1 + #value] = ""
                        else
                            value[#value] = f:ReadString()
                        end
                        byte = f:ReadByte()
                    end
                    return 0x9,value
                elseif f:EndOfFile() then -- End of File
                    return nil
                end
            end
            return function () -- Iterator
                return readToken()
            end
        end

        net.Receive("JAAS_RequestLogClient", function (_, ply)
            net.Start("JAAS_RequestLogClient")
            for byte,value in logFunctions.IGetLogToken(date) do
                net.WriteUInt(byte, 8)
                if byte == 0x1 or byte == 0xA then
                elseif byte == 0x2 then
                    net.WriteUInt(value, 32)
                elseif byte == 0x3 then
                    net.WriteString(value)
                elseif byte == 0x4 then
                    net.WriteUInt(value, 16)
                elseif byte == 0x5 or byte == 0x7 or byte == 0x9 then
                    net.WriteUInt(#value, 8)
                    for k,v in ipairs(value) do
                        net.WriteString(v)
                    end
                elseif byte == 0x6 then
                    net.WriteUInt(#value, 8)
                    for k,v in ipairs(value) do
                        net.WriteULong(v)
                    end
                elseif byte == 0x8 then
                    net.WriteUInt(#value, 8)
                    for k,v in ipairs(value) do
                        net.WriteFloat(v)
                    end
                end
            end
            net.Send(ply)
        end)

        function logFunctions:Log(type_, t) -- {rank=, player=, entity=, data=, string=}
            if !(self.label and type_ > 0) then return end
            if t.rank then
                for k,v in ipairs(t.rank) do
                    if !isstring(v) then
                        error("Rank inputs must be strings", 2)
                    end
                end
            end
            if t.player then
                for i=1,#t.player do
                    if IsPlayer(t.player[i]) then
                        t.player[i] = t.player[i]:SteamID64()
                    end
                    if !isnumber(t.player[i]) then
                        error("Player inputs must be player entity or numbers", 2)
                    end
                end
            end
            if t.entity then
                for i=1,#t.entity do
                    if isentity(t.entity[i]) then
                        t.entity[i] = t.entity[i]:GetName()
                    end
                    if !isstring(t.entity[i]) do
                        error("Entity inputs must be strings", 2)
                    end
                end
            end
            if t.data then
                for k,v in ipairs(t.data) do
                    if !isnumber(v) then
                        error("Data inputs must be numbers", 2)
                    end
                end
            end
            if t.string then
                for k,v in ipairs(t.string) do
                    if !isstring(v) then
                        error("String inputs must be strings", 2)
                    end
                end
            end
            local f
            if file.Exists(os.date("jslogs/%d-%m-%Y.dat"), "DATA") then
                f = file.Open(os.date("jslogs/%d-%m-%Y.dat"), "ab", "DATA")
            else
                f = file.Open(os.date("jslogs/%d-%m-%Y.dat"), "wb", "DATA")
            end
            f:WriteByte(0x1) -- Open Record
            f:WriteByte(0x2) f:WriteULong(os.time()) -- Timestamp
            f:WriteByte(0x3) f:WriteString(self.label) -- Label
            f:WriteByte(0x4) f:WriteUShort(type_) -- Type
            if t.rank then
                f:WriteByte(0x5) -- Open
                    if istable(t.rank) then
                        if #t.rank > 1 then
                            for i=1,#t.rank - 1 do
                                f:WriteString(t.rank[i])
                                f:WriteByte(0x0)
                            end
                            f:WriteString(t.rank[#t.rank])
                        else
                            f:WriteString(t.rank[1])
                        end
                    else
                        f:WriteString(t.rank)
                    end
                f:WriteByte(0x5) -- Close
            end
            if t.player then
                f:WriteByte(0x6) -- Open
                    if istable(t.player) then
                        if #t.player > 1 then
                            for i=1,#t.player - 1 do
                                f:WriteU64Int(t.player[i])
                                f:WriteByte(0x0)
                            end
                            f:WriteU64Int(t.player[#t.player])
                        else
                            f:WriteU64Int(t.player[1])
                        end
                    else
                        f:WriteU64Int(t.player)
                    end
                f:WriteByte(0x6) -- Close
            end
            if t.entity then
                f:WriteByte(0x7) -- Open
                    if istable(t.entity) then
                        if #t.entity > 1 then
                            for i=1,#t.entity - 1 do
                                f:WriteString(t.entity[i])
                                f:WriteByte(0x0)
                            end
                            f:WriteString(t.entity[#t.entity])
                        else
                            f:WriteString(t.entity[1])
                        end
                    else
                        f:WriteString(t.entity)
                    end
                f:WriteByte(0x7) -- Close
            end
            if t.data then
                f:WriteByte(0x8) -- Open
                    if istable(t.data) then
                        if #t.data > 1 then
                            for i=1,#t.data - 1 do
                                f:WriteFloat(t.data[i])
                                f:WriteByte(0x0)
                            end
                            f:WriteFloat(t.data[#t.data])
                        else
                            f:WriteFloat(t.data[1])
                        end
                    else
                        f:WriteFloat(t.data)
                    end
                f:WriteByte(0x8) -- Close
            end
            if t.string then
                f:WriteByte(0x9) -- Open
                    if istable(t.string) then
                        if #t.string > 1 then
                            for i=1,#t.string - 1 do
                                f:WriteString(t.string[i])
                                f:WriteByte(0x0)
                            end
                            f:WriteString(t.string[#t.string])
                        else
                            f:WriteString(t.string[1])
                        end
                    else
                        f:WriteString(t.string)
                    end
                f:WriteByte(0x9) -- Close
            end
            f:WriteByte(0xA) -- Close Record
        end

        function logFunctions:chat(str) -- [JAAS] - secret_survivor added to Superadmin
            PrintMessage(HUD_PRINTTALK, "[JAAS] - "..str)
        end

        function logFunctions:adminChat(str)
            for k,v in ipairs(player.GetAll()) do
                if v:IsAdmin() then
                    v:PrintMessage(HUD_PRINTTALK, "[JAAS] - "..str)
                end
            end
        end

        function logFunctions:superadminChat(str)
            for k,v in ipairs(player.GetAll()) do
                if v:IsSuperAdmin() then
                    v:PrintMessage(HUD_PRINTTALK, "[JAAS] - "..str)
                end
            end
        end
    else
        local logs = {}

        local function ILog(date, func)
            if logs[date] then
                func(function ()
                    local i,x = 1
                    return function ()
                        x = logs[date][i]
                        if x then
                            i = 1 + i
                            return x[1],x[2]
                        end
                    end
                end)
            else
                net.Start("JAAS_RequestLogClient") net.SendToServer()
                logs[date] = func
            end
        end

        net.Receive("JAAS_RequestLogClient", function ()
            local date,func = net.ReadString()
            if logs[date] and isfunction(logs[date]) then
                func = logs[date]
            end
            logs[date] = {}
            local byte,value,length
            while net.BytesLeft() > 0 do
                byte = net.ReadInt(8)
                if byte == 0x1 or byte == 0xA then
                    value = nil
                elseif byte == 0x2 then
                    value = net.ReadUInt(32)
                elseif byte == 0x3 then
                    value = net.ReadString()
                elseif byte == 0x4 then
                    value = net.ReadUInt(16)
                elseif byte == 0x5 or byte == 0x7 or byte == 0x9 then
                    length = net.ReadUInt(8)
                    value = {}
                    for i=1,length do
                        value[i] = net.ReadString()
                    end
                elseif byte == 0x6 then
                    length = net.ReadUInt(8)
                    value = {}
                    for i=1,length do
                        value[i] = net.ReadULong()
                    end
                elseif byte == 0x8 then
                    length = net.ReadUInt(8)
                    value = {}
                    for i=1,length do
                        value[i] = net.ReadFloat()
                    end
                end
                logs[date][1 + #logs[date]] = {byte,value}
            end
            if func then
                ILog(date, func)
            end
        end)

        delayedHandles.log.client = {function (jaas)
            local CONTROL = jaas.Panel().ControlBuilder "RichText" ("JLogReader", "Dedicated to reading and filtering JAAS Logs")
            CONTROL:AccessorTableFunc "Module" -- Named Label in code
            CONTROL:AccessorTableFunc "Player"
            CONTROL:AccessorTableFunc "Rank"
            CONTROL:AccessorTableFunc "Action"
            CONTROL:AccessorFunc "Filter"
            CONTROL:AccessorFunc "Date"

            function CONTROL:Init()--[[
                self:SetModule({})
                self:SetPlayer({})
                self:SetRank({})
                self:SetAction({}) ]]
                self:SetFilter({})
            end

            function CONTROL:AddLog(t) -- {timestamp=, label=, entity=, player=, rank=, tool=, data=, string=}
                if t.type then
                    self:InsertColorChange(237, 125, 49, 255)
                    self:AppendText(os.date("[%H:%M]", t.timestamp))
                    self:InsertColorChange(112, 173, 71, 255)
                    self:AppendText(t.label.." ")
                    local p,r,d,to,s = 1,1,1,1,1
                    local func = t.type
                    local _,v = func()
                    while v != nil do
                        if isnumber(v) then
                            if v == 1 then -- Player
                                v = player.GetBySteamID64(t.player[p])
                                if v then
                                    self:InsertColorChange(91, 155, 213, 255)
                                    self:AppendText(v:Nick().." ")
                                    p = 1 + p
                                end
                            elseif v == 2 then -- Rank
                                self:InsertColorChange(112, 48, 160, 255)
                                self:AppendText("["..t.rank[r].."] ")
                                r = 1 + r
                            elseif v == 3 then -- Entity
                                self:InsertColorChange(255, 217, 102, 255)
                                self:AppendText(t.entity[to].." ")
                                to = 1 + to
                            elseif v == 4 then -- Data
                                self:InsertColorChange(173, 79, 15, 255)
                                self:AppendText(t.data[d].." ")
                                d = 1 + d
                            elseif v == 5 then -- String
                                self:InsertColorChange(173, 79, 15, 255)
                                self:AppendText("“"..t.string[s].."” ")
                                s = 1 + s
                            elseif v == 6 then -- Action
                                _,v = func()
                                self:InsertColorChange(192, 0, 0, 255)
                                self:AppendText(v.." ")
                            end
                        else
                            self:InsertColorChange(0, 0, 0, 255)
                            self:AppendText(v.." ")
                        end
                        _,v = func()
                    end
                    self:AppendText("\n")
                end
            end

            function CONTROL:SetDate(date)
                self.___Date = date
                ILog(self:GetDate(), function (iterator)
                    for t,v in iterator() do
                        if t == 0x3 then -- Label
                            self:AppendModule(v)
                        elseif t == 0x4 then -- Type
                            self:AppendAction(v)
                        elseif t == 0x5 then -- Rank
                            for k,v in ipairs(v) do
                                self:AppendRank(v)
                            end
                        elseif t == 0x6 then -- Player
                            for k,v in ipairs(v) do
                                self:AppendPlayer(player.GetBySteamID64(v))
                            end
                        end
                    end
                end)

            end

            function CONTROL:SetFilter(type, v)
                if type == "module" or type == "action" or type == "rank" or type == "player" then
                    self.___Filter[type] = v
                end
            end

            function CONTROL:Display()
                local record,filtered = {},#self:GetFilter() == 0
                ILog(self:GetDate(), function (iterator)
                    for t,v in ILog(self:GetDate()) do
                        if t == 0x1 then -- Open Record
                            record = {}
                        elseif t == 0xA then -- Close Record
                            if filtered then
                                self:AddLog(record)
                            end
                        elseif t == 0x2 then -- Timestamp
                            record.timestamp = v
                        elseif t == 0x3 then -- Label
                            if !filtered then
                                filtered = self:GetFilter().module == v
                            end
                            record.label = v
                        elseif t == 0x4 and record.label then -- Type
                            if v < 1 then
                                v = 1
                            end
                            if !filtered then
                                local func = ipairs(registeredLogs[record.label][v])
                                local _,i = func()
                                while i != nil do
                                    if i == 6 then
                                        _,i = func()
                                        if i == self:GetFilter().action then
                                            filtered = true
                                            break
                                        end
                                    end
                                    _,i = func()
                                end
                            end
                            record.type = registeredLogs[record.label][v]
                        elseif t == 0x5 then -- Rank
                            if !filtered then
                                if istable(v) then
                                    for k,v in ipairs(v) do
                                        if self:GetFilter().rank == v then
                                            filtered = true
                                            break
                                        end
                                    end
                                else
                                    filtered = self:GetFilter().rank == v
                                end
                            end
                            record.rank = v
                        elseif t == 0x6 then -- Player
                            if !filtered then
                                if istable(v) then
                                    for k,v in ipairs(v) do
                                        if self:GetFilter().player == v then
                                            filtered = true
                                            break
                                        end
                                    end
                                else
                                    filtered = self:GetFilter().player == v
                                end
                            end
                            record.player = v
                        elseif t == 0x7 then -- Entity
                            record.entity = v
                        elseif t == 0x8 then -- Data
                            record.data = v
                        elseif t == 0x9 then -- String
                            record.string = v
                        end
                    end
                end)
            end
        end}
    end

    local executionTrace = executionTrace or {} -- [label][id] = {file path, line}
    local refusedTrace = refusedTrace or {} -- [label] = {id*}

    function logFunctions:executionTraceLog(offset)
        if !JAAS.Var.TraceExecution then
            return
        end
        offset = offset or 0
        local info = debug.getinfo(3 + (offset or 0))
        if executionTrace[self.label] ~= nil then
            for _,v in ipairs(executionTrace[self.label]) do
                if v[1] == filepath and v[2] == line then
                    return
                end
            end
            executionTrace[self.label][1 + #executionTrace[self.label]] = {info.short_src, info.currentline}
        else
            executionTrace[self.label] = {{info.short_src, info.currentline}}
        end
        return info.short_src, #executionTrace[self.label] -- file path, id
    end

    function logFunctions:removeTraceLog(id)
        if !JAAS.Var.ExecutionRefusal then
            return false
        end
        if refusedTrace[self.label] ~= nil then
            for _,v in ipairs(refusedTrace[self.label]) do
                if v == id then
                    return
                end
            end
            refusedTrace[self.label][1 + #refusedTrace[self.label]] = id
        else
            refusedTrace[self.label] = {id}
        end
        return true
    end

    concommand.Add("JAAS_readTraceLogs", function ()
        PrintTable(executionTrace)
    end)

    log = class(logFunctions, "jaas_log_library", false, "label")
end

local SQL
do
    local q,isS,isT,pairs,isnumber,isstring,t = sql.Query,isstring,istable,pairs,isnumber,isstring,table
    local QUERY,db
    if JAAS.Var.MySQLServer then -- MySQL Functions not tested, may not work in this current version
        require("mysqloo")
        do
            local info = JAAS.Var.MySQLServerInformation
            db = mysqloo.connect(info.host, info.username, info.password, info.database)
        end
        db.onConnected = function ()
            print("MySQL Database Connected")
        end
        db.onConnectionFailed = function (db, err)
            ErrorNoHalt("JAAS MySQL Connection Failed - Reverting back to SQLite\n" .. err)
            QUERY = function (str)
                local r = q(str)
                if r and #r == 1 then
                    return r[1]
                end
                return r
            end
        end
        hook.Add("Initialize", "JAAS_MySQLServerConnect", function ()
            db:connect()
        end)
        QUERY = function (str)
            local c = coroutine.create(function ()
                local q = db:query(str)
                q.onSuccess = function (q, data)
                    coroutine.yield(data)
                end
                q.onError = function ()
                    coroutine.yield(false)
                end
                q:start()
                coroutine.yield()
            end)
            coroutine.resume(c)
            local r = coroutine.resume(c)
            if r and #r == 1 then
                return r[1]
            end
            return r
        end
    else
        QUERY = function (str)
            local r = q(str)
            if r and #r == 1 then
                return r[1]
            end
            return r
        end
    end
    local function table_to_str(t)
        local q, first = "", true
        for k,v in pairs(t) do
            if isnumber(v) then
                if first then
                    q = q .. k .. "=" .. v
                    first = false
                else
                    q = q .. "," .. k .. "=" .. v
                end
            elseif isstring(v) then
                if first then
                    q = q .. k .. "=" .. "'" .. v .. "'"
                    first = false
                else
                    q = q .. "," .. k .. "=" .. "'" .. v .. "'"
                end
            end
        end
        return q
    end
    local function table_to_WHERE(t)
        local q, first = "", true
        for k,v in pairs(t) do
            if isnumber(v) then
                if first then
                    q = q .. k .. "=" .. v
                    first = false
                else
                    q = q .. " AND " .. k .. "=" .. v
                end
            elseif isstring(v) then
                if first then
                    q = q .. k .. "=" .. "'" .. v .. "'"
                    first = false
                else
                    q = q .. " AND " .. k .. "=" .. "'" .. v .. "'"
                end
            end
        end
        return q
    end
    local function isstring(v) return v and isS(v) end
    local function istable(v) return v and isT(v) end
    SQL = function (sql_table)
        return setmetatable({
            EXISTS = JAAS.Var.MySQLServer and QUERY("select * from information_schema.tables where table_name='".. sql_table .."'") or sql.TableExists(table),
            CREATE = setmetatable({
                TABLE = function (columns)
                    if isstring(columns) then
                        return QUERY("CREATE TABLE " .. sql_table .. " (" .. columns .. ")") == nil
                    elseif istable(columns) then
                        local q,eq,first = "","",true
                        for k,v in pairs(columns) do
                            if isstring(k) then
                                if first then
                                    q = q .. k .. " " .. v
                                    first = false
                                else
                                    q = q .. "," .. k .. " " .. v
                                end
                            else
                                eq = eq .. "," .. v
                            end
                        end
                        return QUERY("CREATE TABLE " .. sql_table .. " (" .. q .. eq .. ")") == nil
                    end
                end,
                INDEX = function (index_name)
                    return function (columns)
                        if isstring(columns) then
                            return QUERY("CREATE INDEX " .. index_name .. " ON " .. sql_table .. " (" .. columns .. ")") == nil
                        elseif istable(columns) then
                            return QUERY("CREATE INDEX " .. index_name .. " ON " .. sql_table .. " (" .. t.concat(columns, ",") .. ")") == nil
                        end
                    end
                end
            }, {__call = function (self, str)
                return QUERY("CREATE " .. str)
            end}),
            SELECT = function (column)
                if column then
                    if istable(column) then
                        column = t.concat(column, ",")
                    end
                    return function (where)
                        if isstring(where) then
                            return QUERY("SELECT " .. column .. " FROM " .. sql_table .. " WHERE " .. where)
                        elseif istable(where) then
                            return QUERY("SELECT " .. column .. " FROM " .. sql_table .. " WHERE " .. table_to_WHERE(where))
                        else
                            return QUERY("SELECT " .. column .. " FROM " .. sql_table)
                        end
                    end
                else
                    QUERY("SELECT * FROM " .. sql_table)
                end
            end,
            UPDATE = function (set)
                if istable(set) then
                    set = table_to_str(set)
                end
                return function (where)
                    if isstring(where) then
                        return QUERY("UPDATE " .. sql_table .. " SET " .. set .. " WHERE " .. where) == nil
                    elseif istable(where) then
                        return QUERY("UPDATE " .. sql_table .. " SET " .. set .. " WHERE " .. table_to_WHERE(where)) == nil
                    else
                        return QUERY("UPDATE " .. sql_table .. " SET " .. set) == nil
                    end
                end
            end,
            INSERT = function (set)
                if isstring(set) then
                    return function (values)
                        return QUERY("INSERT INTO " .. sql_table .. "(" .. set .. ") VALUES (" .. values .. ")") == nil
                    end
                elseif istable(set) then
                    local cat,val,first_c,first_v = "","",true,true
                    for k,v in pairs(set) do
                        if first_c then
                            cat = cat .. k
                            first_c = false
                        else
                            cat = cat .. "," .. k
                        end
                        if isstring(v) then
                            if first_v then
                                val = val .. "'" .. v .. "'"
                                first_v = false
                            else
                                val = val .. ",'" .. v .. "'"
                            end
                        else
                            if first_v then
                                val = val .. v
                                first_v = false
                            else
                                val = val .. "," .. v
                            end
                        end
                    end
                    return QUERY("INSERT INTO " .. sql_table .. "(" .. cat .. ") VALUES (" .. val .. ")") == nil
                end
            end,
            DELETE = function (where)
                if isstring(where) then
                    return QUERY("DELETE FROM " .. sql_table .. " WHERE " .. where) == nil
                elseif istable(where) then
                    return QUERY("DELETE FROM " .. sql_table .. " WHERE " .. table_to_WHERE(where)) == nil
                else
                    return QUERY("DELETE FROM " .. sql_table) == nil
                end
            end,
            DROP = {
                TABLE = function ()
                    return QUERY("DROP TABLE " .. sql_table) == nil
                end,
                INDEX = function (name)
                    return QUERY("DROP INDEX " .. name) == nil
                end
            },
            ESCAPE = sql.SQLStr
        }, {__call = function (self, str)
            return QUERY(str)
        end, __metatable = "jaas_sql_interface"})
    end

    /*   TEST 1
        Module SQL:     0.0030246275247499
        fQuery SQL:     0.0038082836274652
        Module SQL is   0.0007836561027153 seconds faster and 22.9% faster
         TEST 2
        Module SQL:     0.0038284250674659
        fQuery SQL:     0.0041772511323763
        Module SQL is   0.00034882606491038 seconds faster and 8.7% faster
         TEST 3
        Module SQL:     0.0044253088625228
        fQuery SQL:     0.0038262876559714
        fQuery SQL is   0.00059902120655145 seconds faster and 14.5% faster
         TEST 4
        Module SQL:     0.0032171184375652
        fQuery SQL:     0.003427164767123
        Module SQL is   0.00021004632955776 seconds faster and 6.3% faster
         TEST 5
        Module SQL:     0.0032568432510215
        fQuery SQL:     0.0030948519395239
        fQuery SQL is   0.0001619913114976 seconds faster and 5.1% faster
         TEST 6
        Module SQL:     0.0034483948663395
        fQuery SQL:     0.0033343231579222
        fQuery SQL is   0.00011407170841739 seconds faster and 3.3% faster

        So in some cases Module's SQL has been shown to be
        faster but I would overall say that fQuery is the faster
        function sadly but I would say the syntax of the
        Module's SQL is much more useful and easier to use.
        I will have to look into techniques to make the Module
        SQL faster. Module SQL is -14.5% to 22.9% faster.
    */
end

local modules = {}
local handles = {server = {}, client = {}}

function JAAS:RegisterModule(name)
    local l,d = log(name),dev()
    local f_str, id = l:executionTraceLog()
    if JAAS.Var.ExecutionRefusal and !d.VerifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
        return l:removeTraceLog(id)
    end
    local jaas = self
    return {Access = function (index, execution_log, access_name)
            execution_log = execution_log == nil or execution_log == true
            if istable(index) then
                if access_name then
                    if execution_log then
                        jaas[access_name] = function (...)
                            local f_str, id = l:executionTraceLog()
                            if JAAS.Var.ExecutionRefusal and !d.VerifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
                                return l:removeTraceLog(id)
                            end
                            return index(...)
                        end
                    else
                        jaas[access_name] = function (...)
                            return index(...)
                        end
                    end
                    modules[access_name] = index
                else
                    if execution_log then
                        jaas[name] = function (...)
                            local f_str, id = l:executionTraceLog()
                            if JAAS.Var.ExecutionRefusal and !d.VerifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
                                return l:removeTraceLog(id)
                            end
                            return index(...)
                        end
                    else
                        jaas[name] = function (...)
                            return index(...)
                        end
                    end
                    modules[name] = index
                end
            elseif isfunction(index) then
                if access_name then
                    if execution_log then
                        jaas[access_name] = function (...)
                            local f_str, id = l:executionTraceLog()
                            if JAAS.Var.ExecutionRefusal and !d.VerifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
                                return l:removeTraceLog(id)
                            end
                            return index(...)
                        end
                    else
                        jaas[access_name] = index
                    end
                    modules[access_name] = index
                else
                    if execution_log then
                        jaas[name] = function (...)
                            local f_str, id = l:executionTraceLog()
                            if JAAS.Var.ExecutionRefusal and !d.VerifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
                                return l:removeTraceLog(id)
                            end
                            return index(...)
                        end
                    else
                        jaas[name] = index
                    end
                    modules[name] = index
                end
            end
        end,
        Class = class,
        Handle = setmetatable({
            Server = function (func)
                if isfunction(func) then
                    handles.server[1 + #handles.server] = func
                end
            end,
            Client = function (func)
                if isfunction(func) then
                    handles.client[1 + #handles.client] = func
                end
            end,
            Shared = function (func)
                if isfunction(func) then
                    handles.server[1 + #handles.server] = func
                    handles.client[1 + #handles.client] = func
                end
            end
        }, {__call = function (self, func)
            self.Shared(func)
        end}),
        ExecutionTrace = function (offset)
            local f_str, id = l:executionTraceLog(1 + (offset or 0))
            if JAAS.Var.ExecutionRefusal and !d.VerifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
                return !l:removeTraceLog(id)
            end
            return true
        end
    }, l, d, SQL
end

function JAAS:PostInitialise()
    if SERVER and 0 < #handles.server then
        for k,v in ipairs(handles.server) do
            v(setmetatable({}, {__index = modules}))
        end
        handles.server = {}
    elseif CLIENT and 0 < #handles.client then
        for k,v in ipairs(handles.client) do
            v(setmetatable({}, {__index = modules}))
        end
        handles.client = {}
    end
end

local MODULE = JAAS:RegisterModule"Log"
MODULE.Access(log)
if SERVER then
else
    for k,v in ipairs(delayedHandles.log.client) do
        MODULE.Handle.Client(v)
    end
end
JAAS:RegisterModule"Developer".Access(dev, true, "Dev")
JAAS:RegisterModule"SQL".Access(SQL, false)