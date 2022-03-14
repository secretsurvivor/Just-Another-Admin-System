local MODULE,LOG,J_NET,CONFIG = JAAS:Module("GUI", "Client")

JAAS:Configs{
	JAAS_INTERFACE = ""
}

local interface_list = {}
local tab_list = {}

local interface_object = {}

function interface_object:OpenMenu()
	error("Function not implemented")
end

function interface_object:CloseMenu()
	error("Function not implemented")
end

function interface_object:OpenTab(args, args_str, cmd_str)
	error("Function not implemented")
end

function interface_object:AddCommand(name, callback)
	self.commands[name] = callback
end

function interface_object:ReceiveRegisteredTabs(tab_object)
	error("Function not implemented")
end

local tab_object = {}

function tab_object:GetName()
	return self.name
end

function tab_object:SetIconPath(imagePath)
	self.imagepath = imagePath
end

function tab_object:GetIconPath()
	return self.imagepath
end

function tab_object:SetParent()
	error("Function not implemented")
end

local function TabObject(name)
	return Object(tab_object, {name = name})
end

local current_interface_object = nil

function MODULE:RegisterInterface(interface_name, authors, version)
	interface_list[interface_name] = Object(interface_object, {commands = {}})

	return interface_list[interface_name]
end

function MODULE:RegisterTab(tab_name)
	tab_list[1 + #tab_list] = TabObject(tab_name)

	return tab_list[1 + #tab_list]
end

function MODULE.Client:Post()
	if interface_list[CONFIG.JAAS_INTERFACE] != nil then
		current_interface_object = interface_list[CONFIG.JAAS_INTERFACE]

		for k,tab_object in ipairs(tab_list) do
			current_interface_object:ReceiveRegisteredTabs(tab_object)
		end
	else
		-- TODO : Uncomment when Interface exists
		--error("Interface Set in Configs has not been Registered; this interface name may have been a missspelling, double check the name before overwriting Configurations")
	end
end

concommand.Add("+jaas", function ()
	current_interface_object:OpenMenu()
end, nil, "Opens JAAS Interface", FCVAR_LUA_CLIENT)

concommand.Add("-jaas", function ()
	current_interface_object:CloseMenu()
end, nil, "Closes JAAS Interface", FCVAR_LUA_CLIENT)

concommand.Add("jaas_open_tab", function (ply, cmd, args, argStr)
	current_interface_object:OpenTab(args, argStr, cmd)
end, nil, "Opens Certain Tab in JAAS Interface", FCVAR_LUA_CLIENT)

concommand.Add("jaas_interface_cmd", function (ply, cmd, args, argStr)
	if current_interface_object.commands[args[1]] != nil then
		local new_args = table.remove(args, 1)
		current_interface_object.commands[args[1]](ply, cmd, new_args, table.concat(new_args, " "))
	else
		ErrorNoHalt("Unknown JAAS Interface Command")
	end
end, nil, "Executes JAAS Interface Command", FCVAR_LUA_CLIENT)