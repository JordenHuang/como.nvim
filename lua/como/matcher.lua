local M = {}

M.matcher_set = {
    gcc = {
        pattern = "(%S+):(%d+):(%d+): (%S+): (.+)",
        parts = { "filename", "lnum", "col", "etype", "message" }
    },
    python = {
        pattern = "  File \"(%S+)\", line (%d+), (.+)",
        parts = {
            [1] = "filename",
            [2] = "lnum",
            [3] = "message"
        }
    },
    shell = {
        pattern = "(%S+): line (%d+): (.+)",
        parts = { "filename", "lnum", "message" }
    },
    rust = {
        pattern = " --> (%S+):(%d+):(%d+)",
        parts = { "filename", "lnum", "col" }
    },
    grep = {
        pattern = "(%S+):(%d+):(.+)",
        parts = { "filename", "lnum", "message" }
    }
}

M.Pos = {
    name = 1,
    start_col = 2,
    end_col = 3,
    data = 4
}

M.parse_line = function(line)
    local matched_most = -1
    local matched_result = nil
    for mname, matcher in pairs(M.matcher_set) do
        local res = {}
        local values = { string.match(line, matcher.pattern) }
        -- for a, b in ipairs(values) do
        --     print(a, b)
        -- end

        if #values ~= 0 and #values > matched_most then
            -- res.mname = mname
            -- res.mpattern = matcher.pattern
            res.parts = M.calc_position(matcher.parts, values, line)

            matched_most = #values
            matched_result = res
        end
    end

    if matched_most ~= -1 then
        return matched_result
        -- return res
    else
        return nil
    end
end

M.calc_position = function(parts, values, line)
    local res = {}
    local start_col, end_col
    local next_start = 1
    for i = 1, #values do
        -- Needs to give 'plain' argument, or some operator in parts[i] will be treated as 'magic'. See :h string.find()
        start_col, end_col = string.find(line, values[i], next_start, true)

        start_col = tonumber(start_col)
        end_col = tonumber(end_col)
        next_start = end_col + 1

        -- parts[i] is the part's name, like filename, lnum .etc
        res[i] = { parts[i], start_col, end_col, values[i] }
    end
    -- print(vim.inspect(res))
    return res
end

return M
