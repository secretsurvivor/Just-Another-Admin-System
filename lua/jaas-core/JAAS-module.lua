local function class(table, metatable, properties)
    if properties then
        if isstring(properties) then
            return setmetatable({}, {__call = function (self, p)
                local o = {}
                o[properties] = p
                return setmetatable(o, {__index = table, __newindex = table, __metatable = metatable})
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
                return setmetatable(o, {__index = table, __newindex = table, __metatable = metatable})
            end, __newindex = function () end, __index = table})
        end
    else
        return setmetatable({}, {__call = function ()
            return setmetatable({}, {__index = table, __newindex = table, __metatable = metatable})
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

    function devFunctions.verifyFilepath(filepath, verify_str)
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

    function devFunctions.verifyFilepath_table(filepath, verify_str_table)
        for _, v_str in ipairs(verify_str_table) do
            if verifyFilepath(filepath, v_str) then
                return true
            end
        end
        return false
    end

    if SERVER then
        function devFunctions.sharedSync(networkString, server_func)
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
        function devFunctions.sharedSync(networkString, _, hook_identifier, client_func)
            net.Receive(networkString, function (_, ply)
                client_func(_, ply, net.ReadTable())
            end)
            hook.Add("InitPostEntity", hook_identifier, function ()
                net.Start(networkString)
                net.SendToServer()
            end)
        end
    end

    function devFunctions.mergeSort(table) -- Acc
        local function sort(table, lower, upper)
            if lower < upper then
                local mid = math.ceil((lower + upper)/2)
                sort(table, lower, mid)
                sort(table, mid + 1, upper)
                do
                    local sub1_l, sub2_l = mid - lower + 1, upper - mid
                    local left, right = {}, {}
                    for i=1, sub1_l do
                        left[i] = table[lower + i]
                    end
                    for i=0, sub2_l do
                        right[i] = table[1 + mid + i]
                    end
                    local i,j,k = 0,0,l
                    while(i < sub1_l && j < sub2_l) do
                        if left[i] <= right[j] then
                            table[k] = left[i]
                            i = 1 + i
                        else
                            table[k] = right[j]
                            j = 1 + j
                        end
                    end
                    while i < sub1_l do
                        table[k] = left[i]
                        i = 1 + i
                        k = 1 + k
                    end
                    while j < sub2_l do
                        table[k] = right[j]
                        j = 1 + j
                        k = 1 + k
                    end
                end
            end
        end
        return sort(table, 1, (#table) - 1)
    end

    function devFunctions.quickSort()

    end

    function devFunctions:isTypeFunc(name, metatable)
        self["is" .. name] = function (v)
            return getmetatable(v) == metatable
        end
    end
    for k,v in ipairs({
        {"RankObject","jaas_rank_object"},
        {"PermissionObject","jaas_permission_object"},
        {"CommandObject","jaas_command_object"},
        {"PlayerObject","jaas_player_object"},
        {"RankLibrary","jaas_rank_library"},
        {"CommandLibrary","jaas_command_library"},
        {"PermissionLibrary","jaas_permission_library"},
        {"PlayerLibrary","jaas_player_library"},
        {"LogLibrary","jaas_log_library"},
        {"DevLibrary","jaas_developer_library"}
    }) do
        devFunctions:isTypeFunc(v[1], v[2])
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

    function logFunctions:gameLog(action, str)
    end

    local executionTrace = executionTrace or {} -- [label][id] = {file path, line}
    local refusedTrace = refusedTrace or {} -- [label] = {id*}

    function logFunctions:executionTraceLog()
        if !JAAS.Var.TraceExecution then
            return
        end
        local info = debug.getinfo(3)
        if executionTrace[self.label] ~= nil then
            for _,v in ipairs(executionTrace[self.label]) do
                if v[1] == filepath and v[2] == line then
                    return
                end
            end
            table.insert(executionTrace[self.label], {info.short_src, info.currentline})
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
            table.insert(refusedTrace[self.label], id)
        else
            refusedTrace[self.label] = {id}
        end
        return true
    end

    log = class(logFunctions, "jaas_log_library", "label")
end

local SQL
do
    local q,isS,isT = sql.Query,isstring,istable
    SQL = function (table)
        local function QUERY(str)
            local r = q(str)
            if r and #r == 1 then
                return r[1]
            end return r
        end
        local function table_to_str(t) local q,c = "",1
            for k,v in pairs(t) do
                if isnumber(v)  then q = q .. k .. "=" .. v
                elseif isstring(v) then q = q .. k .. "=" .. "'" .. v .. "'"
                end
                if c < #t then q = q .. "," end
                c = 1 + c
            end return q
        end
        local function table_to_WHERE(t) local q,c = "",1
            for k,v in pairs(t) do
                if isnumber(v) then q = q .. k .. "=" .. v
                elseif isstring(v) then q = q .. k .. "=" .. "'" .. v .. "'"
                end
                if c < #t then q = q .. " AND " end
                c = 1 + c
            end return q
        end
        local function isstring(v) return v and isS(v) end
        local function istable(v) return v and isT(v) end
        return setmetatable({
            EXISTS = sql.TableExists(table),
            CREATE = setmetatable({
                TABLE = function (columns)
                    if isstring(columns) then
                        return QUERY("CREATE TABLE " .. table .. " (" .. columns .. ")")
                    elseif istable(columns) then
                        local q,c = "",1
                        for k,v in pairs(columns) do
                            if isstring(k) then
                                q = q .. k .. " " .. v
                            else
                                q = q .. v
                            end
                            if c < #columns then
                                q = q .. ","
                            end
                            c = 1 + c
                        end
                        return QUERY("CREATE TABLE " .. table .. " (" .. q .. ")")
                    end
                end,
                INDEX = function (index_name)
                    return function (columns)
                        if isstring(columns) then
                            return QUERY("CREATE INDEX " .. index_name .. " ON " .. table .. " (" .. columns .. ")")
                        elseif istable(columns) then
                            return QUERY("CREATE INDEX " .. index_name .. " ON (" .. table.concat(columns, ",") .. ")")
                        end
                    end
                end
            }, {__call = function (self, str)
                return QUERY("CREATE " .. str)
            end}),
            SELECT = function (column)
                if column then
                    if istable(column) then
                        column = table.concat(column, ",")
                    end
                    return function (where)
                        if isstring(where) then
                            return QUERY("SELECT " .. column .. " FROM " .. table .. " WHERE " .. where)
                        elseif istable(where) then
                            return QUERY("SELECT " .. column .. " FROM " .. table .. " WHERE " .. table_to_WHERE(where))
                        else
                            return QUERY("SELECT " .. column .. " FROM " .. table)
                        end
                    end
                else
                    QUERY("SELECT * FROM " .. table)
                end
            end,
            UPDATE = function (set)
                if istable(set) then
                    set = table_to_str(set)
                end
                return function (where)
                    if isstring(where) then
                        return QUERY("UPDATE " .. table .. " SET " .. set .. " WHERE " .. where)
                    elseif istable(where) then
                        return QUERY("UPDATE " .. table .. " SET " .. set .. " WHERE " .. table_to_WHERE(where))
                    else
                        return QUERY("UPDATE " .. table .. " SET " .. set)
                    end
                end
            end,
            INSERT = function (set)
                if isstring(set) then
                    return function (values)
                        return QUERY("INSERT INTO " .. table .. "(" .. set .. ") VALUES (" .. values .. ")")
                    end
                elseif istable(set) then
                    local cat,val,c = "","",1
                    for k,v in pairs(set) do
                        cat = cat .. k
                        if isstring(v) then
                            val = val .. "'" .. v .. "'"
                        else
                            val = val .. v
                        end
                        if c < #set then
                            cat = cat .. ","
                            val = val .. ","
                        end
                        c = 1 + c
                    end
                    return QUERY("INSERT INTO " .. table .. "(" .. cat .. ") VALUES (" .. val .. ")")
                end
            end,
            DELETE = function (where)
                if isstring(where) then
                    return QUERY("DELETE FROM " .. table .. " WHERE " .. where)
                elseif istable(where) then
                    return QUERY("DELETE FROM " .. table .. " WHERE " .. table_to_WHERE(where))
                else
                    return QUERY("DELETE FROM " .. table)
                end
            end,
            DROP = {
                TABLE = function (name) -- To make sure that they know they're dropping the table
                    if name == table then return QUERY("DROP TABLE " .. table) end
                end,
                INDEX = function (name)
                    return QUERY("DROP INDEX " .. name)
                end
            }
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
        SQL faster.
    */
end

local modules = {}
local handles = {server = {}, client = {}}

function JAAS:RegisterModule(name)
    local l,d = log(name),dev()
    local f_str, id = l:executionTraceLog()
    if JAAS.Var.ExecutionRefusal and !d.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
        return l:removeTraceLog(id)
    end
    local jaas = self
    return {Access = function (index, execution_log, access_name)
            if istable(index) then
                if access_name then
                    if execution_log then
                        jaas[access_name] = function (...)
                            local f_str, id = l:executionTraceLog()
                            if JAAS.Var.ExecutionRefusal and !d.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
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
                            if JAAS.Var.ExecutionRefusal and !d.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
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
                            if JAAS.Var.ExecutionRefusal and !d.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
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
                            if JAAS.Var.ExecutionRefusal and !d.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
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
        Handle = {
            server = function (func)
                table.insert(handles.server, func)
            end,
            client = function (func)
                table.insert(handles.client, func)
            end,
            shared = function (func)
                table.insert(handles.server, func)
                table.insert(handles.client, func)
            end
        }
    }, l, d, SQL
end

function JAAS:PostInitialise()
    if SERVER then
        for k,v in ipairs(handles.server) do
            v(setmetatable({}, {__index = modules}), SQL)
            handles[k] = nil
        end
    elseif CLIENT then
        for k,v in ipairs(handles.client) do
            v(setmetatable({}, {__index = modules}), SQL)
            handles[k] = nil
        end
    end
end

JAAS:RegisterModule"Log".Access(log, true)
JAAS:RegisterModule"Developer".Access(dev, true, "Dev")
JAAS:RegisterModule"SQL".Access(SQL)