local var = {
    MySQLServer = false,
    MySQLServerInformation = {
        host="",
        username="",
        password="",
        database=""
    },
    TraceExecution = true,
    ExecutionRefusal = false,
    ValidFilepaths = {
        "addons/*/lua/jaas/*",
        "addons/just-another-admin-system/lua/*"
    }
}

JAAS.Var = setmetatable({}, {
    __index = var,
    __newindex = function () end,
    __metatable = nil
})