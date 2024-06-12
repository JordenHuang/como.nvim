local core = require('como.core')

local M = {}

M.default_config = {
    show_last_cmd = true
}

M.last_command = ""

M.commands = {
    "compile",
    "recompile",
    "open"
}

M.determine_mode = function(opts)
    -- print("'" .. opts.args .. "'")

    -- Compile
    if opts.args == M.commands[1] then
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
                core.compile(cmd)
                M.last_command = cmd
            end
        )
    -- Recompile
    elseif opts.args == M.commands[2] then
        if M.last_command == '' then
            print("No last command, compile first")
            return
        end
        core.recompile(M.last_command)
    -- Open como buffer
    elseif opts.args == M.commands[3] then
        core.open_como_buffer()
    end
end

M.setup = function(user_opts)
    if user_opts then
        M.config = vim.tbl_deep_extend("force", M.default_config, user_opts)
    else
        M.config = M.default_config
    end

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
