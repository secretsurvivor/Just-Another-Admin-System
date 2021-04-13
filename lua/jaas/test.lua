local panel = JAAS.Panel()
local GUI = JAAS.GUI()
local dev = JAAS.Dev()
local gui_gVar_set, gui_gVar_get, gui_hook = JAAS.GlobalVar.Set "GUI", JAAS.GlobalVar.Get "GUI", JAAS.Hook.GlobalVar "GUI"

gui_gVar_set "BackgroundColor_1" (cookie.GetColor("JAAS_BackgroundColor_1", Color(59, 56, 56, 255))) -- Panel Background
gui_hook "BackgroundColor_1" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_BackgroundColor_1", after)
end

gui_gVar_set "BackgroundColor_2" (cookie.GetColor("JAAS_BackgroundColor_2", Color(242, 242, 242, 255))) -- Element Background
gui_hook "BackgroundColor_2" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_BackgroundColor_2", after)
end

gui_gVar_set "TextColor_1" (cookie.GetColor("JAAS_TextColor_1", Color(242, 242, 242, 255))) -- Contrast Background 1, normal
gui_hook "TextColor_1" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_TextColor_1", after)
end

gui_gVar_set "TextColor_2" (cookie.GetColor("JAAS_TextColor_2", Color(255, 255, 255, 255))) -- Contrast Background 1, header
gui_hook "TextColor_2" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_TextColor_2", after)
end

gui_gVar_set "TextColor_3" (cookie.GetColor("JAAS_TextColor_3", Color(0, 0, 0, 255))) -- Contrast Background 2
gui_hook "TextColor_3" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_TextColor_3", after)
end

gui_gVar_set "TextColor_4" (cookie.GetColor("JAAS_TextColor_4", Color(191, 191, 191, 255))) -- Shade of Text Color 2, used for unselected text
gui_hook "TextColor_4" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_TextColor_4", after)
end

gui_gVar_set "TextColor_5" (cookie.GetColor("JAAS_TextColor_5", Color(127, 127, 127, 255)))  -- Shade of Text Color 2
gui_hook "TextColor_5" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_TextColor_5", after)
end

gui_gVar_set "SelectionColor_1" (cookie.GetColor("JAAS_SelectionColor_1", Color(173, 185, 202)))
gui_hook "SelectionColor_1" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_SelectionColor_1", after)
end

gui_gVar_set "SelectionColor_2" (cookie.GetColor("JAAS_SelectionColor_2", Color(226, 240, 217)))
gui_hook "SelectionColor_2" ["UpdateCookie"] = function (before, after)
    cookie.SetColor("JAAS_SelectionColor_2", after)
end

gui_gVar_set "MenuToggle" (cookie.GetBool("JAAS_MenuToggle", true))
gui_hook "MenuToggle" ["UpdateCookie"] = function (before, after)
    cookie.SetBool("JAAS_MenuToggle", after)
end

GUI.RegisterSettings("User Interface",{
    {"Panel Background", "COLOR", function (color)
        gui_gVar_set "BackgroundColor_1" (color)
    end, gui_gVar_get "BackgroundColor_1", "Changes the color of panel backgrounds"},

    {"Text Color Normal", "COLOR", function (color)
        gui_gVar_set "TextColor_1" (color)
    end, gui_gVar_get "TextColor_1", "Changes the color of the normal text color, this contrasts Panel Background"},

    {"Text Color Header", "COLOR", function (color)
        gui_gVar_set "TextColor_2" (color)
    end, gui_gVar_get "TextColor_2", "Changes the color of the header text color, this contrasts Panel Background"},

    {"Element Background", "COLOR", function (color)
        gui_gVar_set "BackgroundColor_2" (color)
    end, gui_gVar_get "BackgroundColor_2", "Changes the color of element backgrounds"},

    {"Element Text Color 1", "COLOR", function (color)
        gui_gVar_set "TextColor_3" (color)
    end, gui_gVar_get "TextColor_3", "Changes the color of the text color, this contrasts Element Background"},

    {"Element Text Color 2", "COLOR", function (color)
        gui_gVar_set "TextColor_4" (color)
    end, gui_gVar_get "TextColor_4", "Changes the color of the text color, this is a shade that contrasts Element Background"},

    {"Element Text Color 3", "COLOR", function (color)
        gui_gVar_set "TextColor_5" (color)
    end, gui_gVar_get "TextColor_5", "Changes the color of the text color, this is a shade that contrasts Element Background"},

    {"Element Selection 1", "COLOR", function (color)
        gui_gVar_set "SelectionColor_1" (color)
    end, gui_gVar_get "SelectionColor_1", "Element selection color 1"},

    {"Element Selection 2", "COLOR", function (color)
        gui_gVar_set "SelectionColor_2" (color)
    end, gui_gVar_get "SelectionColor_2", "Element selection color 2"},

    {},

    {"UI Toggle", "BOOL", function (bool)
        gui_gVar_set "MenuToggle" (bool)
        open = bool
    end, gui_gVar_get "MenuToggle", "If the User Interface is toggled open"}
})

