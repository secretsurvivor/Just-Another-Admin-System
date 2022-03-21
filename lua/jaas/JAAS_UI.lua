local JUI = JAAS:GetModule("GUI"):RegisterInterface("Default::JUI", "secret_survivor", 1.0)

local visible_tab_window_funcs, visible_tab_button_funcs = {}, {}

local current_open_panel_right, current_open_panel_left

local background_panel = vgui.Create("DPanel")
local background_blur_amount = 4

do -- Background Panel Code
	background_panel:SetSize(ScrW(), ScrH())
	background_panel:SetPos(0, 0)

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