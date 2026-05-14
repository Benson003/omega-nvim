local M = {}

--- Internal function to handle Mason and Treesitter installations
--- Moved inside the module scope to ensure M.setup can access it
local function init_background_tasks()
    vim.defer_fn(function()
        local reg = require("omega.core.registry")

        -- 1. Async Mason Installation
        local ok_m, mason_reg = pcall(require, "mason-registry")
        if ok_m then
            local tools = reg.get_all_mason_tools()
            for _, tool in ipairs(tools) do
                mason_reg.refresh(function()
                    local ok_p, p = pcall(mason_reg.get_package, tool)
                    if ok_p and not p:is_installed() then
                        p:install()
                    end
                end)
            end
        end

        -- 2. Treesitter Parsers
        local parsers = reg.get_all_treesitter_parsers()
        for _, p in ipairs(parsers) do
            -- Check if parser is already installed in runtime path
            local has_parser = #vim.api.nvim_get_runtime_file("parser/" .. p .. ".*", false) > 0
            if not has_parser then
                vim.schedule(function()
                    local cmd = string.format("TSInstall %s", p)
                    pcall(vim.cmd, cmd)
                end)
            end
        end
    end, 500) -- Ensures UI is idle before triggering intensive installs
end

function M.setup()
    local state = require("omega.core.state")

    -- 1. Setup the core engine (Immediate)
    -- Must run now so the shim is active when other plugins load
    require("omega.core.registry").init()
    require("omega.core.shim").install()

    -- 2. Baseline: Load internal defaults with instrumentation OFF
    -- Immediate setup for standard Neovim options
    state.disable_instrumentation()
    require("omega.core.default").init()
    state.enable_instrumentation()

    -- 3. PHASE 3: The "Wait for Lazy" Wrapper (CRITICAL)
    -- Hooking into "VeryLazy" ensures 'rtp' is populated and modules are found.
    vim.api.nvim_create_autocmd("User", {
        pattern = "VeryLazy",
        once = true,
        callback = function()
            -- Load Infra (LSP, Autocommands, Handlers)
            local ok_infra, err_infra = pcall(require, "omega.infra")
            if ok_infra then
                require("omega.infra").init()
            else
                -- Using notify instead of error to prevent bricking the session
                vim.notify("Omega Infra failed to load: " .. err_infra, vim.log.levels.ERROR)
            end

            -- Load User Overrides
            local ok_ov, overrides = pcall(require, "omega.core.overrides")
            if ok_ov then
                overrides.load()
            end

            -- Finalize: Flush the gathered state to Neovim
            require("omega.core.editor").apply()

            -- Trigger background maintenance tasks
            init_background_tasks()
        end,
    })
end

return M
