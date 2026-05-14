local M = {}

function M.setup()
    -- This calls the init() function in lua/omega/core/init.lua
    require("omega.core").init()
end

return M
