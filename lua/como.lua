local Config = require('como.config')
local Worker = require('como.worker')
local Parser = require('como.parser')

--- Main Interface
--- @class como
---
--- Public API
---
--- Compile with command
--- @field compile fun(cmd: string|nil)
---
--- Compile with last command
--- @field recompile fun()
---
--- Open como buffer
--- @field open_como_buffer fun()
---
--- Toggle como buffer
--- @field toggle_como_buffer fun()
---
--- Kill (terminate) process
--- @field kill_compilation fun()
---
--- Go to error location
--- @field jump_to_file fun()
---
--- @field setup fun(user_opts: table)
---
--- @field private sub_commands string[]
--- @field private parse_sub_commands fun(opts: table)
local Como = {
    sub_commands = {
        "compile",
        "recompile",
        "open",
        "toggle",
        "kill_compilation",
        "jump_to_file",
    },
}

Como.compile = function(cmd)
    local worker, cwd = Worker.get_target_worker()

    if not worker then
        worker = Worker:new()
    end

    worker:run_command(cmd, cwd)
end

Como.recompile = function()
    Como.compile(nil)
end

Como.open_como_buffer = function()
    local worker = Worker.get_target_worker()
    if worker then
        worker:open_buffer()
    end
end

Como.toggle_como_buffer = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:toggle_buffer()
end

Como.jump_to_file = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:jump_to_file()
end


Como.kill_compilation = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:terminate_process()
end

Como.add_new_matchers = function(new_matchers)
    for matcher_name, data in pairs(new_matchers) do
        Parser.matcher_set[matcher_name] = data
    end
end


Como.parse_sub_commands = function(opts)
    local worker = Worker.get_target_worker()
    --- @type string
    local worker_last_cmd = worker and worker.last_cmd or ''

    if opts.args == Como.sub_commands[1] then
        -- Compile
        local default
        if not Config.show_last_cmd then
            default = ''
        else
            default = worker_last_cmd
        end

        local completion = vim.fn.has("nvim-0.11.0") == 1 and "shellcmdline" or "file"

        vim.ui.input(
            { prompt = "Compile command: ", default = default, completion = completion },
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
        if worker_last_cmd == '' then
            print("No last command, compile first")
            return
        end
        Como.recompile()
    elseif opts.args == Como.sub_commands[3] then
        -- Open como buffer
        Como.open_como_buffer()
    elseif opts.args == Como.sub_commands[4] then
        -- Toggle como buffer
        Como.toggle_como_buffer()
    elseif opts.args == Como.sub_commands[5] then
        -- Kill (terminate) process in buffer
        Como.kill_compilation()
    elseif opts.args == Como.sub_commands[6] then
        -- Go to error location
        Como.jump_to_file()
    end
end

Como.setup = function(user_opts)
    if user_opts then
        local merged = vim.tbl_deep_extend("force", Config, user_opts)
        for k, v in pairs(merged) do
            Config[k] = v
        end
    end

    -- Add custom matchers to the matcher set
    if Config.custom_matchers ~= {} then
        Como.add_new_matchers(Config.custom_matchers)
    end

    -- Callback for setup keymap in como buffer
    if type(Config.set_buf_keymap_cb) ~= "function" then
        vim.notify("[como.nvim] Invalid callback in Como.set_buf_keymap", vim.log.levels.ERROR)
        Config.set_buf_keymap_cb = function()end
    end

    -- Initialize highlight group
    Config.init_hl_group()

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
