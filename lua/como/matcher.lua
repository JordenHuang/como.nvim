local M = {}

M.matcher_set = {
    gcc = {
        pattern = "(%S+):(%d+):(%d+): (%S+): (.+)",
        parts = {
            [1] = "filename",
            [2] = "lnum",
            [3] = "col",
            [4] = "qtype",
            [5] = "message"
        }
    },
    python = {
        pattern = "  File \"(%S+)\", line (%d+), (.+)",
        parts = {
            "filename",
            "lnum",
            "message"
        }
    },
}

M.parse_line = function(line)
    for mname, matcher in pairs(M.matcher_set) do
        local res = {}
        local values = { string.match(line, matcher.pattern) }
        -- for a, b in ipairs(parts) do
        --     print(a, b)
        -- end

        if #values ~= 0 then
            -- res.mname = mname
            -- res.mpattern = matcher.pattern
            res.parts = M.calc_position(matcher.parts, values, line)
            return res
        end
    end
    return nil
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
    return res
end

-- M.test = function()
--     local s = ": unused variable ‘k’ [-Wunused-variable]"
--     print(s)
--     -- Needs to give 'plain' argument, or some operator will be treat as 'magic'. See :h string.find()
--     local start_col, end_col = string.find(s, ": unused variable ‘k’ [-Wunused-variable]", 1, true)
--     print(start_col, end_col)
-- end

return M
