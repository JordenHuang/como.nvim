local M = {}

local mh = require('como.matcher')

local Pos = mh.Pos


M.default_hl_val = {
    ["ok"] = "DiagnosticSignOk",
    ["warning"] = "DiagnosticSignWarn",
    ["error"] = "DiagnosticSignError",
    ["filename"] = "qfFileName",
    -- ok = {
    --     fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="DiagnosticSignOk"}).fg),
    -- },
    -- warning = {
    --     fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="DiagnosticSignWarn"}).fg),
    -- },
    -- error = {
    --     fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="DiagnosticSignError"}).fg),
    -- },
    -- filename = {
    --     fg = string.format("#%06x",vim.api.nvim_get_hl(0, {name="qfFileName"}).fg),
    --     underline = true
    -- },
}

M.ns_id = ''

M.init_hl_group = function()
    local val = M.default_hl_val
    local ns_id = vim.api.nvim_create_namespace('Como_ns')
    M.ns_id = ns_id
    -- vim.api.nvim_set_hl(ns_id, 'Como_hl_ok', val.ok)
    -- vim.api.nvim_set_hl(ns_id, 'Como_hl_warn', val.warning)
    -- vim.api.nvim_set_hl(ns_id, 'Como_hl_error', val.error)
    -- vim.api.nvim_set_hl(ns_id, 'Como_hl_filename', val.filename)

    local hl_group = "def link Como_hl_ok " .. val.ok
    vim.cmd.highlight(hl_group)
    hl_group = "def link Como_hl_warn " .. val.warning
    vim.cmd.highlight(hl_group)
    hl_group = "def link Como_hl_error " .. val.error
    vim.cmd.highlight(hl_group)
    hl_group = "def link Como_hl_filename " .. val.filename
    vim.cmd.highlight(hl_group)

    -- Active the highlight namespace
    -- vim.api.nvim_set_hl_ns(ns_id)
end

M.apply_highlight = function(bufnr, hl_group, line, start_col, end_col)
    -- Add the highlight to the specified range
    vim.api.nvim_buf_add_highlight(bufnr, M.ns_id, hl_group, line, start_col, end_col)
end

-- The logic for applying highlights to text
M.highlight_logic = function(vals, bufnr, line_nr)
    if vals ~= nil then
        local parts = vals.parts
        local hl_group

        -- Get error type
        local etype
        for _, part in ipairs(parts) do
            if part[Pos.name] == "etype" then
                etype = part
                break
            end
        end
        if etype ~= nil then
            -- Determine the hl group for the current line base on etype
            if etype[Pos.data] == "warning" then
                hl_group = 'Como_hl_warn'
            elseif etype[Pos.data] == "error" then
                hl_group = 'Como_hl_error'
            else
                hl_group = 'Normal'
            end
        else
            hl_group = 'Como_hl_error'
        end

        -- Loop through the parts in the line, apply color to them
        for _, part in ipairs(parts) do
            if part[Pos.name] == "filename" then
                M.apply_highlight(bufnr, 'Como_hl_filename', line_nr, part[Pos.start_col]-1, part[Pos.end_col])
            elseif part[Pos.name] == "message" then
                M.apply_highlight(bufnr, 'Normal', line_nr, part[Pos.start_col]-1, part[Pos.end_col])
            else
                M.apply_highlight(bufnr, hl_group, line_nr, part[Pos.start_col]-1, part[Pos.end_col])
            end
            -- @function: apply_highlight(bufnr, hl_group, line, start_col, end_col)
            -- hl.apply_highlight(buf, 'Como_hl_error', line_nr, part[Pos.start_col]-1, part[Pos.end_col])
        end
    end
end

return M
