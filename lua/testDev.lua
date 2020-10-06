local functionEx = function(x, ...)
	local args = {...}
	return function(f, ...)
		local overload = {...}
		return function(...)
			
			f(...)
		end
	end
end

local query = sql.Query
local format = string.format
function fQuery(s, ...)
	return query(format(s, ...))
end