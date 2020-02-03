local permissionTable, permission, permission_local = {}, {["add"]=true, ["exist"]=true, ["get"]=true}, {["getCode"]=true, ["execute"]=true, ["code"]=true}
function permission_local:getCode()
	return self.code
end
setmetatable(permission_local, {
	__call = function(self, func, code)
		rawset(self, "code", code)
		function self:execute(...) func(self, ...) end
		local o = {}
		setmetatable(o, {__index = self})
		return o
	end,
	__newindex = function() end,
	__metatable = nil
})

function permission:add(name, func, code)
	local nullCheck = name and func
	code = code or 0
	local typeName, typeFunc, typeCode = type(name) == "string", type(func) == "function", type(code) == "number"
	if nullCheck and (typeName and typeFunc and typeCode) then --ToDo: SQL implementation and categories
		permissionTable[name] = {func, code}
		return permission_local(func, code)
	elseif !nullCheck then
		error(string.format("The parameter \"%s\" cannot be nil", !name and "name" or "func"))
	else
		local message = typeName and {"name", "string"} or (typeFunc and {"func", "function"}) or {"code", "number"}
		error(string.format("The parameter \"%s\" must be a %s", message[1], message[2]))
	end
end
function permission.exist(name)
	local test, err = pcall(function(name) local p = permissionTable[name].code end, name)
	return not(err and true)
end
function permission.get(name)
	local perm = permissionTable[name]
	return permission_local(perm[1], perm[2])
end
setmetatable(permission, {
	__index = function() end,
	__newindex = function() end,
	__metatable = nil
})
JAASPermission = {}
setmetatable(JAASPermission, {
	__call = function(self, name)
		--ToDo: Add file use log
		if name then
			local perm = permissionTable[name]
			return permission_local(perm[1], perm[2])
		else
			local o = {}
			setmetatable(o, {__index = permission})
			return o
		end
	end,
	__index = function() end,
	__newindex = function() end,
	__metatable = nil
})