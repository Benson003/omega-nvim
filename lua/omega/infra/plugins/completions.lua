return {
    'saghen/blink.cmp',
    version = 'v0.*',
    dependencies = 'rafamadriz/friendly-snippets',
    lazy = false,
    priority = 1000,

    opts = {
        snippets = { preset = 'default' },
        keymap = { preset = 'default' },
        appearance = {
            nerd_font_variant = 'mono',
        },
        sources = {
            default = { 'lsp', 'path', 'snippets', 'buffer' },
        },
        completion = {
            ghost_text = { enabled = false },
        },
    },
    -- Use the default config logic which Lazy handles best
}
