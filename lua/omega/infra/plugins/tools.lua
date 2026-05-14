return {
    {
        "stevearc/conform.nvim",
        lazy = false,
        priority = 1000,

        opts = function()
            local conform_map, _ = require("omega.core.registry").build_tool_config()

            return {
                formatters_by_ft = conform_map,
                format_on_save = false, -- IMPORTANT: disable plugin-level autocmds
            }
        end,
    },
    {
        "mfussenegger/nvim-lint",
        priority = 1000,
        lazy = false,
        config = function()
            local _, lint_map = require("omega.core.registry").build_tool_config()
            local lint = require("lint")

            lint.linters_by_ft = lint_map
        end
    }
}