local CONTROL = panel.ControlBuilder "DButton" ("JMenuButton", "Menu Button that uses JAAS' Icon Vector")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "Icon"
CONTROL:AccessorFunc "Label"

function CONTROL:Setup(label, icon) -- Icon needs to be a JVector
    self:SetText(label)
    self:SetTextColor(gui_gVar_get "TextColor_2")
    self:SetLabel(dLabel)
    self:SetContentAlignment(5)
    if icon then
        local w,h = self:GetSize()
        icon:SetParent(self)
        self:Add(icon)
        icon:Dock(1)
        icon:SetSize(w * 0.8, w * 0.8)
        icon:SetPos(w * 0.1, 0)
        icon:Show()
        self:SetIcon(icon)
    end
end

function CONTROL:SetColor(color)
    self:GetLabel():SetColor(color)
    self:GetIcon():SetColor(color)
end

function CONTROL:Paint()
end

CONTROL:Define()

CONTROL = panel.ControlBuilder "DPanel" ("JMenuPanel", "Panel dedicated to the JAAS Menu")
CONTROL:Derma_Hook "Paint"

function CONTROL:Setup(label, panel)
    local dLabel = vgui.Create("DLabel", self)
    dLabel:SetText(label)
    dLabel:SetColor(gui_gVar_get "TextColor_2")
    dLabel:Dock(4)
    dLabel:SetContentAlignment(2)
    local w,h = self:GetSize()
    panel:SetParent(self)
    panel:StretchToParent(w * 0.05, h * 0.08, w * 0.05, 0)
    local selWidth = self:GetSize()
    self:SetSize(selWidth * 0.15 + panel:GetWide(), ScrH() * 0.85)
end

function CONTROL:Paint(w, h)
    surface.SetDrawColor(gui_gVar_get "BackgroundColor_1":Unpack())
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(gui_gVar_get "TextColor_2":Unpack())
    surface.DrawLine(w * 0.05, h * 0.06, w * 0.95, h * 0.06)
end

CONTROL:Define()

CONTROL = panel.ControlBuilder "DPanel" ("JPanelGrid", "Panel grid that fits accordingly per added panel")
CONTROL:AccessorFunc "Padding"
CONTROL:AccessorFunc "Cols"
CONTROL:AccessorFunc "ColWide"
CONTROL:AccessorTableFunc "PanelList"

function CONTROL:Init()
    self:SizeToChildren(false, true)
    self:SetCols(1)
    self:SetPadding(0)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetPaintBackground(false)
end

function CONTROL:AddPanel(panel)
    panel:SetParent(self)
    local height_sum = self:GetPadding()
    if self.panelNum != nil then
        for i= 1 + (1 + self.panelNum) % self:GetCols(),self.panelNum,self:GetCols() do
            height_sum = height_sum + self.___PanelList[i]:GetTall() + self:GetPadding()
        end
    end
    self:AppendPanelList(panel)
    self.panelNum = 1 + (self.panelNum or 0)
    panel:SetPos(self:GetPadding() + panel:GetWide() * (1 - (1 + (self.panelNum % self:GetCols()))), height_sum)
end

CONTROL:Define()

local UI, main_interface = GUI.RegisterInterface(vgui.Create "DPanel")
main_interface:SetSize(ScrW() * 0.05, ScrH() * 0.58)
main_interface:SetPos(ScrW() * 0.95, ScrH() * 0.21)
main_interface:SetZPos(1)
main_interface:Hide()

function main_interface:Paint(w, h)
    surface.SetDrawColor(gui_gVar_get "BackgroundColor_1":Unpack())
    surface.DrawRect(0, 0, w, h)
end

function main_interface:ShowAll()
    self:Show()
    if self.currentPanel then
        self.currentPanel:Show()
    end
end

function main_interface:HideAll()
    self:Hide()
    if self.currentPanel then
        self.currentPanel:Hide()
    end
end

UI:SetAccess(function ()
    if gui_gVar_get "MenuToggle" then
        if open then
            main_interface:HideAll()
        else
            main_interface:ShowAll()
        end
        open = !open
        gui.EnableScreenClicker(open)
    else
        main_interface:ShowAll()
        gui.EnableScreenClicker(true)
    end
end, function ()
    if !gui_gVar_get "MenuToggle" then
        main_interface:HideAll()
        gui.EnableScreenClicker(false)
    end
end)

function main_interface:OpenPanel(panel)
    if panel == self.currentPanel then
        self.currentPanel:SetZPos(-2)
        self.currentPanel:MoveTo(ScrW(), ScrH() * 0.21, 0.1, 0, -1, function (animData, pnl)
            pnl:Hide()
        end)
        self.currentPanel = nil
    else
        if self.currentPanel then
            self.currentPanel:SetZPos(-2)
            self.currentPanel:MoveTo(ScrW(), ScrH() * 0.21, 0.1, 0, -1, function (animData, pnl)
                pnl:Hide()
            end)
        end
        self.currentPanel = panel
        panel:Show()
        panel:SetZPos(-1)
        panel:SetPos(ScrW(), ScrH() * 0.21)
        local w,h = panel:GetSize()
        panel:MoveTo(ScrW() * 0.92 - w, ScrH() * 0.21, 0.1, 0, -1, function (animData, pnl)
            panel:SetPos(ScrW() * 0.92 - w, ScrH() * 0.21)
        end)
    end
