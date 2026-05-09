local Pane = require("como.pane")
local Dispatcher = require("como.dispatcher")

--- Get command, send to server via Dispatcher, display result
--- @class (private) como.client
---
--- User config
--- @field config table
---
--- @field id string
--- @field last_command string|nil
--- @field cwd string|nil
--- @field pane como.pane
---
--- Constructor
--- @field new fun(self: como.client, config: table): como.client
---
--- Handle response from Dispatcher
--- @field handle_response fun(self: como.client, response: table)
---
--- Open buffer, if not exist, tell pane to create one
--- @field open_buffer fun(self: como.client)
---
--- Toggle buffer, if not exist, tell pane to create one
--- @field toggle_buffer fun(self: como.client)
---
--- Send cmd to server
--- @field run_command fun(self: como.client, cmd: string|nil, cwd: string)
local Client = {}
Client.__index = Client

function Client:new(config)
    local obj = setmetatable({}, self)
    obj.config = config or {}
    obj.id = Dispatcher.register_client(obj)
    obj.last_command = nil
    obj.cwd = nil
    obj.pane = Pane:new()
    return obj
end

-- TODO: Output
function Client:handle_response(response)
    if response then
        -- TODO: Auto scrolling
        local win_valid = self.pane:buf_is_displaying()
        -- local s = vim.split(data, '\n', { plain = true, trimempty = false })
        -- for _, line in ipairs(s) do
        local lines = response.lines
            -- line_nr = line_nr + 1
            -- print(string.format("%d: %s", line_nr, line))

            -- Write lines to buffer
            vim.api.nvim_set_option_value('modifiable', true, { buf = self.pane.buf })
            vim.api.nvim_buf_set_lines(self.pane.buf, -1, -1, false, lines)
            vim.api.nvim_set_option_value('modifiable', false, { buf = self.pane.buf })

            -- local result = mh.parse_line(line)
            -- print(vim.inspect(result))

            -- Adding highlight to the text
            -- hl.highlight_logic(result, buf, line_nr)

            if self.config.auto_scroll and win_valid then
                -- Check cursor position, and auto scroll the window
                self.pane:auto_scroll()
            end
        -- end
    end
end

function Client:open_buffer()
    local function on_buffer_close()
        Dispatcher.unregister_client(self.id)
    end
    -- self.pane:buf_open(self.config.preferred_win_pos, on_buffer_close)
    self.pane:buf_open(self.config, on_buffer_close)
end

function Client:toggle_buffer()
    if self.pane:buf_is_displaying() then
        vim.api.nvim_win_hide(self.pane.win)
    else
        self:open_buffer()
    end
end

function Client:run_command(cmd, cwd)
    -- Open buffer to display compilation result
    self:open_buffer()

    self.last_command = cmd or self.last_command
    if not self.last_command then
        vim.notify("[como.nvim]: No last command, compile first", vim.log.levels.WARN)
        return
    end --- @cast cmd string

    print("cmd", cmd)

    -- Send command via Dispatcher
    Dispatcher.send_request(self.id, "run", cmd, cwd)
end

function Client:kill_command()
    -- TODO:
end

return Client
