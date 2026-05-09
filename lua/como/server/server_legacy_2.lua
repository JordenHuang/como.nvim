-- 儲存正在執行的編譯任務：{ ["client_001"] = vim.SystemObj, ... }
local active_jobs = {}

-- 用來處理讀取 stdin 時可能被截斷的字串 (Line Buffer)
local stdin_buffer = ""

--- 處理並發送單行編譯結果
local function process_and_send_line(client_id, line)
    -- 這裡實作你的 Regex 解析邏輯 (尋找檔案、行號、錯誤訊息)
    -- 假設這是一行普通的純文字
    local response = {
        client_id = client_id,
        line = line,
        pure_text = true,
        parts = {}
    }

    -- TODO: 在這裡加上你的解析邏輯，如果解析成功，將 pure_text 設為 false，並填入 parts

    -- 轉成 JSON 並寫入 stdout (加上 \n 作為分隔)
    io.stdout:write(vim.json.encode(response) .. "\n")
    io.stdout:flush() -- 🌟 確保資料立刻送出
end

--- 執行 Client 送來的指令
local function handle_run(client_id, payload, cwd)
    -- 如果該 Client 已經有任務在跑，先殺掉舊的
    if active_jobs[client_id] then
        active_jobs[client_id]:kill(15)
    end

    -- 🌟 使用 vim.system 非同步執行編譯指令
    local job = vim.system({"bash", "-c", payload}, {
        cwd = cwd,
        text = true,
        stdout = function(err, data)
            if not data then return end
            -- 將編譯器的輸出依換行符號切開，逐行解析並串流回傳
            for line in data:gmatch("[^\r\n]+") do
                process_and_send_line(client_id, line)
            end
        end,
        stderr = function(err, data)
            -- 同樣處理 stderr...
            if not data then return end
            for line in data:gmatch("[^\r\n]+") do
                process_and_send_line(client_id, "[STDERR] " .. line)
            end
        end,
    }, function(out)
            -- 行程結束時的清理邏輯
            active_jobs[client_id] = nil
            local end_msg = {
                client_id = client_id,
                line = "[como] Compilation finished with exit code: " .. out.code,
                pure_text = true
            }
            io.stdout:write(vim.json.encode(end_msg) .. "\n")
            io.stdout:flush()
        end)

    active_jobs[client_id] = job
end

--- 主迴圈：使用 vim.uv 非同步監聽 stdin
local function main()
    -- 建立一個非同步的 Pipe 來讀取 FD 0 (標準輸入)
    local stdin = vim.uv.new_pipe(false)

    if stdin == nil then
        error("[como.nvim] In server, stdin pipe is nil\n")
        return
    end

    stdin:open(0)

    stdin:read_start(function(err, chunk)
        if err then
            io.stderr:write("Stdin error: " .. err .. "\n")
            return
        end

        -- 如果 Dispatcher 斷線 (送出 nil)，關閉 Server
        if not chunk then
            stdin:close()
            -- 優雅關閉所有還在跑的子行程
            for _, job in pairs(active_jobs) do job:kill(15) end
            os.exit(0)
            return
        end

        -- 處理字串緩衝 (因為 chunk 不一定會剛好在換行符號切斷)
        stdin_buffer = stdin_buffer .. chunk
        while true do
            local newline_pos = stdin_buffer:find("\n")
            if not newline_pos then break end

            local line = stdin_buffer:sub(1, newline_pos - 1)
            stdin_buffer = stdin_buffer:sub(newline_pos + 1)

            -- 嘗試解析 Dispatcher 送來的指令
            local ok, req = pcall(vim.json.decode, line)
            if ok and req.client_id then
                if req.action == "run" then
                    handle_run(req.client_id, req.payload, req.cwd)
                elseif req.action == "kill" then
                    if active_jobs[req.client_id] then
                        active_jobs[req.client_id]:kill(15)
                    end
                end
            end
        end
    end)
end

-- 啟動非同步事件迴圈
main()