end

local canModifyRank = panel.PermissionCheck("Can Modify Rank Table")
local canModifyCommand = panel.PermissionCheck("Can Modify Commands")
local canModifyPermission = panel.PermissionCheck("Can Modify Permissions")
local canModifyPlayers = panel.PermissionCheck("Can Modify Player")
if canModifyRank or canModifyCommand or canModifyPermission or canModifyPlayers then
    local ranks = vgui.Create("JMenuPanel")
    ranks:SetSize(ScrW() * 0.27, ScrH() * 0.58)
    local rank_panel = vgui.Create("DPanel", ranks)
    local rank_list = vgui.Create("JSelectionList", rank_panel)
    rank_list:SetSize(ScrW() * 0.1, ScrH() * 0.485)

    net.Start "JAAS_RankPullChannel"
    net.SendToServer()

    net.Receive("JAAS_RankPullChannel", function (len, ply)
        local rankTable = net.ReadTable()
        for k,v in ipairs(rankTable) do
            local button = vgui.Create("JBoolButton")
            button:SetSize(rank_list:GetWide(), ScrH() * 3.33)
            --button.DoClick
        end
    end)

    ranks:Setup("Ranks", rank_panel)
    GUI.RegisterTab("Ranks", ranks)
end

local settings = vgui.Create("JMenuPanel")
settings:SetSize(ScrW() * 0.33, ScrH() * 0.58)
local settings_panel = vgui.Create("JPanelGrid", settings)
settings_panel:Dock(1)
settings_panel:SetPadding(7)
settings:Setup("Settings", settings_panel)
GUI.RegisterTab("Settings", settings, -1)

UI.BuildTabs(function (name, panel, order)
    local button = vgui.Create("JMenuButton", main_interface)
    button:Setup(name, icon)
    button.DoClick = function (self)
        main_interface:OpenPanel(panel)
    end
    panel:SetSize(panel:GetWide(), ScrH() * 0.58)
    button:SetSize(ScrW() * 0.05, ScrH() * 0.09)
    main_interface:Add(button)
end)

UI.BuildSettings(function (name, settings_info)
    local var_panel = vgui.Create("DPanel", settings_panel)
    var_panel.Paint = function (self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, gui_gVar_get "BackgroundColor_2")
        surface.SetDrawColor(gui_gVar_get "TextColor_3":Unpack())
        surface.DrawLine(w * 0.075, h * 0.06, w * 0.925, h * 0.06)
    end
    var_panel:SizeToChildren(false, true)
    local title = vgui.Create("DLabel", var_panel)
    title:Dock(4)
    title:SetContentAlignment(5)
    title:SetColor(gui_gVar_get "TextColor_3")
    title:SetText(name)
    local internal_panel = vgui.Create("JPanelGrid", var_panel)
    internal_panel:Dock(1)
    internal_panel:SetContentAlignment(5)
    internal_panel:SetCols(1)
    internal_panel:SetPadding(7)
    internal_panel:Dock(1)
    internal_panel:StretchToParent(7, 7, 15, 7)
    internal_panel:SetPos(var_panel:GetWide() * 0.05, var_panel:GetTall() * 0.08)
    internal_panel:SetPaintBackgroundEnabled(false)
	internal_panel:SetPaintBorderEnabled(false)
	internal_panel:SetPaintBackground(false)
    local element
    for k,v in ipairs(settings_info) do
        if #v == 0 then
            element = vgui.Create("DPanel")
            element.Paint = function (self, w, h)
                surface.SetDrawColor(0, 0, 0)
                surface.DrawLine(w * 0.075, h * 0.5, w * 0.925, h * 0.5)
            end
        elseif v[2] == "COLOR" then
            element = vgui.Create("JColorPicker")
            element.OnChange = function (self, color)
                v[3](color)
            end
            element:SetColor(v[4])
            element:SetText(v[1])
        elseif v[2] == "BOOL" then
            element = vgui.Create("DCheckBoxLabel")
            element.OnChange = function (self, bool)
                v[3](bool)
            end
            element:SetTextColor(gui_gVar_get "TextColor_3")
            element:SetText(v[1])
            element:SetChecked(v[4])
        end
        element:SetSize(ScrW() * 0.1, 25)
        internal_panel:AddPanel(element)
        internal_panel:InvalidateLayout(true)
        var_panel:InvalidateLayout(true)
    end
    var_panel:SetSize(ScrW() * 0.11, ScrH())
    internal_panel:SizeToChildren(false, true)
    var_panel:SizeToChildren(false, true)
    settings_panel:AddPanel(var_panel)
end)