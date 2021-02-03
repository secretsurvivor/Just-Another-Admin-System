local MODULE, log, dev = JAAS:RegisterModule "Panel"
local panel = {PermissionCheck = true, ControlBuilder = true}
local permissionCheck = {}

function panel.PermissionCheck(permName, success, failure)
    net.Start "JAAS_PermissionClientCheck"
    net.WriteString(permName)
    net.SendToServer()
    permissionCheck[permName] = {success, failure}
end

net.Receive("JAAS_PermissionClientCheck" , function (name, check)
    name = net.ReadString()
    if permissionCheck[name] then
        check = net.ReadBool() and 1 or 2
        if isfunction(permissionCheck[name][check]) then
            permissionCheck[name][check]()
        end
        permissionCheck[name] = nil
    end
end)

function panel.ControlBuilder(base)
    return function (name, description)
        return setmetatable({internal = {PermissionAdd = function (self, permName, panel)
                panel.PermissionCheck(permName, function ()
                    self:Add(panel)
                end)
            end}}, {
            __newindex = function (self, k, v)
                self.internal[k] = v
            end,
            __index = {
                Derma_Hook = function (self, func)
                    Derma_Hook(self.internal, func, func, name)
                end,
                Derma_Install_Convar_Functions = function ()
                    Derma_Install_Convar_Functions(self.internal)
                end,
                Derma_Anim = function (name, func)
                    Derma_Anim(name, self.internal, func)
                end,
                Derma_DrawBackgroundBlur = function (startTime)
                    Derma_DrawBackgroundBlur(self.internal, startTime or 0)
                end,
                DermaMenu = function (keepOpen)
                    DermaMenu(keepOpen or true, self.internal)
                end,
                RegisterDermaMenuForClose = function ()
                    RegisterDermaMenuForClose(self.internal)
                end,
                AccessorFunc = function (self, name, force)
                    self.internal["Get" .. name] = function (self)
                        return self["___" .. name]
                    end
                    if force == 1 then -- String
                        self.internal["Set" .. name] = function (self, v)
                            self["___" .. name] = tostring(v)
                        end
                    elseif force == 2 then -- Number
                        self.internal["Set" .. name] = function (self, v)
                            self["___" .. name] = tonumber(v)
                        end
                    elseif force == 3 then -- Bool
                        self.internal["Set" .. name] = function (self, v)
                            self["___" .. name] = tobool(v)
                        end
                    else
                        self.internal["Set" .. name] = function (self, v)
                            self["___" .. name] = v
                        end
                    end
                end,
                AccessorTableFunc = function (self, name)
                    self.internal["___" .. name] = {}
                    self.internal["Get" .. name] = function (self)
                        return self["___" .. name]
                    end
                    self.internal["Append" .. name] = function (self, v)
                        self["___" .. name][1 + #self["___" .. name]] = v
                        return #self["___" .. name]
                    end
                    self.internal["Set" .. name] = function (self, v)
                        self["___" .. name] = {v}
                    end
                end,
                Define = function (self, n, d)
                    derma.DefineControl(name, description, self.internal, base)
                    if n and d then
                        self.internal = {}
                        name = n
                        description = d
                    end
                end
            }
        })
    end
end

MODULE.Access(MODULE.Class(panel, "jaas_panel_library"))

/* Custom Element List
    Vertical Icon Tab List
        Icon Tab
    Command List
        Argument Forms - Created with Command Object
            Bool
            Number Selector
                Integer
                Float
            String
            Selection Table - Single and Multiple select
                Player/Players
                Rank/Ranks
                Option/Options
            Execute Command
    Rank Modifier
        Integer Form - For power value so it does not go below 0
        Rank List - Support Access Modifier
            Rank Label - Created with Rank Object
        JAAS Object List - For Command, Permission, and User
            Command Category
            Object Label - Created using Command, Permission, Rank, Access, and User Object - Needs to be able to show Rank Code and Access Value on both left and right side of the label
    Access Modifier
        Access Group List with Selected value slider
    Log
        Log Reader
            Time selector
    Settings Menu
        Panel Controller
    Scrollbar Panel
        Scrollbar
*/

local CONTROL = panel.ControlBuilder "DButton" ("JColourPicker", "Interactive Button that opens DColorMixer")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "Colour"

function CONTROL:OnChange(colour)
end

local picker_panel
function CONTROL:DoClick()
    picker_panel = vgui.Create("DFrame")
    local colour_picker = vgui.Create("DColorMixer", picker_panel)
    local save_button = vgui.Create("DButton", picker_panel)
    local w,h = self:GetPos()
    picker_panel:SetPos(w, h)
    picker_panel:SetSize(ScrW() * 0.2, ScrH() * 0.2)
    picker_panel:SetSizable(true)
    picker_panel:SetTitle("")
    picker_panel.Paint = function (self, w, h)
        surface.SetDrawColor(228, 228, 228)
        for i=0,h do
            surface.DrawLine(0, i, w, i)
        end
        surface.SetDrawColor(0, 0, 0)
        surface.DrawRect(0, 0, w, h)
    end
    colour_picker:Dock(1)
    save_button:Dock(5)
    save_button.DoClick = function ()
        self:SetColour(colour_picker:GetColor())
        self:OnChange(self:GetColour())
        picker_panel:Remove()
    end
    save_button:SetText("Save")
end

function CONTROL:Paint(w, h)
    surface.SetDrawColor(self:GetColour() or Colour(0,0,0))
    for i=0,h do
        surface.DrawLine(0, i, w, i)
    end
end

CONTROL:Define("JBoolButton", "Button that acts as a Checkbox")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "BackgroundColour"
CONTROL:AccessorFunc "SelectedColour"
CONTROL:AccessorFunc "AltSelectionColour"
CONTROL:AccessorFunc "AltColour"
CONTROL:AccessorFunc "Checked"
CONTROL:AccessorFunc "LabelType"
CONTROL:AccessorFunc "TextColour"
CONTROL:AccessorFunc "AltTextColour"
CONTROL:AccessorFunc "TextAlignment"
CONTROL:AccessorFunc "AltTextAlignment"
CONTROL:AccessorFunc "Padding"

function CONTROL:Init()
    self:SetAltColour(false)
    self:SetPadding(0)
    self:SetTextAlignment(2)
    self:SetAltTextAlignment(1)
    self:SetTextColour(Colour(0,0,0))
    self:SetAltTextColour(Colour(127,127,127))
    self:SetLabelType(1)
end

function CONTROL:SetLabelType(num)
    self.___LabelType = math.Clamp(num, 1, 3)
end

function CONTROL:SetTextAlignment(num)
    self.___TextAlignment = math.Clamp(num, 1, 3)
end

function CONTROL:SetAltTextAlignment(num)
    self.___AltTextAlignment = math.Clamp(num, 1, 3)
end

function CONTROL:Setup(text, alt_text_1, alt_text_2)
    self.main_text = vgui.Create("DLabel", self)
    self.main_text:SetText(text)
    self.main_text:SetSize(self:GetWide() - self:GetPadding() * 2, self.main_text:GetTall())
    self.main_text:SetPos(self:GetPadding(), self:GetTall() * 0.21)
    self.main_text:SetContentAlignment(3 + self:GetTextAlignment())
    self.main_text:SetColor(self:GetTextColour())
    if self:GetLabelType() == 2 then
        self.alt_text = vgui.Create("DLabel", self)
        self.alt_text:SetText(alt_text_1)
        self.alt_text:SetSize(self:GetWide() - self:GetPadding() * 2, self.alt_text:GetTall())
        self.alt_text:SetPos(self:GetPadding(), self:GetTall() * 0.65)
        self.alt_text:SetContentAlignment(3 + self:GetTextAlignment())
        self.alt_text:SetColor(self:AltTextColour())
    else
        self.alt_text_1 = vgui.Create("DLabel", self)
        self.alt_text_1:SetText(alt_text_1)
        self.alt_text_1:SetSize(self:GetWide() - self:GetPadding() * 2, self.alt_text_1:GetTall())
        self.alt_text_1:SetPos(self:GetPadding(), self:GetTall() * 0.65)
        self.alt_text_1:SetContentAlignment(4)
        self.alt_text_1:SetColor(self:AltTextColour())
        self.alt_text_2 = vgui.Create("DLabel", self)
        self.alt_text_2:SetText(alt_text_2)
        self.alt_text_2:SetSize(self:GetWide() - self:GetPadding() * 2, self.alt_text_2:GetTall())
        self.alt_text_2:SetPos(self:GetPadding(), self:GetTall() * 0.65)
        self.alt_text_2:SetContentAlignment(6)
        self.alt_text_2:SetColor(self:AltTextColour())
    end
end

function CONTROL:OnChange(bool)
end

function CONTROL:DoClick()
    self:SetChecked(!self:GetChecked())
    self:OnChange(self:GetChecked())
end

function CONTROL:Paint(w, h)
    if self:GetAltColour() then
        surface.SetDrawColor(self:GetAltSelectionColour():Unpack())
    elseif self:GetChecked() then
        surface.SetDrawColor(self:GetSelectedColour():Unpack())
    else
        surface.SetDrawColor(self:GetBackgroundColour():Unpack())
    end
    for i=0,h do
        surface.DrawLine(0, i, w, i)
    end
    surface.SetDrawColor(self:GetTextColour():Unpack())
    surface.DrawLine(0, h, w, h)
end

CONTROL:Define()
CONTROL = panel.ControlBuilder "DScrollPanel" ("JScrollPanel", "Used JAAS Menu, hidden scroll bar") -- Modified Code from https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/vgui/dscrollpanel.lua

function CONTROL:Init()
	self.pnlCanvas = vgui.Create( "Panel", self )
	self.pnlCanvas.OnMousePressed = function( self, code ) self:GetParent():OnMousePressed( code ) end
	self.pnlCanvas:SetMouseInputEnabled( true )
	self.pnlCanvas.PerformLayout = function( pnl )
		self:PerformLayoutInternal()
		self:InvalidateParent()
	end
	-- Create the scroll bar
	self.VBar = vgui.Create( "DVScrollBar", self )
    self.VBar:SetSize(0, self:GetTall())
	self.VBar:SetHideButtons(true)

	self:SetPadding( 0 )
	self:SetMouseInputEnabled( true )

	-- This turns off the engine drawing
	self:SetPaintBackgroundEnabled( false )
	self:SetPaintBorderEnabled( false )
	self:SetPaintBackground( false )
end

CONTROL:Define()

log:print "Module Loaded"