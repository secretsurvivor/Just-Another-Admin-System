local MODULE, log, dev = JAAS:RegisterModule "Panel"
local panel = {PermissionCheck = true, ControlBuilder = true}
local permissionCheck = {}
local permissionCheckFunc = {}

function panel.PermissionCheck(func, ...)
    local perm_list = {...}
    for k,v in ipairs(perm_list) do
        net.Start "JAAS_PermissionClientCheck"
        net.WriteString(v)
        net.SendToServer()
    end
    permissionCheckFunc[1 + #permissionCheckFunc] = {perm_list, func}
end

net.Receive("JAAS_PermissionClientCheck" , function (name, check)
    name = net.ReadString()
    permissionCheck[name] = net.ReadBool() and true
    for k,v in ipairs(permissionCheckFunc) do
        local arg_list = {}
        for i, name in ipairs(v[1]) do
            if permissionCheck[name] then
                arg_list[i] = permissionCheck[name]
            end
        end
        if #arg_list == #v[1] then
            v[2](unpack(arg_list))
            table.remove(permissionCheckFunc, k)
        end
    end
end)

local rankList = {} -- rankList[id] = {name=, power=, invisible=, rowid=, access_group=, position=}
local HookRankRun = JAAS.Hook.Run"Rank"

hook.Add("InitPostEntity", "JAAS_InitialRankPull", function ()
    net.Start "JAAS_RankPullChannel"
    net.SendToServer()
end)

net.Receive("JAAS_RankPullChannel", function (len)
    rankList = net.ReadTable()
end)

net.Receive("JAAS_RankUpdate", function (len)
    local update_type = net.ReadUInt(3)
    local id = net.ReadFloat()
    if update_type == 0 then -- Add
        rankList[id] = net.ReadTable()
        HookRankRun "Added" (id, rankList[id].name, rankList[id].power, rankList[id].invisible, rankList[id].position)
    elseif update_type == 1 then -- Remove
        if rankList[id] then
            HookRankRun "Removed" (id, rankList[id].name, rankList[id].power, rankList[id].invisible, rankList[id].position)
            local rank_position = tonumber(rankList[id].position)
            local rank_code = bit.lshift(1, rank_position - 1)
            local error, message = HookRankRun "RemovedPosition" (function (bit_code)
            if bit_code > 0 then
                local bit_length = math.ceil(math.log(bit_code, 2))
                if bit.band(bit_code, rank_code) > 0 then
                    bit_code = bit.bxor(bit_code, rank_code)
                end
                if bit_length < rank_position then
                    return bit_code
                else
                    local shifted_bits = bit.rshift(bit_code, rank_position)
                    shifted_bits = bit.lshift(shifted_bits, rank_position - 1)
                    bit_code = bit.ror(bit_code, rank_position)
                    bit_code = bit.rshift(bit_code, bit_length - rank_position)
                    bit_code = bit.rol(bit_code, bit_length)
                    return shifted_bits + bit_code
                end
            end
            return bit_code or 0
        end)
            if !error then
                print(message)
            end
            rankList[id] = nil
        end
    elseif update_type == 2 then -- Name Changed
        if rankList[id] then
            local name = net.ReadString()
            HookRankRun "NameUpdated" (id, rankList[id][1], name)
            rankList[id][1] = name
        end
    elseif update_type == 3 then -- Power Changed
        if rankList[id] then
            local power = net.ReadUInt(8)
            HookRankRun "PowerUpdated" (id, rankList[id][2], power)
            rankList[id][2] = power
        end
    elseif update_type == 4 then -- Invis Changed
        if rankList[id] then
            local invis = net.ReadBool()
            HookRankRun "InvisUpdated" (id, rankList[id][3], invis)
            rankList[id][3] = invis
        end
    end
end)

function panel.GetRankIterator()
    local func, iTable, i = pairs(rankList)
    local value,index = nil, i
    return function ()
        index,value = func(iTable, index)
        if value then
            return index,value
        end
    end
end

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

local CONTROL = panel.ControlBuilder "DButton" ("JColorPicker", "Interactive Button that opens DColorMixer")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "Color"

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
        self:OnChange(self:GetColor())
        picker_panel:Remove()
    end
    save_button:SetText("Save")
end

function CONTROL:Paint(w, h)
    draw.Rect(0, 0, w, h, (self:GetColor() or Color(0,0,0)):Unpack())
end

CONTROL:Define("JBoolButton", "Button that acts as a Checkbox")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "BackgroundColor"
CONTROL:AccessorFunc "SelectedColor"
CONTROL:AccessorFunc "AltSelectionColor"
CONTROL:AccessorFunc "AltColor"
CONTROL:AccessorFunc ("Checked", FORCE_BOOL)
CONTROL:AccessorFunc "LabelType"
CONTROL:AccessorFunc "TextColor"
CONTROL:AccessorFunc "AltTextColor"
CONTROL:AccessorFunc "TextAlignment"
CONTROL:AccessorFunc "AltTextAlignment"
CONTROL:AccessorFunc "Padding"

function CONTROL:Init()
    self:SetAltColour(false)
    self:SetPadding(0)
    self:SetTextAlignment(2)
    self:SetAltTextAlignment(1)
    self:SetTextColour(Color(0,0,0))
    self:SetAltTextColour(Color(127,127,127))
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
    self.main_text:SetColor(self:GetTextColor())
    if self:GetLabelType() == 2 then
        self.alt_text = vgui.Create("DLabel", self)
        self.alt_text:SetText(alt_text_1)
        self.alt_text:SetSize(self:GetWide() - self:GetPadding() * 2, self.alt_text:GetTall())
        self.alt_text:SetPos(self:GetPadding(), self:GetTall() * 0.65)
        self.alt_text:SetContentAlignment(3 + self:GetTextAlignment())
        self.alt_text:SetColor(self:AltTextColor())
    else
        self.alt_text_1 = vgui.Create("DLabel", self)
        self.alt_text_1:SetText(alt_text_1)
        self.alt_text_1:SetSize(self:GetWide() - self:GetPadding() * 2, self.alt_text_1:GetTall())
        self.alt_text_1:SetPos(self:GetPadding(), self:GetTall() * 0.65)
        self.alt_text_1:SetContentAlignment(4)
        self.alt_text_1:SetColor(self:AltTextColor())
        self.alt_text_2 = vgui.Create("DLabel", self)
        self.alt_text_2:SetText(alt_text_2)
        self.alt_text_2:SetSize(self:GetWide() - self:GetPadding() * 2, self.alt_text_2:GetTall())
        self.alt_text_2:SetPos(self:GetPadding(), self:GetTall() * 0.65)
        self.alt_text_2:SetContentAlignment(6)
        self.alt_text_2:SetColor(self:AltTextColor())
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
        draw.Rect(0, 0, w, h, self:GetAltSelectionColor():Unpack())
    elseif self:GetChecked() then
        draw.Rect(0, 0, w, h, self:GetSelectedColor():Unpack())
    else
        draw.Rect(0, 0, w, h, self:GetBackgroundColor():Unpack())
    end
    surface.SetDrawColor(self:GetTextColor():Unpack())
    surface.DrawLine(0, h, w, h)
end

CONTROL:Define()

CONTROL = panel.ControlBuilder "DPanel" ("JTabPanel", "Used in JAAS Menu, external tab panel")

function CONTROL:Init()
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetPaintBackground(false)

    self.tabs = {}
end

function CONTROL:AddTab(name, panel)
    panel:SetParent(self)
    panel:Dock(FILL)
    if self.currentPanel then
        panel:Hide()
    else
        self.currentPanel = panel
        self.currentPanel:Show()
    end
    self.tabs[name] = panel
end

function CONTROL:OnChange(changeTo)
end

function CONTROL:OpenTab(name)
    if self.tabs[name] != nil then
        self.currentPanel:Hide()
        self.currentPanel = self.tabs[name]
        self.currentPanel:Show()
        self.currentTab = name
        self:OnChange(name)
    end
end

function CONTROL:GetCurrentTab()
    return self.currentTab
end

CONTROL:Define("DNumberWangLabel", "Label version of Number Wang")

function CONTROL:Init()
	self:SetTall( 16 )

	self.Button = vgui.Create( "DNumberWang", self )
	self.Button.OnChange = function( _, val ) self:OnChange( val ) end

	self.Label = vgui.Create( "DLabel", self )
	self.Label:SetMouseInputEnabled( true )
	self.Label.DoClick = function() self:Toggle() end
end

CONTROL:Define("JList", "Selection list")
CONTROL:Derma_Hook "Paint"
CONTROL:AccessorFunc "MultiSelect"
CONTROL:AccessorFunc "Selected"

function CONTROL:Init()
    self.Items = {}
    self:TDLib()
        :ClearPaint()
        :Background(Color(242, 242, 242, 255))
        :Outline(Color(59, 56, 56, 255), 1)

    self.Title = vgui.Create("DLabel", self)
    self.Title:Dock(TOP)
    self.Title:TDLib()
        :ClearPaint()
        :Outline(Color(59, 56, 56, 255), 1)
    self.Title:SetTall(20)
    self:SizeToChildren(false, true)
end

function CONTROL:SetMultiSelect(bool)
    if bool then
        self:SetSelected({})
    end
    self.___MultiSelect = bool
end

function CONTROL:OnSelected(val) end

function CONTROL:SetSelected(val)
    self.___Selected = val
    self:OnSelected(val)
end

function CONTROL:SetName(name)
    self.Title:TDLib()
        :Text(name, "Default", Color(59, 56, 56, 255), TEXT_ALIGN_LEFT, 5)
end

function CONTROL:AddItem(val)
    if isstring(val) then
        self.Items[val] = vgui.Create("DButton", self)
        self.Items[val]:TDLib()
            :ClearPaint()
            :Text(val, "Default", Color(59, 56, 56, 255))
        self.Items[val]:Dock(TOP)
        self.Items[val]:SetTall(20)
        self.Items[val]:SetContentAlignment(5)

        self.Items[val].IsSelected = function ()
            if self:GetMultiSelect() then
                return table.HasValue(self.___Selected, val)
            end
            return self.___Selected == val
        end

        self.Items[val].DoClick = function (pnl)
            if self:GetMultiSelect() then
                if table.HasValue(self.___Selected, val) then
                    table.RemoveByValue(self.___Selected, val)
                    self:OnSelected(self.___Selected)
                    pnl:TDLib()
                        :ClearPaint()
                else
                    self.___Selected[1 + #self.___Selected] = val
                    self:OnSelected(self.___Selected)
                    pnl:TDLib()
                        :Background(Color(173, 185, 202))
                end
            else
                if self.___Selected == val then
                    self.___Selected = nil
                    self:OnSelected(nil)
                    pnl:TDLib()
                        :ClearPaint()
                else
                    self.___Selected = val
                    self:OnSelected(val)
                    pnl:TDLib()
                        :Background(Color(173, 185, 202))
                end
            end
        end
        self:InvalidateLayout(true)
        self:SizeToChildren(false, true)
    end
end

function CONTROL:RemoveItem(val)
    if isstring(val) and self.Items[val] then
        self.Items[val]:Remove()
        self.Items[val] = nil
        self:InvalidateLayout(true)
        self:SizeToChildren(false, true)
    end
end

CONTROL:Define()
CONTROL = panel.ControlBuilder "JList" ("JPlayerList", "List of Players updated")

local registeredPlayerLists = {}
hook.Add("PlayerConnect", "JPlayerListUpdater", function (name, ip)
    for k,v in ipairs(registeredPlayerLists) do
        v[1](name, ip)
    end
end)
hook.Add("PlayerDisconnected", "JPlayerListUpdater", function (ply)
    for k,v in ipairs(registeredPlayerLists) do
        v[2](ply:Nick())
    end
end)

function CONTROL:Init()
    self:SetName("Players")
    for k,v in ipairs(player.GetAll()) do
        self:AddItem(v:Nick())
    end
    hook.Add("PlayerConnect", "JPlayerListUpdater", function (name, ip)
        self:AddItem(name)
    end)
    hook.Add("PlayerDisconnected", "JPlayerListUpdater", function (ply)
        self:RemoveItem(name)
    end)
end

function CONTROL:GetSelected(returnPly)
    if self:GetMultiSelect() then
        if 1 > #self.___Selected then return end
        for k,v in ipairs(self.___Selected) do

        end
    elseif self.___Selected == nil then return
    end
    for k,ply in ipairs(player.GetAll()) do
        if ply:Nick() == self.___Selected then
            returnPly = ply
            break
        end
    end
    return returnPly
end

CONTROL:Define("JOptionList", "List of Options")

function CONTROL:Init()
    self:SetName("Options")
end

function CONTROL:Setup(optionList)
    for k,v in pairs(optionList) do
        self:AddItem(k)
    end
end

CONTROL:Define("JRankList", "List of Options")

function CONTROL:Init()
    self:SetName("Ranks")
    for k,v in pairs(rankList) do

    end
end

CONTROL:Define()

log:print "Module Loaded"