
--- @class como.errorlist.error
---
--- @field line_nr integer
--- @field filename string
--- @field lnum integer
--- @field col integer
local Error = {}
Error.__index = Error

function Error:new(line_nr, filename, lnum, col)
    local obj = setmetatable({}, self)
    obj.line_nr = line_nr
    obj.filename = filename
    obj.lnum = lnum
    obj.col = col
    return obj
end

--- @class como.errorlist
---
--- Constructor
--- @field new fun(self: como.errorlist): como.errorlist
---
--- @field private idx integer
--- @field private errors como.errorlist.error[]
local ErrorList = {}
ErrorList.__index = ErrorList

function ErrorList:new()
    local obj = setmetatable({}, self)
    obj.idx = 0
    obj.errors = {}
    return obj
end

function ErrorList:len()
    return #self.errors
end

function ErrorList:get_idx()
    return self.idx
end

function ErrorList:set_idx(idx)
    if idx >= 1 and idx <= #self.errors then
        self.idx = idx
    else
        vim.notify("[como.nvim] idx out of range", vim.log.levels.ERROR)
    end
end

function ErrorList:is_empty()
    return #self.errors == 0
end

function ErrorList:append(line_nr, filename, lnum, col)
    local e = Error:new(line_nr, filename, lnum, col)
    self.errors[#self.errors + 1] = e
end

function ErrorList:get(line_nr)
    local left = 1
    local right = #self.errors

    while left <= right do
        local mid = math.floor((left + right) / 2)
        local mid_line = self.errors[mid].line_nr

        if mid_line == line_nr then
            return self.errors[mid], mid
        elseif mid_line < line_nr then
            left = mid + 1
        else
            right = mid - 1
        end
    end

    return nil, nil
end

function ErrorList:get_with_index()
    return self.errors[self.idx]
end

function ErrorList:clear()
    self.errors = {}
end

return ErrorList
