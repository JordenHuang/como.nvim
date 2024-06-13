local M = {}

M.patterns = {
    gcc = "(%S+):(%d+):(%d+): (%S+): (.+)",
    clang = "(%S+):(%d+):(%d+): error: (.+)",
}

M.parse_line = function(line)
    for _, pattern in pairs(M.patterns) do
        local filename, lnum, col, qtype, text = string.match(line, pattern)
        if filename and lnum and col and text then
            return {
                filename = filename,
                lnum = tonumber(lnum),
                col = tonumber(col),
                qtype = qtype,
                text = text,
            }
            -- break -- Stop checking other patterns if a match is found
        end
    end
    return nil
end

-- TODO:
-- 1 Create a function for calculating the position for higlighting
--   reduce the code inside core.lua, on_output function

return M
