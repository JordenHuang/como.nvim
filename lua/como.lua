local M = {}

local bf = require('como.buffer')
local mh = require('como.matcher')
local hl = require('como.highlight')


M.default_config = {
    show_last_cmd = true,
    auto_scroll = true,
    preferred_win_pos = "bottom",
    custom_matchers = {}
}

M.config = {}

M.last_command = ""

M.pid = nil

M.commands = {
    "compile",
    "recompile",
    "open",
    "toggle"
}

M.compile = function(cmd)
    if M.pid then
        vim.notify("Last command still running!", vim.log.levels.ERROR)
        return
    end

    if not cmd then
        print("Empty input, abort")
        return
    end

    local buf = bf.buf_open(M.config.preferred_win_pos)

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
    local function on_output(data)
        if data then
            local win_valid = bf.if_buf_present(bf.buf)
            local s = vim.split(data, '\n', {plain=true, trimempty = true})
            for _, line in ipairs(s) do
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

                if M.config.auto_scroll and win_valid then
                    -- Check cursor position, and auto scroll the window
                    bf.check_and_auto_scroll()
                end
            end
        end
    end

    local function on_exit(exit_code, signal)
        -- Auto-scroll feature:
        -- Get the current row
        -- to check if it needs to scroll to the bottom when compilation finished
        local win_valid = vim.api.nvim_win_is_valid(bf.win)
        local row
        if win_valid then
            row = vim.api.nvim_win_get_cursor(bf.win)[1]
        else
            vim.notify("Compilation ended, result is in the compilation buffer / ", vim.log.levels.WARN)
        end

        -- Write end message to buffer
        local end_msg
        local hl_group, hl_start, hl_end
        local ok_to_clear = false
        if signal == 9 then
            end_msg = "Compilation interrupted"
            hl_group = 'Como_hl_error'
            hl_start, hl_end = 12, 23
        elseif exit_code ~= 0 then
            end_msg = string.format("Compilation exited abnormally with code %d", exit_code)
            hl_group = 'Como_hl_error'
            hl_start, hl_end = 19, 29
        else
            end_msg = "Compilation finished"
            hl_group = 'Como_hl_ok'
            hl_start, hl_end = 12, 20
            ok_to_clear = true
        end
        -- Write end_msg to buffer
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, {'', end_msg .. " at " .. os.date("%a %b %d %X")})
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
        hl.apply_highlight(buf, hl_group, vim.api.nvim_buf_line_count(buf)-1, hl_start, hl_end)

        -- Print the msg out and clear it after 2.75 seconds
        vim.cmd('echon "' .. end_msg ..'"')
        if ok_to_clear and win_valid then vim.fn.timer_start(2750, function() vim.cmd([[echon ' ']]) end) end

        -- To scroll to end of the buffer
        if M.config.auto_scroll and win_valid then
            local line_count = vim.api.nvim_buf_line_count(buf)
            if row and row == (line_count - 2) then
                vim.api.nvim_win_set_cursor(bf.win, {line_count, 0})
            end
        end

        -- Clear pid
        M.pid = nil
    end

    -- Start the job (execute the user command)
    local handle
    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    handle, M.pid = vim.uv.spawn(
        'sh',
        {
            args = { '-c', cmd },
            stdio = { nil, stdout, stderr }
        },
        function(exit_code, signal)
            stdout:read_stop()
            stderr:read_stop()
            stdout:close()
            stderr:close()
            handle:close()
            vim.schedule(function()
                on_exit(exit_code, signal)
            end)
        end
    )

    stdout:read_start(function(err, data)
        assert(not err, err)
        vim.schedule(function()
            on_output(data)
        end)
    end)

    stderr:read_start(function(err, data)
        assert(not err, err)
        vim.schedule(function()
            on_output(data)
        end)
    end)
end

M.recompile = function(cmd)
    M.compile(cmd)
end

M.open_como_buffer = function()
    bf.buf_open(M.config.preferred_win_pos)
end

M.toggle_como_buffer = function()
    local buf_present = bf.if_buf_present(bf.buf)
    if buf_present then
        vim.api.nvim_win_hide(bf.win)
    else
        bf.buf_open(M.config.preferred_win_pos)
    end
end


M.interrupt_program = function()
    -- Ctrl+c to quit program
    -- see como/buffer.lua
    if M.pid then
        -- Kill child process first
        local child_process = vim.api.nvim_get_proc_children(M.pid)
        for i, v in ipairs(child_process) do
            vim.uv.kill(v, 9)
        end
        -- Kill process
        vim.uv.kill(M.pid, 9)
        M.pid = nil
    end
end

M.add_new_matchers = function(new_matchers)
    for matcher_name, data in pairs(new_matchers) do
        mh.matcher_set[matcher_name] = data
    end
    -- print(vim.inspect(mh.matcher_set))
end


M.determine_mode = function(opts)
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
    elseif opts.args == M.commands[4] then
        M.toggle_como_buffer()
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
