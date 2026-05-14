return {
    "williamboman/mason.nvim",
    cmd = "Mason",
    lazy = false,
    config = function()
        require("mason").setup()
        -- The registry can now tell Mason what to do in the background
    end,
}
