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

    function devFunctions.isPlayer(v)
        return isentity(v) and IsValid(v) and v:IsPlayer()
    end

    function devFunctions.isBot(v)
        return isentity(v) and IsValid(v) and v:IsBot()
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

    function devFunctions:isTypeFunc(name, metatable)
        self["is" .. name] = function (v)
            return getmetatable(v) == metatable
        end
    end

    devFunctions:isTypeFunc("DevLibrary", "jaas_developer_library")
    devFunctions:isTypeFunc("LogLibrary", "jaas_log_library")

    function math.PercentageDif(a, b)
        return (math.abs(a - b) / ((a + b) / 2)) * 100
    end

    dev = class(devFunctions, "jaas_developer_library")
end

local log
do -- Log Module Initialisation
    local logFunctions = {["getLogFile"] = true, ["writeToLogFile"] = true, ["printLog"] = true, ["silentLog"] = true}
    function logFunctions.getLogFile(date)
    end

    function logFunctions.writeToLogFile(...)
        if SERVER and file.Exists("", "DATA") then
        elseif SERVER then
        end
    end

    function logFunctions:printLog(str)
        local str = "[JAAS] ["..self.label.."] - "..str
        print(str)
        log.writeToLogFile(str)
    end

    function logFunctions:silentLog(str)
        log.writeToLogFile(str)
    end

    function logFunctions:chatLog(str)
        local str = "[JAAS] - "..str
        PrintMessage(HUD_PRINTTALK, str)
        log.writeToLogFile(str)
    end

    function logFunctions:adminPrintLog()
    end

    function logFunctions:superadminPrintLog()
    end

    function logFunctions:adminChatLog()
    end

    function logFunctions:superadminChatLog()
    end

    function logFunctions:gameLog(action, str)
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

    log = class(logFunctions, "jaas_log_library", false, "label")
end

local SQL
do
    local q,isS,isT,pairs,isnumber,isstring,t = sql.Query,isstring,istable,pairs,isnumber,isstring,table
    local QUERY,db
    if JAAS.Var.MySQLServer then
        require("mysqloo")
        db = mysqloo.connect(JAAS.Var.MySQLServerInformation.host, JAAS.Var.MySQLServerInformation.username, JAAS.Var.MySQLServerInformation.password, JAAS.Var.MySQLServerInformation.database)
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
        end})
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
            handles[k] = nil
        end
    elseif CLIENT and 0 < #handles.client then
        for k,v in ipairs(handles.client) do
            v(setmetatable({}, {__index = modules}))
            handles[k] = nil
        end
    end
end

JAAS:RegisterModule"Log".Access(log)
JAAS:RegisterModule"Developer".Access(dev, true, "Dev")
JAAS:RegisterModule"SQL".Access(SQL, false)