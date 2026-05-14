local M = {}

local diag = require("omega.core.diagnostics")


_G._omega_editor_state = _G._omega_editor_state or {
    commands = {},
    keymaps = {},
    autocmds = {},
    options = {},
}

local state = _G._omega_editor_state


local function apply_options()
    for k, v in pairs(state.options) do
        local ok, err = pcall(vim.api.nvim_set_option_value, k, v, {})
        if not ok then
            diag.add("runtime", "warnings", {
                type = "invalid_option", detail = err,
            })
        end
    end
end

local function apply_commands()
    local seen = {}
    for _, spec in ipairs(state.commands) do
        local name = spec.name
        if not name or type(spec.fn) ~= "function" then
            diag.add("runtime", "errors", {
                type = "invalid_command",
                detail = spec,
            })
            goto continue
        end

        if seen[name] then
            diag.add("runtime", "warnings", {
                type = "command_duplicate",
                name = name,
            })
        end

        seen[name] = true

        vim.api.nvim_create_user_command(
            name,
            spec.fn,
            spec.opts or {}
        )

        :: continue ::
    end
end

local function apply_keymaps()
    local seen = {}

    for _, spec in ipairs(state.keymaps) do
        local mode = spec.mode
        local lhs = spec.lhs

        if not mode or not lhs then
            diag.add("runtime", "errors", {
                type = "invalid_keymap",
                detail = spec
            })

            goto continue
        end

        local id = mode .. ":" .. lhs
        if seen[id] then
            diag.add("runtime", "warnings", {
                type = "keymap_duplicate",
                key = id,
            })
        end
        seen[id] = true

        vim.keymap.set(
            mode,
            lhs,
            spec.rhs,
            spec.opts or {}
        )
        :: continue ::
    end
end

local function apply_autocmds()
    local group = vim.api.nvim_create_augroup("OmegaEditor", { clear = true })
    for _, spec in ipairs(state.autocmds) do
        if not spec.event then
            diag.add("runtime", "errors", {
                type = "invalid_autocmd",
                detail = spec,
            })
            goto continue
        end

        vim.api.nvim_create_autocmd(spec.event, {
            group = group,
            pattern = spec.opts and spec.opts.pattern,
            callback = spec.opts and spec.opts.callback,
            desc = spec.opts and spec.opts.desc,
        })
        ::continue::
    end
end



function M.opt(name, value)
    state.options[name] = value
end

function M.keymap(mode, lhs, rhs, opts)
    table.insert(state.keymaps, {
        mode = mode,
        lhs = lhs,
        rhs = rhs,
        opts = opts,
    })
end

function M.command(name, fn, opts)
    table.insert(state.commands, {
        name = name,
        fn = fn,
        opts = opts,
    })
end

function M.autocmd(event, opts)
    table.insert(state.autocmds, {
        event = event,
        opts = opts
    })
end

function M._state()
    return state
end

function M.apply()
    local state = require("omega.core.state")
    local old_state = state.instrumentation
    state.disable_instrumentation()
    apply_options()
    apply_keymaps()
    apply_commands()
    apply_autocmds()
    state.instrumentation = old_state
end

return M
