local MODULE, log, dev, SQL = JAAS:RegisterModule "Access Group"
SQL = SQL"JAAS_access_group"

if SERVER and !SQL.EXIST then
    SQL.CREATE.TABLE {
        name = "TEXT NOT NULL",
        code = "UNSIGNED BIGINT NOT NULL DEFAULT 0",
        access_value = "UNSIGNED INT NOT NULL DEFAULT 0",
        access_type = "UNSIGNED INT NOT NULL",
        "PRIMARY KEY(name, access_type)"
    }
end

local access_local = {}
local a_cache = dev.Cache() -- [id] = {name, code, access_value}
JAAS.Hook "AccessGroup" "GlobalAccessChange" ["AccessGroup_module_cache"] = function ()
    a_cache()
end

local AccessHookRun = JAAS.Hook.Run "AccessGroup"
local GlobalChange = AccessHookRun "GlobalAccessChange"
local access

if SERVER then
    function access_local:getName()
        if a_cache[self.id] == nil then
            local q = SQL.SELECT "*" {rowid = self.id}
            q.access_value = tonumber(q.access_value)
            q.code = tonumber(q.code)
            a_cache[self.id] = {q.name, q.code, q.access_value}
            return q.name
        end
        return a_cache[self.id][1]
    end

    function access_local:setName(name)
        if SQL.UPDATE {name = name} {rowid = self.id} then
            GlobalChange()
            return true
        end
        return false
    end

    function access_local:getCode()
        if a_cache[self.id] == nil then
            local q = SQL.SELECT "*" {rowid = self.id}
            q.access_value = tonumber(q.access_value)
            q.code = tonumber(q.code)
            a_cache[self.id] = {q.name, q.code, q.access_value}
            return q.code
        end
        return a_cache[self.id][2]
    end

    function access_local:setCode(code)
        if SQL.UPDATE {code = code} {rowid = self.id} then
            GlobalChange()
            AccessHookRun "UpdatedCode" (self.id, code)
            return true
        end
        return false
    end

    function access_local:xorCode(code)
        if dev.isRankObject(code) then
            code = code:getCode()
        end
        local before = self:getCode()
        if SQL.UPDATE ("code = (code | " .. code .. ") & (~code | ~" .. code .. ")") {rowid = self.id} then
            GlobalChange()
            AccessHookRun "UpdatedCode" (self.id, bit.bxor(before, code))
            return true
        end
        return false
    end

    function access_local:getValue()
        if a_cache[self.id] == nil then
            local q = SQL.SELECT "*" {rowid = self.id}
            q.access_value = tonumber(q.access_value)
            q.code = tonumber(q.code)
            a_cache[self.id] = {q.name, q.code, q.access_value}
            return q.access_value
        end
        return a_cache[self.id][3]
    end

    function access_local:setValue(v)
        if SQL.UPDATE {access_value = v} {rowid = self.id} then
            GlobalChange()
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
            end
        end
    })

    local access_count = tonumber(SQL.SELECT "COUNT(rowid)" () ["COUNT(rowid)"])

    access = {
        addAccessGroup = function (name, type, value)
            if !value or value == 0 then
                value = 1 + (tonumber(SQL.SELECT "MAX(access_value)" () ["MAX(access_value)"]) or 0)
            end
            if SQL.INSERT {name = name, access_type = type, access_value = value} then
                access_count = 1 + access_count
                local id = SQL.SELECT "rowid" {name = name, access_type = type}.rowid
                local obj = access_local(id)
                local error, messsage = AccessHookRun "Added" (id, name, type, value)
                if !error then
                    print(message)
                end
                return obj
            end
            return false
        end,
        removeAccessGroup = function (name)
            if dev.isAccessObject(name) then
                if SQL.DELETE {rowid = name.id} then
                    AccessHookRun "Removed" (name.id)
                    access_count = access_count - 1
                    return true
                end
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
        codeCheck = function (type, value, code)
            if access_count > 0 and value > 0 then
                local info = SQL.SELECT "code" ("access_value <= "..value.." AND access_type = "..type)
                if istable(info) and #info == 0 then
                    return bit.band(code, tonumber(info.code)) > 0
                elseif istable(info) then
                    for k,v in ipairs(info) do
                        if bit.band(code, tonumber(v.code)) > 0 then
                            return true
                        end
                    end
                end
                return false
            end
            return true
        end,
        PERMISSION = 0,
        COMMAND = 1,
        RANK = 2
    }

    util.AddNetworkString"JAAS_PullAccessGroups"
    net.Receive("JAAS_PullAccessGroups", function (_, ply)
        local table = SQL.SELECT () or {}
        if access_count == 1 then
            table = {table}
        end
        net.Start"JAAS_PullAccessGroups"
        net.WriteTable(table)
        net.Send(ply)
    end)

    util.AddNetworkString"JAAS_AccessClientUpdate"
    JAAS.Hook "AccessGroup" "UpdatedCode" ["ModuleClientUpdate"] = function (id, code)
        net.Start"JAAS_AccessClientUpdate"
        net.WriteFloat(id)
        net.WriteFloat(code)
        net.Broadcast()
    end

    util.AddNetworkString"JAAS_AccessGroupChangeClient"
    JAAS.Hook "AccessGroup" "Added" ["ClientUpdate"] = function (id, name, type, value)
        net.Start"JAAS_AccessGroupChangeClient"
        net.WriteUInt(0, 1)
        net.WriteFloat(id)
        net.WriteString(name)
        net.WriteFloat(type)
        net.WriteFloat(value)
        net.Broadcast()
    end

    JAAS.Hook "AccessGroup" "Removed" ["ClientUpdate"] = function (id)
        net.Start"JAAS_AccessGroupChangeClient"
        net.WriteUInt(1, 1)
        net.WriteFloat(id)
        net.Broadcast()
    end
