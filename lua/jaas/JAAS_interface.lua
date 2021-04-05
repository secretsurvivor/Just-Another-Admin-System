local GUI,PANEL = JAAS.GUI(),JAAS.Panel()
local ui_toggle,open = true,false

local toggle_convar = CreateConVar("jaas_toggle", "1", FCVAR_LUA_CLIENT, "Decides if the JAAS Menu is toggled open or held", 0, 1)
cvars.AddChangeCallback("jaas_toggle", function (name, old, new)
    ui_toggle = tobool(new) or true
end)

local JUI, main = GUI.RegisterInterface(vgui.Create "DScrollPanel") --------- JAAS Menu Panel -----------
main:TDLib()
    :ClearPaint()
    :Background(Color(59, 56, 56, 255))
    :HideVBar()
    :SetPos(ScrW() * 0.935, ScrH() * 0.21)
main:SetSize(ScrW() * 0.07, ScrH() * 0.58)
main:SetZPos(1)
main:DockPadding(8, 8, 8, 8) -- Left: 8, Top: 8, Right: 8, Bottom: 8

function main:OpenPanel(panel) ------- Open Tab Function -------
    if self.currentPanel == panel then
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
        panel:MoveTo((ScrW() * 0.92) - panel:GetWide() + 1, ScrH() * 0.21, 0.1, 0, -1, function (animData, pnl)
            panel:SetPos((ScrW() * 0.92) - panel:GetWide() + 1, ScrH() * 0.21)
        end)
    end
end

function main:ShowAll() ----- Show JAAS Menu -----
    self:Show()

    if self.currentPanel then
        self.currentPanel:Show()
    end
end

function main:HideAll() ----- Hide JAAS Menu -----
    self:Hide()

    if self.currentPanel then
        self.currentPanel:Hide()
    end
end

JUI.BuildTabs(function (name, panel, color)
    local tab_button = main:Add("DButton")
    tab_button:Dock(TOP)
    tab_button:DockMargin(0, 0, 0, 8) -- Left: 0, Top: 0, Right: 0, Bottom: 8
    tab_button:TDLib()
        :ClearPaint()
        :SideBlock(color, 4, LEFT)
        :Text(name, "Trebuchet24", Color(242, 242, 242, 255), TEXT_ALIGN_CENTER, 4)
        :DivTall(0.7)
        :DivWide(1)

    tab_button.DoClick = function (self)
        main:OpenPanel(panel)
    end
end)

local command_base_panel = vgui.Create("EditablePanel") ---------- Command Tab ------------
command_base_panel:TDLib()
    :ClearPaint()
    :Background(Color(59, 56, 56, 255))
    :Outline(Color(238, 66, 66), 2)
command_base_panel:SetTall(ScrH() * 0.58)
command_base_panel:SetWide(ScrW() * 0.107)
local command_panel = vgui.Create("DScrollPanel", command_base_panel)
command_panel:TDLib()
    :ClearPaint()
    :HideVBar()
    :DockPadding(20, 30, 20, 20) -- Left: 20, Top: 30, Right: 20, Bottom: 20
command_panel:Dock(FILL)

local COMMAND = JAAS.Command()

