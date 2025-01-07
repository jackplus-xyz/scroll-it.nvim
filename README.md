# scroll-it.nvim

A Neovim plugin for continuous scrolling across multiple windows, ideal for comparing different sections of the same file. Perfectly suited for ultrawide monitors, enabling comfortable viewing of multiple vertical splits of a long document.

## Demo

https://github.com/user-attachments/assets/6d5a560a-7773-445c-84cf-f2cb681819ca


## Features

 - Automatic Scroll Sync: Keeps scrolling synchronized across all windows displaying the same buffer.
 - Configurable Overlap: Define the number of overlapping lines between adjacent windows.
 - Customizable Line Numbers: Choose to hide line numbers in synchronized windows.
 - Bidirectional Support: Syncs scrolling both forward and in reverse directions.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "jackplus-xyz/scroll-it.nvim",
    opts = {
        -- Add your configuration here
    }
}
```

## Configuration

`scroll-it.nvim` comes with the following default configuration:

```lua
{
    enabled = false,             -- Enable the plugin on startup
    reversed = false,            -- Reverse the continuous direction (default: left-to-right, top-to-bottom)
    hide_line_number = "others", -- Options: "all" | "others" | "none"
                                 -- "all": Hide line numbers in all synchronized windows
                                 -- "others": Hide line numbers in all but the focused window
                                 -- "none": Show line numbers in all windows
    overlap_lines = 0,           -- Number of lines to overlap between adjacent windows
}
```

## Usage

The plugin provides the following commands:

- `:ScrollItEnable` - Enable scroll synchronization
- `:ScrollItDisable` - Disable scroll synchronization
- `:ScrollItToggle` - Toggle scroll synchronization

## How it works

When enabled, `scroll-it.nvim` monitors all windows displaying the same buffer and:

1. Detects window positions and orders them based on their layout
2. Synchronizes scrolling based on the active window
3. Maintains configurable overlap between adjacent windows
4. Updates window positions whenever you scroll or change window layouts

## Tips

- Works well with [smooth scrolling](https://github.com/folke/snacks.nvim/blob/main/docs/scroll.md)
- Use with vertical splits for comparing different sections of the same file
- Adjust `overlap_lines` to maintain context between windows
- Toggle line numbers visibility for cleaner comparison views
- The `reversed` option can be useful for reviewing code changes in opposite directions

## Credits

- This plugin is inspired and develped by folllowing the [Neovim Plugin From Scratch](https://www.youtube.com/watch?v=VGid4aN25iI&list=PLep05UYkc6wTyBe7kPjQFWVXTlhKeQejM&index=18) from the [Advent of Neovim: Why Neovim?](https://www.youtube.com/watch?v=TQn2hJeHQbM&list=PLep05UYkc6wTyBe7kPjQFWVXTlhKeQejM) series by [tjdevries (TJ DeVries)](https://github.com/tjdevries). It makes making my first Neovim plugin a lot less scary.
- Special thanks to [folke/snacks.nvim: 🍿 A collection of small QoL plugins for Neovim](https://github.com/folke/snacks.nvim) for being an excellent resource on implementing and structuring Neovim plugins.
- [neovide/neovide: No Nonsense Neovim Client in Rust](https://github.com/neovide/neovide) for making stunning demonstration of the plugin.

## License

MIT

