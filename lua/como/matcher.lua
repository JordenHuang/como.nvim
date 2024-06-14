local M = {}

M.matcher_set = {
    gcc = {
        pattern = "(%S+):(%d+):(%d+): (%S+): (.+)",
        [1] = "filename",
        [2] = "lnum",
        [3] = "col",
        [4] = "qtype",
        [5] = "message"
    },
    python = {
        pattern = "  File \"(%S+)\", (line %d+), (.+)",
        [1] = "filename",
        [2] = "lnum",
        [3] = "message"
    },
}

M.parse_line = function(line)
    for mname, matcher in pairs(M.matcher_set) do
        local res = {}
        local parts = {string.match(line, matcher.pattern)}
        -- for a, b in ipairs(parts) do
        --     print(a, b)
        -- end

        if #parts ~= 0 then
            res.mname = mname
            res.mpattern = matcher.pattern
            -- for i = 1, #parts do
            --     -- print(i, parts[i], matcher[i])
            --     res[matcher[i]] = parts[i]
            -- end
            -- local temp = M.calc_position(matcher, parts, line)
            -- print(vim.inspect(temp))
            res.parts = M.calc_position(matcher, parts, line)
            return res
        end
    end
    return nil
end

M.calc_position = function(matcher, parts, line)
    local res = {}
    local start_col, end_col
    local next_start = 1
    for i = 1, #parts do
        -- Needs to give 'plain' argument, or some operator in parts[i] will be treated as 'magic'. See :h string.find()
        start_col, end_col = string.find(line, parts[i], next_start, true)

        start_col = tonumber(start_col)
        end_col = tonumber(end_col)
        next_start = end_col + 1

        -- matcher[i] is the part's name, like filename, lnum .etc
        res[i] = { matcher[i], start_col, end_col, parts[i] }
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
