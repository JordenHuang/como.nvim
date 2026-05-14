local Config = require('como.config')

--- Manage buffer, window, highlight
--- @class (private) como.pane
---
--- @field buf integer|nil
--- @field win integer|nil
--- @field autocmd_id integer|nil
---
--- Constructor
--- @field new fun(self: como.pane): como.pane
---
--- Create a window and attach buffer (create one if not exist) to it
--- @field buf_open fun(self: como.pane, on_close: fun())
---
--- TODO: Not used, provide a set unique name api?
--- @field buf_set_name fun(self: como.pane, name: string)
---
--- Check if the buffer is displaying in one of the windows
--- @field buf_is_displaying fun(self: como.pane): boolean
---
--- Check if the buffer can be reuse
--- @field buf_can_be_reused fun(self: como.pane): boolean
---
--- @field get_cursor fun(self: como.pane): integer[]
--- @field set_cursor fun(self: como.pane, row: integer, col: integer)
--- @field get_line_count fun(self: como.pane): integer
---
--- @field append_lines fun(self: como.pane, lines: string[])
--- @field clear_lines fun(self: como.pane)
--- @field set_begin_msg fun(self: como.pane, cmd: string)
---
--- line_nr is zero-indexed
--- @field set_highlight fun(self: como.pane, hl_group: string, line_nr: integer, start_col: integer, end_col: integer)
---
--- Create buffer, set options
--- @field private buf_create fun(self: como.pane, on_close: fun())
---
--- Delete buffer
--- @field private buf_delete fun(self: como.pane, on_close: fun()) 
local Pane = {}
Pane.__index = Pane

function Pane:new()
    local obj = setmetatable({}, self)
    obj.buf = nil
    obj.win = nil
    obj.autocmd_id = nil
    return obj
end

function Pane:buf_open(on_close)
    -- Create buffer if not valid
    if not self:buf_can_be_reused() then
        if type(on_close) == 'function' then
            self:buf_create(on_close)
        else
            vim.notify("[como.nvim] Type mismatch with `Pane:buf_open`'s on_close parameter", vim.log.levels.ERROR)
            on_close = function() end
            self:buf_create(on_close)
        end
    end

    local win_cmd
    if Config.preferred_win_pos == "top" then
        win_cmd = 'topleft split'
    elseif Config.preferred_win_pos == "left" then
        win_cmd = 'topleft vsplit'
    elseif Config.preferred_win_pos == "right" then
        win_cmd = 'belowright vsplit'
    else
        win_cmd = 'belowright split'
    end

    -- Create window to display buffer
    if not self:buf_is_displaying() then
        vim.api.nvim_command(win_cmd)
        self.win = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_buf(self.win, self.buf)
    end
end

function Pane:buf_set_name(name)
    vim.api.nvim_buf_set_name(self.buf, name)
end

function Pane:buf_is_displaying()
    if not self.buf then return false end

    local win_ids = vim.fn.win_findbuf(self.buf)
    return #win_ids > 0
end

function Pane:buf_can_be_reused()
    -- Check if buffer is created
    if not self.buf then return false end

    -- Check if buffer is valid
    -- If not, buf is wiped out
    if not vim.api.nvim_buf_is_valid(self.buf) then return false end

    -- Check if buffer is loaded
    -- If not, buf is valid but unloaded
    if not vim.api.nvim_buf_is_loaded(self.buf) then return false end

    return true
end

function Pane:get_cursor()
    return vim.api.nvim_win_get_cursor(self.win)
end

function Pane:set_cursor(row, col)
    vim.api.nvim_win_set_cursor(self.win, {row, col})
end

function Pane:get_line_count()
    return vim.api.nvim_buf_line_count(self.buf)
end


function Pane:append_lines(lines)
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })
    vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, lines)
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

function Pane:clear_lines()
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {})
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

function Pane:set_begin_msg(cmd)
    -- Write beginning message
    local begin_msg = string.format("-*- mode: compilation; default-directory: \"%s\" -*-", vim.uv.cwd())
    local start_time_msg = "Compilation started at " .. os.date("%a %b %d %X")
    vim.api.nvim_set_option_value('modifiable', true, { buf = self.buf })
    vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, {begin_msg, start_time_msg, '', cmd})
    vim.api.nvim_set_option_value('modifiable', false, { buf = self.buf })
end

function Pane:set_highlight(hl_group, line_nr, start_col, end_col)
    local hl_id = Config.hl_id
    vim.api.nvim_buf_add_highlight(self.buf, hl_id, hl_group, line_nr, start_col, end_col)
end

function Pane:buf_create(on_close)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(true, false)
    -- Set options
    vim.api.nvim_buf_set_name(buf, Config.default_buf_name)
    vim.api.nvim_set_option_value('buftype'   , 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('modifiable',   false , { buf = buf })
    vim.api.nvim_set_option_value('swapfile'  ,   false , { buf = buf })

    if type(Config.set_buf_keymap_cb) == "function" then
        Config.set_buf_keymap_cb(buf)
    end

    self.buf = buf

    -- Create autocmd
    self.autocmd_id = vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, { --, "BufUnload"
        buffer = self.buf,
        callback = function()
            -- On buffer close
            if on_close then on_close() vim.notify("[como.nvim] Buffer killed", vim.log.levels.WARN) end
            self.buf = nil
            self.autocmd_id = nil
        end,
        once = true,
    })

    -- TODO: Check this
    vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
        buffer = self.buf,
        callback = function()
            self.win = vim.api.nvim_get_current_win()
        end,
    })
end

function Pane:buf_delete()
    if not self.buf then return end

    if self.autocmd_id then
        pcall(vim.api.nvim_del_autocmd, self.autocmd_id)
        self.autocmd_id = nil
    end

    if vim.api.nvim_buf_is_valid(self.buf) then
        vim.api.nvim_buf_delete(self.buf, { force = true })
    end

    self.buf = nil
end

return Pane
