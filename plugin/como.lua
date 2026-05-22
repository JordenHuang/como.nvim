-- Provide user command
vim.api.nvim_create_user_command(
    'Como',
    function(opts)
        require("como").parse_sub_commands(opts)
    end,
    {
        nargs = 1,
        complete = function(ArgLead, CmdLine, CursorPos)
            local candidates = {}
            for cmd, _ in pairs(require("como").sub_command_handlers) do
                if vim.startswith(cmd, ArgLead) then
                    table.insert(candidates, cmd)
                end
            end
            return candidates
        end,
    }
)
