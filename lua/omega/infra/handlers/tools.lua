local M = {}

function M.attach(bufnr, tools_spec)
    local group = vim.api.nvim_create_augroup("OmegaAutoTools", { clear = false })

    local should_format = tools_spec.formatter and (tools_spec.formatter.format_on_save ~= false)

    -- FORMAT ON SAVE
    if should_format then
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = group,
            buffer = bufnr,
            callback = function()
                require("conform").format({
                    bufnr = bufnr,
                    lsp_fallback = true,
                })
            end,
        })
    end

    -- LINT TRIGGER
    if tools_spec.linter then
        require("lint").linters_by_ft[vim.bo[bufnr].filetype] = tools_spec.linter.preferred
        vim.api.nvim_create_autocmd({ "BufWritePost" }, {
            group = group,
            buffer = bufnr,
            callback = function()
                require("lint").try_lint()
            end,
        })
    end
end

return M
