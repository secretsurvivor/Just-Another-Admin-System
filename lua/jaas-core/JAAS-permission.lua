local MODULE, log, dev, SQL = JAAS:RegisterModule "Permission"
SQL = SQL"JAAS_permission"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {name = "NOT NULL UNIQUE", code = "UNSIGNED BIGINT NOT NULL DEFAULT 0", access_group = "UNSIGNED INT DEFAULT 0"}
    SQL.CREATE.INDEX "JAAS_permission_name" "name"
end

local permission_table = permission_table or {} -- [name] = {code, description, access} // string, integer, string, integer
local permission_local = {["getCode"] = true, ["setCode"] = true, ["getName"] = true, ["xorCode"] = true}
local permission = {["registerPermission"] = true, ["CheckPermissions"] = true}


function permission_local:getName()
    return self.name
end

function permission_local:getCode()
    return permission_table[self.name][1]
end

function permission_local:getDescription()
    return permission_table[self.name][2]
end

function permission_local:getAccess()
    return permission_table[self.name][3]
end

local AND = bit.band
function permission_local:codeCheck(code)
    if self:defaultAccess() then
        return true
    else
        if isnumber(code) then
            return AND(self:getCode(), code) > 0
        elseif dev.isCommandObject(code) or dev.isPermissionObject(code) or dev.isPlayerObject(code) then
            return AND(self:getCode(), code:getCode()) > 0
        elseif dev.isPlayer(code) then
            return AND(self:getCode(), code:getJAASCode()) > 0
        end
    end
end

if SERVER then
    function permission_local:setAccess(value)
        if dev.isAccessObject(value) then
            value = value:getValue()
        end
        if SQL.UPDATE {access_group = value} {name = self.name} then
            permission_table[self.name][3] = value
            return true
        end
        return false
    end

    function permission_local:setCode(code)
        if SQL.UPDATE {code = code} {name = self.name} then
            local before = permission_table[self.name][1]
            permission_table[self.name][1] = code
            JAAS.Hook.Run.Permission(self.name)(before, code)
            JAAS.Hook.Run "Permission" "GlobalCodeUpdate" (self.name, before, code)
            return true
        end
        return false
    end

    function permission_local:xorCode(code)
        if dev.isRankObject(code) then
            code = code:getCode()
        end
        local before = permission_table[self.name][1]
        local c_xor = bit.bxor(before, code)
        if SQL.UPDATE {code = c_xor} {name = self.name} then
            permission_table[self.name][1] = c_xor
            JAAS.Hook.Run.Permission(self.name)(before, c_xor)
            JAAS.Hook.Run "Permission" "GlobalCodeUpdate" (self.name, before, c_xor)
            return true
        end
        return false
    end
end

MODULE.Handle.Server(function (jaas)
    local access = jaas.AccessGroup()

    function permission_local:accessCheck(code)
        if isnumber(code) then
            return access.codeCheck(access.PERMISSION, self:getAccess(), code)
        elseif dev.isPlayerObject(code) then
            return access.codeCheck(access.PERMISSION, self:getAccess(), code:getCode())
        elseif dev.isPlayer(code) then
            return access.codeCheck(access.PERMISSION, self:getAccess(), code:getJAASCode())
        end
    end
end)

function permission_local:defaultAccess()
    if self:getCode() == 0 then
        return true
    end
end

setmetatable(permission_local, {
    __call = function (self, name)
        return setmetatable({name = name}, {
            __index = permission_local,
            __metatable = "jaas_permission_object"
        })
    end
})

if SERVER then
    function permission.registerPermission(name, description, code, access)
        if !name or name == "" then
            error("Permission name cannot be empty", 2)
        end
        local q = SQL.SELECT "code, access_group" {name = name}
        if q then
            code = tonumber(q["code"])
            access = tonumber(q["access_group"])
        end
        code = code or 0
        access = access or 0
        if !q then
            q = SQL.INSERT {name = name, code = code, access_group = access}
        end
        if q then
            permission_table[name] = {code, description, access}
            return permission_local(name)
        end
    end

    JAAS.Hook "Rank" "RemovePosition" ["Permission_module"] = function (func)
        sql.Begin()
        for name, t in pairs(permission_table) do
            local new_code = func(t[1])
            permission_table[name][1] = new_code
            SQL.UPDATE {code = new_code} {name = name}
        end
        sql.Commit()
    end

    util.AddNetworkString"JAAS_PermissionClientUpdate"
    JAAS.Hook "Permission" "GlobalCodeUpdate" ["ClientCodeUpdate"] = function (name, old, new)
        net.Start"JAAS_PermissionClientUpdate"
        net.WriteString(name)
        net.WriteFloat(new)
        net.Broadcast()
    end
