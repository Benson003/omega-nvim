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
	local lines = {
		" 󱓞 Omega Diagnostic Report",
		" " .. string.rep("━", 40),
		"",
	}
	local has_data = false

	-- Helper to indent and split multi-line strings
	local function add_wrapped(str, indent)
		local parts = vim.split(str, "\n")
		for _, p in ipairs(parts) do
			table.insert(lines, string.rep(" ", indent) .. p)
		end
	end

	for section_name, kinds in pairs(store) do
		local section_added = false
		for kind_name, entries in pairs(kinds) do
			if #entries > 0 then
				if not section_added then
					table.insert(lines, string.format(" [%s]", section_name:upper()))
					section_added = true
					has_data = true
				end

				for _, entry in ipairs(entries) do
					table.insert(lines, string.format("  󰅙 %s", kind_name:upper()))

					local d = entry.data
					-- CUSTOM FORMATTERS based on your specific keys
					if d.path and d.error then
						-- Format for Loader Path Errors
						table.insert(lines, "    󰈔 Path  : " .. d.path)
						table.insert(lines, "    󰅚 Error : " .. d.error)
					elseif d.name and d.from and d.to then
						-- Format for Loader Overrides
						table.insert(lines, "    󰏖 Plugin: " .. d.name)
						table.insert(lines, "    󰃠 Status: " .. d.from .. " ━󰁔 " .. d.to)
					elseif d.spec and d.error then
						-- Format for Registry Conflicts
						table.insert(lines, "    󰗀 Spec  : " .. d.spec)
						add_wrapped("    󰅚 Issue : " .. d.error, 0)
					else
						-- Fallback for unknown shapes
						add_wrapped(vim.inspect(d), 4)
					end
					table.insert(lines, "") -- Small gap between entries
				end
			end
		end
		if section_added then
			table.insert(lines, " " .. string.rep("─", 40))
		end
	end

	if not has_data then
		table.insert(lines, "  󰄬 No issues detected. Engine is healthy.")
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

	-- Buffer styling
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr }) -- Use markdown for bold/icons
	vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

	local width = math.floor(vim.o.columns * 0.7)
	local height = math.floor(vim.o.lines * 0.6)

	vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " 󰒓 Omega System Status ",
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
