local MODULE, log, dev = JAAS:RegisterModule "Panel"

local drawColor = surface.SetDrawColor
function surface.SetDrawColor(r, g, b, a)
    if IsColor(r) then
        drawColor(r.r, r.g, r.b, r.a)
    else
        drawColor(r, g, b, a)
    end
end

local textColor = surface.SetTextColor
function surface.SetTextColor(r, g, b, a)
    if IsColor(r) then
        textColor(r.r, r.g, r.b, r.a)
    else
        textColor(r, g, b, a)
    end
end

local panel = {PermissionCheck = true, ControlBuilder = true}
local permissionCheck = {}

local function panel.PermissionCheck(permName, success, failure)
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

local function panel.ControlBuilder(base)
    return function (name, description)
        return setmetatable({internal = {PermissionAdd = function (self, permName, panel)
                panel.PermissionCheck(permName, function ()
                    self:Add(panel)
                end)
            end}}, {
            __newindex = function (self, k, v)
                self.internal[k] = v
            end,
            Derma_Hook = function (self, func)
                Derma_Hook(self.internal, func, func, name)
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
            end,
            Builder = function (self, b)
                derma.DefineControl(name, description, self.internal, base)
                self = ControlBuilder(b)
            end
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

local CONTROL = ControlBuilder "DButton" ("", "")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "Title"
CONTROL:AccessorFunc "Panel"
CONTROL:AccessorFunc "Icon"

function CONTROL:SetSize(w, h)
    self:SetWidth(w)
    self:SetHeight(w)
end

function CONTROL:Setup(title, icon, panel)
    self:SetPanel(panel)
    self:SetTitle(title)
    self:SetIcon(icon)
end

function CONTROL:Paint(w, h)
    h = self:GetIcon()
    if h then
        h(w * 0.6, w * 0.2)
    end
    surface.SetTextColor(242, 242, 242)
    h = w - (surface.GetTextSize(self:GetTitle()) * 0.5)
    surface.SetTextPos(number x, number y)
end

CONTROL:Builder "DPanel" ("JMenu", "Menu for JAAS")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "TabList"

function CONTROL:Init()
    self:SetPos(0, 0)
    self:SetSize(ScrW(), ScrH())
end

local panelWidth, panelHeight = ScrW() * 0.07, ScrH() * 0.85
function CONTROL:Paint(w, h)
    surface.DrawRect(0, 0, panelWidth, panelHeight)

end

function CONTROL:AddTab()
end

CONTROL:Builder "" ("", "")

log:printLog "Module Loaded"