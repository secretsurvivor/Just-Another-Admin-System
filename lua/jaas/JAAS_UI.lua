local GUI = JAAS:GetModule("GUI")
local JUI = GUI:RegisterInterface("Default::JUI", "secret_survivor", 1.0)

local visible_tab_window_funcs, visible_tab_button_funcs = {}, {}

local current_open_panel_right, current_open_panel_left

local background_panel = vgui.Create("DPanel")
local background_blur_amount = 4

do -- Background Panel Code
	background_panel:SetSize(ScrW(), ScrH())
	background_panel:SetPos(0, 0)
	background_panel:SetVisible(false)

	background_panel:StartPaint()
		:Blur(background_blur_amount)
	background_panel:WritePaint()
end

local side_menu_height = ScrH() * 0.58
local side_menu_x_pos = ScrW() * 0.935

local JAAS_side_menu = vgui.Create("DScrollPanel")

do -- Main JAAS Menu Code
	JAAS_side_menu:SetParent(background_panel)
	JAAS_side_menu:HideScrollBar()
	JAAS_side_menu:SetPos(side_menu_x_pos, ScrH() * 0.21)
	JAAS_side_menu:SetSize(ScrW() * 0.07, side_menu_height)
	JAAS_side_menu:SetZPos(1)

	JAAS_side_menu:StartPaint()
		:Background(Color(59, 56, 56))
	JAAS_side_menu:WritePaint()

	local side_menu_canvas = vgui.Create("JControlPanel")
	side_menu_canvas:SetChildrenPadding(4)
	side_menu_canvas:BaseAutoSize(false)
	side_menu_canvas:ChildrenAutoSize(true)
	side_menu_canvas:SetOrder(false)
	side_menu_canvas:SetAnimated(true)
	side_menu_canvas:ClearPaint()
	JAAS_side_menu:SetCanvas(side_menu_canvas)

	local menu_minimised = false

	function JAAS_side_menu:AddTabButton(tab_object, toggle_panel_func)
		local tab_button = vgui.Create("DButton")

		tab_button:SetFractionTall(0.7, JAAS_side_menu)
		tab_button:SetZPos(2)
		side_menu_canvas:AddChild(tab_object:GetName(), tab_button, tab_object:GetOrderNum())

		tab_button:StartPaint()
			:SideBlock(tab_object:GetColor(), LEFT, 4)
			:Text(tab_object:GetName(),  Color(242, 242, 242), "Trebuchet24", TEXT_ALIGN_CENTER)
		tab_button:WritePaint()

		function tab_button:DoClick()
			toggle_panel_func(false)
		end

		if tab_object:CanOpenedAlt() then
			function tab_button:DoRightClick()
				toggle_panel_func(true)
			end
		end

		function tab_button:IsExtended()
			return self.extended
		end

		function tab_button:Extend(extend)
			if extend != self:IsExtended() then
				if extend then
					self:MoveTo(0 - self:GetWide(), self:GetY(), 0.1, 0, -1, function () end)
				else
					self:MoveTo(4, self:GetY(), 0.1, 0, -1, function () end)
				end

				self.extended = extend
			end
		end

		function tab_button:Think()
			if self:IsHovered() or self:IsChildHovered() then
				self:Extend(true)
			else
				self:Extend(false)
			end
		end

		return function (visible)
			side_menu_canvas:InvalidatePositions()
			tab_button:SetVisible(visible)
		end
	end

	local menu_hidden = false

	function JAAS_side_menu:SetHidden(hide)
		if menu_hidden != hide then
			if hide then
				self:MoveTo(ScrW(), self:GetY(), 0.1, 0, -1, function () end)
			else
				self:MoveTo(side_menu_x_pos, self:GetY(), 0.1, 0, -1, function () end)
			end

			current_open_panel_right:RefreshPosition()
			menu_hidden = !menu_hidden
		end
	end

	function JAAS_side_menu:SetMinimised(minimised)
		if minimised != menu_minimised then
			if minimised then
				self:MoveTo(ScrW() - 8, self:GetY(), 0.1, 0, -1, function () end)
			else
				self:MoveTo(side_menu_x_pos, self:GetY(), 0.1, 0, -1, function () end)
			end

			current_open_panel_right:RefreshPosition()
			menu_minimised = !menu_minimised
		end
	end

	function JAAS_side_menu:IsHidden()
		return menu_hidden
	end

	function JAAS_side_menu:IsMinimised()
		return menu_minimised
	end

	function JAAS_side_menu:Post()
		side_menu_canvas:RefreshPositions(true)
	end
end

