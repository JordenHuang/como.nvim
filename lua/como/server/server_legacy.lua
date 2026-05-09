local counter = 0
local function main()
    io.stderr:write("Server running\n")
    while true do

        local line = io.read("*line")
        if not line then
            io.stderr:write("line EOF\n")
            break
        end

        local ok, request = pcall(vim.json.decode, line)

        if ok and type(request) == "table" then
            local action = request.action

            -- 在這裡執行你的核心邏輯
            local result = {
                client_id = request.client_id,
                status = "success",
                message = "Processed action: " .. (action or "unknown"),
                command = request.payload,
                lines = { string.format("%s, %s, %s", counter, counter+1, counter+2) },
            }
            counter = counter + 3

            -- 3. 轉回 JSON 並輸出
            local response_str = vim.json.encode(result)
            io.write(response_str .. "\n")

            -- ⚠️ 致命細節：務必強制清空緩衝區 (Flush Buffer)
            io.flush()
        else
            local error_resp = vim.json.encode({ status = "error", message = "Invalid JSON format" })
            io.write(error_resp .. "\n")
            io.flush()
        end
    end

    io.stderr:write("Server stopped\n")
end

main()

