local Pane = require('como.pane')
local Parser = require('como.parser')
local Config = require('como.config')

--- @class como.worker
---
--- Constructor
--- @field new fun(self: como.worker): como.worker
---
--- @field worker_id integer
--- @field last_cmd string
--- @field cwd string|nil
--- @field job_obj vim.SystemObj|nil
--- @field line_queue string[]
--- @field is_processing boolean
--- @field process_exited boolean
--- @field exit_info table|nil
--- @field current_batch_size integer
--- @field MIN_BATCH_SIZE integer
--- @field MAX_BATCH_SIZE integer
--- @field private pane como.pane
--- @field private stdout_buffer string
--- @field private throttle_timer uv.uv_timer_t|nil
--- @field private jmp_to_file_win integer
---
--- @field run_command fun(self: como.worker, cmd: string|nil, cwd: string)
--- @field private check_running fun(self: como.worker): boolean
--- @field private spawn_process fun(self: como.worker, cmd: string, cwd: string)
--- @field private on_stdout fun(self: como.worker, err: string, data: string)
--- @field private process_queue fun(self: como.worker)
--- @field terminate_process fun(self: como.worker)
---
--- Open buffer, if not exist, tell pane to create one
--- @field open_buffer fun(self: como.worker)
---
--- Toggle buffer, if not exist, tell pane to create one
--- @field toggle_buffer fun(self: como.worker)
---
--- @field jump_to_file fun(self: como.worker)
--- @field private open_file_and_set_cursor fun(self: como.worker, path: string, row: integer, col: integer|nil)
local Worker = {}
Worker.__index = Worker

--- @type table<integer, como.worker>
Worker._worker_list = {}

--- @type integer
Worker._next_worker_id = 1

--- @param worker_obj como.worker
--- @return integer
Worker._register_worker = function(worker_obj)
    local id = Worker._next_worker_id
    Worker._worker_list[id] = worker_obj
    Worker._next_worker_id = Worker._next_worker_id + 1
    return id
end

--- @param worker_id integer
Worker._unregister_worker = function(worker_id)
    Worker._worker_list[worker_id] = nil
    Worker.throttle_timer:close()
end

