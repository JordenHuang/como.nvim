-- TODO: set auto scroll when at the last line, else don't scroll
local M = {}

M.buf = false

M.if_buf_is_valid = function(buf_to_check)
    -- If the buffer is never created
    if buf_to_check == false then
        return false
    end

    -- Check if the previous buffer exists
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in pairs(bufs) do
        -- print(buf)
        if buf_to_check == buf then
            return true
        end
    end
    return false
end

-- Check if the buffer is displaying in one of the windows
M.if_buf_present = function(buf)
    if buf == false then
        return false
    end
    local windows = vim.api.nvim_list_wins()
    for _, win in pairs(windows) do
        if vim.api.nvim_win_get_buf(win) == buf then
            return true
        end
    end
    return false
end

M.create_buf = function()
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, false)
    -- Set some options for the buffer
    vim.api.nvim_buf_set_name(buf, "Compilation mode")
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nowrite')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    -- vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ":q<CR>", {silent=true, noremap=true, desc="close como window"})

    M.buf = buf
    return buf
end

M.buf_open = function()
    local buf = M.buf
    local buf_valid = M.if_buf_is_valid(buf)
    local buf_present = M.if_buf_present(buf)

    -- Create a buffer for the output
    if not buf_valid then
        buf = M.create_buf()
    end

    -- Create a window to display the buffer
    if not buf_present then
        vim.api.nvim_command('topleft split')
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
    end
    return buf
end

return M
