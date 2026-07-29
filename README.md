# nvim-clipy

System-wide clipboard history for Neovim. Copy anything, anywhere on your machine: Neovim, your browser, Slack, a terminal, and it's captured, searchable, and re-copyable from inside Neovim via a Telescope picker with preview.

It's backed by [clipy](https://github.com/c12i/clipy-rust), a small daemon that polls the OS clipboard continuously in the background, independent of Neovim. nvim-clipy talks to it over its Unix socket via `vim.uv`.

## Why not neoclip.lua?

[neoclip.lua](https://github.com/AckslD/nvim-neoclip.lua) is a similar-looking picker, but it's fundamentally different: it hooks `TextYankPost`, so it only records things yanked or deleted _inside Neovim_. Copy any text anywhere outside Neovim, and it's invisible to neoclip. Its history also lives in Neovim's own memory by default, so it resets every time Neovim closes unless you turn on persistent history.

nvim-clipy's history comes from the daemon polling the real system clipboard, not a Neovim event, so it captures everything you copy anywhere on the machine. Because that capture is a separate process from Neovim, it persists across Neovim restarts and is shared across every Neovim instance you have open.

## Prerequisites

`clipy` is published on crates.io and installs via cargo:

```sh
cargo install clipy
```

nvim-clipy starts the daemon for you. On `VimEnter` it checks whether `clipy watch` is already reachable and, if not, spawns it detached so it keeps running after Neovim closes. If `clipy` isn't on `$PATH`, you'll get a warning, pointing back at `cargo install clipy`.

If you'd rather the daemon run independently of Neovim entirely, surviving reboots, capturing clipboard changes even when Neovim is never opened, you can start it yourself under a process supervisor instead:

```sh
clipy watch > /tmp/clipy.log 2>&1 &
```

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
-- lua/plugins/nvim-clipy.lua
return {
  {
    "c12i/nvim-clipy",
    dependencies = { "nvim-telescope/telescope.nvim" },
    -- Must load at startup, not lazily on keypress: the daemon-autostart
    -- autocmd lives in plugin/nvim-clipy.lua, which only gets sourced once
    -- the plugin loads. Declaring only `keys` below (without `lazy = false`)
    -- would defer loading until the first keypress past VimEnter, so
    -- the autocmd never gets a chance to fire and the daemon never
    -- auto-starts.
    lazy = false,
    keys = {
      {
        "<leader>sy",
        function()
          require("nvim-clipy.telescope").pick()
        end,
        desc = "Clipboard history",
      },
    },
    config = function()
      require("nvim-clipy").setup()
    end,
  },
}
```

## Commands

`:ClipyList`, `:ClipyShow {id}`, `:ClipyCopy {id}`, `:ClipyDelete {id}`, `:ClipyClear`, `:ClipyStatus`, `:ClipyKill` (restarts automatically next time Neovim starts), `:ClipyPick` (Telescope, with preview). See `:help nvim-clipy` for details, or the Lua API via `require("nvim-clipy")`.

In the `:ClipyPick` picker: `<CR>` copies the selected entry back to the clipboard, `<C-d>` deletes it.

## Keymaps

No default keymaps are set. If you're not using lazy.nvim's `keys` spec (shown in Installation above), a plain keymap works too:

```lua
vim.keymap.set("n", "<leader>sy", function()
  require("nvim-clipy.telescope").pick()
end, { desc = "Clipboard history" })
```

This project is [MIT](LICENSE) licensed.
