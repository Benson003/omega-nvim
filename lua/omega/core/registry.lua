--[[
Cannonical Format
{
    name = string,/implicit
    filetypes = { string },

    treesitter = {
        host = string,
        injections = { string }?,
    }?,

    lsp = {
        servers = {
            [string] = {
                settings = table?,
                on_attach = function?,
                capabilities = table?,
            }
        }
    }?,

    tools = {
        mason = {
            ensure_installed = { string }?
        }?,

        formatter = {
            preferred = { string },
            config = table | function?,
        }?,

        linter = {
            preferred = { string },
            config = table | function?,
        }?,
    }?,
}
]]

local M = {}
local specs = {}
local ft_map = {}
local diag = require("omega.core.diagnostics")

local SCHEMA = {
    name = { type = "string", required = true, is_positional = true },
    filetypes = { type = "table", item_type = "string", required = true },

    treesitter = {
        type = "table",
        required = false,
        fields = {
            host = { type = "string", required = true },
            injections = { type = "table", item_type = "string", required = false },
        }
    },

    lsp = {
        type = "table",
        required = false,
        fields = {
            servers = { type = "table", required = true } -- [string] = table
        }
    },

    tools = {
        type = "table",
        required = false,
        fields = {
            mason = {
                type = "table",
                fields = { ensure_installed = { type = "table", item_type = "string" } }
            },
            formatter = {
                type = "table",
                fields = {
                    preferred = { type = "table", item_type = "string" },
                    config = { type = { "table", "function" } }
                }
            },
            linter = {
                type = "table",
                fields = {
                    preferred = { type = "table", item_type = "string" },
                    config = { type = { "table", "function" } }
                }
            }
        }
    }
}

local function validate_field(val, rule, key_path)
    -- 1. Check Requirement
    if rule.required and val == nil then
        return false, string.format("Missing required field: %s", key_path)
    end
    if val == nil then return true end

    -- 2. Check Type (handles single string or table of strings for multi-type)
    local actual_type = type(val)
    local expected_types = type(rule.type) == "table" and rule.type or { rule.type }
    local type_match = false
    for _, t in ipairs(expected_types) do
        if actual_type == t then
            type_match = true
            break
        end
    end

    if not type_match then
        return false, string.format("Type mismatch at %s: expected %s, got %s",
            key_path, table.concat(expected_types, "|"), actual_type)
    end

    -- 3. Check List Items
    if rule.item_type and actual_type == "table" then
        for i, item in ipairs(val) do
            if type(item) ~= rule.item_type then
                return false, string.format("Invalid item type in %s[%d]: expected %s",
                    key_path, i, rule.item_type)
            end
        end
    end

    -- 4. Recursive Check for Nested Fields
    if rule.fields and actual_type == "table" then
        for sub_key, sub_rule in pairs(rule.fields) do
            local ok, err = validate_field(val[sub_key], sub_rule, key_path .. "." .. sub_key)
            if not ok then return false, err end
        end
    end

    return true
end

function M.register(input_spec)
    -- 1. Extract Name
    local raw_name = input_spec.name or input_spec[1]
    if not raw_name then
        diag.add("registry", "conflicts", "Language spec missing name identifier")
        return
    end

    -- 2. Validate top-level fields against SCHEMA
    -- We iterate through the SCHEMA and validate each field present in input_spec
    for key, rule in pairs(SCHEMA) do
        local value = (key == "name") and raw_name or input_spec[key]
        local ok, err = validate_field(value, rule, raw_name .. "." .. key)

        if not ok then
            diag.add("registry", "conflicts", {
                spec = raw_name,
                error = err
            })
            return
        end
    end

    -- 3. Collision Detection
    if specs[raw_name] then
        diag.add("registry", "conflicts", "Duplicate language spec: " .. raw_name)
        return
    end

    -- 4. Successful Storage
    input_spec.name = raw_name
    specs[raw_name] = input_spec
    for _, ft in ipairs(input_spec.filetypes) do
        ft_map[ft] = ft_map[ft] or {}
        table.insert(ft_map[ft], raw_name)
    end
end

-- Get all specs associated with a specific filetype
function M.get_specs(ft)
    local names = ft_map[ft] or {}
    local result = {}
    for _, name in ipairs(names) do
        table.insert(result, specs[name])
    end
    return result
end

-- Get a flat list of all tools for Mason to ensure_installed
function M.get_all_mason_tools()
    local tools = {}
    local seen = {}
    for _, spec in pairs(specs) do
        local mason = spec.tools and spec.tools.mason
        if mason and mason.ensure_installed then
            for _, tool in ipairs(mason.ensure_installed) do
                if not seen[tool] then
                    table.insert(tools, tool)
                    seen[tool] = true
                end
            end
        end
    end
    return tools
end

-- Get a flat list of all unique TS parsers needed by the system
-- Add to omega/core/registry.lua

function M.get_all_treesitter_parsers()
    local parsers = {}
    local seen = {}
    for _, spec in pairs(specs) do
        if spec.treesitter then
            -- Collect the host
            local host = spec.treesitter.host
            if host and not seen[host] then
                table.insert(parsers, host)
                seen[host] = true
            end
            -- Collect all injections
            if spec.treesitter.injections then
                for _, inj in ipairs(spec.treesitter.injections) do
                    if not seen[inj] then
                        table.insert(parsers, inj)
                        seen[inj] = true
                    end
                end
            end
        end
    end
    return parsers
end

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


function M.build_tool_config()
    local conform = {}
    local lint = {}

    for _, spec in pairs(specs) do
        local ft_list = spec.filetypes

        local tools = spec.tools
        if tools then
            if tools.formatter and tools.formatter.preferred then
                for _, ft in ipairs(ft_list) do
                    conform[ft] = tools.formatter.preferred
                end
            end

            if tools.linter and tools.linter.preferred then
                for _, ft in ipairs(ft_list) do
                    lint[ft] = tools.linter.preferred
                end
            end
        end
    end

    return conform, lint
end

function M.init()
    local base_path = vim.fn.stdpath("config") .. "/lua"

    local path = base_path .. "/user/langs"

    -- Only scan if directory exists
    if vim.fn.isdirectory(path) == 1 then
        local found = scan_dir(path, "user")

        for _, spec in ipairs(found) do
            M.register(spec)
        end
    end
end

return M
