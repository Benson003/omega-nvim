return {
    "neovim/nvim-lspconfig",
    lazy = false,
    priority = 1000,
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
    config = function()
        -- Core logic for LSP will live here later,
        -- but it will be triggered by BufAttach/FileType
    end
}
