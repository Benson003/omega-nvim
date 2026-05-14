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

    -- 3. THE PROTECTOR: Schedule the "Plugin-Heavy" logic
    -- This waits for Lazy.nvim to finish setting up the Runtime Path (rtp)
    -- effectively fixing the 'rtp (a nil value)' crash.
    vim.schedule(function()
        -- Load infra (LSP, Handlers) and user overrides
        require("omega.infra").init()
        require("omega.core.overrides").load()

        -- Finalize: Flush the gathered state to Neovim
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
