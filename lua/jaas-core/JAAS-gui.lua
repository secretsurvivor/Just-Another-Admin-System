local MODULE, log, dev = JAAS:RegisterModule "GUI"

local interface_tab, settings = {}, {} -- interface_tab = {{name, panel, order}*},  settings[name] = {{name, data_type, client_func, default value, description}*}
local current_interface = nil
local open_func, close_func = function() end, function () end

local jaas_interface = {
    BuildTabs = function (func)
        for k,v in ipairs(interface_tab) do
            func(v)
        end
    end,
    BuildSettings = function (func)
        for k,v in pairs(settings) do
            func(k, v)
        end
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
        return setmetatable({panel = panel}, {__index = jaas_interface}), panel
    end,
    RegisterTab = function (name, panel, order)
        interface_tab = {name, panel, order}
    end,
    RegisterSettings = function (name, settings_info) settings_info
        settings[name] = settings_info
    end
}

concommand.Add("+open_jaas", function () open_func() end)
concommand.Add("-open_jaas", function () close_func() end)