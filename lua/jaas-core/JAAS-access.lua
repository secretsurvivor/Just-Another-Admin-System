local MODULE, log, dev, SQL = JAAS:RegisterModule "Access Group"
SQL = SQL"JAAS_access_group"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {
        name = "TEXT NOT NULL UNIQUE",
        code = "UNSIGNED BIGINT NOT NULL DEFAULT 0",
        access_value = "UNSIGNED INT UNIQUE DEFAULT 0",
        access_type = "UNSIGNED INT NOT NULL"
    }
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
    if SQL.UPDATE {name = name} {rowid = self.id} then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
        return true
    end
    return false
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
    if SQL.UPDATE {code = code} {rowid = self.id} then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
        return true
    end
    return false
end

function access_local:xorCode(code)
    if dev.isRankObject(code) then
        code = code:getCode()
    end
    if SQL.UPDATE ("code = (code | " .. code .. ") & (~code | ~" .. code .. ")") {rowid = self.id} then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
        return true
    end
    return false
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
    if SQL.UPDATE {access_value = v} {rowid = self.id} then
        JAAS.Hook "AccessGroup" "GlobalAccessChange" ()
        return true
    end
    return false
end

setmetatable(access_local, {
    __call = function (self, v)
        if isnumber(v) then
            if SQL.SELECT "name" {rowid = v} then
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

local access_count = access_count or SQL.SELECT "COUNT(rowid)" () ["COUNT(rowid)"]
local cv_cache = dev.Cache()
JAAS.Hook "AccessGroup" "GlobalAccessChange" ["AccessGroup_module_codeCheck_cache"] = function ()
    cv_cache()
end

local access = {
    addAccessGroup = function (name, type, value)
        if SQL.INSERT {name = name, access_type = type, access_value = value} then
            access_count = 1 + access_count
            return access_local(name)
        end
        return false
    end,
    removeAccessGroup = function (name)
        return SQL.DELETE {name = name}
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
        if access_count == 0 then
            return true
        end
        if cv_cache[type] ~= nil and cv_cache[type][code] ~= nil and cv_cache[type][code][value] ~= nil then
            return v_cache[type][code][value]
        else
            if cv_cache[type] == nil then
                cv_cache[type] = {}
            end
            if cv_cache[type][code] == nil then
                cv_cache[type][code] = {}
            end
            cv_cache[type][code][value] = SQL.SELECT "code" ("access_value <= value AND code & ".. code .." > 0 AND access_type ="..type) != false
            return cv_cache[type][code][value]
        end
    end,
    PERMISSION = 0,
    COMMAND = 1,
    RANK = 2
}

MODULE.Access(function (identifier)
    if identifier then
        identifier = SQL.ESCAPE(identifier)
        return access_local(identifier)
    end
    return setmetatable({}, {__index = access, __metatable = "jaas_access_library"})
end, true, "AccessGroup")

dev:isTypeFunc("AccessObject", "jaas_access_object")
dev:isTypeFunc("AccessLibrary", "jaas_access_library")

log:registerLog {1, 6, "created", "group", 3} -- [1] secret_survivor created group Moderator
log:registerLog {1, 6, "deleted", "group", 3} -- [2] secret_survivor deleted group Admin
log:registerLog {1, 6, "assigned", "group", 3, "to", 2} -- [3] secret_survivor assigned group Admin to Admin
log:registerLog {"Group", 3, "value", 6, "set", "to", 4} -- [4] Group Admin value set to 2
log:registerLog {"Permission", 3, "access value", 6, "set", "to group", 3, "-", 4, "by", 1} -- [5] Permission Noclip access value set to group Manager - 2 by secret_survivor
log:registerLog {"Command", 3, "access value", 6, "set", "to group", 3, "-", 4, "by", 1} -- [6] Command Utility.Toggle_Flight access value set to group Manager - 2 by secret_survivor
log:registerLog {2, "access value", 6, "set", "to group", 3, "-", 4, "by", 1} -- [7] Manager access value set to group Manager - 1 by secret_survivor
log:registerLog {1, 6, "attempted", "to modify an access group"} -- [8] Dempsy40 attempted to modify an access group
MODULE.Handle.Server(function (jaas)
    local perm = jaas.Permission()
    local access_permission = perm.registerPermission("Can Modify Access Group", "Player will be able to modify access groups and values")

    util.AddNetworkString "JAAS_AccessModify_Channel"
    /* Access feedback codes :: 2 Bits
        0 :: Change was a success
        1 :: Could not be executed
        2 :: Unknown Access identifier
        3 :: Unknown Type code
    */
    local sendFeedback = dev.sendUInt("JAAS_AccessModify_Channel", 2)
    net.Receive("JAAS_AccessModify_Channel", function (len, ply)
        if access_permission:codeCheck(ply) then
            local type_ = net.ReadUInt(2)
            if type_ == 0 then -- Add
                local name,access_type,value = net.ReadString(),net.ReadUInt(2),net.ReadUInt(8)
                if access.addAccessGroup(name, access_type, value) then
                    sendCode(0)
                    log:Log(1, {player = {ply}, entity = {name}})
                    log:superadminChat("%p created access group %e", ply:Nick(), name)
                else
                    sendCode(1)
                end
            elseif type_ == 1 then -- remove
                local name = net.ReadString()
                if access.removeAccessGroup(name) then
                    sendCode(0)
                    log:Log(2, {player = {ply}, entity = {name}})
                    log:superadminChat("%p removed access group %e", ply:Nick(), name)
                else
                    sendCode(1)
                end
            elseif type_ == 2 then -- Xor Rank Code
                local accessGroup = jaas.AccessGroup(net.ReadString())
                local rank = jaas.Rank(net.ReadString())
                if dev.isAccessObject(accessGroup) and dev.isRankObject(rank) then
                    if accessGroup:xorCode(rank) then
                        sendCode(0)
                        log:Log(3, {player = {ply}, rank = {rank}, entity = {accessGroup:getName()}})
                        log:superadminChat("%p assigned access group %e to %r", ply:Nick(), accessGroup:getName(), rank:getName())
                    else
                        sendCode(1)
                    end
                else
                    sendCode(2)
                end
            elseif type_ == 3 then -- Set Value
                local accessGroup = jaas.AccessGroup(net.ReadString())
                local value = net.ReadUInt(8)
                if dev.isAccessObject(accessGroup) then
                    if accessGroup:setValue(value) then
                        sendCode(0)
                        log:Log(4, {entity = {accessGroup:getName()}, data = {value}})
                        log:superadminChat("Access Group %e's value set to %d by %p", accessGroup:getName(), value, ply:Nick())
                    else
                        sendCode(1)
                    end
                else
                    sendCode(2)
                end
            elseif type_ == 4 then -- Object Value Change
                local type_ = net.ReadUInt(2)
                local accessGroup = jaas.AccessGroup(net.ReadString())
                local sendCode = sendFeedback(ply)
                if type_ == 0 then -- Permission
                    local obj = jaas.Permission(net.ReadString())
                    if dev.isPermissionObject(obj) then
                        if obj:setAccess(accessGroup) then
                            sendCode(0)
                            log:Log(5, {player = {ply}, entity = {obj:getName(), accessGroup:getName()}, data = {accessGroup:getValue()}})
                            log:superadminChat("Permission %e's access value set to %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                        else
                            sendCode(1)
                        end
                    else
                        sendCode(2)
                    end
                elseif type_ == 1 then -- Command
                    local obj = jaas.Command(net.ReadString())
                    if dev.isCommandObject(obj) then
                        if obj:setAccess(accessGroup) then
                            sendCode(0)
                            log:Log(6, {player = {ply}, entity = {tostring(obj), accessGroup:getName()}, data = {accessGroup:getValue()}})
                            log:superadminChat("Command %e's access value set to %e by %p", tostring(obj), accessGroup:getName(), ply:Nick())
                        else
                            sendCode(1)
                        end
                    else
                        sendCode(2)
                    end
                elseif type_ == 2 then -- Rank
                    local obj = jaas.Rank(net.ReadString())
                    if dev.isRankObject(obj) then
                        if obj:setAccess(accessGroup) then
                            log:Log(7, {player = {ply}, rank = {obj}, entity = {accessGroup:getName()}, data = {accessGroup:getValue()}})
                            log:superadminChat("%r's access value set to %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            sendCode(0)
                        else
                            sendCode(1)
                        end
                    else
                        sendCode(2)
                    end
                else
                    sendCode(3)
                end
            else
                sendCode(3)
                log:Log(8, {player = {ply}})
                log:superadminChat("%p attempted to modify an Access Group", ply:Nick())
            end
        end
    end)
end)

log:print "Module Loaded"