for category,command_list in COMMAND.ICommand() do ----------- Build Command List -------------
    local category_element = command_panel:Add("DPanel") ----- Category Header -------
    category_element:Dock(TOP)
    category_element:DockPadding(2.5, 0, 0, 0) -- Left: 2.5, Top: 0, Right: 0, Bottom: 0
    category_element:DockMargin(2.5, 10, 0, 0) -- Left: 2.5, Top: 10, Right: 0, Bottom: 0
    category_element:TDLib()
        :ClearPaint()
        :Text(category, "DermaLarge", Color(242, 242, 242), TEXT_ALIGN_LEFT, 9)

    local category_container = command_panel:Add("DPanel") ----- Category Command Panel -----

    category_container:Dock(TOP)
    category_container:DockPadding(5, 0, 0, 0) -- Left: 5, Top: 0, Right: 0, Bottom: 0
    category_container:TDLib()
        :ClearPaint()

    for name,info in pairs(command_list) do ----- Build Command Element List -----
        local command_element = category_container:Add("DCollapsibleCategory") -- Command Element

        command_element.Think = function (self)
            self.animSlide:Run()
            if self.animSlide:Active() then
                category_container:InvalidateLayout(true)
                category_container:SizeToChildren(false, true)
            end
        end

        local command_element_container = vgui.Create("DPanel") -- Command Element Inner Panel
        command_element_container:TDLib()
            :ClearPaint()
        command_element:TDLib()
            :ClearPaint()
        command_element:SetLabel(string.gsub(name, "_", " "))
        command_element:SetExpanded(false)

        local argument_element
        local execute_arguments = {}
        local argument_controllers = {}

        for k,v in ipairs(info[2]) do ----- Build Command Data Types -----
            if v[2] == 0x1 then ------------ Bool ------------
                argument_element = vgui.Create("DCheckBoxLabel", command_element_container)
                argument_element:SetContentAlignment(4)
                argument_element:TDLib()
                    :ClearPaint()
                    :SquareCheckbox(Color(173, 185, 202), Color(242, 242, 242))
                    :Text(v[1], "Default", Color(242, 242, 242), TEXT_ALIGN_RIGHT)
                argument_element:SetChecked(v[4] or false)

                argument_element.OnChange = function (self, val)
                    execute_arguments[k] = val
                end

                argument_element:SetTall(30)
            elseif v[2] == 0x2 then ------------ Int ------------
                argument_element = vgui.Create("DNumSlider", command_element_container)
                argument_element:TDLib()
                    :ClearPaint()
                    :Text(v[1], "Default", Color(242, 242, 242), TEXT_ALIGN_RIGHT)
                argument_element:SetMin(0)
                argument_element:SetMax(5000)
                argument_element:SetDecimals(0)
                argument_element:SetValue(math.Round(v[4] or 0))

                argument_element.OnValueChanged = function (self, val)
                    execute_arguments[k] = val
                end

                argument_element:SetTall(30)

            elseif v[2] == 0x3 then ------------ Float ------------
                argument_element = vgui.Create("DNumSlider", command_element_container)
                argument_element:TDLib()
                    :ClearPaint()
                    :Text(v[1], "Default", Color(242, 242, 242), TEXT_ALIGN_RIGHT)
                argument_element:SetMax(0)
                argument_element:SetDecimals(3)
                argument_element:SetValue(math.Round(v[4] or 0))

                argument_element.OnValueChanged = function (self, val)
                    execute_arguments[k] = val
                end

                argument_element:SetTall(30)

            elseif v[2] == 0x4 then ------------ String ------------
                argument_element = vgui.Create("DTextEntry", command_element_container)
                argument_element:TDLib()
                    :ClearPaint()
                    :ReadyTextbox()
                    :BarHover(Color(173, 185, 202))
                argument_element:SetUpdateOnType(true)

                argument_element.OnValueChange = function (self, str)
                    execute_arguments[k] = str
                end

                argument_element:SetPlaceholderText(v[1])
                argument_element:SetTall(30)

            elseif v[2] == 0x5 then ------------ Player ------------
                argument_element = vgui.Create("JPlayerList", command_element_container)
                argument_element:SetMultiSelect(false)

                argument_element.OnSelected = function (self, val)
                    execute_arguments[k] = val
                    print(k, val)
                end

            elseif v[2] == 0x6 then ------------ Players ------------
                argument_element = vgui.Create("JPlayerList", command_element_container)
                argument_element:SetMultiSelect(true)

                argument_element.OnSelected = function (self, val)
                    execute_arguments[k] = val
                end

            elseif v[2] == 0x7 then ------------ Rank ------------
                argument_element = vgui.Create("JRankList", command_element_container)
                argument_element:SetMultiSelect(false)

            elseif v[2] == 0x8 then ------------ Ranks ------------
                argument_element = vgui.Create("JRankList", command_element_container)
                argument_element:SetMultiSelect(true)

            elseif v[2] == 0x9 then ------------ Option--------------
                argument_element = vgui.Create("JOptionList", command_element_container)
                argument_element:SetMultiSelect(false)

                argument_element.OnSelected = function (self, val)
                    execute_arguments[k] = val
                end

            elseif v[2] == 0xA then ------------ Options ------------
                argument_element = vgui.Create("JOptionList", command_element_container)
                argument_element:SetMultiSelect(true)

                argument_element.OnSelected = function (self, val)
                    execute_arguments[k] = val
                end

            end

            argument_element:Dock(TOP)
            argument_element:DockMargin(2, 2, 2, 2) -- Left: 2, Top: 2, Right: 2, Bottom: 2
        end

        argument_element = vgui.Create("DButton", command_element_container) ------------ Execute Button ------------
        argument_element:TDLib()
            :ClearPaint()
            :Background(Color(59, 56, 56))
            :Outline(Color(242, 242, 242), 2)
            :Text("Execute", "Default", Color(242, 242, 242), TEXT_ALIGN_CENTER)

        argument_element.DoClick = function()
            COMMAND.executeCommand(category, name, info[2], execute_arguments)
        end

        argument_element:Dock(TOP)
        argument_element:DockMargin(2, 2, 2, 2) -- Left: 2, Top: 2, Right: 2, Bottom: 2
        argument_element:SetTall(30)

        argument_element = vgui.Create("DLabel", command_element_container) ------------ Command Feedback ------------
        argument_element:TDLib()
            :ClearPaint()
            :Text("", "Default", Color(255, 0, 0), TEXT_ALIGN_LEFT)

        JAAS.Hook "Command" "CommandFeedback" ["CommandGUI"] = function(code, category, name, message)
            if code == 2 then
                argument_element:TDLib()
                    :Text("Invalid Access", "DebugFixed", Color(255, 0, 0), TEXT_ALIGN_LEFT)
            elseif code == 3 then
                argument_element:TDLib()
                    :Text("Invalid Arguments", "DebugFixed", Color(255, 0, 0), TEXT_ALIGN_LEFT)
            elseif code == 4 then
                argument_element:TDLib()
                    :Text(message, "DebugFixed", Color(255, 0, 0), TEXT_ALIGN_LEFT)
            else
                argument_element:TDLib()
                    :Text("Unknown Error", "DebugFixed", Color(255, 0, 0), TEXT_ALIGN_LEFT)
            end
            argument_element:InvalidateLayout(true)
            argument_element:SizeToContents()
        end

        argument_element:Dock(TOP)
        argument_element:DockMargin(2, 2, 2, 2) -- Left: 2, Top: 2, Right: 2, Bottom: 2
        argument_element:InvalidateLayout(true)
        argument_element:SizeToChildren(false, true)

        command_element_container:InvalidateLayout(true)
        command_element_container:SizeToChildren(false, true)

        command_element:SetContents(command_element_container)
        command_element:SetContentAlignment(5)
        command_element:Dock(TOP)
        command_element:DockMargin(0, 0, 0, 0) -- Left: 0, Top: 0, Right: 0, Bottom: 0
        command_element:InvalidateLayout(true)
        command_element:UpdateAltLines()
    end

    if category_container:GetTall() == 0 then ----- No Command in Category -----
        category_element:Hide()
        category_container:Hide()
    end

    category_container:InvalidateLayout(true)
    category_container:SizeToChildren(false, true)
