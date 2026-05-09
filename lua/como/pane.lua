--- Manage buffer, window, highlight, jump to file
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
--- @field buf_open fun(self: como.pane, opt: table, on_close: fun())
---
--- @field buf_set_name fun(self: como.pane, name: string)
---
--- Check if the buffer is displaying in one of the windows
--- @field buf_is_displaying fun(self: como.pane): boolean
---
--- Check if the buffer can be reuse
--- @field buf_can_be_reused fun(self: como.pane): boolean
---
--- Jump to the file
--- @field jump_to_file fun(self: como.pane)
---
--- @field open_file_and_set_cursor fun(self: como.pane)
--- @field auto_scroll fun(self: como.pane)
---
--- Create buffer, set options
--- @field private buf_create fun(self: como.pane, name: string, on_close: fun())
---
--- Delete buffer
--- @field private buf_delete fun(self: como.pane, on_close: fun())
local Pane = {}
Pane.__index = Pane

--- @enum Pane.preferred_win_pos
Pane.preferred_win_pos = {
    TOP    = "top",
    LEFT   = "left",
    RIGHT  = "right",
    BOTTOM = "bottom",
}

function Pane:new()
    local obj = setmetatable({}, self)
    obj.buf = nil
    obj.win = nil
    obj.autocmd_id = nil
    return obj
end

--- Convert Pane.preferred_win_pos to window command
--- @param preferred_win_pos Pane.preferred_win_pos
--- @return string
local function win_open_cmd(preferred_win_pos)
    if preferred_win_pos == Pane.preferred_win_pos.TOP then
        return 'topleft split'
    elseif preferred_win_pos == Pane.preferred_win_pos.LEFT then
        return 'topleft vsplit'
    elseif preferred_win_pos == Pane.preferred_win_pos.RIGHT then
        return 'belowright vsplit'
    end

    if preferred_win_pos ~= Pane.preferred_win_pos.BOTTOM then
        vim.notify("[como.nvim] Invalid option for `preferred_win_pos`, use default value", vim.log.levels.WARN)
    end
    return 'belowright split'
end

function Pane:buf_open(opt, on_close)
    -- Create buffer if not valid
    if not self:buf_can_be_reused() then
        if type(on_close) == 'function' then
            self:buf_create(opt.default_buf_name, on_close)
        else
            vim.notify("[como.nvim] Type mismatch with `Pane:buf_open`'s on_close parameter", vim.log.levels.ERROR)
            on_close = function() end
            self:buf_create(opt.default_buf_name, on_close)
        end
    end

    -- Create window to display buffer
    if not self:buf_is_displaying() then
        vim.api.nvim_command(win_open_cmd(opt.preferred_win_pos))
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

function Pane:jump_to_file()
end

function Pane:open_file_and_set_cursor()
end

--- Auto scroll down
function Pane:auto_scroll()
    -- Get cursor's row position and number of lines in the compilation buffer
    local row = vim.api.nvim_win_get_cursor(self.win)[1]

    local line_count = vim.api.nvim_buf_line_count(self.buf)
    if row == (line_count-1) then
        vim.api.nvim_win_set_cursor(self.win, {line_count, 0})
    end
end


function Pane:buf_create(name, on_close)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(true, false)
    -- Set options
    vim.api.nvim_buf_set_name(buf, name)
    vim.api.nvim_set_option_value('buftype'   , 'nofile', { buf = buf })
    vim.api.nvim_set_option_value('modifiable',   false , { buf = buf })
    vim.api.nvim_set_option_value('swapfile'  ,   false , { buf = buf })

    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ":q<CR>", {silent=true, noremap=true, desc="close como window"})
    -- Pressing r to recompile
    vim.api.nvim_buf_set_keymap(buf, 'n', 'r', ":Como recompile<CR>", {silent=true, noremap=true, desc="como recompile"})
    -- Jump to file when hit enter
    vim.api.nvim_buf_set_keymap(buf, 'n', "<CR>", ":lua require('como.buffer').jump_to_file()<CR>", {silent=true, noremap=true, desc="como jump to file"})
    -- Quit program when hit Ctrl+c
    vim.api.nvim_buf_set_keymap(buf, 'n', "<C-c>", ":lua require('como').interrupt_program()<CR>", {silent=true, noremap=true, desc="como quit program"})

    self.buf = buf

    -- Create autocmd
    self.autocmd_id = vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, { --, "BufUnload"
        buffer = self.buf,
        callback = function()
            -- On buffer close
            if on_close then on_close() print("Huh") end
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
