local MODULE, log, dev, SQL = JAAS:RegisterModule "Access Group"
SQL = SQL"JAAS_access_group"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {name = "TEXT NOT NULL UNIQUE", code = "UNSIGNED BIGINT NOT NULL DEFAULT 0", access_value = "UNSIGNED INT UNIQUE DEFAULT 0", access_type = "UNSIGNED INT NOT NULL"}
end

local access_local = {}
local a_cache = dev.Cache() -- [id] = {name, code, access_value}
JAAS.Hook "AccessGroup" "GlobalAccessChange" ["AccessGroup_module_cache"] = function ()
    a_cache()
end

function access_local:getName()
    if a_cache[self.id] == nil then
        local q = SQL.SELECT "*" {rowid = self.id}
        a_cache[self.id] = {q.name, q.code, q.access_value}
        return q.name
    end
    return a_cache[self.id][1]
end

function access_local:setName(name)
    local q = SQL.UPDATE {name = name} {rowid = self.id}
    if q then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
    end
    return q
end

function access_local:getCode()
    if a_cache[self.id] == nil then
        local q = SQL.SELECT "*" {rowid = self.id}
        a_cache[self.id] = {q.name, q.code, q.access_value}
        return q.code
    end
    return a_cache[self.id][2]
end

function access_local:setCode(code)
    local q = SQL.UPDATE {code = code} {rowid = self.id}
    if q then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
    end
    return q
end

function access_local:xorCode(code)
    local q = SQL.UPDATE ("code = (code | " .. code .. ") & (~code | ~" .. code .. ")") {rowid = self.id}
    if q then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
    end
    return q
end

function access_local:getValue()
    if a_cache[self.id] == nil then
        local q = SQL.SELECT "*" {rowid = self.id}
        a_cache[self.id] = {q.name, q.code, q.access_value}
        return q.access_value
    end
    return a_cache[self.id][3]
end

function access_local:setValue(v)
    local q = SQL.UPDATE {access_value = v} {rowid = self.id}
    if q then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
    end
    return q
end

setmetatable(access_local, {
    __call = function (self, v)
        if isnumber(v) then
            local q = SQL.SELECT "name" {rowid = v}
            if q then
                return setmetatable({id = v}, {__index = access_local, __metatable = "jaas_access_object"})
            end
        elseif isstring(v) then
            local q = SQL.SELECT "rowid" {name = v}
            if q then
                return setmetatable({id = q}, {__index = access_local, __metatable = "jaas_access_object"})
            end
        end
    end
})

local cv_cache = dev.Cache()
JAAS.Hook "AccessGroup" "GlobalAccessChange" ["AccessGroup_module_codeCheck_cache"] = function ()
    cv_cache()
end

local access = {
    registerAccess = function (name, type, value)
        local q = SQL.INSERT {name = name, access_type = type, access_value = value}
        if q then
            return access_local(name)
        end
        return false
    end,
    accessIterator = function ()
        local q = SQL.SELECT ()
        local i = 0
        return function ()
            i = 1 + i
            if i <= #q then
                return q[i]
            end
        end
    end,
    codeCheck = function (value, type, code) -- Checks if player has access to this group
        if cv_cache[type] ~= nil and cv_cache[type][code] ~= nil and cv_cache[type][code][value] ~= nil then
            return v_cache[type][code][value]
        else
            if cv_cache[type] == nil then
                cv_cache[type] = {}
            end
            if cv_cache[type][code] == nil then
                cv_cache[type][code] = {}
            end
            local q = SQL.SELECT "code" ("access_value <= value AND code & ".. code .." > 0 AND access_type ="..type) != false
            cv_cache[type][code][value] = q
        end
    end,
    PERMISSION = 0,
    COMMAND = 1,
    RANK = 2
}

MODULE.Access(function (identifier)
    if identifier then
        local r = access_local(identifier)
        if r then
            return r
        end
    end
    return setmetatable({}, {__index = access, __metatable = "jaas_access_library"})
end, true, "AccessGroup")

dev:isTypeFunc("AccessObject", "jaas_access_object")
dev:isTypeFunc("AccessLibrary", "jaas_access_library")

MODULE.Handle.Server(function (jaas)
    local perm = jaas.Permission()
    local access_permission = perm.registerPermission("Can Modify Access Group", "Player will be able to modify access groups")

    util.AddNetworkString "JAAS_AccessModify_Channel"
    /* Access feedback codes :: 2 Bits
        0 :: Permission Change was a success
        1 :: Code could not be changed
        2 :: Unknown Access identifier
    */
    local sendFeedback = dev.sendUInt("JAAS_AccessModify_Channel", 2)
    net.Receive("JAAS_AccessModify_Channel", function (len, ply)
        if access_permission:codeCheck(ply) then
            local name = net.ReadString()
            local code = net.ReadUInt(64)
            local acc, sendCode = jaas.AccessGroup(), sendFeedback(ply)
            if dev.isAccessObject(acc) then
                if acc:xorCode(code) then
                    sendCode(0)
                else
                    sendCode(1)
                end
            else
                sendCode(2)
            end
        end
    end)
end)

log:printLog "Module Loaded"