local M = {}

function M.setup()
    local state = require("omega.core.state")

    -- 1. Setup the core engine (Immediate)
    require("omega.core.registry").init()
    require("omega.core.shim").install()

    -- 2. Baseline: Load internal defaults with instrumentation OFF
    -- This handles non-plugin things like line numbers and clipboard
    state.disable_instrumentation()
    require("omega.core.default").init()
    state.enable_instrumentation()

    -- PHASE 3: The "Wait for Lazy" Wrapper (CRITICAL)
    -- This pushes the loading of infra/overrides to the next tick.
    -- This gives Lazy time to set the paths for snacks, blink, etc.
    vim.schedule(function()
        -- Now it's safe to load things that depend on other plugins
        local ok_infra, err_infra = pcall(require, "omega.infra")
        if ok_infra then
            require("omega.infra").init()
        else
            print("Omega Infra Error: " .. err_infra)
        end

        require("omega.core.overrides").load()
        require("omega.core.editor").apply()
    end)

    -- 4. Background tasks (Mason & Treesitter)
    vim.defer_fn(function()
        local reg = require("omega.core.registry")

        -- Async Mason Installation
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

        -- Treesitter Parsers
        local parsers = reg.get_all_treesitter_parsers()
        for _, p in ipairs(parsers) do
            local has_parser = #vim.api.nvim_get_runtime_file("parser/" .. p .. ".*", false) > 0
            if not has_parser then
                vim.schedule(function()
                    local cmd = string.format("TSInstall %s", p)
                    pcall(vim.cmd, cmd)
                end)
            end
        end
    end, 200)
end

return M
