local MODULE, log, dev, SQL = JAAS:RegisterModule "Permission"
SQL = SQL"JAAS_permission"

if SERVER then
    SQL.CREATE.TABLE {name = "NOT NULL UNIQUE", code = "UNSIGNED BIGINT NOT NULL DEFAULT 0"}
    SQL.CREATE.INDEX "JAAS_permission_name" "name"
end

local permission_table = permission_table or {} -- [name] = {code, description}
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
    local q = SQL.UPDATE {code = code} {name = self.name}
    if q then
        local before = permission_table[self.name][1]
        permission_table[self.name][1] = code
        JAAS.Hook.Run.Permission(self.name)(before, code)
    end
    return q
end

function permission_local:xorCode(code)
    local before = permission_table[self.name][1]
    local c_xor = bit.bxor(before, code)
    local q = SQL.UPDATE {code = c_xor} {name = self.name}
    if q then
        permission_table[self.name][1] = c_xor
        JAAS.Hook.Run.Permission(self.name)(before, c_xor)
    end
    return q
end

function permission_local:codeCheck(code)
    if self:defaultAccess() then
        return true
    else
        if isnumber(code) then
            if bit.band(self:getCode(), code) then
                return true
            end
        elseif dev.isCommandObject(code) or dev.isPermissionObject(code) or dev.isPlayerObject(code) then
            if bit.band(self:getCode(), code:getCode()) then
                return true
            end
        end
    end
    return false
end

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

function permission.registerPermission(name, description, code)
    local q = SQL.SELECT "code" {name = name}
    if q then
        code = tonumber(q["code"])
    elseif code == nil then
        code = 0
    end
    if !q then
        SQL.INSERT {name = name, code = code}
        q = true
    end
    if q then
        permission_table[name] = {code, description}
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
end, true)

concommand.Add("JAAS_printPermissions", function ()
    for k,v in pairs(permission_table) do
        print(k, v[1], v[2])
    end
end)

log:printLog "Module Loaded"