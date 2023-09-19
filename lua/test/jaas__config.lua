local config_path = "Just-Another-Admin-System/config.txt"

local read_configs = {}

if SERVER then
	util.AddNetworkString("__JAAS_CONFIGS")
	readConfig()
end

local config_module = {}

/*	:: Usage ::

	JAAS.Config("SteamAPIKey")
	JAAS.Config.Color("LogPlayerColour")
	JAAS.Config.Number("RankMaxNumber")
*/
local function Config(name, default, validation)
	if read_configs[name] == nil then
		return default
	end

	local valid,msg = validation(default)
	if !valid then
		error(string.format("Config '%s' failed validation; \"%s\"", name, msg), 1)
	end

	return read_configs[name]
end

function config_module.Color(name, default, validation)
	local r = JAAS.Config(name, default, validation)

	if IsColor(r) then
		return r
	end

	return string.ToColor(r)
end

function config_module.Number(name, default, validation)
	local r = JAAS.Config(name, default, validation)

	if isnumber(r) then
		return r
	end

	return tonumber(r)
end

JAAS.Config = setmetatable({}, {__index = config_module, __call = Config})

local update_client_net

if SERVER then
	local function readConfig()
		if file.Exists(config_path, "lsv") then
			local f = file.Open(config_path, "r", "lsv")
			local char = f:ReadByte()

			local function NextChar()
				char = f:ReadByte()
			end

			/*
				[0] NULL
				[1] State = SHARED, SERVER, or CLIENT
				[2] Setter = :
				[3] Value
				[5] NEWLINE = CRLF or LF
				[6] EOL

				Example: {value = "SHARED", id = 1}
				State Value Setter Value (NEWLINE | EOL)
			*/
			local lastToken,token
			local captureSpaces = false

			local function NextToken()
				lastToken = token
				local value,id = "",0

				while true do
					if f:EndOfFile() then
						id = 6

						break
					elseif isWhiteSpace(char) then
						if byte == 13 or byte == 10 then
							id = 5

							if byte == 13 then
								NextChar()
							end

							break
						end
					elseif char == 58 then
						id = 2

						break
					elseif (char >= 65 and char <= 90) or (char >= 97 and char <= 122) or (char >= 48 and char <= 57) then
						local v = ""

						while !isWhiteSpace(char, captureSpaces) do
							v = v .. string.char(char)

							NextChar()
						end

						value = v

						if v == "SHARED" or v == "SERVER" or v == "CLIENT" then
							id = 1
						else
							id = 3
						end

						break
					else
						error("Unrecognised Symbol", 3)
					end

					NextChar()
				end

				token = {value = string.Trim(value), id = id}
			end

			local function ConfigValue()
				local state // 0 = Shared, 1 = Server, 2 = Client
				local key
				local value
				local eof = false

				assert(token.id == 1, "Expected State")

				if token.value == "SHARED" then
					state = 0
				elseif token.value == "SERVER" then
					state = 1
				elseif token.value == "CLIENT" then
					state = 2
				end

				NextToken()
				assert(token.id == 3, "Expected Name")

				key = token.value

				NextToken()
				assert(token.id == 2, "Expected ':'")

				captureSpaces = true

				NextToken()
				assert(token.id == 3, "Expected Value")

				value = token.value
				captureSpaces = false

				NextToken()
				assert(token.id == 5 or token.id == 6, "Expected Newline or EOF")

				if token.id == 6 then
					eof = true
				end

				return eof,state,key,value
			end

			local client_config_num = 0
			local client_configs = {}

			while true do
				NextToken()

				local eof,state,key,value = ConfigValue()

				if state == 0 or state == 2 then
					client_config_num = 1 + client_config_num
					client_configs[1 + #client_configs] = {key,value}
				end

				if state == 0 or state == 1 then
					read_configs[key] = value
				end

				if eof then
					break
				end
			end

			if client_config_num > 0 then
				update_client_net = function (ply)
					net.Start("__JAAS_CONFIGS")
					net.WriteUInt(client_config_num, 16)

					for k,v in ipairs(client_configs) do
						net.WriteString(v[1]) // Key
						net.WriteString(v[2]) // Value
					end

					net.Send(ply)
				end
			end
		end
	end

	JAAS.Hook.Register("System", "Connect", "__JAAS_CONFIG", function (ply)
		update_client_net(ply)
	end)
end

if CLIENT then
	net.Receive("__JAAS_CONFIGS", function ()
		local count = net.ReadUInt(16)

		for i=1,count do
			local key = net.ReadString()

			read_configs[key] = net.ReadString()
		end
	end)
end

/*
	CLIENT LogPlayerColour : 68  84  106
	SERVER SteamAPIKey : asfm53-35o-r3f-faw-fagdgb
*/