else
    local access_group_list = {} -- [id] = {name=, code=, access_value=, access_type=}

    hook.Add("InitPostEntity", "JAAS_AccessInitialPull", function ()
        net.Start"JAAS_PullAccessGroups"
        net.SendToServer()
    end)

    net.Receive("JAAS_PullAccessGroups", function ()
        access_group_list = net.ReadTable()
    end)

    net.Receive("JAAS_AccessClientUpdate", function ()
        local id = net.ReadFloat()
        local code = net.ReadFloat()
        access_group_list[id].code = code
        AccessHookRun "UpdatedCode" (id, code)
    end)

    net.Receive("JAAS_AccessGroupChangeClient", function ()
        local opcode = net.ReadUInt(1)
        if opcode == 1 then
            local id = net.ReadFloat()
            AccessHookRun "Removed" (id)
            access_group_list[id] = nil
        else
            local id = net.ReadFloat()
            local name = net.ReadString()
            local type = net.ReadFloat()
            local value = net.ReadFloat()
            AccessHookRun "Added" (id, {name = name, code = 0, access_value = value, access_type = type})
            access_group_list[id] = {name = name, code = 0, access_value = value, access_type = type}
        end
    end)

    JAAS.Hook "Rank" "RemovedPosition" ["AccessModuleUpdate"] = function (func)
        for id,v in pairs(access_group_list) do
            access_group_list[id].code = func(access_group_list[id].code)
        end
    end

    access = {
        GetAccessGroups = function ()
            return pairs(access_group_list)
        end
    }
end

