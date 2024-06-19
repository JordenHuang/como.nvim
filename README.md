# como.nvim

Como.nvim is a lua plugin that creates a buffer for compilation results in Neovim (**co**mpilation **mo**de).


**TODO:** Put a demo image here

## Features

- Compile and Recompile

- Highlights the error/warning messages

- Jumps to the line that occurs the error/warning when hitting \<CR\> on that message

- Auto scroll down

- **TODO:** Add custom matcher

## Requirements

**TODO**

## Installation

Install with your favorite plugin manager. For example:

### Lazy.nvim

```lua
{
    "JordenHuang/como.nvim",
    config = function()
        require('como').setup({
            -- Set some options here
            -- Or leaving it empty to use the default comfiguation, see below
        })
    end
}
```

## Configuration

Default configuration

```lua
{
    -- If true, shows the last compile command in input when re-calls the 'Como compile' command
    show_last_cmd = true,
    -- Auto scorlls down in the compilation buffer if your cursor is on the last line
    auto_scroll = true,

    add_matchers = {
        -- **TODO:** this function is not yet implement
    }
}
```

## Mappings

When the cursor is in the compilation buffer,

- pressing `q` will close the buffer, and can be re-open by calling `:Como open`

- pressing <CR> will jump to the line that occurs the error/warning, if the line with the cursor
has the error/warning message

The two key map is default, and can't be customed

## Usage

- To compile, use `:Como compile`, and enter the command

- You can use `:Como recompile` to compile with the last command

- If you close the compilation buffer and want to open it again, use `:Como open`

### Optional config

You can set up some key mappings to make calling the commands easier, for example (my setting):

```lua
local function opts(description)
    return { desc = description, noremap = true, silent = true }
end

vim.api.nvim_set_keymap("n", "<leader>cc", ":Como compile<CR>", opts("Como compile"))
vim.api.nvim_set_keymap("n", "<leader>cr", ":Como recompile<CR>", opts("Como recompile"))
vim.api.nvim_set_keymap("n", "<leader>co", ":Como open<CR>", opts("Como focus como buffer"))
```

## Contributing

Contributions are welcome, if you fix an issue or add some features, feel free to open a pull request

If you found some issues, please open a github issue

## Inspiration

This is my first neovim plugin, I have no idea where to start when I first create the project folder

And by asking AI and reading other great plugins' code

I've learned a lot from these and being able to create the plugin

So I would like to give a special thanks to the plugins that helps me a lot

- [compile-mode.nvim](https://github.com/ej-shafran/compile-mode.nvim)
- [local-highlight.nvim](https://github.com/tzachar/local-highlight.nvim/blob/master/lua/local-highlight.lua)
- [reddit - adding_highlighted_text_to_a_buffer](https://www.reddit.com/r/neovim/comments/13bp2hp/adding_highlighted_text_to_a_buffer/)
- [nvim-pqf](https://github.com/yorickpeterse/nvim-pqf)
- [qfview.nvim](https://github.com/ashfinal/qfview.nvim)
- [NvChad/nvim-colorizer.lua](https://github.com/NvChad/nvim-colorizer.lua/blob/master/lua/colorizer/buffer.lua#L74)
- [bmessages.nvim](https://github.com/ariel-frischer/bmessages.nvim/blob/main/lua/bmessages.lua#L62)


Hope you enjoy
