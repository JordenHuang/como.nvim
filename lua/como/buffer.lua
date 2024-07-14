local M = {}

local mh = require('como.matcher')
local uv = vim.uv or vim.loop
local Pos = mh.Pos


M.buf = false
M.win = false

M.if_buf_is_valid = function(buf_to_check)
    -- If the buffer is never created
    if buf_to_check == false then
        return false
    end

    local flag = false
    -- Check if the previous buffer in buffer-list
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in pairs(bufs) do
        -- print(buf)
        if buf_to_check == buf then
            flag = true
        end
    end

    -- if not flag, means the buffer is not in buffer-list
    if flag then
        -- Check buffer is valid and loaded
        local b = vim.api.nvim_buf_is_loaded(buf_to_check)
        -- print("loaded: ", b)
        if b == true then
            return true
        else
            vim.api.nvim_buf_delete(buf_to_check, {})
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
    vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'buflisted', false)

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ":q<CR>", {silent=true, noremap=true, desc="close como window"})
    -- Pressing r to recompile
    vim.api.nvim_buf_set_keymap(buf, 'n', 'r', ":Como recompile<CR>", {silent=true, noremap=true, desc="como recompile"})
    -- Jump to file when hit enter
    vim.api.nvim_buf_set_keymap(buf, 'n', "<CR>", ":lua require('como.buffer').jump_to_file()<CR>", {silent=true, noremap=true, desc="como jump to file"})
    -- Quit program when hit Ctrl+c
    vim.api.nvim_buf_set_keymap(buf, 'n', "<C-c>", ":lua require('como').interrupt_program()<CR>", {silent=true, noremap=true, desc="como quit program"})

    M.buf = buf
    return buf
end

local function win_open_cmd(preferred_win_pos)
    local cmd = ''
    if preferred_win_pos == "top" then
        cmd = 'topleft split'
    elseif preferred_win_pos == "left" then
        cmd = 'topleft vsplit'
    elseif preferred_win_pos == "right" then
        cmd = 'belowright vsplit'
    else
        if preferred_win_pos ~= "bottom" then
            print("[como.nvim] Invalid option for `preferred_win_pos`, use default value")
        end
        cmd = 'belowright split'
    end
    return cmd
end

M.buf_open = function(preferred_win_pos)
    local buf = M.buf
    local buf_valid = M.if_buf_is_valid(buf)
    local buf_present = M.if_buf_present(buf)
    local cmd = win_open_cmd(preferred_win_pos)

    -- Create a buffer for the output
    if not buf_valid then
        buf = M.create_buf()
    end

    -- Create a window to display the buffer
    if not buf_present then
        vim.api.nvim_command(cmd)
        local win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(win, buf)
        M.win = win
    end

    return buf
end

-- Jump to the file
M.jump_to_file = function()
    local line = vim.api.nvim_get_current_line()
    -- print('current line: ' .. line)

    local result = mh.parse_line(line)
    if result == nil then
        return nil
    end

    -- Variables with default value nil
    local file_path, lnum, col
    -- Loop through the parts in the line, to get the filename, lnum (and probrobly col)
    for _, part in ipairs(result.parts) do
        -- Get the filename
        if part[Pos.name] == "filename" then
            -- print("The 'only' filename: ")
            -- print(vim.fn.fnamemodify(part[Pos.data], ":t"))

            file_path = vim.fn.fnamemodify(part[Pos.data], ":p")
            -- Try to find the file with its full path
            local ok, err = uv.fs_stat(file_path)
            if not ok then
                vim.notify("Error to find file:", vim.log.levels.ERROR)
                vim.notify(err, vim.log.levels.ERROR)
                return nil
                -- else
                --     print(file_path)
                --     print("no problem")
            end
        end

        -- Get the line number
        if part[Pos.name] == "lnum" then
            lnum = tonumber(part[Pos.data])
        end

        -- Get the column number
        if part[Pos.name] == "col" then
            col = tonumber(part[Pos.data])
        end
    end

    if file_path ~= nil and lnum ~= nil then
        M.open_file_and_set_cursor(file_path, lnum, col)
    else
        return nil
    end
end


-- By Chat-GPT
--[[
1. Check if the file is already open in one of the windows.
2. Focus the window if the file is already open,
    or use the last window which is opened by this function, if it exist,
    or Open a new window below and open the file if it's not already open.
3. Set the cursor to a specific (row, col) position.
--]]
M.open_file_and_set_cursor = function(file_path, row, col)
    local is_file_open = false
    local win_id = nil
    local has_last_win = false

    -- Iterate over all windows to check if the file is already open
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name == file_path then
            is_file_open = true
            win_id = win
            break
        elseif win == M.jmp_to_file_win then
            has_last_win = true
            win_id = win
            -- Don't break because the file might have opened in other windows
        end
    end

    if is_file_open then
        -- Focus the window where the file is open
        vim.api.nvim_set_current_win(win_id)
    elseif has_last_win then
        -- If last used window exist, use that window
        vim.api.nvim_set_current_win(win_id)
        vim.cmd('edit ' .. file_path)
    else
        -- Open a new window below and open the file
        vim.cmd('belowright split ' .. file_path)
    end
    M.jmp_to_file_win = vim.api.nvim_get_current_win()

    -- Set the cursor position
    if col then
        -- let col minus 1 because it's 0-indexed
        vim.api.nvim_win_set_cursor(0, {row, col-1})
    else
        vim.api.nvim_win_set_cursor(0, {row, 0})
    end
end


-- Auto scroll down
M.check_and_auto_scroll = function()
    -- if vim.api.nvim_get_current_win() ~= M.win then
    --     -- print('not same win')
    --     return
    -- end

    -- Get cursor's row position and number of lines in the compilation buffer
    local row = vim.api.nvim_win_get_cursor(M.win)[1]

    local line_count = vim.api.nvim_buf_line_count(M.buf)
    if row == (line_count-1) then
        vim.api.nvim_win_set_cursor(M.win, {line_count, 0})
    end
end

return M
