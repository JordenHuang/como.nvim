local M = {}

M.default_hl_val = {
    -- warning = { link = "DiagnosticSignWarn", underline = true },
    warning = {
        fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="DiagnosticSignWarn"}).fg),
        underline = true
    },
    error = {
        fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="DiagnosticSignError"}).fg),
        underline = true
    },
    filename = {
        fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="qfFileName"}).fg),
        -- underline = true
    },
}

M.ns_id = ''

M.init_hl_group = function()
    local val = M.default_hl_val
    local ns_id = vim.api.nvim_create_namespace('Como_ns')
    M.ns_id = ns_id
    vim.api.nvim_set_hl(ns_id, 'Como_hl_warn', val.warning)
    vim.api.nvim_set_hl(ns_id, 'Como_hl_error', val.error)
    vim.api.nvim_set_hl(ns_id, 'Como_hl_filename', val.filename)

    -- Active the highlight namespace
    vim.api.nvim_set_hl_ns(ns_id)
end

M.apply_highlight = function(bufnr, hl_group, line, start_col, end_col)
    -- Add the highlight to the specified range
    vim.api.nvim_buf_add_highlight(bufnr, M.ns_id, hl_group, line, start_col, end_col)
end

return M