local function CreateTabWindow(tab_object)
	local tab_window = vgui.Create("DFrame")

	tab_window:SetName(tab_object:GetName())
	tab_window:SetParent(background_panel)
	tab_window:ShowCloseButton(false)
	tab_window:SetDraggable(false)
	tab_window:SetTall(side_menu_height)

	tab_window:StartPaint()
		:Background(Color(59, 56, 56))
		:Outline(tab_object:GetColor(), 4)
	tab_window:WritePaint()

	local internal_panel = tab_object:GetPanel()

	tab_window:SetWide(internal_panel:GetWide() + 16)
	internal_panel:SetParent(tab_window)
	internal_panel:Dock(FILL)
	internal_panel:DockPadding(8, 8, 8, 8)

	local window_visible_toggle = false

	function tab_window:OpenWindow(left)
		self:SetZPos(-1)
		self:SetVisible(true)

		if left then
			self:SetPos(0 - self:GetWide() + 4, JAAS_side_menu:GetY())
			current_open_panel_left = self
			self:MoveTo(4, JAAS_side_menu:GetY(), 0.1, 0, -1, function () end)
		else
			self:SetPos(ScrW() + 4, JAAS_side_menu:GetY())
			current_open_panel_right = self
			self:RefreshPosition()
		end
	end

	function tab_window:CloseWindow(left)
		self:SetZPos(-2)

		if left then
			current_open_panel_left = nil
			self:MoveTo(0 - self:GetWide() + 4, JAAS_side_menu:GetY(), 0.1, 0, -1, function (_, pnl)
				pnl:SetVisible(false)
			end)
		else
			current_open_panel_right = nil
			self:MoveTo(ScrW() + 4, JAAS_side_menu:GetY(), 0.1, 0, -1, function (_, pnl)
				pnl:SetVisible(false)
			end)
		end
	end

	function tab_window:RefreshPosition()
		self:MoveTo(JAAS_side_menu:GetX() - self:GetWide() + 4, JAAS_side_menu:GetY(), 0.1, 0, -1, function () end)
	end

	local function toggle_window_func(left)
		local current_side = (left and current_open_panel_left or current_open_panel_right) or nil

		if current_side != nil then
			current_side:CloseWindow(left)

			if current_side:GetName() != tab_object:GetName() then
				tab_window:OpenWindow(left)
			end
		else
			tab_window:OpenWindow(left)
		end
	end

	visible_tab_window_funcs[tab_object:GetName()] = toggle_window_func
	visible_tab_button_funcs[tab_object:GetName()] = JAAS_side_menu:AddTabButton(tab_object, toggle_window_func)
end

function JUI:ReceiveRegisteredTabs(tab_object)
	CreateTabWindow(tab_object)
end

function JUI:OpenMenu()
	background_panel:ToggleVisible()
	gui.EnableScreenClicker(background_panel:IsVisible())
end

function JUI:CloseMenu()
	background_panel:ToggleVisible()
	gui.EnableScreenClicker(background_panel:IsVisible())
end

function JUI:Post()
	JAAS_side_menu:Post()
end

function JUI:OpenTab(args, args_str, cmd_str)
	if visible_tab_window_funcs[args[1]] != nil then
		if args[2] == nil or args[2] == "right" then
			visible_tab_window_funcs[args[1]](false)
		elseif args[2] == "left" then
			visible_tab_window_funcs[args[1]](true)
		end
	end
end

JUI:AddCommand("ToggleHidden", function ()
	JAAS_side_menu:SetHidden(!JAAS_side_menu:IsHidden())
end)

JUI:AddCommand("ToggleMinimise", function ()
	JAAS_side_menu:SetMinimised(!JAAS_side_menu:IsMinimised())
end)

JUI:AddCommand("CloseAllTabs", function ()
	if current_open_panel_right != nil then
		current_open_panel_right:CloseWindow()
	end

	if current_open_panel_left != nil then
		current_open_panel_left:CloseWindow()
	end
end)

JUI:AddCommand("ForceVisible", function (ply, cmd, args, arg_str)
	if visible_tab_button_funcs[args[1]] != nil then
		visible_tab_button_funcs[args[1]](true)
	end
end)

