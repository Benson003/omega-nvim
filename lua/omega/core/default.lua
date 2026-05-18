local M = {}
local editor = require("omega.core.editor")
local diag = require("omega.core.diagnostics")

local function default_options()
	editor.opt("clipboard", "unnamedplus")
	editor.opt("laststatus", 3)
	editor.opt("number", true)
	editor.opt("relativenumber", true)
	editor.opt("expandtab", true)
	editor.opt("shiftwidth", 4)
	editor.opt("tabstop", 4)
	editor.opt("termguicolors", true)
	editor.opt("signcolumn", "yes")
end

local function default_keymaps()
	local map = editor.keymap
	-- Window Navigation
	map("n", "<C-h>", "<C-w>h", { silent = true })
	map("n", "<C-j>", "<C-w>j", { silent = true })
	map("n", "<C-k>", "<C-w>k", { silent = true })
	map("n", "<C-l>", "<C-w>l", { silent = true })

	-- Search and UI
	map("n", "<Esc>", "<cmd>nohlsearch<cr>", { silent = true })

	-- LSP / Completion Quality of Life
	map("n", "K", function()
		vim.lsp.buf.hover()
	end, { desc = "LSP: Hover Documentation" })
	map("n", "gd", function()
		vim.lsp.buf.definition()
	end, { desc = "LSP: Go to Definition" })
	map("n", "gr", function()
		vim.lsp.buf.references()
	end, { desc = "LSP: List References" })
	map("n", "<leader>ca", function()
		vim.lsp.buf.code_action()
	end, { desc = "LSP: Code Action" })
	map("n", "<leader>rn", function()
		vim.lsp.buf.rename()
	end, { desc = "LSP: Rename Symbol" })

	-- Diagnostic Navigation
	map("n", "[d", function()
		vim.diagnostic.goto_prev()
	end, { desc = "Next Diagnostic" })
	map("n", "]d", function()
		vim.diagnostic.goto_next()
	end, { desc = "Prev Diagnostic" })
	map("n", "<leader>e", function()
		vim.diagnostic.open_float()
	end, { desc = "Floating Diagnostic" })

	-- INSERT MODE COMPLETION BINDINGS
	-- 1. Accept completion with Enter
	map("i", "<CR>", function()
		if require("blink.cmp").is_visible() then
			return require("blink.cmp").accept()
		else
			return vim.api.nvim_replace_termcodes("<CR>", true, true, true)
		end
	end, { expr = true, silent = true, desc = "Blink: Accept Completion" })

	-- 2. Navigate menu with Ctrl+n / Ctrl+p (Standard Vim feel)
	map("i", "<C-n>", function()
		require("blink.cmp").select_next()
	end, { silent = true })
	map("i", "<C-p>", function()
		require("blink.cmp").select_prev()
	end, { silent = true })

	-- 3. Signature Help
	map("i", "<C-s>", function()
		vim.lsp.buf.signature_help()
	end, { desc = "LSP: Signature Help" })
end

local function default_commands()
	local cmd = editor.command

	cmd("OmegaInspect", function()
		print(vim.inspect(diag.get()))
	end, {})

	cmd("OmegaReset", function()
		diag.reset()
		print("Omega diagnostics reset")
	end, {})

	cmd("OmegaDiag", function()
		diag.open_diagnostics_window()
	end, {})

	-- OmegaUpdate using standard commands to avoid Lua API errors
	cmd("OmegaUpdate", function()
		print("🚀 Omega Update Sequence Initiated...")
		require("lazy").sync({ wait = false })

		require("nvim-treesitter.install").update()
		if vim.fn.exists(":MasonUpdate") > 0 then
			vim.cmd("MasonUpdate")
		end
		print("✨ Updates queued")
	end, {})
end

local function default_autocmds()
	local ac = editor.autocmd
	ac("TextYankPost", {
		callback = function()
			vim.highlight.on_yank()
		end,
	})

	ac("VimResized", {
		callback = function()
			vim.cmd("tabdo wincmd =")
		end,
	})
end

function M.init()
	default_options()
	default_keymaps()
	default_commands()
	default_autocmds()
end

return M