--- Determine which worker (buffer) to use, like emacs
--- @return como.worker|nil, string
Worker.get_target_worker = function()
    -- Default CWD
    local current_buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(current_buf)
    local resolved_cwd = vim.fn.getcwd()
    local dir = vim.fn.fnamemodify(buf_name, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then
        resolved_cwd = dir
    end

    -- User focus in one of the como buffer
    for _, worker in pairs(Worker._worker_list) do
        if worker.pane.buf == current_buf then
            -- print("in como buffer")
            return worker, worker.cwd
        end
    end

    -- Or user has opened a como buffer, but not in one of the windows (buffer not displaying)
    for _, worker in pairs(Worker._worker_list) do
        local worker_buf_name = vim.api.nvim_buf_get_name(worker.pane.buf)
        if worker_buf_name:match(Config.default_buf_name:gsub("([^%w])", "%%%1") .. "$") then
            -- print("Use default")
            return worker, resolved_cwd
        end
    end

    -- No como buffer has been created by user
    -- print("Default como buffer not found, create one")
    return nil, resolved_cwd
end


function Worker:new()
    local obj = setmetatable({}, self)
    obj.worker_id = self._register_worker(obj)
    obj.last_cmd = nil
    obj.cwd = nil
    obj.job_obj = nil
    obj.line_queue = {}
    obj.is_processing = false
    obj.process_exited = false
    obj.exit_info = nil
    obj.current_batch_size = 1
    obj.MIN_BATCH_SIZE = 32
    obj.MAX_BATCH_SIZE = 32
    obj.pane = Pane:new()
    obj.stdout_buffer = ""
    obj.throttle_timer = vim.uv.new_timer()
    obj.killed = false
    return obj
end

function Worker:check_running()
    -- Ask to terminate if last job is still running
    if self.job_obj then
        vim.notify("[como.nvim] A compilation process is running; kill it first", vim.log.levels.WARN)
        return true
        -- vim.ui.input(
        --     { prompt = "A compilation process is running; kill it? (yes or no) "},
        --     function(reply)
        --         if reply == nil or reply == '' then
        --             print("Please answer yes or no.")
        --             return
        --         elseif reply == "yes" then
        --             self:terminate_process()
        --             user_choose_terminate = true
        --             return
        --         end
        --     end
        -- )
    end
    return false
end

function Worker:run_command(cmd, cwd)
    if self:check_running() then
        return
    end

    if cmd == nil then
        if self.last_cmd == nil then
            vim.notify("[como.nvim]: No last command, compile first", vim.log.levels.WARN)
            return
        end --- @cast cmd string

        cmd = self.last_cmd
    end

    if cwd == nil then
        cwd = vim.fn.getcwd()
        vim.notify("[como.nvim]: cwd should not be nil, use default cwd: " .. cwd, vim.log.levels.ERROR)
    end --- @cast cwd string

    self:open_buffer()

    self.pane:clear_lines()
    self.pane:set_begin_msg(cmd)

    if Config.auto_scroll then
        self.pane:set_cursor(4, 0)
    end

    -- Reset
    self.stdout_buffer = ""
    self.line_queue = {}
    self.is_processing = false
    self.process_exited = false
    self.exit_info = {}
    self.killed = false

    self:spawn_process(cmd, cwd)

    self.last_cmd = cmd
    self.cwd = cwd
end

function Worker:spawn_process(cmd, cwd)
    if cmd == nil or cwd == nil then
        vim.notify("[como.nvim] Invalid command or cwd, cmd: " .. cmd .. ",cwd: " .. cwd, vim.log.levels.ERROR)
        return
    end

    local shell = vim.o.shell or "sh"
    local spawn_cmd = { shell, "-c", cmd }

    ---@type boolean, vim.SystemObj|string
    local ok, sysobj_or_err = pcall(vim.system, spawn_cmd, {
        cwd = cwd,
        stdout = function(err, data)
            assert(not err, err)
            self:on_stdout(err, data)
        end,
        stderr = function(err, data)
            assert(not err, err)
            self:on_stdout(err, data)
        end,
        text = true,
    }, function(obj)
            self:on_exit(obj.code, obj.signal)
        end)

    if not ok then ---@cast sysobj_or_err string
        error(('Spawning process with cmd: `%s` failed with error message: %s'):format(table.concat(spawn_cmd, " "), sysobj_or_err))
    end ---@cast sysobj_or_err vim.SystemObj

    self.job_obj = sysobj_or_err
end

function Worker:on_stdout(err, data)
    assert(not err, err)
    if not data then return end

    -- If process got killed, return
    if self.killed then return end

    self.stdout_buffer = self.stdout_buffer .. data

    local start_pos = 1
    while true do
        -- Find new line character from start_pos
        local newline_pos = self.stdout_buffer:find("\n", start_pos, true)
        if not newline_pos then break end

        -- Get the line
        local line = self.stdout_buffer:sub(start_pos, newline_pos - 1)
        table.insert(self.line_queue, line)

        start_pos = newline_pos + 1
    end

    -- Trim the buffer
    self.stdout_buffer = self.stdout_buffer:sub(start_pos)

    if not self.is_processing and #self.line_queue > 0 then
        vim.schedule(function()
            self.is_processing = true
            self:process_queue()
        end)
    end
end

function Worker:on_exit(code, signal)
    self.process_exited = true
    self.job_obj = nil

    -- Write end message to buffer
    local end_msg
    local hl_group, hl_start, hl_end
    local ok_to_clear = false -- clear message or not
    if signal == 9 or signal == 15 then
        end_msg = "Compilation interrupt"
        hl_group = 'Como_hl_error'
        hl_start, hl_end = 12, 21
    elseif code ~= 0 then
        end_msg = string.format("Compilation exited abnormally with code %d", code)
        hl_group = 'Como_hl_error'
        hl_start, hl_end = 19, 29
    else
        end_msg = "Compilation finished"
        hl_group = 'Como_hl_ok'
        hl_start, hl_end = 12, 20
        ok_to_clear = true
    end

    self.exit_info = {
        code = code,
        signa = signal,
        end_msg = end_msg,
        end_time = " at " .. os.date("%a %b %d %X"),
        hl_group = hl_group,
        start_col = hl_start,
        end_col = hl_end,
    }

    if not self.is_processing then
        vim.schedule(function()
            self.is_processing = true
            self:process_queue()
        end)
    end
end

function Worker:process_queue()
    if #self.line_queue == 0 or self.killed then
        if self.process_exited and self.exit_info then
            -- Process exited
            local end_msg = self.exit_info.end_msg
            local end_time = self.exit_info.end_time
            vim.api.nvim_set_option_value('modifiable', true, { buf = self.pane.buf })
            vim.api.nvim_buf_set_lines(self.pane.buf, -1, -1, false, { '', end_msg .. end_time })
            vim.api.nvim_set_option_value('modifiable', false, { buf = self.pane.buf })

            local line_nr = vim.api.nvim_buf_line_count(self.pane.buf)
            local hl_group, start_col, end_col = self.exit_info.hl_group, self.exit_info.start_col, self.exit_info.end_col
            assert(hl_group and start_col and end_col)
            self.pane:set_highlight(hl_group, line_nr - 1, start_col, end_col)

            -- Reset status
            self.process_exited = false
            self.exit_info = nil

            -- Auto scroll to last line
            if Config.auto_scroll then
                self.pane:set_cursor(line_nr, 0)
            end

            -- Print the msg out and clear it after 2.75 seconds
            vim.cmd('echon "' .. end_msg ..'"')
            vim.defer_fn(function() vim.cmd([[echon ' ']]) end, 2750)
        end

        if self.killed then
            self.line_queue = {}
            self.killed = false
        end

        -- Reset status
        self.is_processing = false
        self.current_batch_size = self.MIN_BATCH_SIZE
        return
    end

    -- Determine how many lines to process this iteration
    local lines_to_process = {}
    local limit = math.min(#self.line_queue, self.current_batch_size)

    for _ = 1, limit do
        table.insert(lines_to_process, table.remove(self.line_queue, 1))
    end

    -- Update UI
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.pane.buf })

    local line_nr = self.pane:get_line_count()
    local hl_group, start_col, end_col
    for _, line in ipairs(lines_to_process) do
        -- Append line to buffer
        vim.api.nvim_buf_set_lines(self.pane.buf, -1, -1, false, {line})

        -- Parse line and add highlight
        local parsed_result = Parser.parse_line(line)
        if parsed_result then
            hl_group, start_col, end_col = Parser.highlight_logic(parsed_result)
            assert(hl_group and start_col and end_col)
            self.pane:set_highlight(hl_group, line_nr, start_col, end_col)
        end
        line_nr = line_nr + 1
    end

    vim.api.nvim_set_option_value('modifiable', false, { buf = self.pane.buf })

    -- Auto scroll to last line if buf is displaying
    if Config.auto_scroll and self.pane:buf_is_displaying() then
        if self.pane:get_cursor()[1] == line_nr - #lines_to_process then
            self.pane:set_cursor(line_nr, 0)
        end
    end

    -- Update batch size for next iteration
    self.current_batch_size = math.min(self.current_batch_size * 2, self.MAX_BATCH_SIZE)

    -- Schedule next iteration
    -- If line_queue is not empty, schedule so it can continue process
    -- Else, output the exit messages
    self.throttle_timer:start(50, 0, vim.schedule_wrap(function() self:process_queue() end))
