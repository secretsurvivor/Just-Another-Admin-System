local query, format, type = sql.Query, string.format, type
local dev, dev_string = {
	function (s, ...) -- fQuery
		return query(format(s, ...))
	end,
	function (...) -- dataTypeCheck
		local varArgs = {...}
		if varArgs and (#varArgs) % 2 == 0 then
			for i=1, #varArgs, 2 do
				if type(varArgs[1 + i]) == varArgs[i] then
					return true
				else
					error("Invalid Datatype", 2)
				end
			end
		end
	end,
	function (table_, key, key2) -- keyExists
		if !table_ and !key then return end
		if key2 then
			return pcall(function(_,__) local ___ = table_[_][__] end, key, key2)
		end
		return !pcall(function(_) local __ = table_[_] end, key)
	end
},
{
	"fQuery",
	"dataTypeCheck",
	"keyExists"
}
QUERY, TYPECHECK, KEYEXIST = (function ()
	local v = {}
	for i=0, #dev-1 do
		table.insert(v, bit.lshift(1, i))
	end
	return unpack(v)
end)()

JAAS.Dev = setmetatable({}, {
	__concat = function(left, right)
		local v = {}
		for i=0, #dev-1 do
			if bit.band(right, bit.lshift(1, i)) != 0 then
				v[1 + i] = dev[1 + i]
			end
		end
		if #v == 1 then
			return v[1]
		end
		return v
	end,
	__call = function ()
		local a = {}
		for i, v in ipairs(dev) do
			a[dev_string[i]] = v
		end
	return a
end
})

print "JAAS Developer Module - Loaded"