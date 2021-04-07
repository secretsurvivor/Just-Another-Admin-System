local MODULE, log, dev = JAAS:RegisterModule "GUI"

local interface_tab, settings = {}, {} -- interface_tab[name] = {panel, color},  settings[name] = {{name, data_type, client_func, default value, description}*}
local current_interface = nil
local open_func, close_func = function() end, function () end
local post_build_tab = function () end

local jaas_interface = {
    BuildTabs = function (func)
        post_build_tab = func
    end,
    SetAccess = function (self, func_open, func_close)
        if self.panel == current_interface then
            open_func = func_open
            close_func = func_close
        end
    end
}

local gui = {
    RegisterInterface = function (panel)
        current_interface = panel
        panel:Hide()
        return setmetatable({panel = panel}, {__index = jaas_interface}), panel
    end,
    RegisterTab = function (name, panel, color)
        panel:Hide()
        if !interface_tab[name] then
            post_build_tab(name, panel, color)
        end
        interface_tab[name] = {panel, color}
    end
}

concommand.Add("+open_jaas", function () open_func() end)
concommand.Add("-open_jaas", function () close_func() end)

MODULE.Access(MODULE.Class(gui, "jaas_gui_library"))

log:print "Module Loaded"