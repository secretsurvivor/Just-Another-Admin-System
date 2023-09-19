/*
Frame LogViewerFrame (Width = 0.21, Height = 0.58, Class = JAASInterfaceDefault)
	Label logDate ()
	Panel filterPanel ()
		TimestampSelector timeSelector ()
		Dropdown headerFilter ()
		Dropdown playerFilter ()
		Dropdown rankFilter ()
		Dropdown actionFilter ()
	LogViewer viewer ()

Tokens:
	Value - 1 : Any value
	OpenProperty  - 2
	CloseProperty - 3
	Seperator - 4
	Setter - 5
	Tab - 6 : Number len
	TemplateModifier - 7
	[Newline] - 8
	OpenParameter - 9
	CloseParameter - 10
	SetPanel - 11
	AddPanel - 12
	[EOF] - -1

Panel =
	[Tab]? [Value] [TemplateModifier]? [Value] ( [OpenProperty] [Property] [CloseProperty] )? ( [Newline] | [EOF] )

Property =
	[Value] |
	[Value] [Setter] [Value] |
	[Value] [Setter] [Value] [Seperator] [Property] |
	[Value] [Setter] [OpenParameter] [PropertyParameters] [CloseParameter] |
	[Value] [Setter] [OpenParameter] [PropertyParameters] [CloseParameter] [Seperator] [Property]

PropertyParameters =
	[Value] |
	( [Value] [Seperator] [PropertyParameters] )


Frame = DFrame
Panel = DPanel
Label = DLabel
EditableLabel = DLabelEditable
Menu = DMenu
TextEntry = DTextEntry
Tooltip = DTooltip
Tree = DTree
VerticalDivider = DVerticalDivider
Button = DButton
Binder = DBinder
Checkbox = DCheckbox
CheckboxLabel = DCheckboxLabel
CollapsiblePanel = DCollapsibleCategory
HorizontalDivider = DHorizontalDivider
ColourMixer = DColorMixer
Combobox = DComboBox
ScrollPanel = DScrollPanel
HScrollPanel = DHorizontalScroller
IconLayout = DIconLayout
*/

local function BuildForm(filename)
end

