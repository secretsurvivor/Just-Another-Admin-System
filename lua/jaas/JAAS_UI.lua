local JUI = JAAS:GetModule("GUI"):RegisterInterface("Default::JUI", "secret_survivor", 1.0)

local JAAS_side_menu = vgui.Create("DScrollPanel")

do -- Main JAAS Menu Code
	JAAS_side_menu:StartPaint()
		:Background(Color(59, 56, 56))
	JAAS_side_menu:WritePaint()
	JAAS_side_menu:HideScrollBar()
	JAAS_side_menu:SetPos(ScrW() * 0.935, ScrH() * 0.21)
	JAAS_side_menu:SetSize(ScrW() * 0.07, ScrH() * 0.58)
	JAAS_side_menu:SetZPos(1)

	local side_menu_canvas = vgui.Create("JControlPanel")
	side_menu_canvas:SetBasePadding(8, 8, 8, 8)
	side_menu_canvas:BaseAutoSize(false)
	side_menu_canvas:ChildrenAutoSize(true)
	side_menu_canvas:SetOrder(false)
	side_menu_canvas:SetAnimated(true)
	JAAS_side_menu:SetCanvas(side_menu_canvas)

	function JAAS_side_menu:AddTabButton(tab_object, panel)

	end

	function JUI:Post()
		side_menu_canvas:RefreshPositions()
	end
end