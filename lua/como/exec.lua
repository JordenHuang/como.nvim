
local M = {}

local uv = vim.loop

local function exec_cmd(cmd, args, on_exit)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local handle, pid
    handle, pid = uv.spawn(cmd, {
        args = args,
        stdio = {nil, stdout, stderr}
    }, function(code, signal)
            stdout:read_stop()
            stderr:read_stop()
            stdout:close()
            stderr:close()
            handle:close()
            if on_exit then on_exit(code, signal) end
        end)

    stdout:read_start(function(err, data)
        assert(not err, err)
        if data then
            -- vim.api.nvim_out_write(data)
            print(data)
        end
    end)

    stderr:read_start(function(err, data)
        assert(not err, err)
        if data then
            -- vim.api.nvim_err_write(data)
            print(data)
        end
    end)
end

M.e = function(cmd)
    exec_cmd("sh", {"-c", cmd}, function(code, signal)
        -- if code == 0 then
        --     -- exec_cmd("./test.out", {}, function(cod, signa)
        --         -- if cod == 0 then
        --         --     -- vim.api.nvim_out_write("\nProgram executed successfully\n")
        --         --     print("\nProgram executed successfully\n")
        --         -- else
        --         --     -- vim.api.nvim_err_write("\nProgram execution failed with code: " .. code .. ", signal: " .. signal .. "\n")
        --         --     print("\nProgram execution failed with code: " .. cod .. ", signal: " .. signa .. "\n")
        --         -- end
        --             -- print("code: " .. cod .. ", signal: " .. signa .. "\n")
        --     -- end)
        -- else
        --     -- vim.api.nvim_err_write("\nCompilation failed with code: " .. code .. ", signal: " .. signal .. "\n")
        --     print("\nCompilation failed with code: " .. code .. ", signal: " .. signal .. "\n")
        -- end
            print("code: " .. code .. ", signal: " .. signal .. "\n")
    end)
end


return M
