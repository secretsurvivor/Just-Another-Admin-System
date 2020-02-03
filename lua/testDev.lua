local functionEx = function(x, ...)
	local args = {...}
	return function(f, ...)
		local overload = {...}
		return function(...)
			
			f(...)
		end
	end
end

local add = functionEx{"number", "number"}(
function(a, b) 
	return a + b
end)()
print(add(1, 2))