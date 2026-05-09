local Dispatcher = require('como.dispatcher')
local Client = require('como.client')

--- @class como
---
--- Public API
--- @field compile fun(cmd: string|nil)
--- @field recompile fun()
--- @field open_como_win fun()
--- @field toggle_como_win fun()
--- @field kill_compilation fun()
--- @field setup fun(user_opts: table)
---
--- @field private config table
--- @field private default_config table
--- @field private sub_commands string[]
--- @field private parse_sub_commands fun(opts: table) -- TODO:
local Como = {
    clients = {},
    config = {},
    default_config = {
        show_last_cmd = true,
        auto_scroll = true,
        preferred_win_pos = "bottom",
        custom_matchers = {},
        default_buf_name = "*compilation*",
    },
    sub_commands = {
        "compile",
        "recompile",
        "open",
        "toggle"
    },
}

Como.compile = function(cmd)
    -- TODO: If last job is still running, ask to terminate it
    local client, cwd = Dispatcher.get_target_client()

    if not client then
        client = Client:new(Como.config)
    end

    client:run_command(cmd, cwd)
end

Como.recompile = function()
    Como.compile(nil)
end

Como.open_como_buffer = function()
    local client = Dispatcher.get_target_client()
    if client then
        client:open_buffer()
    end
end

Como.toggle_como_buffer = function()
    local client = Dispatcher.get_target_client()
    if not client then return end

    client:toggle_buffer()
end


Como.interrupt_program = function()
    -- -- Ctrl+c to quit program
    -- -- see como/buffer.lua
    -- if M.pid then
    --     -- Kill child process first
    --     local child_process = vim.api.nvim_get_proc_children(M.pid)
    --     for i, v in ipairs(child_process) do
    --         vim.uv.kill(v, 9)
    --     end
    --     -- Kill process
    --     vim.uv.kill(M.pid, 9)
    --     M.pid = nil
    -- end
end

Como.add_new_matchers = function(new_matchers)
    -- for matcher_name, data in pairs(new_matchers) do
    --     mh.matcher_set[matcher_name] = data
    -- end
    -- -- print(vim.inspect(mh.matcher_set))
end


Como.parse_sub_commands = function(opts)
    local client = Dispatcher.get_target_client()
    --- @type string
    local client_last_cmd = client and client.last_command or ''

    if opts.args == Como.sub_commands[1] then
        -- Compile
        local default
        if not Como.config.show_last_cmd then
            default = ''
        else
            default = client_last_cmd
        end

        vim.ui.input(
            { prompt = "Compile command: ", default = default, completion = "file"},
            function(cmd)
                if cmd == nil or cmd == '' then
                    print("Empty input, abort")
                    return
                end
                Como.compile(cmd)
            end
        )
    elseif opts.args == Como.sub_commands[2] then
        -- Recompile
        if client_last_cmd == '' then
            print("No last command, compile first")
            return
        end
        Como.recompile()
    elseif opts.args == Como.sub_commands[3] then
        -- Open como buffer
        Como.open_como_buffer()
    elseif opts.args == Como.sub_commands[4] then
        Como.toggle_como_buffer()
    end
end

Como.setup = function(user_opts)
    if user_opts then
        Como.config = vim.tbl_deep_extend("force", Como.default_config, user_opts)
    else
        Como.config = Como.default_config
    end

    -- Add custom matchers to the matcher set
    if Como.config.custom_matchers ~= {} then
        Como.add_new_matchers(Como.config.custom_matchers)
    end

    -- hl.init_hl_group()

    Como.config.default_buf_name = Como.config.default_buf_name:gsub("([^%w])", "%%%1")

    Dispatcher.init(Como.config.default_buf_name)

    vim.api.nvim_create_user_command(
        'Como',
        function(opts)
            Como.parse_sub_commands(opts)
        end,
        {
            nargs = 1,
            complete = function()
                -- return completion candidates as a list-like table
                return Como.sub_commands
            end,
        }
    )
end

return Como
