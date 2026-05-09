local M = {}

--- @type vim.SystemObj|nil
local server_obj = nil

local result_bufnr = nil

function M.stop_server()
    if server_obj then
        server_obj:write(nil)

        if not server_obj:is_closing() then
            server_obj:kill(15)
        end
        server_obj = nil
        vim.notify("como.nvim: Server 已關閉", vim.log.levels.INFO)
    end
end

local function start_server()
    local server_script = vim.api.nvim_get_runtime_file("lua/como/server.lua", true)
    if #server_script == 0 then
        error("como.nvim: 無法在 runtimepath 找到 server.lua")
        return
    end

    local server_path = server_script[1]
    -- print("server script: " .. server_path)
    vim.notify("server script: " .. server_path, vim.log.levels.INFO)

    ---@type table
    local server_cmd = { "nvim", "-l", server_path }

    ---@type boolean, vim.SystemObj|string
    local ok, sysobj_or_err = pcall(vim.system, server_cmd, {
        stdin = true,
        -- TODO:
        stdout = function(_, data) print("stdout:", data)  end,
        -- stderr = on_stderr,
        text = true,
    }, function()
            M.stop_server()
            print("on exit")
            server_obj = nil
        end)

    if not ok then ---@cast sysobj_or_err string
        local err = sysobj_or_err
        local sfx = err:match('ENOENT')
        and '. The como server is not found.'
        or string.format(' with error message: %s', err)

        error(('Spawning como server with cmd: `%s` failed%s'):format(server_cmd, sfx))
    end ---@cast sysobj_or_err vim.SystemObj

    server_obj = sysobj_or_err

    print("job id: " .. server_obj.pid)
    vim.notify("como.nvim: Server 已啟動", vim.log.levels.INFO)
end

function M.run_command(cmd)
    if server_obj == nil then start_server() end

    -- 步驟 B：檢查是否需要建立新的 Buffer
    -- 如果 result_bufnr 是 nil，或是該 Buffer 已經被使用者刪除了 (invalid)
    if not result_bufnr or not vim.api.nvim_buf_is_valid(result_bufnr) then

        -- 建立一個新的 Buffer (listed = false, scratch = true)
        result_bufnr = vim.api.nvim_create_buf(true, false)

        -- 替這個特定的 Buffer 註冊 Autocmd (自動命令)
        vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
            buffer = result_bufnr, -- 只針對這個 Buffer 生效
            callback = function()
                M.stop_server()
                result_bufnr = nil
            end,
            once = true, -- 觸發一次後就自動解除綁定，避免記憶體洩漏
        })

        -- (選作) 你可以在這裡開啟一個 Window (視窗) 來顯示這個 Buffer
        vim.cmd('sbuffer ' .. result_bufnr)
    end

    -- 步驟 C：發送指令給 Server
    local request = vim.json.encode({ action = "run", payload = cmd })
    server_obj:write(request .. "\n")
end

vim.api.nvim_create_user_command("Cc", function() M.run_command("ls") end, {})

return M