local function FormParser(f, filename)
	local line,pos = 1,1
	local byte = f:ReadByte()

	local function ThrowError(msg)
		error(string.format("%s : %s | Line : %s, Pos : %s", filename, msg, line, pos), 4)
	end

	local function NextChar()
		byte = f:ReadByte()

		pos = 1 + pos
	end

	local lastToken,token

	local function AssertToken(id, msg)
		if token.id != id then
			ThrowError(msg)
		end
	end

	local function NextToken()
		lastToken = token
		token = {
			id = nil,
			value = nil
		}

		if byte == nil then
			token.id = -1
		elseif byte == 13 or byte == 10 then // Newline; Windows, Unix, Mac
			token.id = 8
			line = 1 + line
			pos = 0

			if byte == 13 then
				NextChar()

				if byte != 10 then
					return
				end
			end
		elseif byte == 9 then
			token.id = 6
			token.value = 1
			NextChar()

			while true do
				if byte != 9 then
					return
				end

				token.value = 1 + token.value
				NextChar()
			end
		elseif byte == 32 then
			NextChar()
			while true do
				if byte != 32 then
					break
				end
				NextChar()
			end
			NextToken()
			return
		elseif (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122) then
			token.id = 1
			token.value = string.char(byte)
			NextChar()

			while true do
				if !((byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122)) then
					return
				end

				token.value = token.value .. string.char(byte)
				NextChar()
			end
		elseif byte == 44 then // ,
			token.id = 4
		elseif byte == 40 then // (
			token.id = 2
		elseif byte == 41 then // )
			token.id = 3
		elseif byte == 35 then // #
			token.id = 7
		elseif byte == 123 then // {
			token.id = 9
		elseif byte == 125 then // }
			token.id = 10
		elseif byte == 94 then // ^
			token.id = 11
		elseif byte == 43 then // +
			token.id = 12
		else
			ThrowError("Unexpected Symbol")
		end

		NextChar()
	end

	local panelStack = util.Stack()
	local lastTabAmt = 0
	local lastPanel

	local panel_data = {}
	local panel_names = {}

	local function ReadPanel()
		NextToken()

		local panel_info = {
			className = nil,
			name = nil,
			parent = nil,
			template = false,
			internalPanel = false,
			addPanel = false,
			panel = {}
			properties = {} // {{name, value}*}
		}

		if token.id = 7 then// Tab Token
			local difference = token.value - lastTabAmt

			if difference >= -1 and difference <= 1 then
				if lastTabAmt > 0 then //
					if difference == -1 then
						panelStack:Pop()
					elseif difference == 1 then
						if lastPanel == nil then
							ThrowError("Invalid amount of Tabs inserted; None should be present")
						end

						panelStack:Push(lastPanel)
					else // == 0
						panel_info.parent = panelStack:Top().name
					end

					lastTabAmt = lastTabAmt + difference
				else
					ThrowError("Unexpected error")
				end
			else
				ThrowError("Invalid amount of Tabs inserted")
			end

			NextToken()
		end

		AssertToken(1, "Expected Class Token")
		token.value = string.lower(token.value)

		local classes = { // Ordered Alphabetically, should be ordered by usage amount
			DCheckbox = {"checkbox"},
			DCheckboxLabel = {"checkboxlabel"},
			DCollapsibleCategory = {"collapsiblepanel", internalPanels = {"header", "content"}},
			DColorMixer = {"colourmixer"},
			DComboBox = {"combobox"},
			DBinder = {"binder"},
			DButton = {"button"},
			DLabelEditable = {"editablelabel"},
			DFrame = {"frame"},
			DHorizontalDivider = {"horizontaldivider", internalPanels = {"left", "right"}},
			DIconLayout = {"iconlayout"},
			DLabel = {"label"},
			DMenu = {"menu"},
			DPanel = {"panel"},
			DTextEntry = {"textentry"},
//			DTooltip = {"tooltip"},
			DTree = {"tree"},
			DScrollPanel = {"scrollpanel"},
			DVerticalDivider = {"verticaldivider"}
		}

		for k,v in pairs(classes) do
			if string.StartsWith(v[1], token.value) then
				panel_info.className = k
				break
			end
		end

		if panel_info.className == nil then
			ThrowError("Unknown Classname")
		end

		NextToken()

		// Panel Modifier

		if panel_info.parent != nil and classes[panel_info.parent.name].internalPanels != nil then
			AssertToken(11, "Expected Internal Panel Token")

			if panel_info.className != "DPanel" then
				ThrowError("Expected Panel")
			end

			panel_info.internalPanel = true
		end

		if token.id != 1 then
			-- TODO Implement Add Panel Token
			if token.id == 9 or token.id == 11 or token.id == 12 then
				if token.id == 9 then // Template Panel
					panel_info.template = true
				end

				NextToken()
			else
				ThrowError("Unexpected Token; Panel Modifiers and Name Token only")
			end
		end

		AssertToken(1, "Expected Name Token")

		if panel_info.template then
			if classes[panel_info.parent.name].internalPanels != nil then
				local validPanelName = false

				for k,v in ipairs(classes[panel_info.parent.name].internalPanels) do
					if token.value == v then
						validPanelName = true
						break
					end
				end

				if !validPanelName then
					ThrowError("Invalid Template Name")
				end

				-- TODO Finish whatever this is meant to be
			else
				ThrowError("Expected Panel")
			end
		else
			if panel_names[token.value]
			if panel_data[token.value] != nil then
				ThrowError("Name must be unique")
			end

			panel_info.name = token.value
		end

		NextToken()

		if token.id == 2 then
			panel_info.properties = ReadProperty(panel_info.className)
		end

		if token.id != 9 or token.id != -1 then // Expected Newline or EOF
			ThrowError("Expected Newline")
		end

		if panel_info.template then
			lastPanel.panel[panel_info.name] = panel_info
		else
			panel_data[panel_info.name] = panel_info
		end

		lastPanel = panel_info
	end

	local function ReadProperty(classname)
		// Properties
		local global_properties = {
			pwidth = {method = "SetWidth", convert = tonumber, argNum = 1},
			pheight = {method = "SetHeight", convert = tonumber, argNum = 1},
			px = {method = "SetX", convert = tonumber, argNum = 1},
			py = {method = "SetY", convert = tonumber, argNum = 1},
			z = {method = "SetZPos", convert = tonumber, argNum = 1},
			enabled = {method = "SetEnabled", convert = tobool, argNum = 1},
			centre = {custom = function (p, v)
				if v == nil then
					p:Center()
				else
					if v == "vertical" then
						p:CenterVertical()
					else // == "horizontal"
						p:CenterHorizontal()
					end
				end
			end, enum = {"vertical", "horizontal"}, argNum = 1},
			dock = {method = "Dock", enum = {"fill", "left", "right", "top", "bottom"}, argNum = 1},
			width = {custom = function (p, v)
				local wide = (p:GetParent() and p:GetParent():GetWide()) or ScrW()
				p:SetWidth(wide*v)
			end, convert = tonumber, argNum = 1},
			height = {custom = function (p, v)
				local tall = (p:GetParent() and p:GetParent():GetTall()) or ScrH()
				p:SetHeight(tall*v)
			end, convert = tonumber, argNum = 1},
			x = {custom = function (p, v)
				local wide = (p:GetParent() and p:GetParent():GetWide()) or ScrW()
				p:SetX(wide*v)
			end, convert = tonumber, argNum = 1},
			y = {custom = function (p, v)
				local tall = (p:GetParent() and p:GetParent():GetTall()) or ScrH()
				p:SetY(tall*v)
			end, convert = tonumber, argNum = 1},
			margin = {method = "DockMargin", convert = tonumber, argNum = 4},
			padding = {method = "DockPadding", convert = tonumber, argNum = 4},
			tooltip = {method = "SetTooltip", argNum = 1},
			visible = {method = "SetVisible", convert = tobool, argNum = 1},
			class = {parserMethod = "class", argNum = 1}
		}

		// Alias properties
		global_properties.pw = global_properties.pwidth
		global_properties.ph = global_properties.pheight
		global_properties.w = global_properties.width
		global_properties.h = global_properties.height

		local class_based_properties = {
			DCheckBox = {
				checked = {method = "SetChecked", convert = tobool, argNum = 1}
			},
			DCheckBoxLabel = {},
			DCollapsibleCategory = {
				expanded = {method = "SetExpanded", convert = tobool, argNum = 1}
			},
			DComboBox = {
				sortitems = {method = "SetSortItems", convert = tobool, argNum = 1},
				title = {method = "SetValue", argNum = 1}
			},
			DFrame = {
				title = {method = "SetTitle", argNum = 1},
				shadow = {method = "SetPaintShadow", convert = tobool, argNum = 1},
				ismenu = {method = "SetIsMenu", convert = tobool, argNum = 1},
				draggable = {method = "SetDraggable", convert = tobool, argNum = 1},
				deleteonclose = {method = "SetDeleteOnClose", convert = tobool, argNum = 1},
				blurbackground = {method = "SetBackgroundBlur", convert = tobool, argNum = 1},
				minheight = {method = "SetMinHeight", convert = tonumber, argNum = 1},
				minwidth = {method = "SetMinWidth", convert = tonumber, argNum = 1},
				screenlock = {method = "SetScreenLock", convert = tobool, argNum = 1},
				sizeable = {method = "SetSizable", convert = tobool, argNum = 1},
				closebutton = {method = "ShowCloseButton", convert = tobool, argNum = 1}
			}
		}

		// Alias/Multiclass Properties
		class_based_properties.DCheckBoxLabel.checked = class_based_properties.DCheckBox.checked

		if class_based_properties[classname] != nil then // Add Class Based properties to the properties table
			for k,v in pairs(class_based_properties[classname]) do
				global_properties[k] = v
			end
		end

		local props = {}

		local function addProp(name, value)
			global_properties[name].value = value
			props[1 + #props] = global_properties[name]
		end

		// [Value] [CloseProperty]
		// [Value] [Seperator] [Property]
		// [Value] [Setter] [Value] [CloseProperty]
		// [Value] [Setter] [Value] [Seperator] [Property]
		// [Value] [Setter] [OpenParameter] [PropertyParameters] [CloseParameter] [CloseProperty]
		// [Value] [Setter] [OpenParameter] [PropertyParameters] [CloseParameter] [Seperator] [Property]

		local function readProp()
			nextToken()

			if token.id == 3 then
				return
			end

			AssertToken(1, "Expected Value Token")

			local name = string.lower(token.value)
			local argNum

			if global_properties[name] == nil then
				ThrowError("Invalid Property Name")
			else
				argNum = global_properties[name].argNum
			end

			nextToken()

			if argNum == 0 then
				addProp(name)

				if token.id == 3 then // End of Properties
					return props // [Value] [CloseProperty]
				elseif token.id == 4 then // Seperator
					nextToken()

					readProp() // [Value] [Seperator] [Property]
				else
					ThrowError("Expected either a Seperator or CloseProperty Token")
				end
			else
				AssertToken(5, "Expected Setter Token")

				nextToken()

				if token.id == 1 then // [Value]
					addProp(name, token.value)

					nextToken()

					if token.id == 3 then // End of Properties
						return props // [Value] [Setter] [Value] [CloseProperty]
					elseif token.id == 4 then // Seperator
						readProp() // [Value] [Setter] [Value] [Seperator] [Property]
					else
						ThrowError("Expected either a Seperator or CloseProperty Token")
					end
				elseif token.id == 2 then // [OpenParameter]
					nextToken()

					local args = readPropParam()

					if #args != argNum then
						ThrowError("Expected " .. argNum .. " arguments")
					end

					addProp(name, args)

					nextToken()

					if token.id == 3 then // End of Properties
						return props // [Value] [Setter] [OpenParameter] [PropertyParameters] [CloseParameter] [CloseProperty]
					elseif token.id == 4 then // Seperator
						nextToken()

						readProp() // [Value] [Setter] [OpenParameter] [PropertyParameters] [CloseParameter] [Seperator] [Property]
					else
						ThrowError("Expected either a Seperator or CloseProperty Token")
					end
				else
					ThrowError("Expected either a Value or OpenParameter Token")
				end
			end
		end

		local function readPropParam()
			local args = {}

			// [Value] [CloseParameter]
			// [Value] [Seperator] [PropertyParameters]

			local function read()
				nextToken()

				AssertToken(1, "Expected Value Token")

				args[1 + #args] = token.value

				nextToken()

				if token.id == 3 then // [CloseParameter]
					return args
				elseif token.id == 4 then // [Seperator]
					nextToken()

					read()
				else
					ThrowError("Expected either a Value or CloseParameter Token")
				end
			end

			return read()
		end

		return readProp()
	end

	while token.id != -1 do
		ReadPanel()
	end

	return panel_data
end

-- TODO Implement Class parsing
-- TODO Implement Font parsing

/*

CLASS JAASInterfaceDefault


*/

local function ClassParser(f, filename)
	local line,pos = 1,1
	local byte = f:ReadByte()

	local function ThrowError(msg)
		error(string.format("%s : %s | Line : %s, Pos : %s", filename, msg, line, pos), 4)
	end

	local function NextChar()
		byte = f:ReadByte()

		pos = 1 + pos
	end

	local lastToken,token

	local function AssertToken(id, msg)
		if token.id != id then
			ThrowError(msg)
		end
	end

	local function NextToken()
	end


end