end

GUI.RegisterTab("Commands", command_base_panel, Color(238, 66, 66))

PANEL.PermissionCheck(function (canModifyRank, canModifyCommand, canModifyPermission, canModifyPlayers) ------ Rank Tab -------
    if canModifyRank or canModifyCommand or canModifyPermission or canModifyPlayers then
        local rank_panel = vgui.Create("EditablePanel") ------- Rank Tab --------
        rank_panel:TDLib()
            :ClearPaint()
            :Background(Color(59, 56, 56, 255))
            :Outline(Color(174, 75, 229), 2)
            :DockPadding(20, 30, 20, 20) -- Left: 20, Top: 30, Right: 20, Bottom: 20
        rank_panel:SetTall(ScrH() * 0.58)
        rank_panel:SetWide(515)

        local tab_buttons = vgui.Create("DPanel", rank_panel) ----- Tab Button Panel -----
        tab_buttons:TDLib()
            :ClearPaint()
        tab_buttons:DockMargin(0, 0, 0, 5) -- Left: 0, Top: 0, Right: 0, Bottom: 5
        tab_buttons:Dock(TOP)

        local object_list = vgui.Create("JTabPanel", rank_panel) ----- Object List Panel -----
        object_list:TDLib()
            :ClearPaint()
            :Background(Color(255, 255, 255))
        object_list:SetWide(266)
        object_list:Dock(RIGHT)

        local rank_list_container = vgui.Create("DPanel", rank_panel) ----- Rank List Panel -----
        rank_list_container:TDLib()
            :ClearPaint()
        rank_list_container:SetWide(195)
        rank_list_container:Dock(LEFT)
        rank_list_container:DockMargin(0, 0, 6, 0) -- Left: 0, Top: 0, Right: 6, Bottom: 0

        local rank_list = vgui.Create("DScrollPanel", rank_list_container) ----- Rank List Inner Panel -----
        rank_list:TDLib()
            :ClearPaint()
            :Background(Color(255, 255, 255))
            :HideVBar()
        rank_list:Dock(FILL)

        local rank_command_panel = vgui.Create("DCollapsibleCategory", rank_list_container) ----- Rank List Command Buttons Panel -----
        rank_command_panel:SetExpanded(false)
        rank_command_panel:TDLib()
            :ClearPaint()
        rank_command_panel:DockMargin(0, 1, 0, 0) -- Left: 0, Top: 1, Right: 0, Bottom: 0
        rank_command_panel:Dock(BOTTOM)
        rank_command_panel:InvalidateParent(true)
        rank_command_panel.Header:SetTall(0)

        local add_rank_panel = vgui.Create("EditablePanel") ----- Rank Adding Panel -----
        add_rank_panel:TDLib()
            :ClearPaint()
            :Background(Color(255, 255, 255))
        add_rank_panel:DockMargin(0, 1, 0, 0) -- Left: 0, Top: 1, Right: 0, Bottom: 0
        add_rank_panel:DockPadding(6, 6, 6, 6)
        local name_control = vgui.Create("DTextEntry", add_rank_panel) ---- Name Input ----
        name_control:SetPlaceholderText "Name"
        name_control:TDLib()
            :ReadyTextbox()
            :FadeHover()
            :BarHover()
        name_control:Dock(TOP)
        name_control:SetTall(21)
        name_control:SetEditable(true)
        name_control:SetPlaceholderColor(Color(191, 191, 191, 255))
        local power_control = vgui.Create("DNumSlider", add_rank_panel) ---- Power Input ----
        power_control:TDLib()
        power_control:Dock(TOP)
        power_control:SetTall(38)
        local invisible_control = vgui.Create("DCheckBoxLabel", add_rank_panel) ---- Invisible Input ----
        invisible_control:TDLib()
            :ClearPaint()
            :Text("Invisible", "Default", Color(0, 0, 0))
            :SquareCheckbox(Color(173, 185, 202))
        invisible_control:Dock(TOP)
        invisible_control:SetTall(38)

        rank_command_panel:SetContents(add_rank_panel)

        local button_panel = vgui.Create("DPanel", rank_command_panel) ------ Button Panel -------
        rank_command_panel.Header = button_panel
        button_panel:TDLib()
            :ClearPaint()
        button_panel:Dock(TOP)
        button_panel:SetTall(19)

        local add_rank_button = vgui.Create("DButton", button_panel) ------- Add Rank Button --------
        local remove_rank_button = vgui.Create("DButton", button_panel) ------- Remove Rank Button --------

        local function default_button_props() ----- Default Command Button Properties ------
            add_rank_button:TDLib()
                :ClearPaint()
                :Background(Color(255, 255, 255))
                :Text("Add", "Default", Color(0, 0, 0))
                :FadeHover(Color(209, 209, 209))
            remove_rank_button:TDLib()
                :ClearPaint()
                :Background(Color(255, 255, 255))
                :Text("Remove", "Default", Color(0, 0, 0))
                :FadeHover(Color(209, 209, 209))
        end

        local remove_selection_toggle = false ----- Rank Selection Toggle ------
        local remove_selection_list = {} ------ Rank Selection List ------

        default_button_props()

        add_rank_button:DockMargin(0, 0, 1, 0) -- Left: 0, Top: 0, Right: 1, Bottom: 0
        add_rank_button:Dock(LEFT)
        add_rank_button:SetWide(95)
        remove_rank_button:Dock(FILL)

        function add_rank_button:DoClick() ------- Add Rank Button Click Function -------
            if remove_selection_toggle then
                default_button_props()
                remove_selection_toggle = !remove_selection_toggle
            else
                if rank_command_panel:GetExpanded() then
                    default_button_props()
                    net.Start "JAAS_ModifyRank_Channel"
                        net.WriteUInt(0, 3)
                        net.WriteString(name_control:GetValue())
                        net.WriteUInt(power_control:GetValue(), 8)
                        net.WriteBool(invisible_control:GetValue())
                    net.SendToServer()
                else
                    add_rank_button:TDLib()
                        :ClearPaint()
                        :Background(Color(255, 255, 255))
                        :Text("Add", "Default", Color(0, 0, 0))
                        :FadeHover(Color(125, 231, 128))
                    remove_rank_button:TDLib()
                        :ClearPaint()
                        :Background(Color(255, 255, 255))
                        :Text("Cancel", "Default", Color(0, 0, 0))
                        :FadeHover(Color(240, 116, 116))
                    add_rank_panel:MakePopup()
                    add_rank_panel:SetParent(rank_command_panel)
                end
                rank_command_panel:Toggle()
            end
        end

        function remove_rank_button:DoClick() ------ Remove Rank Button Click Function ------
            if rank_command_panel:GetExpanded() then
                default_button_props()
                rank_command_panel:Toggle()
            else
                if remove_selection_toggle then
                    default_button_props()
                    if #remove_selection_list > 1 then
                        net.Start "JAAS_ModifyRank_Channel"
                        net.WriteUInt(#remove_selection_list, 64)
                        for k,v in ipairs(remove_selection_list) do
                            net.WriteString(v)
                        end
                        net.SendToServer()
                    elseif #remove_selection_list == 1 then
                        net.Start "JAAS_ModifyRank_Channel"
                        net.WriteString(remove_selection_list[1])
                        net.SendToServer()
                    end
                    remove_selection_list = {}
                else
                    add_rank_button:TDLib()
                        :ClearPaint()
                        :Background(Color(255, 255, 255))
                        :Text("Cancel", "Default", Color(0, 0, 0))
                        :FadeHover(Color(240, 116, 116))
                    remove_rank_button:TDLib()
                        :ClearPaint()
                        :Background(Color(255, 255, 255))
                        :FadeHover(Color(125, 231, 128))
                end
                remove_selection_toggle = !remove_selection_toggle -- Toggle Rank Selection
            end
        end

        rank_panel:InvalidateChildren(true)

        local selected_rank
        local rank_buttons = {}

        local function RankCategory(name) ---- Rank Element Builder ----
            local rankCategory = vgui.Create("DCollapsibleCategory", rank_list)
            rankCategory:SetLabel(name)
            rankCategory.Header:SetTextColor(Color(191, 191, 191, 255))
            rankCategory:Dock(TOP)
            rankCategory:SetExpanded(false)
            rankCategory.Header:TDLib()
                :ClearPaint()
                :Background(Color(255, 255, 255))
                :FadeHover(Color(209, 209, 209))
            rankCategory:SetTall(35)
            rankCategory.Header:SetContentAlignment(5)

            rankCategory.Header.UpdateColours = function (self, skin)
                if ( self:GetParent():GetExpanded() ) then
                    return Color(0, 0, 0, 255)
                else
                return Color(191, 191, 191, 255)
                end
            end

            rankCategory.OnToggle = function (self)
                if selected_rank == self then
                    selected_rank = nil
                else
                    if selected_rank then
                        selected_rank:Toggle()
                    end
                    selected_rank = self
                end
            end

            rankCategory.Think = function (self)
                self.animSlide:Run()

                --self:GetParent():InvalidateLayout(true)
                --self:GetParent():SizeToChildren(false, true)
            end

            function rankCategory:SetLabel(val)
                rankCategory:SetLabel(val)
            end

            local rankInfoContents = vgui.Create("DPanel")
            rankInfoContents:SetTall(54)
            rankInfoContents:SetContentAlignment(5)
            rankCategory.powerslider = vgui.Create("DNumSlider", rankInfoContents)
            rankCategory.powerslider:SetMin(0)
            rankCategory.powerslider:SetDecimals(0)
            rankCategory.powerslider:SetText("Power")
            rankCategory.powerslider:Dock(TOP)

            rankCategory.powerslider.OnValueChanged = function (self)
                net.Start "JAAS_ModifyRank_Channel"
                net.WriteUInt(3, 3)
                net.WriteString(name)
                net.WriteUInt(self:GetValue(), 8)
                net.SendToServer()
            end

            function rankCategory:SetPowerValue(val)
                self.powerslider:SetValue(tonumber(val))
            end

            rankCategory.invisCheck = vgui.Create("DCheckBoxLabel", rankInfoContents)
            rankCategory.invisCheck:TDLib()
                    :ClearPaint()
                    :Text("Invisible", "Default", Color(0, 0, 0))
                    :SquareCheckbox(Color(173, 185, 202), Color(242, 242, 242))

            rankCategory.invisCheck.OnChange = function (pnl, val)
                net.Start "JAAS_ModifyRank_Channel"
                net.WriteUInt(4, 3)
                net.WriteString(name)
                net.WriteBool(val)
                net.SendToServer()
            end

            function rankCategory:SetInvisValue(val)
                self.invisCheck:SetValue(tobool(val))
            end

            rankInfoContents:InvalidateLayout(true)
            rankInfoContents:SizeToChildren(false, true)
            rankCategory:SetContents(rankInfoContents)

            return rankCategory
        end

        for id,info in PANEL.GetRankIterator() do -------- Initial Rank List Build ---------
            rank_buttons[id] = RankCategory(info.name)
        end

        rank_list:InvalidateLayout(true)
        rank_list:SizeToChildren(false, true)

        local HookRank = JAAS.Hook "Rank" ------- Rank List Update Hooks -------
        HookRank "Added" ["InterfaceUpdate"] = function (id, name, power, invis)
            print(id, name, power, invis)
            rank_buttons[id] = RankCategory(name)
        end
        HookRank "Removed" ["InterfaceUpdate"] = function (id)
            rank_buttons[id]:Remove()
            rank_buttons[id] = nil
        end
        HookRank "NameUpdated" ["InterfaceUpdate"] = function (id, old, new)
            rank_buttons[id]:SetLabel(new)
        end
        HookRank "PowerUpdated" ["InterfaceUpdate"] = function (id, old, new)
            rank_buttons[id]:SetPowerValue(val)
        end
        HookRank "InvisUpdated" ["InterfaceUpdate"] = function (id, old, new)
            rank_buttons[id]:SetInvisValue(new)
        end

        if canModifyCommand or canModifyPermission or canModifyPlayers then
            if canModifyPlayers then ------- User Tab Button --------
                local user_button = vgui.Create("DButton", tab_buttons)
                user_button:Dock(RIGHT)
                user_button:TDLib()
                    :ClearPaint()
                    :Background(Color(255, 255, 255))
                    :Text("Users", "DermaDefaultBold", Color(0, 0, 0))
                    :FadeHover(Color(209, 209, 209))
                user_button:SetWide(88)

                user_button.DoClick = function ()
                    object_list:OpenTab("Users")
                end
            end

            if canModifyPermission then ------- Permission Tab Button --------
                local permission_button = vgui.Create("DButton", tab_buttons)
                permission_button:DockMargin(0, 0, 1, 0) -- Left: 0, Top: 0, Right: 1, Bottom: 0
                permission_button:Dock(RIGHT)
                permission_button:TDLib()
                    :ClearPaint()
                    :Background(Color(255, 255, 255))
                    :Text("Permissions", "DermaDefaultBold", Color(0, 0, 0))
                    :FadeHover(Color(209, 209, 209))
                permission_button:SetWide(88)

                permission_button.DoClick = function ()
                    object_list:OpenTab("Permissions")
                end
            end

            if canModifyCommand then ------- Command Tab Button --------
                local command_button = vgui.Create("DButton", tab_buttons)
                command_button:DockMargin(0, 0, 1, 0) -- Left: 0, Top: 0, Right: 1, Bottom: 0
                command_button:Dock(RIGHT)
                command_button:TDLib()
                    :ClearPaint()
                    :Background(Color(255, 255, 255))
                    :Text("Commands", "DermaDefaultBold", Color(0, 0, 0))
                    :FadeHover(Color(209, 209, 209))
                command_button:SetWide(88)

                command_button.DoClick = function ()
                    object_list:OpenTab("Commands")
                end
            end
        end

        GUI.RegisterTab("Ranks", rank_panel, Color(174, 75, 229))
    end
end, "Can Modify Rank Table", "Can Modify Commands", "Can Modify Permissions", "Can Modify Player")

PANEL.PermissionCheck(function (canModifyAccess) ---------- Access Tab -----------
    if canModifyAccess then
        local access_panel = vgui.Create("EditablePanel") ------ Access Base Panel -------
        access_panel:TDLib()
            :ClearPaint()
            :Background(Color(59, 56, 56, 255))
            :Outline(Color(81, 223, 145), 2)
            :DockPadding(20, 30, 20, 20) -- Left: 20, Top: 30, Right: 20, Bottom: 20
        access_panel:SetTall(ScrH() * 0.58)
        access_panel:SetWide(742)

        GUI.RegisterTab("Access", access_panel, Color(81, 223, 145))
    end
end, "Can Modify Access Group")

PANEL.PermissionCheck(function (canAccessLog) --------- Log Tab ----------
    if canAccessLog then
        local log_panel = vgui.Create("EditablePanel") --------- Log Base Panel ----------
        log_panel:TDLib()
            :ClearPaint()
            :Background(Color(59, 56, 56, 255))
            :Outline(Color(106, 189, 198), 2)
        log_panel:SetTall(ScrH() * 0.58)
        log_panel:SetWide(197)

        local date_panel = vgui.Create("DScrollPanel", log_panel) --------- Scroll Log List ---------
        date_panel:Dock(FILL)
        date_panel:TDLib()
            :ClearPaint()
            :HideVBar()
            :Background(Color(242, 242, 242, 255))
        date_panel:SetContentAlignment(5)
        date_panel:DockMargin(10, 10, 10, 10) -- Left: 10, Top: 10, Right: 10, Bottom: 10

        local LOG = JAAS.Log()

        local date_buttons = {}
        local date_viewer = {}

        LOG:getLogDates(function (dates)
            for k,v in ipairs(dates) do
                local date_button = vgui.Create("DButton")

                date_button:SetContentAlignment(5)
                date_button:TDLib()
                    :ClearPaint()
                    :Text(v, "Default", Color(0, 0, 0, 255))
                    :FadeHover(Color(209, 209, 209))
                date_button:SetTall(24)
                date_button.val = v

                date_button.DoClick = function ()
                    date_viewer[v] = vgui.Create("DFrame")
                    date_viewer[v]:TDLib()
                        :ClearPaint()
                        :Background(Color(59, 56, 56, 255))
                    date_viewer[v]:SetSize(432, 627)
                    date_viewer[v]:SetTitle(v)
                    date_viewer[v]:SetSizable(true)
                    local log_reader = date_viewer[v]:Add("JLogReader")
                    log_reader:DockMargin(5, 5, 5, 5) -- Left: 5, Top: 5, Right: 5, Bottom: 5
                    log_reader:Dock(FILL)
                    log_reader:SetDate(v)
                    log_reader:Display()
                    log_reader:TDLib()
                        :ClearPaint()
                        :Background(Color(255, 255, 255))

                    local control_panel = date_viewer[v]:Add("DPanel")
                    control_panel:DockMargin(5, 5, 5, 5) -- Left: 5, Top: 5, Right: 5, Bottom: 5
                    control_panel:Dock(TOP)
                    control_panel:TDLib()
                        :ClearPaint()
                    control_panel:Hide()

                    local module_filter = control_panel:Add("DComboBox")
                    module_filter:Dock(LEFT)
                    module_filter:DockMargin(10, 0, 0, 0) -- Left: 10, Top: 0, Right: 0, Bottom: 0
                    module_filter:SetContentAlignment(4)
                    module_filter:TDLib()
                        :ClearPaint()
                        :Background(Color(242, 242, 242, 255))
                        :FadeHover(Color(173, 185, 202))
                    module_filter:SetValue("Module")

                    for k,v in ipairs(log_reader:GetModule()) do
                        module_filter:AddChoice(v)
                    end

                    module_filter:SetSortItems(true)
                    module_filter.OnSelect = function (pnl, index, value)

                    end
                end

                date_buttons[k] = date_button
            end

            table.sort(date_buttons, function (a,b)
                a = string.Explode("-", a.val)
                b = string.Explode("-", b.val)
                return os.time({day = tonumber(a[1]), month = tonumber(a[2]), year = tonumber(a[3])}) < os.time({day = tonumber(b[1]), month = tonumber(b[2]), year = tonumber(b[3])})
            end)

            for k,v in ipairs(date_buttons) do
                v:SetParent(date_panel)
                v:Dock(TOP)
            end

            date_panel.pnlCanvas:InvalidateLayout(true)
            date_panel.pnlCanvas:SizeToChildren(false, true)
        end)

        GUI.RegisterTab("Logs", log_panel, Color(106, 189, 198))
    end
end, "Can Access Logs")

JUI:SetAccess(
    function ()
        if ui_toggle then
            if open then
                main:HideAll()
            else
                main:ShowAll()
            end
            open = !open
            gui.EnableScreenClicker(open)
        else
            main:ShowAll()
            gui.EnableScreenClicker(true)
        end
    end,
    function ()
        if !ui_toggle then
            main:HideAll()
            gui.EnableScreenClicker(false)
        end
    end
)