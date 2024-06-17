local M = {}

local buf_util = require('como.buffer')
local mh = require('como.matcher')
local hl = require('como.highlight')


M.compile = function(cmd)
    local buf = buf_util.buf_open()

    -- Clear the buffer content
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    -- Write beginning message
    local begin_msg = string.format("-*- mode: compilation; default-directory: \"%s\" -*-", vim.uv.cwd())
    local start_time_msg = "Compilation started at " .. os.date("%a %b %d %X")
    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {begin_msg, start_time_msg, '', cmd})
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

    -- line indexing is zero-based
    local line_nr = 3

    -- Define the callback for the job
    local function on_output(_, data, _)
        if data then
            for _, line in ipairs(data) do
                -- Remove empty strings from the data
                if line ~= "" then
                    line_nr = line_nr + 1
                    -- print(string.format("%d: %s", line_nr, line))

                    -- Write lines to buffer
                    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
                    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {line})
                    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

                    local result = mh.parse_line(line)
                    -- print(vim.inspect(result))

                    -- Adding highlight to the text
                    hl.highlight_logic(result, buf, line_nr)

                    -- Check cursor position, and auto scroll the window
                    buf_util.check_and_auto_scroll()
                end
            end
        end
    end

    local function on_exit(_, exit_code, _)
        -- Get the current row
        -- for checking if it needs to scroll to the bottom when compilation finished
        local row = vim.api.nvim_win_get_cursor(buf_util.win)[1]

        -- Write end message to buffer
        if exit_code == 0 then
            local end_msg = "Compilation finished at " .. os.date("%a %b %d %X")
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, {'', end_msg})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
            print("Compilation finished")
        else
            local err_msg = string.format("Compilation exited abnormally with code %d at %s", exit_code, os.date("%a %b %d %X"))
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, {'', err_msg})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
            print("Compilation exited abnormally with code", exit_code)
        end

        -- To scroll to end of the buffer
        local line_count = vim.api.nvim_buf_line_count(buf)
        if row == (line_count - 2) then
            vim.api.nvim_win_set_cursor(0, {line_count, 0})
        end
    end

    -- Start the job (execute the user command)
    M.job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = false,
        stderr_buffered = false,
        on_stdout = on_output,
        on_stderr = on_output,
        on_exit = on_exit
    })
end

M.recompile = function(cmd)
    M.compile(cmd)
end

M.open_como_buffer = function()
    buf_util.buf_open()
end

M.quit_program = function()
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        -- print('Job stopped:', M.job_id)
    -- else
    --     print('Invalid job ID')
    end
end

return M
