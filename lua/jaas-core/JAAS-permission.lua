local MODULE, log, dev, SQL = JAAS:RegisterModule "Permission"
SQL = SQL"JAAS_permission"

if !SQL.EXIST and SERVER then
    SQL.CREATE.TABLE {name = "NOT NULL UNIQUE", code = "UNSIGNED BIGINT NOT NULL DEFAULT 0", access_group = "UNSIGNED INT DEFAULT 0"}
    SQL.CREATE.INDEX "JAAS_permission_name" "name"
end

local permission_table = permission_table or {} -- [name] = {code, description, access}
local permission_local = {["getCode"] = true, ["setCode"] = true, ["getName"] = true, ["xorCode"] = true}
local permission = {["registerPermission"] = true}

function permission_local:getName()
    return self.name
end

function permission_local:getCode()
    return permission_table[self.name][1]
end

function permission_local:getDescription()
    return permission_table[self.name][2]
end

function permission_local:setCode(code)
    if SQL.UPDATE {code = code} {name = self.name} then
        local before = permission_table[self.name][1]
        permission_table[self.name][1] = code
        JAAS.Hook.Run.Permission(self.name)(before, code)
        return true
    end
    return false
end

function permission_local:xorCode(code)
    local before = permission_table[self.name][1]
    local c_xor = bit.bxor(before, code)
    if SQL.UPDATE {code = c_xor} {name = self.name} then
        permission_table[self.name][1] = c_xor
        JAAS.Hook.Run.Permission(self.name)(before, c_xor)
        return true
    end
    return false
end

function permission_local:getAccess()
    return permission_table[self.name][3]
end

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

function permission.registerPermission(name, description, code, access)
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

MODULE.Access(function (permission_name)
    if permission_name and permission_table[permission_name] ~= nil then
        return permission_local(permission_name)
    end
    return setmetatable({}, {__index = permission, __newindex = function () end, __metatable = "jaas_permission_library"})
end)

dev:isTypeFunc("PermissionObject","jaas_permission_object")
dev:isTypeFunc("PermissionLibrary","jaas_permission_library")

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
        local name = net.ReadString()
        local code = net.ReadUInt(64)
        local perm, sendCode = jaas.Permission(name), sendFeedback(ply)
        if dev.isPermissionObject(perm) then
            if perm:accessCheck(ply) then
                if perm:xorCode(code) then
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

MODULE.Handle.Server(function (jaas)
    util.AddNetworkString "JAAS_PermissionClientCheck"
    net.Receive("JAAS_PermissionClientCheck", function (perm, ply)
        local name = net.ReadString()
        perm = jaas.Permission(name)
        if dev.isPermissionObject(perm) then
            net.Start "JAAS_PermissionClientCheck"
            net.WriteString(name)
            net.WriteBool(perm:codeCheck(ply:getJAASCode()))
            net.Send(ply)
        end
    end)
end)

concommand.Add("JAAS_printPermissions", function ()
    for k,v in pairs(permission_table) do
        print(k, v[1], v[2])
    end
end)

log:printLog "Module Loaded"