local whitespace = {
	[32] = true,
	[9] = true
}

/* Plain Data - Token type : 1
	String = 1
	Positive_Int = 2
	Negative_Int = 3
	Decimal = 4
	Date = 5
	Variable = 6
*/

local keywords = { // Token type : 2
	ARGUMENT = 1,
	NEW = 2,
	COMPRESS = 3,
	CLEAR = 4, // Modifier keyword
	CURRENT_DATE = 5,
	["if"] = 6,
	["for"] = 7
}

local symbols = { // Token type : 3
	[34] = 1, // "
	[35] = 2, // #
	[38] = 3, // &
	[40] = 4, // (
	[41] = 5, // )
	[42] = 6, // *
	[43] = 7, // +
	[44] = 8, // ,
	[45] = 9, // -
	[46] = 10, // .
	[47] = 11, // /
	[58] = 12, // :
	[61] = 13, // =
	[62] = 14, // >
	[91] = 15, // [
	[93] = 16, // ]
	[123] = 17, // {
	[125] = 18, // }
	[126] = 19 // ~
}

local data_type_keywords = { // Token type : 4
	String = 1,
	Int = 2,
	UInt = 3,
	Float = 4,
	Command = 5,
	Permission = 6,
	Rank = 7,
	Group = 8,
	Player = 9
}

local object_data_type_keywords = { // Token type : 5
	FILE = 1,
	DATE = 2,
	["::"] = 3
}

local sql_keywords = { // Token type : 6
	P = 1,
	R = 2,
	C = 3,
	G = 4
}

local file_functions = { // Token type : 7
	SAVE = 1, // Entry point
	WRITE = 2, // Entry point
	EXISTS = 3, // Get function
	ARCHIVE = 4 // Transform function
}

local file_archive_functions = { // Token type : 8
	INSERT = 1,
	COMPRESS = 2
}

local date_functions = { // Token type : 9
	FORMAT = 1
}

local jaas_collections = { // Token type : 10
	COMMANDS = 11,
	PERMISSIONS = 12,
	GROUPS = 13,
	LOGS = 14
}

local function InterpretFile(f)
	local current_line = 1
	local character_position = 1
	local syntax_errors = {}

	local function NewLine()
		current_line = 1 + current_line
		character_position = 0
	end

	local function AddError(str, ...)
		syntax_errors[1 + #syntax_errors] = string.format("Line - %s, Char - %s :: %s", current_line, character_position, string.format(str, ...))
	end

	local read_byte = f:ReadByte()

	local function NextByte()
		read_byte = f:ReadByte()
		character_position = 1 + character_position
	end

	local function GetChar()
		return string.char(read_byte)
	end

	local current_token
	local last_token
	local last_last_token

	local function NextToken()
		last_last_token = last_token
		last_token = current_token

		current_token = {
			token_type = -1
			type = -1
			data = nil
		}

		local active = true

		while active do
			if whitespace[read_byte] then -- Whitespace
			elseif read_byte == 13 then -- Carriage Return (Mac)
				NextByte()
				NewLine()

				if read_byte != 10 then -- Line Feed (Windows)
					break
				end
			elseif read_byte == 10 then -- Line Feed (Unix)
				NewLine()
			elseif read_byte >= 48 and read_byte <= 57 then -- Number
				current_token.token_type = 1

				local string_value = ""
				local decimal = false
				local date_value = {}
				local date = 0
				local final_year_num = 0

				while true do
					if read_byte >= 48 and read_byte <= 57 then
						string_value = string_value + GetChar()

						if date == 2 then
							final_year_num = 1 + final_year_num

							if final_year_num == 4 then
								date_value.year = tonumber(string_value)
								break
							end
						end
					elseif read_byte == 46 and not (decimal or date == 0) then
						decimal = true
						current_token.type = 4
						string_value = string_value + GetChar()
					elseif read_byte == 124 and not (decimal or date == 2) then
						date = 1 + date
						if date == 1 then
							current_token.type = 5
							date_value.day = tonumber(string_value)
						elseif date == 2 then
							date_value.month = tonumber(string_value)
						else
							AddError("Dates cannot have more than 1 '|'")
							NextByte()
							break
						end
						string_value = ""
					elseif whitespace[read_byte] then
						if date > 0 and final_year_num < 4 then
							AddError("Date years must have 4 integers")
						end
						break
					else
						AddError("Unexpected character '%s'", GetChar())
						NextByte()
						break
					end
					NextByte()
				end

				if date > 0 then
					current_token.data = date_value
				else
					current_token.data = tonumber(string_value)
				end
				break
			elseif (read_byte >= 65 and read_byte <= 90) or (read_byte >= 97 and read_byte <= 122) then -- Letter
				local string_value = ""

				while true do
					if (read_byte >= 65 and read_byte <= 90) or (read_byte >= 97 and read_byte <= 122) or (read_byte >= 48 and read_byte <= 57) then
						string_value = string_value + GetChar()
					elseif whitespace[read_byte] then
						break
					else
						AddError("Unexpected character '%s'", GetChar())
						NextByte()
						break
					end
					NextByte()
				end

				if keywords[string_value] != nil then
					current_token.token_type = 2
					current_token.type = keywords[string_value]

				elseif data_type_keywords[string_value] != nil then
					current_token.token_type = 4
					current_token.type = data_type_keywords[string_value]

				elseif object_data_type_keywords[string_value] != nil then
					current_token.token_type = 5
					current_token.type = object_data_type_keywords[string_value]

				elseif sql_keywords[string_value] != nil then
					current_token.token_type = 6
					current_token.type = sql_keywords[string_value]

					NextByte()

					if read_byte == 91 then
						local header = {}
						local i = 0

						while true do
							i = 1 + i
							NextByte()
							if read_byte == 93 then
								break
							else
								header[i] = read_byte
							end
						end

						local string_value = ""

						while true do

						end
					else
						AddError("Expected '['; This function should not be written by hand")
						NextByte()
						break
					end

				elseif file_functions[string_value] != nil then
					current_token.token_type = 7
					current_token.type = file_functions[string_value]

				elseif file_archive_functions[string_value] != nil then
					current_token.token_type = 8
					current_token.type = file_archive_functions[string_value]

				elseif date_functions[string_value] != nil then
					current_token.token_type = 9
					current_token.type = date_functions[string_value]

				elseif jaas_collections[string_value] != nil then
					current_token.token_type = 10
					current_token.type = jaas_collections[string_value]
				else
					current_token.token_type = 1
					current_token.type = 6
					current_token.data = string_value
				end
				active = false
			elseif symbols[read_byte] != nil then -- Symbols
			else
				AddError("Invalid character '%s' ( %s )", GetChar(), read_byte)
				active = false
			end

			NextByte()
		end
	end
end