-- Maybe add ignore filenames, like when using the wrong command, the /bin/bash is jumpable in the como buffer
local M = {}

local bf = require('como.buffer')
local mh = require('como.matcher')
local hl = require('como.highlight')


M.default_config = {
    show_last_cmd = true,
    auto_scroll = true,
    custom_matchers = {}
}

M.config = {}

M.last_command = ""

M.job_id = nil

M.commands = {
    "compile",
    "recompile",
    "open"
}


M.compile = function(cmd)
    if M.job_id then
        vim.notify("Last command still running!", vim.log.levels.ERROR)
        return
    end

    if not cmd then
        print("Empty input, abort")
        return
    end

    local buf = bf.buf_open()

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

    -- line indexing is zero-based, so 3 means it's line number 4
    local line_nr = 3
    if M.config.auto_scroll then
        vim.api.nvim_win_set_cursor(bf.win, {line_nr+1, 0})
    end

    -- Define the callback for the job
    local function on_output(_, data, _)
        if data then
            for _, line in ipairs(data) do
                -- Remove empty strings from the data
                -- if line ~= "" then
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

                    if M.config.auto_scroll then
                        -- Check cursor position, and auto scroll the window
                        bf.check_and_auto_scroll()
                    end
                -- end
            end
        end
    end

    local function on_exit(_, exit_code, _)
        -- This variable is for auto scroll
        -- Get the current row
        -- for checking if it needs to scroll to the bottom when compilation finished
        local row = vim.api.nvim_win_get_cursor(bf.win)[1]

        -- Write end message to buffer
        if exit_code == 0 then
            local end_msg = "Compilation finished at " .. os.date("%a %b %d %X")
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            -- start with -3 because the output has 2 last empty lines, so insert the end_msg from -3 line
            vim.api.nvim_buf_set_lines(buf, -3, -1, false, {end_msg})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
            -- Print the msg out and clear it after 1.75 seconds
            vim.cmd('echon "Compilation finished"')
            vim.fn.timer_start(1750, function() vim.cmd([[echon ' ']]) end)
        else
            local err_msg = string.format("Compilation exited abnormally with code %d at %s", exit_code, os.date("%a %b %d %X"))
            vim.api.nvim_buf_set_option(buf, 'modifiable', true)
            -- start with -3 because the output has 2 last empty lines, so insert the end_msg from -3 line
            vim.api.nvim_buf_set_lines(buf, -3, -1, false, {err_msg})
            vim.api.nvim_buf_set_option(buf, 'modifiable', false)
            -- Print the msg out and clear it after 1.75 seconds
            vim.cmd('echon "Compilation exited abnormally with code "' .. exit_code)
            vim.fn.timer_start(1750, function() vim.cmd([[echon ' ']]) end)
        end

        if M.config.auto_scroll then
            -- To scroll to end of the buffer
            local line_count = vim.api.nvim_buf_line_count(buf)
            if row == (line_count - 1) then
                vim.api.nvim_win_set_cursor(bf.win, {line_count, 0})
            end
        end

        -- Clear job_id
        M.job_id = nil
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
    bf.buf_open()
end


M.interrupt_program = function()
    -- Ctrl+c to quit program
    -- see como/buffer.lua
    if M.job_id then
        vim.fn.jobstop(M.job_id)
        -- print('Job stopped:', M.job_id)
    -- else
    --     print('Invalid job ID')
    end
end

M.add_new_matchers = function(new_matchers)
    for matcher_name, data in pairs(new_matchers) do
        mh.matcher_set[matcher_name] = data
    end
    -- print(vim.inspect(mh.matcher_set))
end


M.determine_mode = function(opts)
    -- print("'" .. opts.args .. "'")

    -- Compile
    if opts.args == M.commands[1] then
        -- local default = M.config.show_last_cmd and M.last_command or ''
        local default
        if not M.config.show_last_cmd then
            default = ''
        else
            default = M.last_command
        end

        vim.ui.input(
            { prompt = "Compile command: ", default = default, completion = "file"},
            function(cmd)
                if cmd == nil or cmd == '' then
                    print("Empty input, abort")
                    return
                end
                M.compile(cmd)
                M.last_command = cmd
            end
        )
    -- Recompile
    elseif opts.args == M.commands[2] then
        if M.last_command == '' then
            print("No last command, compile first")
            return
        end
        M.recompile(M.last_command)
    -- Open como buffer
    elseif opts.args == M.commands[3] then
        M.open_como_buffer()
    end
end

M.setup = function(user_opts)
    if user_opts then
        M.config = vim.tbl_deep_extend("force", M.default_config, user_opts)
    else
        M.config = M.default_config
    end

    -- Add custom matchers to the matcher set
    if M.config.custom_matchers ~= {} then
        M.add_new_matchers(M.config.custom_matchers)
    end

    hl.init_hl_group()

    vim.api.nvim_create_user_command(
        'Como',
        function(opts)
            M.determine_mode(opts)
        end,
        {
            nargs = 1,
            complete = function()
                -- return completion candidates as a list-like table
                return M.commands
            end,
        }
    )
end

return M
