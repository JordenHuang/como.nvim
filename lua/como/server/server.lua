-- lua/como/server/server.lua

-- 兼容不同版本的 Neovim (0.9 使用 vim.loop，0.10+ 使用 vim.uv)
local uv = vim.uv or vim.loop

-- 儲存目前正在執行的子行程 (Child Processes)
-- 結構: { ["client_id"] = handle (uv_process_t) }
local active_jobs = {}

-- 標準輸入 (Standard Input) 的全域字串緩衝區
local stdin_buffer = ""

--- 輔助函式：將單行編譯輸出編碼為 JSON 並回傳給 Dispatcher
--- @param client_id string
--- @param line string
local function process_and_send_line(client_id, line)
    -- 這裡你可以未來加入 Regex 的解析邏輯
    local response = {
        client_id = client_id,
        line = line,
        pure_text = true,
        parts = {}
    }

    -- 輸出 JSONL (JSON Lines) 並強制刷新緩衝區 (Flush Buffer)
    io.stdout:write(vim.json.encode(response) .. "\n")
    io.stdout:flush()
end

--- 安全地終止指定的任務
--- @param client_id string
local function kill_job(client_id)
    local handle = active_jobs[client_id]
    if handle and not handle:is_closing() then
        -- 傳送 SIGTERM (信號 15) 要求優雅終止
        handle:kill(15)
    end
end

--- 核心函式：使用 libuv 生成並管理子行程
--- @param client_id string
--- @param payload string
--- @param cwd string|nil
local function handle_run(client_id, payload, cwd)
    -- 1. 確保舊任務已被清除 (類似 Emacs 的重編譯邏輯)
    kill_job(client_id)

    -- 2. 建立專屬於這個子行程的通訊管線 (Pipes)
    local stdout_pipe = uv.new_pipe(false)
    local stderr_pipe = uv.new_pipe(false)

    -- 專屬的字串緩衝區，避免多行資料被截斷
    local out_buffer = ""
    local err_buffer = ""

    local handle, pid

    -- 3. 生成子行程 (Spawn Process)
    handle, pid = uv.spawn("sh", {
        args = {"-c", payload},
        cwd = cwd,
        -- 關閉 stdin，綁定我們建立的 stdout 和 stderr 管線
        stdio = {nil, stdout_pipe, stderr_pipe} 
    }, function(code, signal)
            -- 🌟 行程結束時的回呼 (On Exit Callback)

            -- 停止讀取並關閉管線，避免記憶體洩漏 (Memory Leak)
            stdout_pipe:read_stop()
            stderr_pipe:read_stop()
            if not stdout_pipe:is_closing() then stdout_pipe:close() end
            if not stderr_pipe:is_closing() then stderr_pipe:close() end
            if handle and not handle:is_closing() then handle:close() end

            -- 清理任務列表
            active_jobs[client_id] = nil

            -- 通知 Dispatcher 任務已結束
            local end_msg = {
                client_id = client_id,
                line = "[como] Compilation finished with exit code: " .. tostring(code),
                pure_text = true,
                parts = {}
            }
            io.stdout:write(vim.json.encode(end_msg) .. "\n")
            io.stdout:flush()
        end)

    if not handle then
        process_and_send_line(client_id, "[STDERR] Failed to spawn process.")
        return
    end

    -- 註冊到活躍任務列表中
    active_jobs[client_id] = handle

    -- 4. 監聽標準輸出 (Standard Output)
    stdout_pipe:read_start(function(err, data)
        if err or not data then return end
        out_buffer = out_buffer .. data
        while true do
            local newline_pos = out_buffer:find("\n")
            if not newline_pos then break end
            local line = out_buffer:sub(1, newline_pos - 1)
            out_buffer = out_buffer:sub(newline_pos + 1)
            process_and_send_line(client_id, line)
        end
    end)

    -- 5. 監聽標準錯誤 (Standard Error)
    stderr_pipe:read_start(function(err, data)
        if err or not data then return end
        err_buffer = err_buffer .. data
        while true do
            local newline_pos = err_buffer:find("\n")
            if not newline_pos then break end
            local line = err_buffer:sub(1, newline_pos - 1)
            err_buffer = err_buffer:sub(newline_pos + 1)
            process_and_send_line(client_id, "[STDERR] " .. line)
        end
    end)
end

--- 主迴圈：伺服器的進入點
local function main()
    -- 建立一個管線來讀取自己的標準輸入 (FD 0)
    local stdin = uv.new_pipe(false)
    stdin:open(0)

    -- 啟動非同步讀取
    stdin:read_start(function(err, chunk)
        if err then
            io.stderr:write("Stdin error: " .. err .. "\n")
            return
        end

        -- 🌟 如果收到 nil，代表主控端 (Neovim) 已關閉通道，也就是收到了 EOF
        if not chunk then
            stdin:close()
            -- 優雅關閉所有仍在背景執行的編譯任務
            for cid, _ in pairs(active_jobs) do
                kill_job(cid)
            end
            -- 結束這個伺服器行程
            os.exit(0)
            return
        end

        -- 處理 JSONL 格式的指令流
        stdin_buffer = stdin_buffer .. chunk
        while true do
            local newline_pos = stdin_buffer:find("\n")
            if not newline_pos then break end

            local line = stdin_buffer:sub(1, newline_pos - 1)
            stdin_buffer = stdin_buffer:sub(newline_pos + 1)

            -- 嘗試解析 Dispatcher 傳來的 JSON
            local ok, req = pcall(vim.json.decode, line)
            if ok and type(req) == "table" and req.client_id then
                if req.action == "run" then
                    handle_run(req.client_id, req.payload, req.cwd)
                elseif req.action == "kill" then
                    kill_job(req.client_id)
                end
            else
                -- JSON 解析失敗時，將錯誤資訊記錄到 stderr，避免污染 stdout
                io.stderr:write("Failed to parse incoming command: " .. line .. "\n")
            end
        end
    end)
end

-- 啟動事件迴圈 (Event Loop)
main()
