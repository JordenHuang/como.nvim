--- @class (private) como.parser
--- @field matcher_set table
local Parser = {}

--- @class como.parser.parse_result
--- @field mname string
--- @field mpattern table
--- @field items como.parser.result_range[]

--- @class como.parser.result_range
--- @field part_name string
--- @field start_col integer
--- @field end_col integer
--- @field part_data string

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

--- @param line string
--- @return como.parser.parse_result | nil
Parser.parse_line = function(line)
    local matched_most = -1
    local matched_result = nil
    for mname, matcher in pairs(Parser.matcher_set) do
        local res = {}
        local parts = { string.match(line, matcher.pattern) }

        if #parts ~= 0 and #parts > matched_most then
            res.mname = mname
            res.mpattern = matcher.pattern
            res.items = Parser.calc_range(matcher.part_map, parts, line)

            matched_most = #parts
            matched_result = res
        end
    end

    return matched_result
end

--- @param part_map table
--- @param parts table
--- @param line string
--- @return como.parser.result_range[]
Parser.calc_range = function(part_map, parts, line)
    --- @type como.parser.result_range[]
    local res = {}
    local start_col, end_col
    local next_start = 1
    for i = 1, #parts do
        -- Needs to give 'plain' argument, or some operator in parts[i] will be treated as 'magic'. See :h string.find()
        start_col, end_col = string.find(line, parts[i], next_start, true)

        -- Columns should be found with no error
        --- @cast start_col integer
        --- @cast end_col integer

        -- start_col = tonumber(start_col)
        -- end_col = tonumber(end_col)
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

--- @param parsed_result como.parser.parse_result
--- @return table semantic_data, table highlights
Parser.analyze_parsed_result = function(parsed_result)
    if not parsed_result or not parsed_result.items then
        return {}, {}
    end

    local items = parsed_result.items
    local semantic_data = {} -- For errorlist
    local highlights = {} -- For highlight

    -- Error level for the line
    local etype_text = "error" -- Default to error
    for _, part in ipairs(items) do
        if part.part_name == "etype" then
            etype_text = part.part_data
            break
        end
    end

    local base_hl_group = 'Como_hl_error'
    if etype_text == "warning" then
        base_hl_group = 'Como_hl_warn'
    elseif etype_text == "normal" then
        base_hl_group = 'Como_hl_normal'
    end

    -- Get semantic data
    -- Assign highlight group and position to each part
    for _, part in ipairs(items) do
        if part.part_name == "filename" then
            semantic_data.filename = part.part_data
            table.insert(highlights, { 'Como_hl_filename', part.start_col - 1, part.end_col })

        elseif part.part_name == "lnum" then
            semantic_data.lnum = tonumber(part.part_data)
            table.insert(highlights, { base_hl_group, part.start_col - 1, part.end_col })

        elseif part.part_name == "col" then
            semantic_data.col = tonumber(part.part_data)
            table.insert(highlights, { base_hl_group, part.start_col - 1, part.end_col })

        elseif part.part_name == "message" then
            table.insert(highlights, { 'Como_hl_normal', part.start_col - 1, part.end_col })

        else
            table.insert(highlights, { base_hl_group, part.start_col - 1, part.end_col })
        end
    end

    return semantic_data, highlights
end

return Parser
