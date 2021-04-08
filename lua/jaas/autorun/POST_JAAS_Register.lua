JAAS.include.Shared.Init "JAAS/JAAS_command_module.lua"
JAAS.include.Server.Init {
    "JAAS/JAAS_permission_module.lua",
    "JAAS/JAAS_log_module.lua"
}
JAAS.include.Client.Post "JAAS/tdlib.lua" -- Three's Derma Library - created by Threebow
JAAS.include.Client.Post "JAAS/JAAS_interface.lua"
JAAS.include.Server.Pre "JAAS/JAAS_ban.lua"