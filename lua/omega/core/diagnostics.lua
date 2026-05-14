local M = {}

-- =========================
-- Schema
-- =========================

local SCHEMA = {
	loader = {
		overrides = true,
		duplicates = true,
		errors = true,
	},
	registry = {
		conflicts = true,
	},
	runtime = {
		errors = true,
		warnings = true,
	},
}

-- =========================
-- Store
-- =========================

local function default_store()
	local store = {}

	for section, kinds in pairs(SCHEMA) do
		store[section] = {}
		for kind, _ in pairs(kinds) do
			store[section][kind] = {}
		end
	end

	return store
end

local store = default_store()

-- =========================
-- Internal helpers
-- =========================

local function valid(section, kind)
	return SCHEMA[section] and SCHEMA[section][kind]
end

local function wrap(section, kind, item)
	if type(item) ~= "table" then
		item = { message = tostring(item) }
	end

	return {
		ts = os.time(),
		section = section,
		kind = kind,
		data = item,
	}
end

-- =========================
-- API
-- =========================

function M.add(section, kind, item)
	if not valid(section, kind) then
		-- silent fail OR track internally (your choice)
		return
	end

	local entry = wrap(section, kind, item)
	table.insert(store[section][kind], entry)
end

function M.get()
	return store
end

function M.get_section(section)
	return store[section]
end

function M.get_kind(section, kind)
	if not valid(section, kind) then
		return nil
	end
	return store[section][kind]
end

function M.reset()
	store = default_store()
end

function M.open_diagnostics_window()
	local lines = { " Diagnostic Report", string.rep("=", 20), "" }
	local has_data = false

	for section_name, kinds in pairs(store) do
		local section_added = false
		for kind_name, entries in pairs(kinds) do
			if #entries > 0 then
				if not section_added then
					table.insert(lines, "[" .. section_name:upper() .. "]")
					section_added = true
					has_data = true
				end
				for _, entry in ipairs(entries) do
					-- 1. Get the message or inspect the data table
					local raw_msg = entry.data.message or vim.inspect(entry.data)

					-- 2. Split by newlines so nvim_buf_set_lines doesn't crash
					local entry_lines = vim.split(raw_msg, "\n")

					-- 3. Insert the first line with the bullet point
					table.insert(lines, string.format("  • [%s]: %s", kind_name, entry_lines[1]))

					-- 4. Insert subsequent lines (indented for readability)
					for i = 2, #entry_lines do
						table.insert(lines, "         " .. entry_lines[i])
					end
				end
			end
		end
		if section_added then
			table.insert(lines, "")
		end
	end

	if not has_data then
		table.insert(lines, "  No issues detected.")
	end

	local bufnr = vim.api.nvim_create_buf(false, true)

	-- This will now succeed because every item in 'lines' is a single-line string
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	-- ... rest of your window/options code ...
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
	vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr }) -- Changed to lua for better table syntax highlighting

	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Diagnostics ",
		title_pos = "center",
	})
end
-- =========================
-- Query helpers (lightweight)
-- =========================

function M.count(section, kind)
	local k = M.get_kind(section, kind)
	return k and #k or 0
end

function M.has_errors()
	return M.count("loader", "errors") > 0 or M.count("runtime", "errors") > 0
end

return M
