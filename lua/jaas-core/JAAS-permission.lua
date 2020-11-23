if JAAS.Permission then return end
local dev = JAAS.Dev()
local log = JAAS.Log("Permission")
if !sql.TableExists("JAAS_permission") and SERVER then
    dev.fQuery("CREATE TABLE JAAS_permission(name TEXT NOT NULL UNIQUE, code UNSIGNED BIG INT NOT NULL DEFAULT 0)")
    dev.fQuery("CREATE UNIQUE INDEX JAAS_permission_name ON JAAS_permission (name)")
end

local permission_table = {} -- [name] = code
local permission_local = {["getCode"] = true, ["setCode"] = true}
local permission = {["registerPermission"] = true}

function permission_local:getCode()
    return permission_table[self.name]
end

function permission_local:setCode(code)
    local q = dev.fQuery("UPDATE JAAS_permission SET code=%u WHERE name='%s'", code, self.name)
    if q then
        local before = permission_table[self.name]
        permission_table[self.name] = code
        JAAS.Hook.Run.Permission(self.name)(before, code)
    end
    return q
end

function permission_local:xorCode(code)
    local before = permission_table[self.name]
    local c_xor = bit.bxor(before, code)
    local q = dev.fQuery("UPDATE JAAS_permission SET code=%u WHERE name='%s'", c_xor, self.name)
    if q then
        permission_table[self.name] = c_xor
        JAAS.Hook.Run.Permission(self.name)(before, c_xor)
    end
    return q
end

function permission_local:codeCheck(code)
    if isnumber(code) then
        if self:getCode() == 0 or bit.band(self:getCode(), code) then
            return true
        end
    elseif dev.isCommandObject(code) or dev.isPermissionObject(code) or dev.isPlayerObject(code) then
        if self:getCode() == 0 or bit.band(self:getCode(), code:getCode()) then
            return true
        end
    end
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

function permission.registerPermission(name, code)
    local q = dev.fQuery("SELECT code FROM JAAS_permission WHERE name='%s'", name)
    if q then
        code = tonumber(q[1]["code"])
    elseif code == nil then
        code = 0
    end
    if !q then
        dev.fQuery("INSERT INTO JAAS_permission (name, code) VALUES ('%s', %u)", name, code)
        q = true
    end
    if q then
        permission_table[name] = code
        return permission_local(name)
    end
end

JAAS.Hook.Add "Rank" "RemovePosition" "Permission_module" (function (func)
    sql.Begin()
    for name, code in pairs(permission_table) do
        local new_code = func(code)
        permission_table[name] = new_code
        dev.fQuery("UPDATE JAAS_permission SET code=%u WHERE name='%s'", new_code, name)
    end
    sql.Commit()
end)

JAAS.Permission = setmetatable({}, {
    __call = function (self, permission_name)
		local f_str, id = log:executionTraceLog("Command")
        if f_str and !dev.verifyFilepath_table(f_str, JAAS.Var.ValidFilepaths) then
            return log:removeTraceLog(id)
        end
        if permission_name and permission_table[permission_name] ~= nil then
            return permission_local(permission_name)
        end
        return setmetatable({}, {__index = permission, __newindex = function () end, __metatable = "jaas_permission_library"})
    end
})

concommand.Add("JAAS_printPermissions", function ()
    for k,v in pairs(permission_table) do
        print(k,v)
    end
end)

log:printLog "Module Loaded"