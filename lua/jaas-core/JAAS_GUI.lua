local MODULE,LOG,J_NET,CONFIG = JAAS:Module("GUI", "Client")

JAAS:Configs{
	JAAS_INTERFACE = "Default::JUI"
}

local interface_list = {}
local interface_information = {}
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

function interface_object:Post()
	error("Function not implemented")
end

local tab_object = {}

function tab_object:GetName()
	return self.name
end

function tab_object:GetOrderNum()
	return self.order
end

function tab_object:GetColor()
	return self.color
end

function tab_object:CanOpenedAlt()
	return self.can_opened_alt
end

function tab_object:GetPanel()
	error("Get Panel function must be set")
end

function tab_object:OnVisibleUpdate(visible)
end

function tab_object:SetVisible(visible)
	self:OnVisibleUpdate(visible)
end

local function TabObject(name, order, color, can_opened_alt)
	return Object(tab_object, {name = name, order = order, color = color, can_opened_alt = can_opened_alt or false})
end

local current_interface_object = nil

function MODULE:RegisterInterface(interface_name, authors, version)
	interface_list[interface_name] = Object(interface_object, {commands = {}})
	interface_information[interface_name] = {authors = authors, version = version}

	return interface_list[interface_name]
end

function MODULE:RegisterTab(tab_name, order_num)
	tab_list[1 + #tab_list] = TabObject(tab_name, order_num)

	return tab_list[1 + #tab_list]
end

function MODULE:GetInterfaceInformation()
	local found_interfaces = {}

	for k,v in pairs(interface_information) do
		found_interfaces[1 + #found_interfaces] = {name = k, authors = v.authors, version = v.version}
	end

	return found_interfaces
end

function MODULE.Client:Post()
	if interface_list[CONFIG.JAAS_INTERFACE] != nil then
		current_interface_object = interface_list[CONFIG.JAAS_INTERFACE]

		for k,tab_object in ipairs(tab_list) do
			current_interface_object:ReceiveRegisteredTabs(tab_object)
		end

		current_interface_object:Post()
	else
		error("Interface Set in Configs has not been Registered; this interface name may have been a missspelling, double check the name before overwriting Configurations")
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

local PaintLib = {}
local PaintLibObject = {}

local function IsHovered(panel, plus_child)
	return panel:IsHovered() or (panel:IsChildHovered() and plus_child or false)
end

do -- Paint Library Code
	local function PaintLib.Background(width, height, panel, color, rounded_corner_radius)
		if rounded_corner_radius != nil then
			draw.RoundedBox(rounded_corner_radius, 0, 0, width, height, color)
		else
			surface.SetDrawColor(color)
			surface.DrawRect(0, 0, width, height)
		end
	end

	local function PaintLib.Outline(width, height, panel, color, thickness, vertical_padding, horizontal_padding)
		vertical_padding = vertical_padding or 0
		horizontal_padding = horizontal_padding or 0
		thickness = thickness or 1

		surface.SetDrawColor(color)
		surface.DrawOutlinedRect(0 + vertical_padding, 0 + horizontal_padding, width - (horizontal_padding * 2), height - (vertical_padding * 2), thickness)
	end

	local function PaintLib.BackgroundHover(width, height, panel, alpha, color, rounded_corner_radius)
		color = ColorAlpha(color, color.a * alpha)

		PaintLib.Background(width, height, panel, color, rounded_corner_radius)
	end

	local function PaintLib.OutlineHover(width, height, panel, alpha, color, thickness, vertical_padding, horizontal_padding)
		color = ColorAlpha(color, color.a * alpha)

		PaintLib.Outline(width, height, panel, color, thickness, vertical_padding, horizontal_padding)
	end

	local function PaintLib.SideBlock(width, height, panel, color, side, thickness, vertical_padding, horizontal_padding)
		vertical_padding = vertical_padding or 0
		horizontal_padding = horizontal_padding or 0
		thickness = thickness or 1

		surface.SetDrawColor(color)
		if side == TOP then -- Top
			surface.DrawRect(0 + horizontal_padding, 0 + vertical_padding, width - (horizontal_padding * 2), thickness)
		elseif side == RIGHT then -- Right
			surface.DrawRect((width - thickness) + horizontal_padding, 0 + vertical_padding, thickness, height - (horizontal_padding * 2))
		elseif side == BOTTOM then -- Bottom
			surface.DrawRect(0 + horizontal_padding, (height - thickness) + vertical_padding, width - (horizontal_padding * 2), thickness)
		elseif side == LEFT then -- Left
			surface.DrawRect(0 + horizontal_padding, 0 + vertical_padding, thickness, height - (vertical_padding * 2))
		end
	end

	local function PaintLib.Text(width, height, panel, str, color, font, align, vertical_padding, horizontal_padding)
		align = align or TEXT_ALIGN_CENTER
		draw.SimpleText(str, font, (width * 0.5) + horizontal_padding or 0, (height * 0.5) + vertical_padding or 0, color, align, TEXT_ALIGN_CENTER)
	end

	J_TEXT_CORNER_TOP_LEFT = 1
	J_TEXT_CORNER_TOP_RIGHT = 2
	J_TEXT_CORNER_BOTTOM_LEFT = 3
	J_TEXT_CORNER_BOTTOM_RIGHT = 4

	local function PaintLib.CornerText(width, height, panel, str, color, font, corner, vertical_padding, horizontal_padding)
		vertical_padding = vertical_padding or 0
		horizontal_padding = horizontal_padding or 0

		if corner == 1 then -- Top Left
			draw.SimpleText(str, font, 0 + horizontal_padding, 0 + vertical_padding, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
		elseif corner == 2 then -- Top Right
			draw.SimpleText(str, font, width + horizontal_padding, 0 + vertical_padding, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
		elseif corner == 3 then -- Bottom Left
			draw.SimpleText(str, font, 0 + horizontal_padding, height + vertical_padding, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
		elseif corner == 4 then -- Bottom Right
			draw.SimpleText(str, font, width + horizontal_padding, height + vertical_padding, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
		end
	end

	local blurscreen_material = Material("pp/blurscreen")

	local function PaintLib.Blur(width, height, panel, amount)
		local x, y = panel:LocalToScreen(0, 0)

		surface.SetDrawColor(255, 255, 255)
		surface.SetMaterial(blurscreen_material)

		for i=0.33, 1, 0.33 do
			blurscreen_material:SetFloat("$blur", i * (amount or 8))
			blurscreen_material:Recompute()

			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(x * -1, y * -1, ScrW(), ScrH())
		end
	end

	local function PaintLib.CheckBox(width, height, panel, color)
	end

	local function PaintLib.TextboxHover(width, height, panel, color)
	end

	local function PaintLib.TextboxPlacerholder(width, height, panel, str, string)
	end

	local function PaintLib.TextboxSideBar()
	end
end

do -- Paint Library Object Code
	-- Paint Functions
	function PaintLibObject:Background(color, rounded_corner_radius)
		self.paint_list[1 + self.paint_list] = {"Background", {color, rounded_corner_radius}}
		return self
	end

	function PaintLibObject:Outline(color, thickness, vertical_padding, horizontal_padding)
		self.paint_list[1 + self.paint_list] = {"Outline", {color, thickness, vertical_padding, horizontal_padding}}
		return self
	end

	function PaintLibObject:SideBlock(color, side, thickness, vertical_padding, horizontal_padding)
		self.paint_list[1 + self.paint_list] = {"SideBlock", {color, side, thickness, vertical_padding, horizontal_padding}}
		return self
	end

	function PaintLibObject:Text(str, color, font, align, vertical_padding, horizontal_padding)
		self.paint_list[1 + self.paint_list] = {"Text", {str, color, font, align, vertical_padding, horizontal_padding}}
		return self
	end

	function PaintLibObject:CornerText(str, color, font, corner, vertical_padding, horizontal_padding)
		self.paint_list[1 + self.paint_list] = {"CornerText", {str, color, font, corner, vertical_padding, horizontal_padding}}
		return self
	end

	function PaintLibObject:Blur(amount)
		self.paint_list[1 + self.paint_list] = {"Blur", {amount}}
		return self
	end
	--

	-- Hover Paint functions
	function PaintLibObject:BackgroundHover(color, time, rounded_corner_radius)
		self.hover_paint_list[1 + self.hover_paint_list] = {"BackgroundHover", {str, color, font, corner, vertical_padding, horizontal_padding}, time or 6}
		return self
	end

	function PaintLibObject:OutlineHover(color, time, thickness, vertical_padding, horizontal_padding)
		self.hover_paint_list[1 + self.hover_paint_list] = {"OutlineHover", {str, color, font, corner, vertical_padding, horizontal_padding}, time or 6}
		return self
	end
	--
end

local tooltip_controller = {}

do -- Tooltip Controller Code
	local tooltip_list = {} -- [index] = {show, text, font, box_color, text_color, bordersize}

	hook.Add("DrawOverlay", "JAAS::UI:Tooltip", function ()
		for k,v in ipairs(tooltip_list) do
			if v[1] then
				draw.WordBox(v[6], gui.MouseX, gui.MouseY, v[2], v[3], v[4], v[5], TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
			end
		end
	end)

	function tooltip_controller:RegisterTooltip(text, font, box_color, text_color, bordersize)
		box_color = box_color or Color(128, 128, 128)
		text_color = text_color or Color(255, 255, 255)
		bordersize = bordersize or 4

		tooltip_list[1 + #tooltip_list] = {false, 0, 0, text, font, box_color, text_color, bordersize}
		local index = #tooltip_list

		return function (show)
			tooltip_list[index][1] = show
		end
	end
end

do -- Panel Metatable Functions
	local Panel = FindMetaTable("Panel")

	function Panel:StartPaint()
		self.paintLibObject = Object({}, {__index = PaintLibObject})
		return self.paintLibObject
	end

	function Panel:WritePaint(plus_child)
		if #self.paintLibObject.paint_list > 0 then
			function self.Paint(w, h)
				for k,v in ipairs(self.paintLibObject.paint_list) do
					PaintLib[v[1]](w, h, self, unpack(v[2]))
				end
			end
		end

		if #self.hover_paint_list > 0 then
			local old_think = self.Think

			function self:Think()
				if old_think then
					old_think()
				end

				for k,v in ipairs(self.paintLibObject.hover_paint_list) do
					self[v[1]] = Lerp(FrameTime() * v[3], 0, IsHovered(self, plus_child) and 1 or 0)
				end
			end

			function self:Paint(w, h)
				for k,v in ipairs(self.paintLibObject.hover_paint_list) do
					PaintLib[v[1]](w, h, self, self[v[1]], unpack(v[2]))
				end
			end
		end
	end

	function Panel:Tooltip(text, font, delay, also_child, box_color, text_color, bordersize)
		local tooltip_update = tooltip_controller:RegisterTooltip(text, font, box_color, text_color, bordersize)

		delay = delay or 2
		also_child = also_child or false

		local old_think = self.Think
		local hover_start

		function self:Think()
			if old_think then
				old_think()
			end

			if self:IsHovered() or (self:IsChildHovered() and also_child) then
				if hover_start == nil then
					hover_start = RealTime()
				else
					if (RealTime() - hover_start) > delay then
						tooltip_update(true)
					end
				end
			else
				tooltip_update(false)
				hover_start = nil
			end
		end
	end

	function Panel:HideScrollBar()
		self:GetVBar():SetWide(0)
		self:GetVBar():Hide()
	end

	function Panel:SetFractionTall(fraction, target)
		target = target or self:GetParent()
		self:SetTall(target:GetTall() / fraction)
	end

	function Panel:SetFractionWide(decimal, target)
		target = target or self:GetParent()
		self:SetWide(target:GetWide() / fraction)
	end

	function Panel:ClearPaint()
		self.Paint = nil
	end
end

do -- Controller Code
	local internal_position_controller = {
		animated = false,
		valid_positions = false,
		base_auto_size = false,
		children_auto_size = false,
		order_pos_direction = false,
		size_threshold = 0.6,
		upper_size_threshold = 1.1,
		child_order = {},
		base_padding = {north = 0, east = 0, south = 0, west = 0},
		child_padding = {north = 0, east = 0, south = 0, west = 0}
	}

	function internal_position_controller:SetBasePadding(north, east, south, west)
		self.base_padding = {north = north or 0, east = east or 0, south = south or 0, west = west or 0}
	end

	function internal_position_controller:SetChildrenPadding(north, east, south, west)
		self.child_padding = {north = north or 0, east = east or 0, south = south or 0, west = west or 0}
	end

	function internal_position_controller:BaseAutoSize(horizontal)
		if self.children_auto_width == horizontal then
			error("Base auto size cannot match Children's auto size", 2)
		else
			self.base_auto_size = true
			self.base_auto_width = horizontal
		end
	end

	function internal_position_controller:ChildrenAutoSize(horizontal) -- horizontal = true (Auto Width); horizontal = false (Auto Height)
		if self.base_auto_width == horizontal then
			error("Children auto size cannot match Base's auto size", 2)
		else
			self.children_auto_size = true
			self.children_auto_width = horizontal
		end
	end

	function internal_position_controller:SetOrder(horizontal)
		self.order_pos_direction = horizontal
	end

	function internal_position_controller:SetSizeDifferenceThreshold(float)
		if float > 1 then
			error("Size Threshold must be a decimal", 2)
		else
			self.size_threshold = float
		end
	end

	function internal_position_controller:SetUpperSizeDifferenceThreshold(float)
		if float < 1 then
			error("Upper Size Threshold must be above 1 and decimal", 2)
		else
			self.upper_size_threshold = float
		end
	end

	function internal_position_controller:AddChild(id, panel, intended_position)
		if id and isnumber(intended_position) then
			if !self.layout_properties[id] then
				panel:SetName(id)
				panel:SetParent(self)

				if intended_position == nil then
					self.child_order[1 + #self.child_order] = {id, intended_position}
				else
					local child_amount = #self.child_order
					local inserted = false
					local index = 1

					repeat
						if self.child_order[index][2] == nil then
							table.insert(self.child_order, index, {id, intended_position})
							inserted = true
						else
							if self.child_order[index][2] > intended_position then
								table.insert(self.child_order, index, {id, intended_position})
								inserted = true
							end
						end

						index = 1 + index
					until (index >= child_amount)

					if !inserted then
						self.child_order[1 + #self.child_order] = {id, intended_position}
					end
				end
			else
				error("ID must be unique", 2)
			end
		else
			error("Child must include an ID", 2)
		end
	end

	function internal_position_controller:GetChildPanel(id)
		for k,panel in ipairs(self:GetChildren()) do
			if panel:GetName() == id then
				return panel
			end
		end
		return false
	end

	function internal_position_controller:SetAnimated(animated)
		self.animated = animated
		if animated then
			self.animation_in_progress = false
			self.animation_time = 0.5
			self.animation_ease = -1
		end
	end

	function internal_position_controller:SetAnimationSpeed(time)
		if time > 0.001 then
			self.animation_time = time
		else
			error("Time should not equal 0; if there must be no Lerp time, turn off animation with SetAnimated(false)", 2)
		end
	end

	function internal_position_controller:SetAnimationEase(ease)
		self.animation_ease = ease
	end

	function internal_position_controller:CalculatePositions()
		local child_info = {}

		for k,panel in ipairs(self:GetChildren()) do
			if self.children_auto_size then
				local width,height = self:GetSize()

				if self.children_auto_width then
					panel:SetWidth(width - (self.base_padding.east + self.base_padding.west))
				else
					panel:SetHeight(height - (self.base_padding.north + self.base_padding.south))
				end
			end

			if panel:IsVisible() then
				child_info[panel:GetName()] = {sizeW = panel:GetWide(), sizeH = panel:GetTall()}
			else
				child_info[panel:GetName()] = {sizeW = 0 - (self.base_padding.east + self.base_padding.west), sizeH = 0 - (self.base_padding.north + self.base_padding.south)}
			end
		end

		self.calculated_pos = {}

		local function calculateX(id)
			return self.calculated_pos[id].x + child_info[id].sizeH + self.child_padding.south + self.child_padding.north
		end

		local function calculateY(id)
			return self.calculated_pos[id].y + child_info[id].sizeW + self.child_padding.west + self.child_padding.east
		end

		local children_height, children_width = self.base_padding.north + self.base_padding.south, self.base_padding.east + self.base_padding.west
		local disjointed = {} -- [x/y] = true/false
		local table_length = {} -- [x/y] = length
		local pos_table = {} -- [x/y][y/x] = {id, size_difference} size_difference = self / last

		for k,v in ipairs(self.child_order) do -- TODO : Finish Calculation
			if self.order_pos_direction then -- Horizontal
			else -- Vertical
				if k > 1 then
					if #pos_table == 1 then
						local last_child_id = self.child_order[k - 1][1]
						local x = calculateX(last_child_id)
						local y = self.base_padding.east

						if x > self:GetTall() and not (self.base_auto_size and !self.base_auto_width) then
							local left_child_id = nil
							local starting_y = 1

							for k,v in ipairs(pos_table[1]) do
								if k != 1 and v[2] < self.size_threshold then
									starting_y = k
									last_child_id = pos_table[1][k - 1][1]
									left_child_id = pos_table[1][k][1]

									if ((calculateY(left_child_id)) + (calculateY(v[1])) / calculateY(last_child_id)) > self.upper_size_threshold then
										starting_y = 1
									end
								end
							end

							if starting_y != 1 then
								x = calculateX(last_child_id)
								y = calculateY(left_child_id)
								pos_table[2] = {[starting_y] = {v[1], (calculateY(left_child_id)) + (calculateY(v[1])) / calculateY(last_child_id)}}
								table_length[2] = 1
								disjointed[2] = true
							else
								x = self.base_padding.north
								y = calculateY(pos_table[1][1][1])
								table_length[2] = 1
								disjointed[2] = false
							end
						else
							pos_table[1][k] = {v[1], (child_info[v[1]].sizeW + self.child_padding.east + self.child_padding.west) / (child_info[last_child_id].sizeW + self.child_padding.east + self.child_padding.west)}
							table_length[1] = 1 + table_length[1]
						end

						calculated_pos[v[1]] = {x = x, y = y}

						if self.base_auto_size and !self.base_auto_width then
							children_height = child_info[v[1]].sizeH + children_height + self.child_padding.south + self.child_padding.north
						end
					else
						if disjointed[#pos_table] then
						else

						end
					end
				else
					calculated_pos[v[1]] = {x = self.base_padding.north, y = self.base_padding.east}
					pos_table[1] = {[1] = {v[1], nil}}
					disjointed[1] = false
				end
			end
		end

		if self.base_auto_size then
			if self.base_auto_width then
				self:SetWidth(children_width)
			else
				self:SetHeight(children_height)
			end
		end

		self.valid_positions = true
	end

	function internal_position_controller:InvalidatePositions()
		self.valid_positions = false
	end

	function internal_position_controller:RefreshPositions(invalidate, force)
		if !self.animation_in_progress or (force or false) then
			if !self.valid_positions or (invalidate or false) then
				self:CalculatePositions()
			end

			local children_amount = 0
			for k,panel in ipairs(self:GetChildren()) do
				local pos_data = self.calculated_pos[panel:GetName()]
				if self.animated then
					self.animation_in_progress = true
					children_amount = 1 + children_amount

					local function FinishedAnimation()
						self.animation_in_progress = false
					end

					panel:MoveTo(pos_data.x, pos_data.y, self.animation_time, 0, self.animation_ease, function (animData, pnl)
						if k == children_amount then
							FinishedAnimation()
						end
					end)
				else
					panel:SetPos(pos_data.x, pos_data.y)
				end
			end

			return true
		else
			return false
		end
	end

	derma.DefineControl("JControlPanel", "A Panel that can control the positions of its children", internal_position_controller, "DPanel")
end