local M = {}

M.buf = require('como.buffer')
M.mh = require('como.matcher')
M.hl = require('como.highlight')


M.compile = function(cmd)
    local buf = M.buf.buf_open()

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

    local line_nr = 3
    -- Define the callback for the job
    local function on_output(_, data, _)
        if data then
            for _, line in ipairs(data) do
                -- Remove empty strings from the data
                if line ~= "" then
                    line_nr = line_nr + 1
                    print(string.format("%d: %s", line_nr, line))

                    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
                    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {line})
                    vim.api.nvim_buf_set_option(buf, 'modifiable', false)

                    local result = M.mh.parse_line(line)
                    print(vim.inspect(result))
                    local hl_group
                    if result ~= nil then
                        if result.qtype == "warning" then
                            hl_group = 'Como_hl_warn'
                        elseif result.qtype == "error" then
                            hl_group = 'Como_hl_error'
                        else
                            hl_group = 'Normal'
                        end
                    end
                    if result ~= nil then
                        local rc = result.lnum .. ':' .. result.col
                        local start_col, end_col = string.find(line, rc)
                        -- @function: apply_highlight(bufnr, hl_group, line, start_col, end_col)
                        M.hl.apply_highlight(buf, hl_group, line_nr, tonumber(start_col)-1, tonumber(end_col))
                        M.hl.apply_highlight(buf, 'Como_hl_filename', line_nr, 0, 6)
                        -- print('start: ' .. start_col)
                        -- print('end: ' .. end_col)
                    end
                end
            end
        end
    end

    local function on_exit(_, exit_code, _)
        if exit_code == 0 then
            -- print("TODO: write end message")
            local end_msg = "Compilation finished at " .. os.date("%a %b %d %X")
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, {'', end_msg})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        else
            local err_msg = string.format("Compilation exited abnormally with code %d at %s", exit_code, os.date("%a %b %d %X"))
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, {'', err_msg})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        end
    end

    -- Start the job (execute the user command)
    vim.fn.jobstart(cmd, {
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
    M.buf.buf_open()
end

-- Example usage
-- vim.api.nvim_set_keymap('n', '<leader>r', [[:lua run_command_async('ls -l')<CR>]], { noremap = true, silent = true })

return M
