--- Manage server and clients, dispatch data between server and client
--- @class (private) como.dispatcher
---
--- @field server_obj vim.SystemObj|nil
--- @field clients table<string, como.client>
--- @field next_id integer
--- @field DEFAULT_BUF_NAME string|nil
---
--- Configure Dispatcher
--- @field init fun(default_buf_name: string)
---
--- @field start_server fun()
--- @field stop_server fun()
---
--- @field register_client fun(client_obj: como.client): string
--- @field unregister_client fun(client_id: string)
---
--- @field send_request fun(client_id: string, action: string, payload: string, cwd: string)
--- @field get_target_client fun(): como.client|nil, string
---
--- @field private on_stdout fun(data: string)
--- @field private on_stderr fun(data: string)
local Dispatcher = {
    server_obj = nil,
    clients = {},
    next_id = 1,
    DEFAULT_BUF_NAME = nil,
}

Dispatcher.init = function(default_buf_name)
    -- Escape all non-alphanumeric characters for safty
    Dispatcher.DEFAULT_BUF_NAME = default_buf_name:gsub("([^%w])", "%%%1")
end

Dispatcher.start_server = function()
    if Dispatcher.server_obj then return end

    --- @type string[]
    local server_script = vim.api.nvim_get_runtime_file("lua/como/server/server.lua", true)
    if #server_script == 0 then
        error("[como.nvim]: Can NOT find server.lua in runtimepath")
        return
    end

    local server_path = server_script[1]
    vim.notify("server script: " .. server_path, vim.log.levels.INFO)

    ---@type table
    local server_cmd = { vim.v.progpath, "-l", server_path }

    ---@type boolean, vim.SystemObj|string
    local ok, sysobj_or_err = pcall(vim.system, server_cmd, {
        stdin = true,
        stdout = function(err, data)
            assert(not err, err)
            vim.schedule(function()
                Dispatcher.on_stdout(data)
            end)
        end,
        stderr = function(err, data)
            assert(not err, err)
            vim.schedule(function()
                Dispatcher.on_stderr(data)
            end)
        end,
        text = true,
    }, function()
            vim.schedule(function()
                vim.notify("como.nvim: Server 已自然結束", vim.log.levels.DEBUG)
            end)
        end)

    if not ok then ---@cast sysobj_or_err string
        local err = sysobj_or_err
        local sfx = err:match('ENOENT')
            and '. The como server is not found.'
          or string.format(' with error message: %s', err)

        error(('Spawning como server with cmd: `%s` failed%s'):format(table.concat(server_cmd, " "), sfx))
    end ---@cast sysobj_or_err vim.SystemObj

    Dispatcher.server_obj = sysobj_or_err

    print("pid:", Dispatcher.server_obj.pid)
    vim.notify("como.nvim: Server 已啟動", vim.log.levels.INFO)
end

Dispatcher.stop_server = function()
    if Dispatcher.server_obj then
        Dispatcher.server_obj:write(nil)

        Dispatcher.server_obj = nil
        vim.notify("como.nvim: 所有 Buffer 已關閉，Server 進入休眠", vim.log.levels.INFO)
    end
end

Dispatcher.register_client = function(client_obj)
    local id = "client_" .. tostring(Dispatcher.next_id)
    Dispatcher.next_id = Dispatcher.next_id + 1
    Dispatcher.clients[id] = client_obj
    return id
end

function Dispatcher.unregister_client(client_id)
    -- 從活躍名單中移除該 Client
    Dispatcher.clients[client_id] = nil

    -- 檢查現在還有沒有活著的 Client
    local active_count = vim.tbl_count(Dispatcher.clients)

    if active_count == 0 then
        -- 這是最後一個 Client，關燈！
        Dispatcher.stop_server()
    end
end

Dispatcher.send_request = function(client_id, action, payload, cwd)
    -- Make sure the server is started
    Dispatcher.start_server()

    if Dispatcher.server_obj then
        local request = vim.json.encode({
            client_id = client_id,
            action = action,
            payload = payload,
            cwd = cwd,
        })
        Dispatcher.server_obj:write(request .. "\n")
    end
end


function Dispatcher.get_target_client()
    local current_buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.api.nvim_buf_get_name(current_buf)

    -- Default CWD
    local resolved_cwd = vim.fn.getcwd()
    local dir = vim.fn.fnamemodify(buf_name, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then
        resolved_cwd = dir
    end

    -- 優先級 1：使用者目前就在某個 compilation buffer 裡面
    for _, client in pairs(Dispatcher.clients) do
        if client.pane.buf == current_buf then
            print("in como buffer")
            return client, client.cwd
        end
    end

    -- 優先級 2：使用者在外部 (例如編輯程式碼)，尋找預設的 compilation buffer
    for _, client in pairs(Dispatcher.clients) do
        -- 取得 buffer 的完整名稱
        -- 如果名稱依然是預設值，代表它沒有被使用者 rename 過
        if buf_name:match(Dispatcher.DEFAULT_BUF_NAME .. "$") then
            print("Use default")
            return client, resolved_cwd
        end
    end

    -- 優先級 3：找不到預設 Buffer (全空，或是舊的被 rename 了)，回傳 nil 要求新建
    print("Default como buffer not found, create one")
    return nil, resolved_cwd
end

Dispatcher.on_stdout = function(data)
    if not data or data == "" then return end

    vim.schedule(function()
        local ok, parsed = pcall(vim.json.decode, data)
        if ok and parsed.client_id then
            -- 🌟 根據 client_id 找到對應的 Client，把資料派發給它
            local target_client = Dispatcher.clients[parsed.client_id]
            if target_client then
                target_client:handle_response(parsed)
                vim.print("parsed:", parsed)
            end
        else
            vim.notify("Dispatcher.on_stdout has something wrong: " .. data, vim.log.levels.ERROR)
        end
    end)
end

local stderr_buffer = ""
Dispatcher.on_stderr = function(data)
    if not data or data == "" then return end
    stderr_buffer = stderr_buffer .. data

    -- 尋找換行符號，切出一行一行乾淨的 Log
    while true do
        local newline_pos = stderr_buffer:find("\n")
        if not newline_pos then break end

        local line = stderr_buffer:sub(1, newline_pos - 1)
        stderr_buffer = stderr_buffer:sub(newline_pos + 1)

        vim.schedule(function()
            vim.notify("Server Error: " .. line, vim.log.levels.ERROR)
        end)
    end
end

return Dispatcher
