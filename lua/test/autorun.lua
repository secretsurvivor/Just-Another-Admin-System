

do -- Include Functions
	local i,c = include,AddCSLuaFile

	include = setmetatable({}, {__call = function (self, _)
		if !istable(_) then
			return i(_)
		end

		for __,_ in ipairs(_) do
			i(_)
		end
	end})

	local function AddCSLuaFile(_)
		if !istable(_) then
			return c(_)
		end

		for __,_ in ipairs(_) do
			c(_)
		end
	end

	function include.Server(_)
		if SERVER then
			include(_)
		end
	end

	function include.Client(_)
		AddCSLuaFile(_)

		if CLIENT then
			include(_)
		end
	end

	function include.Shared(_)
		AddCSLuaFile(_)
		include(_)
	end
end

// Serves as a way to change the file locations easily
local Module_Folders = {
	["MODULE"] = "test",
	["SHARED"] = "",
	["ADDON"] = ""
}

// Everything will be expected to be shared
local function IncludeFile(path, name)
	include.Shared(Module_Folders[path] .. "/" .. name)
end

IncludeFile("MODULE", "jaas_shared.lua")

/*
	JAAS Checklist:

	Permissions - Not Complete
		- Missing Logging
	Commands - Not Started
	Ranks - Not Complete
		- Missing Logging
		- Missing Group Check
	Player - Not Complete
		- Missing some Logging
	Groups - Not Complete
		- Missing SQL Modification Code
		- Missing Object code
		- Missing Global code
	GUI Handler - Not Started
	Interface - Not Started

	Form Builder Language - Not Complete
		- Missing Form Builder
		- Missing Class Parsing
		- Missing Font Parsing
	Paint Functions - Not Complete
		- Missing Function Code
	JSL (Just Some Language) - Not Started
	Autorun - Not Complete
		- Missing Module Includes
*/








local c = 0
local reverse = false

for i=1,9 do
	if (reverse) then
		c = c - 1
	else
		c = c + 1
	end

	if (c > 5) then
		reverse = true
		c = c - 2
	end

	print( string.rep("*", c) )
end