else
    function permission.registerPermission(name, description)
        if !name or name == "" then
            error("Permission name cannot be empty", 2)
        end
        code = code or 0
        access = access or 0
        permission_table[name] = {code, description, access}
        return permission_local(name)
    end

    MODULE.Handle.Client(function (jaas)
        local PLAYER = jaas.Player()

        function permission.CheckPermissions(...)
            local r = {}
            for i,name in ipairs({...}) do
                print(name, permission_table[name])
                if permission_table[name] then
                    r[i] = bit.band(PLAYER.GetLocalCode(), permission_table[name][1])
                else
                    r[i] = false
                end
            end
            return unpack(r)
        end
    end)

    function permission.GetPermissions()
        return pairs(permission_table)
    end

    hook.Add("InitPostEntity", "JAAS_PermissionInitialSync", function ()
        net.Start"JAAS_PermissionView_Channel"
        net.SendToServer()
    end)

    net.Receive("JAAS_PermissionView_Channel", function ()
        permission_table = net.ReadTable()
    end)

    net.Receive("JAAS_PermissionClientUpdate", function ()
        local name = net.ReadString()
        if permission_table[name] then
            permission_table[name][1] = net.ReadFloat()
        end
    end)
end

MODULE.Access(function (permission_name)
    if permission_name and permission_table[permission_name] ~= nil then
        return permission_local(permission_name)
    end
    return setmetatable({}, {__index = permission, __newindex = function () end, __metatable = "jaas_permission_library"})
end)

dev:isTypeFunc("PermissionObject","jaas_permission_object")
dev:isTypeFunc("PermissionLibrary","jaas_permission_library")

log:registerLog {3, "was", 6, "added", "to", 2, "by", 1} -- [1] Noclip was added to Moderator by secret_survivor
log:registerLog {3, "was", 6, "removed", "from", 2, "by", 1} -- [2] Physgun Player Pickup Allow was removed from Admin by secret_survivor
log:registerLog {3, "has", 6, "default access", "by", 1} -- [3] Can Player Spray has default access by secret_survivor
log:registerLog {1, 6, "attempted", "to add/remove", 3} -- [4] Dempsy40 attempted to add/remove a player Can Suicide
MODULE.Handle.Server(function (jaas)
    local modify_permission = permission.registerPermission("Can Modify Permissions", "Player will be able to change what permissions ranks have access to")
    util.AddNetworkString "JAAS_PermissionModify_Channel"
    /* Permission feedback codes :: 2 Bits
        0 :: Permission Change was a success
        1 :: Code could not be changed
        2 :: Unknown Permission identifier
        3 :: Not part of Access Group
    */
    local sendFeedback = dev.sendUInt("JAAS_PermissionModify_Channel", 2)
    net.Receive("JAAS_PermissionModify_Channel", function (len, ply) -- All changes will be xor
        if modify_permission:codeCheck(ply) then
            local perm = jaas.Permission(net.ReadString())
            local rank = jaas.Rank(net.ReadString())
            local sendCode = sendFeedback(ply)
            if dev.isPermissionObject(perm) and dev.isRankObject(rank) then
                if perm:accessCheck(ply) then
                    if perm:xorCode(rank) then
                        net.Start"JAAS_PermissionModify_Channel"
                        net.WriteUInt(0, 2)
                        net.WriteString(perm:getName())
                        net.WriteFloat(perm:getCode())
                        net.Send(ply)
                        if perm:getCode() == 0 then -- Default access
                            log:Log(3, {player = {ply}, entity = {perm:getName()}})
                            log:superadminChat("%e has default access by %p", perm:getName(), ply:Nick())
                        elseif bit.band(perm:getCode(), rank:getCode()) > 0 then -- Added
                            log:Log(1, {player = {ply}, rank = {rank}, entity = {perm:getName()}})
                            log:superadminChat("%p added %e to %r", ply:Nick(), perm:getName(), rank:getName())
                        else -- Removed
                            log:Log(2, {player = {ply}, rank = {rank}, entity = {perm:getName()}})
                            log:superadminChat("%p removed %e to %r", ply:Nick(), perm:getName(), rank:getName())
                        end
                    else
                        sendCode(1)
                    end
                else
                    sendCode(3)
                end
            else
                sendCode(2)
            end
        else
            local perm = jaas.Permission(net.ReadString())
            if dev.isPermissionObject(perm) then
                log:Log(4, {player = {ply}, entity = {perm:getCode()}})
                log:superadminChat("%p attempted to modify %e", ply:Nick(), perm:getName())
            end
        end
    end)

    util.AddNetworkString "JAAS_PermissionView_Channel"
    net.Receive("JAAS_PermissionView_Channel", function (len, ply)
        net.Start("JAAS_PermissionView_Channel")
        net.WriteTable(permission_table)
        net.Send(ply)
    end)

    util.AddNetworkString "JAAS_PermissionClientCheck"
    net.Receive("JAAS_PermissionClientCheck", function (perm, ply)
        local name = net.ReadString()
        perm = jaas.Permission(name)
        net.Start "JAAS_PermissionClientCheck"
        net.WriteString(name)
        if dev.isPermissionObject(perm) then
            net.WriteBool(perm:codeCheck(ply:getJAASCode()))
        else
            net.WriteBool(false)
        end
        net.Send(ply)
    end)
end)

concommand.Add("JAAS_printPermissions", function ()
    for k,v in pairs(permission_table) do
        print(k, v[1], v[2])
    end
end)

log:print "Module Loaded"