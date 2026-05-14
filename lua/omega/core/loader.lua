local M = {}
local diag = require("omega.core.diagnostics")

-- =========================
-- Loading primitives
-- =========================

local function safe_load(path)
    local ok, spec = pcall(dofile, path)

    if not ok then
        diag.add("loader", "errors", {
            path = path,
            error = spec,
        })
        return nil
    end

    if type(spec) ~= "table" then
        diag.add("loader", "errors", {
            path = path,
            error = "spec did not return a table",
        })
        return nil
    end

    return spec
end


local function scan_dir(dir, source)
    local ok, files = pcall(vim.fn.readdir, dir)
    if not ok or type(files) ~= "table" then
        return {}
    end

    local specs = {}

    for _, file in ipairs(files) do
        if file:sub(-4) == ".lua" then
            local path = dir .. "/" .. file
            local spec = safe_load(path)

            if spec then
                spec._omega_source = source
                table.insert(specs, spec)
            end
        end
    end

    return specs
end

-- =========================
-- Startup merge (SAFE)
-- =========================

-- No overrides, no logging, cannot fail
local function startup_merge(infra, ui, extra)
    local seen = {}
    local out = {}

    local function add(list)
        for _, spec in ipairs(list) do
            local name = spec[1] or spec.name
            if name and not seen[name] then
                seen[name] = true
                table.insert(out, spec)
            end
        end
    end

    -- priority via order
    add(infra)
    add(ui)
    add(extra)

    return out
end

-- =========================
-- Audit merge (STRICT + LOGGING)
-- =========================

local PRIORITY = {
    infra = 3,
    ui = 2,
    extra = 1,
}

local function audit_merge(infra, ui, extra)
    local seen = {}

    local function register(spec)
        local name = spec[1] or spec.name
        local source = spec._omega_source or "extra"

        if not name then return end

        if not seen[name] then
            seen[name] = spec
            return
        end

        local existing = seen[name]
        local existing_source = existing._omega_source or "extra"

        local new_prio = PRIORITY[source] or 0
        local old_prio = PRIORITY[existing_source] or 0

        if new_prio > old_prio then
            diag.add("loader", "overrides", {
                name = name,
                from = existing_source,
                to = source,
            })
        else
            diag.add("loader", "duplicates", {
                name = name,
                kept = existing_source,
                ignored = source,
            }
            )
        end
    end

    -- order does not matter here, priority handles it
    for _, s in ipairs(extra) do register(s) end
    for _, s in ipairs(ui) do register(s) end
    for _, s in ipairs(infra) do register(s) end
end

-- =========================
-- Init
-- =========================

function M.init()
    local base      = vim.fn.stdpath("config") .. "/lua"
    local data_path = vim.fn.stdpath("data") .. "/lazy/omega.nvim"
    local infra     = scan_dir(data_path .. "/lua/omega/infra/plugins")
    local extra     = scan_dir(base .. "/user/extras", "extra")
    local ui        = scan_dir(base .. "/user/ui", "ui")

    -- 1. safe startup (never blocks)
    local merged    = startup_merge(infra, ui, extra)
    require("lazy").setup(merged)

    -- 2. async audit (non-blocking diagnostics)
    vim.schedule(function()
        audit_merge(infra, ui, extra)
    end)
end

function M.get_lazy_specs()
    -- 1. 'user' files are still in your config directory
    local config_base = vim.fn.stdpath("config") .. "/lua"

    -- 2. 'infra' files are now in the plugin repo.
    -- We find the 'lua/omega' folder wherever it exists in Neovim's Runtime Path.
    local omega_rtp = vim.api.nvim_get_runtime_file("lua/omega", false)
    local infra_path = ""

    if #omega_rtp > 0 then
        -- This points to the actual path of the abstracted plugin
        infra_path = omega_rtp[1] .. "/infra/plugins"
    end

    -- 3. Perform the scans
    -- If infra_path is empty (plugin not installed yet), scan_dir will just return {}
    local infra  = infra_path ~= "" and scan_dir(infra_path, "infra") or {}
    local extra  = scan_dir(config_base .. "/user/extras", "extra")
    local ui     = scan_dir(config_base .. "/user/ui", "ui")

    -- 4. Merge and Audit as usual
    local merged = startup_merge(infra, ui, extra)

    vim.schedule(function()
        audit_merge(infra, ui, extra)
    end)

    return merged
end

return M
