-- see :help :checkhealth
-- https://github.com/neovim/neovim/blob/b7779c514632f8c7f791c92203a96d43fffa57c6/runtime/doc/pi_health.txt#L17

local M = {}

M.check = function()
    vim.health.start("como.nvim")

    -- Display como.nvim verison
    do
        local v = require("como").version()
        local como_version = (
            string.format(
                "%d.%d.%d",
                v.major,
                v.minor,
                v.patch
            )
        )
        vim.health.info("Como.nvim version: " .. como_version)
    end

    -- Display Neovim verison
    do
        local v = vim.version()
        local nvim_version = (
            string.format(
                "%d.%d.%d, build %s",
                v.major,
                v.minor,
                v.patch,
                v.build or "nil"
            )
        )
        vim.health.info("Neovim version: " .. nvim_version)
    end

    -- Check required minimal Neovim version
    if vim.fn.has("nvim-0.10.0") ~= 1 then
        vim.health.warn(
            "como.nvim requires Neovim >= 0.10.0. Consider switch to newer version of Neovim, or use older verion of como.nvim."
        )
    else
        vim.health.ok("Neovim >= 0.10.0")
    end

    -- Check config
    if type(require("como.config").set_buf_keymap_cb) ~= "function" then
        vim.health.warn("Invalid type of `como.configset_buf_keymap_cb`: Should be a function.")
    else
        vim.health.ok("Type of `como.config.set_buf_keymap_cb` is function")
    end
end

return M
