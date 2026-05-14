return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    priority = 1000,
    build = ":TSUpdate",
    config = function()
        -- We no longer call require('nvim-treesitter.configs').setup()
        -- Highlight is enabled by default in Neovim 0.10+
        -- We will handle parser installation in the background provisioner
    end
}
