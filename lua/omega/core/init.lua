local M = {}
local state = require("omega.core.state")

function M.init()
    require("omega.core.registry").init()

    --require("omega.core.loader").init()

    require("omega.core.shim").install()

    -- 1. Baseline
    state.disable_instrumentation()
    require("omega.core.default").init()

    -- 2. Overrides
    require("omega.infra").init()
    state.enable_instrumentation()

    -- ASYNC INSTALLATION BLOCK
    -- We use a slight delay so the dashboard/buffer renders first
    vim.defer_fn(function()
        local reg = require("omega.core.registry")

        -- 1. Async Mason Installation
        local tools = reg.get_all_mason_tools()
        local ok_m, mason_reg = pcall(require, "mason-registry")

        if ok_m then
            for _, tool in ipairs(tools) do
                mason_reg.refresh(function() -- Refresh registry in background
                    local ok_p, p = pcall(mason_reg.get_package, tool)
                    if ok_p and not p:is_installed() then
                        -- Mason's install is actually async if you don't block for the handle
                        p:install()
                    end
                end)
            end
        end

        -- 2. Treesitter Parsers (Async & Safe)
        local parsers = reg.get_all_treesitter_parsers()
        for _, p in ipairs(parsers) do
            local has_parser = #vim.api.nvim_get_runtime_file("parser/" .. p .. ".*", false) > 0

            if not has_parser then
                vim.schedule(function()
                    -- Force a space and use pcall to prevent the red screen of death
                    local cmd = string.format("TSInstall %s", p)
                    pcall(vim.cmd, cmd)
                end)
            end
        end
    end, 200) -- 200ms gives the UI plenty of time to draw the first frame

    require("omega.core.overrides").load()

    -- 3. Finalize
    require("omega.core.editor").apply()
end

return M
