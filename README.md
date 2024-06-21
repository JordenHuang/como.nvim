# como.nvim

Como.nvim is a lua plugin that creates a buffer for compilation results in Neovim (**co**mpilation **mo**de).


![demo.gif](./the_como_demo.gif)

## Features

- Compile and Recompile

- Highlights the error/warning messages

- Jumps to the line that occurs the error/warning when hitting \<CR\> on that message

- Auto scroll down

- Custom matchers for highlight and jump to file utility


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

For custom_matchers, please see [Matcher](#matchers) section

```lua
{
    -- If true, shows the last compile command in input when re-calls the 'Como compile' command
    show_last_cmd = true,
    -- Auto scorlls down in the compilation buffer if your cursor is on the last line
    auto_scroll = true,

    custom_matchers = {
        -- You can add your matchers here, see Matcher section for detail. Heres an example in the default matcher set:
        -- gcc = {
        --     pattern = "(%S+):(%d+):(%d+): (%S+): (.+)",
        --     parts = { "filename", "lnum", "col", "etype", "message" }
        -- },
    }
}
```

## Mappings

When the cursor is in the compilation buffer,

- pressing `q` will close the buffer, and can be re-open by calling `:Como open`

- pressing <CR> will jump to the line that occurs the error/warning, if the line with the cursor
has the error/warning message

The above maps are default, and can't be customed

## Usage

- To compile, use `:Como compile`, and enter the command

- You can use `:Como recompile` to compile with the last command

- If you close the compilation buffer and want to open it again, use `:Como open`

<br>

### Optional config

You can set up some key mappings to make calling the commands easier, for example (my setting):

```lua
local function opts(description)
    return { desc = description, noremap = true, silent = true }
end

vim.api.nvim_set_keymap("n", "<leader>cc", ":Como compile<CR>", opts("Compile"))
vim.api.nvim_set_keymap("n", "<leader>cr", ":Como recompile<CR>", opts("Recompile"))
vim.api.nvim_set_keymap("n", "<leader>co", ":Como open<CR>", opts("Focus como buffer"))
```

## Matchers

In order to locate the file name, line number and so on, it uses lua's `string.match` function to match a line
with the patterns in the matcher set.

To add custom matchers, we need to provide the pattern and the captures, for example of gcc:

```lua
gcc = {
    pattern = "(%S+):(%d+):(%d+): (%S+): (.+)",
    parts = { "filename", "lnum", "col", "etype", "message" }
}
```

When encounter the error message like this:

> test.c:18:13: error: expected ‘;’ before ‘}’ token

will get the file name `test.c`, line number `18`, column number `13`, error type `error` and message `expected ‘;’ before ‘}’ token`

Any line that don't match any pattern in the matcher set will not have highlights and jump to file utility

Refer to [Lua documentation - Patterns](https://www.lua.org/pil/20.2.html) for how to write a pattern

## Contributing

Contributions are welcome, if you fix an issue or add some features, feel free to open a pull request

If you found any issues, please open a github issue

## Inspiration

This is my first neovim plugin, I have no idea where to start when I first create the project folder

After asking AI and reading other great plugins' code

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

