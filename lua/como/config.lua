--- @class (private) como.config
--- @field show_last_cmd boolean
--- @field auto_scroll boolean
--- @field preferred_win_pos string
--- @field custom_matchers table
--- @field default_buf_name string
--- @field set_buf_keymap_cb fun(buf_nr: integer)|nil
--- @field hl_id integer
local Config = {
    show_last_cmd = true,
    auto_scroll = true,
    preferred_win_pos = "bottom",
    custom_matchers = {},
    default_buf_name = "*compilation*",
    set_buf_keymap_cb = nil,
    hl_id = -1,
}

Config.default_hl_val = {
    ["ok"] = "DiagnosticSignOk",
    ["warning"] = "DiagnosticSignWarn",
    ["error"] = "DiagnosticSignError",
    ["filename"] = "qfFileName",
    ["normal"] = "Normal",
}


Config.init_hl_group = function()
    local val = Config.default_hl_val
    Config.hl_id = vim.api.nvim_create_namespace('Como_ns')

    local hl_group = "def link Como_hl_ok " .. val.ok
    vim.cmd.highlight(hl_group)

    hl_group = "def link Como_hl_warn " .. val.warning
    vim.cmd.highlight(hl_group)

    hl_group = "def link Como_hl_error " .. val.error
    vim.cmd.highlight(hl_group)

    hl_group = "def link Como_hl_filename " .. val.filename
    vim.cmd.highlight(hl_group)

    hl_group = "def link Como_hl_normal " .. val.normal
    vim.cmd.highlight(hl_group)
end

return Config
