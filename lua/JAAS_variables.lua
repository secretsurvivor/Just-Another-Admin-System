local var = {
    TraceExecution = false, -- This will also disable access refusal
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