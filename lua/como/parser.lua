--- @class (private) como.parser
--- @field matcher_set table
--- @field parse_line fun(line: string): table|nil
--- @field calc_range fun(part_map: table, parts: table, line: string): table
--- @field highlight_logic fun(vals: table): string|nil, integer|nil, integer|nil
local Parser = {}

Parser.matcher_set = {
    gcc = {
        pattern = "(%S+):(%d+):(%d+): (%S+): (.+)",
        part_map = { "filename", "lnum", "col", "etype", "message" }
    },
    python = {
        pattern = "  File \"(%S+)\", line (%d+), (.+)",
        part_map = {
            [1] = "filename",
            [2] = "lnum",
            [3] = "message"
        }
    },
    shell = {
        pattern = "(%S+): line (%d+): (.+)",
        part_map = { "filename", "lnum", "message" }
    },
    rust = {
        pattern = " --> (%S+):(%d+):(%d+)",
        part_map = { "filename", "lnum", "col" }
    },
    grep = {
        pattern = "(%S+):(%d+):(.+)",
        part_map = { "filename", "lnum", "message" }
    }
}

Parser.parse_line = function(line)
    local matched_most = -1
    local matched_result = nil
    for mname, matcher in pairs(Parser.matcher_set) do
        local res = {}
        local parts = { string.match(line, matcher.pattern) }

        if #parts ~= 0 and #parts > matched_most then
            -- res.mname = mname
            -- res.mpattern = matcher.pattern
            res.items = Parser.calc_range(matcher.part_map, parts, line)

            matched_most = #parts
            matched_result = res
        end
    end

    return matched_result
end

Parser.calc_range = function(part_map, parts, line)
    local res = {}
    local start_col, end_col
    local next_start = 1
    for i = 1, #parts do
        -- Needs to give 'plain' argument, or some operator in parts[i] will be treated as 'magic'. See :h string.find()
        start_col, end_col = string.find(line, parts[i], next_start, true)

        start_col = tonumber(start_col)
        end_col = tonumber(end_col)
        next_start = end_col + 1

        -- part_map[i] is the part's name, like filename, lnum .etc
        res[i] = {
            part_name = part_map[i],
            start_col = start_col,
            end_col = end_col,
            part_data = parts[i],
        }
    end

    return res
end

Parser.highlight_logic = function(vals)
    if vals ~= nil then
        local items = vals.items
        local hl_group

        -- Get error type
        local etype
        for _, part in ipairs(items) do
            if part.part_name == "etype" then
                etype = part
                break
            end
        end
        if etype ~= nil then
            -- Determine the hl group for the current line base on etype
            if etype.part_data == "warning" then
                hl_group = 'Como_hl_warn'
            elseif etype.part_data == "error" then
                hl_group = 'Como_hl_error'
            else
                hl_group = 'como_hl_normal'
            end
        else
            hl_group = 'Como_hl_error'
        end

        -- Loop through the parts in the line, apply color to them
        for _, part in ipairs(items) do
            if part.part_name == "filename" then
                return 'Como_hl_filename', part.start_col-1, part.end_col
            elseif part.name == "message" then
                return 'como_hl_normal', part.start_col-1, part.end_col
            else
                return hl_group, part.start_col-1, part.end_col
            end
        end
    else
        vim.notify("[como.nvim] warning: vals should not be nil", vim.log.levels.WARN)
        return nil, nil, nil
    end
end

return Parser