end

function Worker:terminate_process()
    if self.job_obj and not self.job_obj:is_closing() then
        self.job_obj:kill(15)
        self.killed = true
    end
end

function Worker:open_buffer()
    local function on_buffer_close()
        self:terminate_process()
        Worker._unregister_worker(self.worker_id)
    end
    self.pane:buf_open(on_buffer_close)
end

function Worker:toggle_buffer()
    if self.pane:buf_is_displaying() then
        vim.api.nvim_win_hide(self.pane.win)
    else
        self:open_buffer()
    end
end

function Worker:jump_to_file()
    local line = vim.api.nvim_get_current_line()

    local result = Parser.parse_line(line)
    if result == nil then
        return
    end

    -- Variables with default value nil
    local file_path, lnum, col
    -- Loop through the parts in the line, to get the filename, lnum (and probrobly col)
    for _, part in ipairs(result.items) do
        -- Get the filename
        if part.part_name == "filename" then
            file_path = vim.fn.fnamemodify(part.part_data, ":p")
            -- Try to find the file with its full path
            local ok, err = vim.uv.fs_stat(file_path)
            if not ok then --- @cast err string
                vim.notify("Error to find file: " .. file_path .. " with error: " .. err, vim.log.levels.ERROR)
                return
            end
        end

        -- Get the line number
        if part.part_name == "lnum" then
            lnum = tonumber(part.part_data)
        end

        -- Get the column number
        if part.part_name == "col" then
            col = tonumber(part.part_data)
        end
    end

    if file_path ~= nil and lnum ~= nil then
        -- Escape the filename contians modifiers like "\t\n*?[{`$\\%#'\"|!<"
        file_path = vim.fn.fnameescape(file_path)
        self:open_file_and_set_cursor(file_path, lnum, col)
    else
        return
    end
end

-- 1. Check if the file is already open in one of the windows.
-- 2. Focus the window if the file is already open,
--     or use the last window which is opened by this function, if it exist,
--     or Open a new window below and open the file if it's not already open.
-- 3. Set the cursor to a specific (row, col) position.
function Worker:open_file_and_set_cursor(path, row, col)
    local is_file_open = false
    local win_id = nil
    local has_last_win = false

    -- Iterate over all windows to check if the file is already open
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if buf_name == path then
            is_file_open = true
            win_id = win
            break
        elseif win == self.jmp_to_file_win then
            has_last_win = true
            win_id = win
            -- Don't break because the file might have opened in other windows
        end
    end

    if is_file_open and win_id then
        -- Focus the window where the file is open
        vim.api.nvim_set_current_win(win_id)
    elseif has_last_win and win_id then
        -- If last used window exist, use that window
        vim.api.nvim_set_current_win(win_id)
        vim.cmd('edit ' .. path)
    else
        -- Open a new window below and open the file
        vim.cmd('belowright split ' .. path)
    end
    self.jmp_to_file_win = vim.api.nvim_get_current_win()

    -- Set the cursor position
    if col then
        -- let col minus 1 because it's 0-indexed
        vim.api.nvim_win_set_cursor(0, {row, col-1})
    else
        vim.api.nvim_win_set_cursor(0, {row, 0})
    end
end

return Worker