MODULE.Access(function (identifier)
    if SERVER and identifier then
        if !isnumber(identifier) then
            identifier = string.Trim(SQL.ESCAPE(identifier), "'")
        end
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
log:registerLog {1, 6, "unassigned", "group", 3, "to", 2} -- [9] secret_survivor unassigned group Admin to Admin
log:registerLog {1, "made group", 3, 6, "default access"} -- [10] secret_survivor made group Admin default access
log:registerLog {"Permission", 3, "access value", 6, "removed", "from group", 3, "-", 4, "by", 1} -- [11] Permission Noclip access value removed from group Manager - 2 by secret_survivor
log:registerLog {"Command", 3, "access value", 6, "removed", "from group", 3, "-", 4, "by", 1} -- [12] Command Utility.Toggle_Flight access value removed from group Manager - 2 by secret_survivor
log:registerLog {2, "access value", 6, "removed", "from group", 3, "-", 4, "by", 1} -- [13] Manager access value removed from group Manager - 1 by secret_survivor
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
        local sendCode = sendFeedback(ply)
        if access_permission:codeCheck(ply) then
            local opcode = net.ReadUInt(3) -- Opcode
            if opcode == 0 then -- Add
                local name,access_type,value = net.ReadString(),net.ReadUInt(2),net.ReadFloat()
                if access.addAccessGroup(name, access_type, value) then
                    sendCode(0)
                    log:Log(1, {player = {ply}, entity = {name}})
                    log:superadminChat("%p created access group %e", ply:Nick(), name)
                else
                    sendCode(1)
                end
            elseif opcode == 1 then -- Remove
                local id = net.ReadFloat()
                local obj = jaas.AccessGroup(id)
                if dev.isAccessObject(obj) then
                    local name = obj:getName()
                    if access.removeAccessGroup(obj) then
                        sendCode(0)
                        log:Log(2, {player = {ply}, entity = {name}})
                        log:superadminChat("%p removed access group %e", ply:Nick(), name)
                    else
                        sendCode(1)
                    end
                else
                    sendCode(2)
                end
            elseif opcode == 2 then -- Xor Rank Code
                local accessGroup = jaas.AccessGroup(net.ReadFloat())
                local rank = jaas.Rank(net.ReadString())
                if dev.isAccessObject(accessGroup) and dev.isRankObject(rank) then
                    if accessGroup:xorCode(rank) then
                        sendCode(0)
                        if accessGroup:getCode() == 0 then
                            log:Log(10, {player = {ply}, entity = {accessGroup:getName()}})
                            log:superadminChat("%p made access group %e default access", ply:Nick(), accessGroup:getName())
                        elseif bit.band(accessGroup:getCode(), rank:getCode()) > 0 then
                            log:Log(3, {player = {ply}, rank = {rank}, entity = {accessGroup:getName()}})
                            log:superadminChat("%p assigned access group %e to %r", ply:Nick(), accessGroup:getName(), rank:getName())
                        else
                            log:Log(9, {player = {ply}, rank = {rank}, entity = {accessGroup:getName()}})
                            log:superadminChat("%p unassigned access group %e to %r", ply:Nick(), accessGroup:getName(), rank:getName())
                        end
                    else
                        sendCode(1)
                    end
                else
                    sendCode(2)
                end
            elseif opcode == 3 then -- Set Value
                local accessGroup = jaas.AccessGroup(net.ReadFloat())
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
            elseif opcode == 4 then -- Object Value Change
                local opcode = net.ReadUInt(2)
                local accessGroup = jaas.AccessGroup(net.ReadFloat()) -- name
                local sendCode = sendFeedback(ply)
                if opcode == 0 then -- Permission
                    local obj = jaas.Permission(net.ReadString()) -- name
                    if dev.isPermissionObject(obj) then
                        if accessGroup:getValue() == obj:getAccess() then
                            if obj:setAccess(0) then
                                sendCode(0)
                                log:Log(11, {player = {ply}, entity = {obj:getName(), accessGroup:getName()}, data = {accessGroup:getValue()}})
                                log:superadminChat("Permission %e's access value removed from %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            else
                                sendCode(1)
                            end
                        else
                            if obj:setAccess(accessGroup) then
                                sendCode(0)
                                log:Log(5, {player = {ply}, entity = {obj:getName(), accessGroup:getName()}, data = {accessGroup:getValue()}})
                                log:superadminChat("Permission %e's access value set to %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            else
                                sendCode(1)
                            end
                        end
                    else
                        sendCode(2)
                    end
                elseif opcode == 1 then -- Command
                    local obj = jaas.Command(net.ReadString(), net.ReadString()) -- name, category
                    if dev.isCommandObject(obj) then
                        if accessGroup:getValue() == obj:getAccess() then
                            if obj:setAccess(0) then
                                sendCode(0)
                                log:Log(12, {player = {ply}, entity = {obj:getName(), accessGroup:getName()}, data = {accessGroup:getValue()}})
                                log:superadminChat("Command %e's access value removed from %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            else
                                sendCode(1)
                            end
                        else
                            if obj:setAccess(accessGroup) then
                                sendCode(0)
                                log:Log(6, {player = {ply}, entity = {obj:getName(), accessGroup:getName()}, data = {accessGroup:getValue()}})
                                log:superadminChat("Command %e's access value set to %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            else
                                sendCode(1)
                            end
                        end
                    else
                        sendCode(2)
                    end
                elseif opcode == 2 then -- Rank
                    local obj = jaas.Rank(net.ReadString()) -- name
                    if dev.isRankObject(obj) then
                        if accessGroup:getValue() == obj:getAccess() then
                            if obj:setAccess(0) then
                                sendCode(0)
                                log:Log(13, {player = {ply}, rank = {obj:getName()}, entity = {accessGroup:getName()}, data = {accessGroup:getValue()}})
                                log:superadminChat("%r's access value removed from %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            else
                                sendCode(1)
                            end
                        else
                            if obj:setAccess(accessGroup) then
                                sendCode(0)
                                log:Log(7, {player = {ply}, rank = {obj:getName()}, entity = {accessGroup:getName()}, data = {accessGroup:getValue()}})
                                log:superadminChat("%r's access value set to %e by %p", obj:getName(), accessGroup:getName(), ply:Nick())
                            else
                                sendCode(1)
                            end
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