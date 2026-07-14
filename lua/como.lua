local Config = require('como.config')
local Worker = require('como.worker')
local Parser = require('como.parser')

--- Main Interface
--- @class como
---
--- Semver
--- @field version fun(): table
local Como = {
    version = function()
        return {
            major = 0,
            minor = 2,
            patch = 0,
        }
    end,
}

--- Compile with command
--- @param cmd string|nil
Como.compile = function(cmd)
    local worker, cwd = Worker.get_target_worker()

    if not worker then
        worker = Worker:new()
    end

    worker:run_command(cmd, cwd)
end

--- Compile with last command
Como.recompile = function()
    Como.compile(nil)
end

--- Open como buffer
Como.open_como_buffer = function()
    local worker = Worker.get_target_worker()
    if worker then
        worker:open_buffer()
    end
end

--- Toggle como buffer
Como.toggle_como_buffer = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:toggle_buffer()
end

--- Kill (terminate) process
Como.kill_compilation = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:terminate_process()
end

--- Go to error location in file
Como.jump_to_file = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:jump_to_file()
end

--- Go to first error location
Como.first_error = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:first_error()
end

--- Go to last error location
Como.last_error = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:last_error()
end

--- Go to next error location
Como.next_error = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:next_error()
end

--- Go to previous error location
Como.prev_error = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:prev_error()
end

--- Set unique name to como buffer, if you are using many
Como.set_unique_name = function()
    local worker = Worker.get_target_worker()
    if not worker then return end

    worker:set_unique_name()
end

--- Add new matcher to parser
--- @param new_matchers table
Como.add_new_matchers = function(new_matchers)
    for matcher_name, data in pairs(new_matchers) do
        Parser.matcher_set[matcher_name] = data
    end
end


--- private
--- @type table<string, fun()>
Como.sub_command_handlers = {
    compile = function()
        local worker = Worker.get_target_worker()
        local worker_last_cmd = worker and worker.last_cmd or ''
        local default = Config.show_last_cmd and worker_last_cmd or ''
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
    end,
    recompile = function()
        local worker = Worker.get_target_worker()
        local worker_last_cmd = worker and worker.last_cmd or ''
        if worker_last_cmd == '' then
            print("No last command, compile first")
            return
        end
        Como.recompile()
    end,

    open = function() Como.open_como_buffer() end,
    toggle = function() Como.toggle_como_buffer() end,
    kill_compilation = function() Como.kill_compilation() end,
    jump_to_file = function() Como.jump_to_file() end,
    first_error = function() Como.first_error() end,
    last_error = function() Como.last_error() end,
    next_error = function() Como.next_error() end,
    prev_error = function() Como.prev_error() end,
    set_unique_name = function() Como.set_unique_name() end,
}

--- private
--- @param opts table
Como.parse_sub_commands = function(opts)
    local cmd_name = opts.args
    local handler = Como.sub_command_handlers[cmd_name]

    if handler then
        handler()
    else
        vim.notify("[como.nvim] Unknown subcommand: " .. cmd_name, vim.log.levels.ERROR)
    end
end

--- @param user_opts table
Como.setup = function(user_opts)
    if user_opts then
        local merged = vim.tbl_deep_extend("force", Config, user_opts)
        for k, v in pairs(merged) do
            Config[k] = v
        end
    end

    -- Add custom matchers to the matcher set
    if Config.custom_matchers ~= {} then
        -- TODO: Verify custom_matchers table
        Como.add_new_matchers(Config.custom_matchers)
    end

    -- Callback for setup keymap in como buffer
    if type(Config.set_buf_keymap_cb) ~= "function" then
        vim.notify(
            "[como.nvim] Invalid type of `set_buf_keymap_cb`: Should be a function.",
            vim.log.levels.ERROR
        )
    end

    -- Initialize highlight group
    Config.init_hl_group()
end

return Como
