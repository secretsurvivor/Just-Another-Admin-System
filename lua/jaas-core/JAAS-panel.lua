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
local before_initial_pull = true
local HookRankRun = JAAS.Hook.Run"Rank"

hook.Add("InitPostEntity", "JAAS_InitialRankPull", function ()
    net.Start "JAAS_RankPullChannel"
    net.SendToServer()
end)

net.Receive("JAAS_RankPullChannel", function (len)
    rankList = net.ReadTable()
    HookRankRun "InitialPull" (rankList)
    before_initial_pull = false
end)

net.Receive("JAAS_RankUpdate", function (len)
    local update_type = net.ReadUInt(3)
    local id = net.ReadFloat()
    if update_type == 0 then -- Add
        rankList[id] = net.ReadTable()
        HookRankRun "Added" (id, rankList[id])
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
            HookRankRun "NameUpdated" (id, rankList[id].name, name)
            rankList[id].name = name
        end
    elseif update_type == 3 then -- Power Changed
        if rankList[id] then
            local power = net.ReadUInt(8)
            HookRankRun "PowerUpdated" (id, rankList[id].power, power)
            rankList[id].power = power
        end
    elseif update_type == 4 then -- Invis Changed
        if rankList[id] then
            local invis = net.ReadBool()
            HookRankRun "InvisUpdated" (id, rankList[id].invisible, invis)
            rankList[id].invisible = invis
        end
    elseif update_type == 5 then
        if rankList[id] then
            local value = net.ReadFloat()
            HookRankRun "AccessUpdated" (id, rankList[id].access_group, value)
            rankList[id].access_group = value
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
        self.currentPanel:Hide()
    end
    self.currentPanel = panel
    self.currentTab = name
    self.currentPanel:Show()
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
        :Text("  "..name, "Default", Color(59, 56, 56, 255), TEXT_ALIGN_LEFT, 5)
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
        registeredPlayerLists[k]:AddItem(name)
    end
end)
hook.Add("PlayerDisconnected", "JPlayerListUpdater", function (ply)
    for k,v in ipairs(registeredPlayerLists) do
        registeredPlayerLists[k]:RemoveItem(ply:Nick())
    end
end)