function JUI:Pre() -- Default JAAS Interface Tabs
	local CommandModule = JAAS:GetModule("Command")
	local PermissionModule = JAAS:GetModule("Permission")
	local RankModule = JAAS:GetModule("Rank")
	local AccessGroupModule = JAAS:GetModule("AccessGroup")
	local PlayerModule = JAAS:GetModule("Player")

	do -- Command Tab
		local CommandTab = GUI:RegisterTab("Command", Color(223, 73, 73), 0, true)

		local root_panel = vgui.Create("DScrollPanel")
		root_panel:HideScrollBar()
		root_panel:ClearPaint()
		root_panel:SetWide(ScrW() * 0.107)

		local function ParentSizeToChildren(panel)
			local size_func = panel.SizeToChildren

			function panel:SizeToChildren(a, b)
				self:InvalidateLayout(true)
				size_func(self, a, b)
				self:GetParent():InvalidateLayout(true)
				self:GetParent():SizeToChildren(a, b)
			end
		end

		local function CreateCollapsiblePanel(label, parent)
			local collapsible = vgui.Create("DCollapsibleCategory", parent)
			collapsible:ClearPaint()
			collapsible:SetLabel(string.gsub(label, "_", " "))
			collapsible:SetExpanded(false)
			collapsible:Dock(TOP)
			collapsible:DockMargin(8, 8, 8, 8)
			collapsible:DockPadding(0, 8, 0, 0)
			ParentSizeToChildren(collapsible)

			function collapsible:Think()
				self.animSlide:Run()
				if self.animSlide:Active() then
					self:GetParent():InvalidateLayout(true)
					self:GetParent():SizeToChildren(false, true)
				end
			end

			return collapsible
		end

		local command_panel = vgui.Create("DPanel", root_panel)

		command_panel:StartPaint()
			:SideBlock(Color(255, 255, 255), LEFT, 0.5, 2)
		command_panel:WritePaint()

		local category_set_parent_func = {}

		local category_visible_func = {} -- [category] = {num_of_visible_commands, visible_func}
		local command_visible_func = {} -- [category][name] = visible_func

		local function CreateCategoryElement(category_name)
			local category_element = CreateCollapsiblePanel(category_name, command_panel)

			local internal_category_element = vgui.Create("DPanel")
			category_element:SetContents(internal_category_element)

			internal_category_element:StartPaint()
				:SideBlock(Color(255, 255, 255), LEFT, 0.5, 2)
			internal_category_element:WritePaint()

			category_set_parent_func[category_name] = function (panel)
				panel:SetParent(internal_category_element)
			end

			category_visible_func[category_name] = {0, function (visible)
				category_element:SetVisible(visible)
			end}

			return internal_category_element
		end

		local function CreateCommandElement(command_name, category_name)
			local command_element = CreateCollapsiblePanel(command_name)

			local internal_command_element = vgui.Create("DPanel")
			command_element:SetContents(internal_command_element)

			internal_command_element:StartPaint()
				:SideBlock(Color(255, 255, 255), LEFT, 0.5, 2)
			internal_command_element:WritePaint()

			if command_visible_func[category_name] == nil then
				command_visible_func[category_name] = {command_name = function (visible)
					command_element:SetVisible(visible)
				end}
			else
				command_visible_func[category_name][command_name] = function (visible)
					command_element:SetVisible(visible)
				end
			end

			return internal_command_element
		end

		for CommandObject in CommandModule:iCommand() do
			local command_element = CreateCommandElement(CommandObject:GetName(), CommandObject:GetCategory())

			if category_set_parent_func[CommandObject:GetCategory()] == nil then
				local panel = CreateCategoryElement(CommandObject:GetCategory())
				command_element:SetParent(panel)
			else
				category_set_parent_func[CommandObject:GetCategory()](command_element)
			end

			if CommandObject:Check(LocalPlayer:GetCode()) then
				category_visible_func[CommandObject:GetCategory()][1] = 1 + category_visible_func[CommandObject:GetCategory()][1]
			else
				command_visible_func[CommandObject:GetCategory()][CommandObject:GetName()](false)
			end

			local element
			local parameter_values[] = {}

			for k,v in ipairs(CommandObject:GetParameters()) do
				local parameter_type = v:GetType()

				if parameter_type == 1 then -- Bool
					element = command_element:Add("DCheckBoxLabel")
					element:SetChecked(v.default or false)

				elseif parameter_type == 2 then -- Int
					element = command_element:Add("DNumSlider")
					element:SetText(v:GetName())
					element:SetValue(v.default or 0)

					if v:GetMin() != nil then
						element:SetMin(v:GetMin())
					end

					if v:GetMax() != nil then
						element:SetMax(v:GetMax())
					end

				elseif parameter_type == 3 then -- Float
					element = command_element:Add("DNumberScratch")
					element:SetValue(v.default or 0)

					if v:GetMin() != nil then
						element:SetMin(v:GetMin())
					end

					if v:GetMax() != nil then
						element:SetMax(v:GetMax())
					end

				elseif parameter_type == 4 then -- String
					element = command_element:Add("DTextEntry")
					element:SetValue(v.default or "")
					element:SetPlaceholderText(v:GetName())

				elseif parameter_type == 5 then -- Player
					element = command_element:Add("DPlayerComboBox")

				elseif parameter_type == 7 then -- Option
					element = command_element:Add("DComboBox")

					for k,v in ipairs(v:GetOptionList()) do
						if v == v:GetDefault() then
							element:AddChoice(v, k, true)
						else
							element:AddChoice(v, k)
						end
					end

				elseif parameter_type == 9 then -- Rank
					element = command_element:Add("JRankComboBox")

				elseif parameter_type == 10 then -- Permission
					element = command_element:Add("JPermissionComboBox")

				elseif parameter_type == 11 then -- Access Group
					element = command_element:Add("JAccessGroupComboBox")

				elseif parameter_type == 12 then -- Command
					element = command_element:Add("JCommandComboBox")

				else
					error("Unknown Parameter Type")
				end

				element:Dock(TOP)
				element:DockPadding(0, 4, 0, 0)
				element:SetTall(30)
				element:Tooltip(v:GetName(), "DermaDefault", 2)

				if parameter_type == 1 then
					function element:OnChange(value)
						parameter_values[k] = value
					end
				elseif parameter_type == 2 or parameter_type == 3 then
					function element:OnValueChanged(value)
						parameter_values[k] = value
					end
				elseif parameter_type == 4 then
					function element:OnValueChange(value)
						parameter_values[k] = value
					end
				elseif parameter_type >= 5 and parameter_type <= 12 then
					function element:OnSelect(index, value, data)
						parameter_values[k] = data
					end
				end
			end

			element = command_element:Add("DButton") -- Execute Button

			element:Dock(TOP)
			element:DockPadding(0, 4, 0, 0)
			element:SetTall(30)

			function element:DoClick()
				CommandObject:Execute(unpack(parameter_values))
			end
		end

		for k,v in pairs(category_visible_func) do
			if v[1] == 0 then
				v[2](false)
			end
		end

		local PlayerHook = JAAS.Hook("Player")("LocalPlayerModifiedCode")
		local CommandHook = JAAS.Hook("Command")("OnCodeUpdate")

		function PlayerHook.Interface_CommandTab_DynamicUpdate(code)
			for category,command_table in pairs(command_visible_func) do
				for name,info in pairs(command_table) do
					local obj = JAAS.CommandObject(name, category)

					if obj:Check(code) then
						command_visible_func[obj:GetCategory()][obj:GetName()](true)
						category_visible_func[obj:GetCategory()][1] = 1 + category_visible_func[obj:GetCategory()][1]
					else
						command_visible_func[obj:GetCategory()][obj:GetName()](false)
						category_visible_func[obj:GetCategory()][1] = category_visible_func[obj:GetCategory()][1] - 1
					end

					if category_visible_func[obj:GetCategory()][1] == 0 then
						category_visible_func[obj:GetCategory()][2](false)
					else
						category_visible_func[obj:GetCategory()][2](true)
					end
				end
			end
		end

		function CommandHook.Interface_CommandTab_DynamicUpdate(obj)
			if obj:Check(LocalPlayer():GetCode()) then
				command_visible_func[obj:GetCategory()][obj:GetName()](true)
				category_visible_func[obj:GetCategory()][1] = 1 + category_visible_func[obj:GetCategory()][1]
			else
				command_visible_func[obj:GetCategory()][obj:GetName()](false)
				category_visible_func[obj:GetCategory()][1] = category_visible_func[obj:GetCategory()][1] - 1
			end

			if category_visible_func[obj:GetCategory()][1] == 0 then
				category_visible_func[obj:GetCategory()][2](false)
			else
				category_visible_func[obj:GetCategory()][2](true)
			end
		end

		function CommandTab:GetPanel()
			return root_panel
		end
	end

	local RankHook_OnAdd = JAAS.Hook("Rank")("OnAdd")
	local RankHook_OnRemove = JAAS.Hook("Rank")("OnRemove")
	local RankHook_OnPowerUpdate = JAAS.Hook("Rank")("OnPowerUpdate")
	local RankHook_OnInvisibleUpdate = JAAS.Hook("Rank")("OnInvisibleUpdate")

	local PlayerHook_OnConnect = JAAS.Hook("Player")("OnConnect")
	local PlayerHook_OnDisconnect = JAAS.Hook("Player")("OnDisconnect")

	local CanAddRank = PermissionModule:GetPermission("Can Add Rank")
	local CanRemoveRank = PermissionModule:GetPermission("Can Remove Rank")
	local CanModifyRankPower = PermissionModule:GetPermission("Can Modify Rank Power Level")
	local CanModifyRankInvisibility = PermissionModule:GetPermission("Can Modify Rank Invisibility")

	local CanModifyPermission = PermissionModule:GetPermission("Can Modify Permission Code")
	local CanModifyCommand = PermissionModule:GetPermission("Can Modify Permission Code")
	local CanModifyPlayer = PermissionModule:GetPermission("Can Modify Player Code")

	local CanAddRank_OnChange = {}
	local CanRemoveRank_OnChange = {}
	local CanModifyRankPower_OnChange = {}
	local CanModifyRankInvisibility_OnChange = {}

	local CanModifyPermission_OnChange = {}
	local CanModifyCommand_OnChange = {}
	local CanModifyPlayer_OnChange = {}

	do -- Rank Tab Permission On Change Functions
		PlayerModule:OnLocalPermissionAccessChange(CanAddRank, function (access)
			for k,func in ipairs(CanAddRank_OnChange) do
				func(access)
			end
		end)
		PlayerModule:OnLocalPermissionAccessChange(CanRemoveRank, function (access)
			for k,func in ipairs(CanRemoveRank_OnChange) do
				func(access)
			end
		end)
		PlayerModule:OnLocalPermissionAccessChange(CanModifyRankPower, function (access)
			for k,func in ipairs(CanModifyRankPower_OnChange) do
				func(access)
			end
		end)
		PlayerModule:OnLocalPermissionAccessChange(CanModifyRankInvisibility, function (access)
			for k,func in ipairs(CanModifyRankInvisibility_OnChange) do
				func(access)
			end
		end)

		PlayerModule:OnLocalPermissionAccessChange(CanModifyPermission, function (access)
			for k,func in ipairs(CanModifyPermission_OnChange) do
				func(access)
			end
		end)
		PlayerModule:OnLocalPermissionAccessChange(CanModifyCommand, function (access)
			for k,func in ipairs(CanModifyCommand_OnChange) do
				func(access)
			end
		end)
		PlayerModule:OnLocalPermissionAccessChange(CanModifyPlayer, function (access)
			for k,func in ipairs(CanModifyPlayer_OnChange) do
				func(access)
			end
		end)
	end

	do -- Rank Tab
		local RankTab = GUI:RegisterTab("Rank", Color(174, 75, 229), 1, true)

		local root = vgui.Create("DPanel")
		root:ClearPaint()
		root:SetWide(515)

		local rank_list = vgui.Create("DPanel", root)
		rank_list:ClearPaint()
		rank_list:Dock(LEFT)
		rank_list:DockMargin(0, 0, 4, 0)

		local current_opened_rank_button

		do -- Rank List
			local list_back_panel = vgui.Create("DScrollPanel", rank_list)
			list_panel:Dock(FILL)
			list_panel:HideScrollBar()
			list_panel:ClearPaint()

			local list_panel = vgui.Create("JControlPanel", list_back_panel)
			list_panel:Dock(FILL)
			list_panel:BaseAutoSize(false)
			list_panel:ChildrenAutoSize(true)
			list_panel:SetOrder(false)
			list_panel:SetAnimated(true)

			local remove_mode = false
			local remove_list = {}

			local rank_delete_func_list = {}
			local rank_set_background_color_func = {}
			local rank_power_func_list = {}
			local rank_invis_func_list = {}

			function list_panel:ClearColors()
				for k,func in pairs(rank_set_background_color_func) do
					func(Color(255, 255, 255))
				end
			end

			do -- Rank Build Code
				local function CreateRankElement(rank_object)
					local rank_button = vgui.Create("DCollapsibleCategory")
					rank_button:SetName(rank_object:GetName())

					function rank_button:GetRankObject()
						return rank_object
					end

					function SetPaint(color)
						rank_button:StartPaint()
							:Background(color)
							:BackgroundHover(Color(127, 127, 127, 127))
							:SideBlock(Color(59, 56, 56), BOTTOM, 1)
							:Text(rank_object:GetName(), Color(0, 0, 0), "Trebuchet18", TEXT_ALIGN_CENTER, -4)
							:CornerText(rank_object:GetPosition(), Color(127, 127, 127), "Trebuchet9", J_TEXT_CORNER_BOTTOM_RIGHT, -3, -3)
						rank_button:WritePaint()
					end

					SetPaint(Color(255, 255, 255))

					list_panel:AddChild(rank_object:GetName(), rank_button, rank_object:GetPosition())
					local modify_controls_panel = vgui.Create("DPanel")

					modify_controls_panel:StartPaint()
						:Background(Color(255, 255, 255))
						:SideBlock(Color(59, 56, 56), BOTTOM, 1)
					modify_controls_panel:WritePaint()

					local modify_power = vgui.Create("DNumSlider", modify_controls_panel)
					modify_power:Dock(TOP)
					modify_power:SetMin(0)
					modify_power:SetMax(32)
					modify_power:SetValue(rank_object:GetPower())
					modify_power:SetText("Power")

					if not CanModifyRankPower:Check(LocalPlayer():GetCode()) then
						modify_power:SetEnabled(false)
					end

					CanModifyRankPower_OnChange[1 + #CanModifyRankPower_OnChange] = function (access)
						if access then
							modify_power:SetEnabled(true)
						else
							modify_power:SetEnabled(false)
						end
					end

					function modify_power:OnValueChanged(value)
						RankModule:SendPowerUpdate(value)
					end

					local modify_invisible = vgui.Create("DCheckBoxLabel", modify_controls_panel)
					modify_invisible:Dock(TOP)
					modify_invisible:SetChecked(rank_object:GetInvisible())
					modify_invisible:SetText("Invisible")

					if not CanModifyRankInvisibility:Check(LocalPlayer():GetCode()) then
						modify_invisible:SetEnabled(false)
					end

					CanModifyRankInvisibility_OnChange[1 + #CanModifyRankInvisibility_OnChange] = function (access)
						if access then
							modify_invisible:SetEnabled(true)
						else
							modify_invisible:SetEnabled(false)
						end
					end

					function modify_invisible:OnChange(bVal)
						RankModule:SendInvisibilityUpdate(bVal)
					end

					rank_button:SetContents(modify_controls_panel)

					function rank_button:ToBeRemoved(value)
						if value == nil then
							return self.to_be_removed
						else
							self.to_be_removed = value
						end
					end

					function rank_button:DoClick()
						if remove_mode then
							if self:ToBeRemoved() then
								for k,v in ipairs(remove_list) do
									if v:GetName() == rank_object:GetName() then
										table.remove(remove_list, k)
										self:ToBeRemoved(false)
										rank_set_background_color_func[v:GetName()](Color(255, 255, 255))
									end
								end
							else
								remove_list[1 + #remove_list] = rank_object
								self:ToBeRemoved(true)
								SetPaint(Color(240, 120, 120))
							end
						else
							list_panel:ClearColors()
							if current_opened_rank_button == nil or current_opened_rank_button:GetName() != rank_object:GetName() then
								if current_opened_rank_button != nil then
									current_opened_rank_button:DoExpansion(false)
								end

								current_opened_rank_button = self

								if CanModifyRankPower:Check(LocalPlayer():GetCode()) or CanModifyRankInvisibility:Check(LocalPlayer():GetCode()) then
									current_opened_rank_button:DoExpansion(true)
								end

								for name,func in pairs(rank_power_func_list) do
									if modify_power:GetValue() > func() then
										rank_set_background_color_func[name](Color(226, 240, 217))
									end
								end

								rank_set_background_color_func[rank_object:GetName()](Color(173, 185, 202))
							else
								current_opened_rank_button = nil
							end
						end
					end

					rank_delete_func_list[rank_object:GetName()] = function ()
						rank_button:Remove()
						list_panel:RemoveChild(rank_object:GetName())
					end

					rank_set_background_color_func[rank_object:GetName()] = function (color)
						SetPaint(color)
					end

					rank_power_func_list[rank_object:GetName()] = function (value)
						if value == nil then
							return modify_power:GetValue()
						else
							modify_power:SetValue(value)
						end
					end

					rank_invis_func_list[rank_object:GetName()] = function (checked)
						if checked == nil then
							return modify_invisible:GetChecked()
						else
							modify_invisible:SetChecked(checked)
						end
					end
				end

				for RankObject in RankModule:iRank() do
					CreateRankElement(RankObject)
				end

				list_panel:RefreshPositions(true, true, true)

				function RankHook_OnAdd.DefaultInterface_RankTab_DynamicUpdate(rank_object)
					CreateRankElement(rank_object)
					list_panel:InvalidatePositions()
					list_panel:RefreshPositions()
				end

				function RankHook_OnRemove.DefaultInterface_RankTab_DynamicUpdate(multi, rank_objects)
					if multi then
						for k,v in ipairs(rank_objects) do
							rank_delete_func_list[v:GetName()]()
						end
					else
						rank_delete_func_list[rank_object:GetName()]()
					end

					list_panel:InvalidatePositions()
					list_panel:RefreshPositions()
				end

				function RankHook_OnPowerUpdate.DefaultInterface_RankTab_DynamicUpdate(rank_object, power)
					rank_power_func_list[rank_object:GetName()](power)
				end

				function RankHook_OnInvisibleUpdate.DefaultInterface_RankTab_DynamicUpdate(rank_object, invis)
					rank_invis_func_list[rank_object:GetName()](invis)
				end
			end

			local modify_category = vgui.Create("DCollapsibleCategory", rank_list)
			modify_category:Dock(BOTTOM)

			local add_panel = vgui.Create("DPanel")
			add_panel:DockPadding(4, 4, 4, 4)

			do -- Add Panel
				local name_textentry = vgui.Create("DTextEntry", add_panel)
				name_textentry:Dock(TOP)
				name_textentry:DockMargin(0, 0, 0, 4)

				local power_slide = vgui.Create("DNumSlider", add_panel)
				power_slide:Dock(TOP)
				power_slide:DockMargin(0, 0, 0, 4)

				local invisible_checkbox = vgui.Create("DCheckBoxLabel", add_panel)
				invisible_checkbox:Dock(TOP)

				add_panel:InvalidateLayout()
				add_panel:SizeToChildren(false, true)

				function add_panel:GetName()
					return name_textentry:GetValue()
				end

				function add_panel:GetPower()
					return power_slide:GetValue()
				end

				function add_panel:GetInvisible()
					return invisible_checkbox:GetChecked()
				end
			end

			do -- Button Code
				local button_panel = vgui.Create("DPanel")

				local left_button_add_submit_cancel = vgui.Create("DButton", button_panel)
				left_button_add_submit:Dock(LEFT)

				local right_button_remove_cancel = vgui.Create("DButton", button_panel)
				right_button_remove_cancel:Dock(RIGHT)

				modify_category.Header = button_panel

				local function LeftButtonPaint(state)
					if state == 1 then -- Cancel
						left_button_add_submit_cancel:StartPaint()
							:BackgroundHover(Color(105, 164, 217))
							:Text("Cancel", Color(0, 0, 0), "Default", TEXT_ALIGN_CENTER)
						left_button_add_submit_cancel:WritePaint()
					elseif state == 2 then -- Disabled Add
						left_button_add_submit_cancel:StartPaint()
							:Text("Add", Color(166, 166, 166), "Default", TEXT_ALIGN_CENTER)
						left_button_add_submit_cancel:WritePaint()
					else -- Add
						left_button_add_submit_cancel:StartPaint()
							:BackgroundHover(Color(125, 231, 128))
							:Text("Add", Color(0, 0, 0), "Default", TEXT_ALIGN_CENTER)
						left_button_add_submit_cancel:WritePaint()
					end
				end

				local function RightButtonPaint(state)
					if state == 1 then -- Cancel
						right_button_remove_cancel:StartPaint()
							:BackgroundHover(Color(105, 164, 217))
							:Text("Cancel", Color(0, 0, 0), "Default", TEXT_ALIGN_CENTER)
						right_button_remove_cancel:WritePaint()
					elseif state == 2 then -- Disabled Remove
						right_button_remove_cancel:StartPaint()
							:Text("Remove", Color(166, 166, 166), "Default", TEXT_ALIGN_CENTER)
						right_button_remove_cancel:WritePaint()
					else -- Remove
						right_button_remove_cancel:StartPaint()
							:BackgroundHover(Color(240, 116, 116))
							:Text("Remove", Color(0, 0, 0), "Default", TEXT_ALIGN_CENTER)
						right_button_remove_cancel:WritePaint()
					end
				end

				local CanAddRank = PermissionModule:GetPermission("Can Add Rank")
				local CanRemoveRank = PermissionModule:GetPermission("Can Remove Rank")

				local function EnableLeftButton(access)
					if access then -- Enable
						LeftButtonPaint()
						left_button_add_submit_cancel:SetMouseInputEnabled(true)
					else -- Disable
						LeftButtonPaint(2)
						left_button_add_submit_cancel:SetMouseInputEnabled(false)
						modify_category:DoExpansion(false)
					end
				end

				local function EnableRightButton(access)
					if access then -- Enable
						RightButtonPaint()
						right_button_remove_cancel:SetMouseInputEnabled(true)
					else -- Disable
						RightButtonPaint(2)
						right_button_remove_cancel:SetMouseInputEnabled(false)
						remove_mode = false
						list_panel:ClearColors()
					end
				end

				EnableLeftButton(CanAddRank:Check(LocalPlayer():GetCode()))

				EnableRightButton(CanRemoveRank:Check(LocalPlayer():GetCode()))

				CanModifyPlayer:OnLocalPermissionAccessChange(CanAddRank, function (access)
					EnableLeftButton(access)
				end)

				CanModifyPlayer:OnLocalPermissionAccessChange(CanRemoveRank, function (access)
					EnableRightButton(access)
				end)

				function left_button_add_submit_cancel:DoClick()
					if modify_category:GetExpanded() then -- Add Mode : Add
						modify_category:DoExpansion(false)
						RightButtonPaint()
						RankModule:AddRank(add_panel:GetName(), add_panel:GetPower(), add_panel:GetInvisible())
					else
						if remove_mode then -- Remove Mode : Cancel
							remove_mode = false
							LeftButtonPaint()
							list_panel:ClearColors()
							if current_opened_rank_button != nil then
								current_opened_rank_button:DoExpansion(false)
								current_opened_rank_button = nil
							end
						else -- Default : Add
							modify_category:DoExpansion(true)
							RightButtonPaint(1) -- Right : Cancel
						end
					end
				end

				function right_button_remove_cancel:DoClick()
					if modify_category:GetExpanded() then -- Add Mode : Cancel
						modify_category:DoExpansion(false)
						RightButtonPaint()
					else
						if remove_mode then -- Remove Mode : Remove
							LeftButtonPaint()
							list_panel:ClearColors()
							if #remove_list > 1 then
								RankModule:RemoveRanks(remove_list)
							else
								RankModule:RemoveRank(remove_list[1])
							end
						else -- Default : Remove
							remove_mode = true
							remove_list = {}
							LeftButtonPaint(1) -- Left : Cancel
							list_panel:ClearColors()
							if current_opened_rank_button != nil then
								current_opened_rank_button:DoExpansion(false)
								current_opened_rank_button = nil
							end
						end
					end
				end
			end
		end

		local modify_panel = vgui.Create("DPanel", root)
		modify_panel:ClearPaint()
		modify_panel:Dock(FILL)
		modify_panel:DockMargin(4, 0, 0, 0)

		local tab_button_panel = vgui.Create("DPanel", modify_panel)
		tab_button_panel:ClearPaint()
		tab_button_panel:Dock(TOP)
		tab_button_panel:DockMargin(0, 0, 0, 4)

		local tab_panel = vgui.Create("JTabPanel", modify_panel)
		tab_panel:ClearPaint()
		tab_panel:Dock(FILL)
		tab_panel:DockMargin(0, 4, 0, 0)

		local function CreateTabButton(name, panel)
			tab_panel:AddTab(name, panel)

			local tab_button = vgui.Create("DButton", tab_button_panel)
			tab_button:SetText(name)

			function tab_button:DoClick()
				tab_panel:OpenTab(name)
			end

			return tab_button
		end

		local PaintLib = GUI:GetPaintLibObject()

		do -- Commands
			local commands_tab = vgui.Create("DScrollPanel")

			local tab_button = CreateTabButton("Commands", commands_tab)
			tab_button:Dock(LEFT)
			tab_button:DockMargin(0, 0, 2, 0)

			local function CreateCommandElement(command_object)
				local command_button = vgui.Create("DButton", commands_tab)
				command_button:Dock(TOP)
				command_button:SetTall(37)

				function command_button:Think()
					self.BackgroundHover = Lerp(FrameTime() * v[3], 0, IsHovered(self, false) and 1 or 0)
				end

				function command_button:Paint(w, h)
					if command_object:GetCode() == 0 then
						PaintLib.Background(w, h, self, Color(226, 240, 217))
					else
						if current_opened_rank_button == nil or command_object:Check(current_opened_rank_button:GetRankObject():GetCode()) then
							PaintLib.Background(w, h, self, Color(255, 255, 255))
						else
							PaintLib.Background(w, h, self, Color(173, 185, 202))
						end
					end

					PaintLib.BackgroundHover(w, h, self, self.BackgroundHover, Color(127, 127, 127, 127))
					PaintLib.SideBlock(w, h, self, Color(59, 56, 56), BOTTOM, 1)
					PaintLib.Text(w, h, self, command_object:GetName(), Color(0, 0, 0), "Trebuchet18", TEXT_ALIGN_LEFT, -2, 4)
					PaintLib.CornerText(w, h, self, bit.tobit(command_object:GetCode()), Color(127, 127, 127), "Trebuchet9", J_TEXT_CORNER_BOTTOM_LEFT, -2, 4)
				end

				function command_button:DoClick()
					if current_opened_rank_button != nil then
						CommandModule:SetCommandCode(command_object, current_opened_rank_button:GetRankObject())
					end
				end
			end

			for CommandObject in CommandModule:iCommand() do
				CreateCommandElement(CommandObject)
			end

			if CanModifyCommand:Check(LocalPlayer():GetCode()) then
				tab_button:SetEnabled(true)
			else
				tab_button:SetEnabled(false)
			end

			CanModifyCommand_OnChange[1 + #CanModifyCommand_OnChange] = function (access)
				if access then
					tab_button:SetEnabled(true)
				else
					tab_button:SetEnabled(false)
				end
			end
		end

		do -- Permissions
			local permissions_tab = vgui.Create("DScrollPanel")

			local tab_button = CreateTabButton("Permissions", permissions_tab)
			tab_button:Dock(FILL)

			local function CreatePermissionElement(permission_object)
				local permission_button = vgui.Create("DButton", permissions_tab)
				permission_button:Dock(TOP)
				permission_button:SetTall(37)

				function permission_button:Think()
					self.BackgroundHover = Lerp(FrameTime() * v[3], 0, IsHovered(self, false) and 1 or 0)
				end

				function permission_button:Paint(w, h)
					if permission_object:GetCode() == 0 then
						PaintLib.Background(w, h, self, Color(226, 240, 217))
					else
						if current_opened_rank_button == nil or not permission_object:Check(current_opened_rank_button:GetRankObject():GetCode()) then
							PaintLib.Background(w, h, self, Color(255, 255, 255))
						else
							PaintLib.Background(w, h, self, Color(173, 185, 202))
						end
					end

					PaintLib.BackgroundHover(w, h, self, self.BackgroundHover, Color(127, 127, 127, 127))
					PaintLib.SideBlock(w, h, self, Color(59, 56, 56), BOTTOM, 1)
					PaintLib.Text(w, h, self, permission_object:GetName(), Color(0, 0, 0), "Trebuchet18", TEXT_ALIGN_LEFT, -2, 4)
					PaintLib.CornerText(w, h, self, bit.tobit(permission_object:GetCode()), Color(127, 127, 127), "Trebuchet9", J_TEXT_CORNER_BOTTOM_LEFT, -2, 4)
				end

				function permission_button:DoClick()
					if current_opened_rank_button != nil then
						PermissionModule:ModifyCode(permission_object, current_opened_rank_button:GetRankObject())
					end
				end
			end

			for PermissionObject in PermissionModule:iPermission() do
				CreatePermissionElement(PermissionObject)
			end

			if CanModifyPermission:Check(LocalPlayer():GetCode()) then
				tab_button:SetEnabled(true)
			else
				tab_button:SetEnabled(false)
			end

			CanModifyPermission_OnChange[1 + #CanModifyPermission_OnChange] = function (access)
				if access then
					tab_button:SetEnabled(true)
				else
					tab_button:SetEnabled(false)
				end
			end
		end

		do -- Players
			local players_tab = vgui.Create("DScrollPanel")

			local tab_button = CreateTabButton("Players", players_tab)
			tab_button:Dock(RIGHT)
			tab_button:DockMargin(2, 0, 0, 0)

			local player_button_element_delete_func = {}

			local function CreatePlayerElement(ply)
				local player_button = vgui.Create("DButton", players_tab)
				player_button:Dock(TOP)
				player_button:SetTall(37)

				function player_button:Think()
					self.BackgroundHover = Lerp(FrameTime() * v[3], 0, IsHovered(self, false) and 1 or 0)
				end

				function player_button:Paint(w, h)
					if ply:GetCode() == 0 then
						PaintLib.Background(w, h, self, Color(226, 240, 217))
					else
						if current_opened_rank_button == nil or bit.band(ply:GetCode(), current_opened_rank_button:GetRankObject():GetCode()) > 0 then
							PaintLib.Background(w, h, self, Color(255, 255, 255))
						else
							PaintLib.Background(w, h, self, Color(173, 185, 202))
						end
					end

					PaintLib.BackgroundHover(w, h, self, self.BackgroundHover, Color(127, 127, 127, 127))
					PaintLib.SideBlock(w, h, self, Color(59, 56, 56), BOTTOM, 1)
					PaintLib.Text(w, h, self, ply:Nick(), Color(0, 0, 0), "Trebuchet18", TEXT_ALIGN_LEFT, -2, 4)
					PaintLib.CornerText(w, h, self, bit.tobit(ply:GetCode()), Color(127, 127, 127), "Trebuchet9", J_TEXT_CORNER_BOTTOM_LEFT, -2, 4)
				end

				function player_button:DoClick()
					if current_opened_rank_button != nil then
						PlayerModule:SetPlayerCode(ply, current_opened_rank_button:GetRankObject())
					end
				end

				player_button_element_delete_func[ply:SteamID()] = function ()
					player_button:Remove()
				end
			end

			for k,ply in ipairs(player.GetHumans()) do
				CreatePlayerElement(ply)
			end

			function PlayerHook_OnConnect.Default_Interface_DynamicUpdate(ply)
				CreatePlayerElement(ply)
			end

			function PlayerHook_OnDisconnect.Default_Interface_DynamicUpdate(ply)
				player_button_element_delete_func[ply:SteamID()]()
			end

			if CanModifyPlayer:Check(LocalPlayer():GetCode()) then
				tab_button:SetEnabled(true)
			else
				tab_button:SetEnabled(false)
			end

			CanModifyPlayer_OnChange[1 + #CanModifyPlayer_OnChange] = function (access)
				if access then
					tab_button:SetEnabled(true)
				else
					tab_button:SetEnabled(false)
				end
			end
		end
	end

	do -- Access Group Tab
		local AccessGroupTab = GUI:RegisterTab("Access", Color(81, 223, 145), 2, true)
	end

	do -- Log Tab
		local LogTab = GUI:RegisterTab("Log", Color(211, 111, 199), 3, true)
	end
end