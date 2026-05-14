local M = {}
local registry = require("omega.core.registry")

local active_buffers = {}
local initialized_tools = {}

function M.detach(bufnr)
    active_buffers[bufnr] = nil
    initialized_tools[bufnr] = nil
end

function M.resolve(bufnr)
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local ft = vim.bo[bufnr].filetype
    if ft == "" then return end

    local specs = registry.get_specs(ft)
    if #specs == 0 then return end

    active_buffers[bufnr] = {}

    local merged_tools = nil

    for _, spec in ipairs(specs) do
        table.insert(active_buffers[bufnr], spec.name)

        require("omega.infra.handlers.treesitter").attach(bufnr, spec.treesitter)

        if spec.lsp and spec.lsp.servers then
            require("omega.infra.handlers.lsp").attach(bufnr, spec.lsp.servers)
        end

        require("omega.infra.handlers.completion").attach(bufnr)
        if spec.tools then
            merged_tools = merged_tools or {}
            merged_tools.formatter = spec.tools.formatter or merged_tools.formatter
            merged_tools.linter = spec.tools.linter or merged_tools.linter
        end
    end

    -- IMPORTANT: attach tools ONCE per buffer
    if merged_tools and not initialized_tools[bufnr] then
        initialized_tools[bufnr] = true

        require("omega.infra.handlers.tools").attach(bufnr, merged_tools)
    end
end

function M.setup()
    local group = vim.api.nvim_create_augroup("OmegaResolver", { clear = true })

    vim.api.nvim_create_autocmd({ "FileType" }, {
        group = group,
        callback = function(args)
            M.resolve(args.buf)
        end,
    })

    vim.api.nvim_create_autocmd("BufUnload", {
        group = group,
        callback = function(args)
            M.detach(args.buf)
        end,
    })
end

return M
