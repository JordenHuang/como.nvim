local buf_util = require('como.buffer')
local M = {}


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


    -- Define the callback for the job
    local function on_output(_, data, _)
        if data then
            for _, line in ipairs(data) do
                -- Remove empty strings from the data
                if line ~= "" then
                    vim.api.nvim_buf_set_option(buf, 'modifiable', true)
                    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {line})
                    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
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
    buf_util.buf_open()
end

-- Example usage
-- vim.api.nvim_set_keymap('n', '<leader>r', [[:lua run_command_async('ls -l')<CR>]], { noremap = true, silent = true })

return M