function CONTROL:Init()
    self:SetName("Players")
    for k,v in ipairs(player.GetAll()) do
        self:AddItem(v:Nick())
    end
    registeredPlayerLists[1 + #registeredPlayerLists] = self
end

function CONTROL:OnRemove()
    table.RemoveByValue(registeredPlayerLists, self)
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

local registeredRankLists = {}
JAAS.Hook "Rank" "Added" ["JAAS_RankListUpdate"] = function (id, name)
    for k,v in ipairs(registeredRankLists) do
        registeredRankLists[k]:AddItem(name)
    end
end
JAAS.Hook "Rank" "Removed" ["JAAS_RankListUpdate"] = function (id, name)
    for k,v in ipairs(registeredRankLists) do
        registeredRankLists[k]:RemoveItem(name)
    end
end
local initial_registeredRankLists = {}
JAAS.Hook "Rank" "InitialPull" ["JAAS_RankListIntitalBuild"] = function (rankList)
    for k,v in ipairs(initial_registeredRankLists) do
        for id,info in pairs(rankList) do
            initial_registeredRankLists[k]:AddItem(info.name)
        end
    end
end

function CONTROL:Init()
    self:SetName("Ranks")
    if before_initial_pull then
        initial_registeredRankLists[1 + #initial_registeredRankLists] = self
    else
        for id,info in panel.GetRankIterator() do
            self:AddItem(info.name)
        end
    end
    registeredRankLists[1 + #registeredRankLists] = self
end

function CONTROL:OnRemove()
    table.RemoveByValue(registeredPlayerLists, self)
end

CONTROL:Define()
CONTROL = panel.ControlBuilder "DPanel" ("JSlider", "Slider designed for the JNumSlider") ----- Code Modified from https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/vgui/dslider.lua -----
CONTROL:AccessorFunc "Dragging"
CONTROL:AccessorFunc "SlideX"
CONTROL:AccessorFunc "Value"

function CONTROL:Init()
    self:SetMouseInputEnabled(true)
    self.knob = vgui.Create("DButton", self)
    self.knob:SetText("")
    self.knob:SetSize(15, 15)
    self.knob:NoClipping(true)
    self.knob:TDLib()
        :ClearPaint()
        :Circle(Color(255, 255, 255))
        :CircleFadeHover()
    self.knob.OnCursorMoved = function(panel, cursorX, cursorY)
        local x,y = panel:LocalToScreen(cursorX, cursorY)
        x,y = self:ScreenToLocal(x, y)
        self:OnCursorMoved(x, y)
    end
    self.knob.OnMousePressed = function ()
        self:OnMousePressed()
    end
    self.knob.OnMouseReleased = function ()
        self:OnMouseReleased()
    end
    self:SetValue(0)
end

function CONTROL:TranslateValue(x)
    return x
end

function CONTROL:SetSlideX(x, w)
    self.___SlideX = x
    self:SetValue(math.Round(self:GetValue() + (x * 5 - 2.5)))
    self:OnChange(self:GetValue())
end

function CONTROL:OnCursorMoved(x, y)
    if self:GetDragging() then
        local w,h = self:GetSize()
        if x <= w then
            x = math.Clamp(x, 0, w)

            x = self:TranslateValue(x)

            self:SetSlideX(x / w)
            self:InvalidateLayout()
        end
    end
end

function CONTROL:OnMousePressed(keyCode)
    if self:IsEnabled() then
        self.knob.Hovered = true
        self:SetDragging(true)
        self:MouseCapture(true)
        local x,y = self:CursorPos()
        self:OnCursorMoved(x, y)
    end
end

function CONTROL:OnChange()
end

function CONTROL:OnChangeRelease(value)
end

function CONTROL:OnMouseReleased(keyCode)
    self.knob.Hovered = vgui.GetHoveredPanel() == self.knob
    self:SetDragging(false)
    self:MouseCapture(false)
    self:OnChange(self:GetValue())
    self:InvalidateLayout()
end

function CONTROL:PerformLayout(w, h)
    local iw, ih = self.knob:GetSize()
    if self:GetDragging() then
        self.knob:SetPos((w * self:GetSlideX()) - iw * 0.2, h * 0.5 - ih * 0.5)
    else
        self.knob:SetPos(w * 0.5 - iw * 0.2, h * 0.5 - ih * 0.5)
    end
end

CONTROL:Define("JNumSlider", "A JAAS Number Slider designed for unknown Min and Max values")

function CONTROL:Init()
    self.Label = vgui.Create("DLabel", self)
    self.Label:DockMargin(0, 0, 5, 0) -- Left: 0, Top: 0, Right: 5, Bottom: 0
    self.Label:Dock(LEFT)
    self.Label:TDLib()
        :ClearPaint()
    self.Label:SetTextColor(Color(0, 0, 0))

    self.Slider = vgui.Create("JSlider", self)
    self.Slider:Dock(FILL)

    self.Entry = vgui.Create("DLabel", self)
    self.Entry:Dock(RIGHT)
    --self.Entry:SetSize(25, 25)
    self.Entry:TDLib()
        :ClearPaint()
    self.Entry:SetText(0)
    self.Entry:InvalidateLayout(true)
    self.Entry:SizeToContents()

    self.Slider.OnChange = function (panel, value)
        self.Entry:SetText(value)
        self.Entry:InvalidateLayout(true)
        self.Entry:SizeToContents()
        return value
    end

    self.Slider.OnChangeRelease = function (panel, value)
        self:OnChange(value)
    end
end

function CONTROL:SetLabel(text)
    self.Label:SetText(text)
    self.Label:InvalidateLayout(true)
    self.Label:SizeToContents()
end

function CONTROL:OnChange()
end

function CONTROL:GetValue()
    return self.Slider:GetValue()
end

CONTROL:Define("VerticalSlider", "A Number Slider for vertical panels")
CONTROL:AccessorFunc "Dragging"
CONTROL:AccessorFunc "SlideY"
CONTROL:AccessorFunc "Value"

function CONTROL:Init()
    self:SetMouseInputEnabled(true)
    self.knob = vgui.Create("DButton", self)
    self.knob:SetText("")
    self.knob:SetSize(12, 14)
    self.knob:NoClipping(true)
    self.knob.Paint = function (panel, w, h)
        surface.SetDrawColor(255, 255, 255)
        draw.NoTexture()
        surface.DrawPoly({{x = 0, y = 0}, {x = w, y = h / 2}, {x = 0, y = h}})
    end
    self.knob.OnCursorMoved = function(panel, cursorX, cursorY)
        local x,y = panel:LocalToScreen(cursorX, cursorY)
        x,y = self:ScreenToLocal(x, y)
        self:OnCursorMoved(x, y)
    end
    self.knob.OnMousePressed = function (panel)
        self:OnMousePressed()
    end
    self.knob.OnMouseReleased = function (panel)
        self:OnMouseReleased()
    end
    self:TDLib()
        :ClearPaint()
end

function CONTROL:TranslateValue(y)
    return y
end

function CONTROL:SetSlideY(y)
    self.___SlideY = y
    self:SetValue(y)
end

function CONTROL:OnCursorMoved(x, y)
    if self:GetDragging() then
        local w,h = self:GetSize()
        y = math.Clamp(y, 0, h)

        y = self:TranslateValue(y)

        self:SetSlideY(y)
        self:InvalidateLayout(true)
    end
end

function CONTROL:OnMousePressed(keyCode)
    if self:IsEnabled() then
        self:SetDragging(true)
        self:MouseCapture(true)
        local x,y = self:CursorPos()
        self:OnCursorMoved(x, y)
    end
end

function CONTROL:OnChange(value)
end

function CONTROL:TranslateFinishValue(value)
    return value
end

function CONTROL:OnMouseReleased(keyCode)
    self:SetDragging(false)
    self:MouseCapture(false)
    self:SetValue(self:TranslateFinishValue(self:GetValue()))
    self:OnChange(self:GetValue())
end

function CONTROL:PerformLayout(w, h)
    if self:GetDragging() then
        self.knob:SetPos(0, self:GetSlideY())
    else
        self.knob:SetPos(0, self:GetValue())
    end
end

CONTROL:Define()
CONTROL = panel.ControlBuilder "DScrollPanel" ("JSliderPanel", "A Panel with a vertical slider")

function CONTROL:Init()
    self.pnlCanvas:Dock(FILL)
    self.slider = vgui.Create("VerticalSlider", self.pnlCanvas)
    self.slider:Dock(LEFT)
    self.slider:SetWide(14)

    self.panel = vgui.Create("JTabPanel", self.pnlCanvas)
    self.panel:Dock(FILL)
    self.panel:TDLib()
        :ClearPaint()
        :Background(Color(255, 255, 255))

    self.pnlCanvas:TDLib()
        :ClearPaint()

    self:TDLib()
        :ClearPaint()
        :HideVBar()
end

function CONTROL:Add(panel)
    panel:SetParent(self.panel)
end

CONTROL:Define()

log:print "Module Loaded"