# nvim-clipy

A Neovim client for the [clipy](https://github.com/c12i/clipy-rust) clipboard-history daemon. Talks directly to the daemon's Unix socket over `vim.uv`, so the daemon must be installed and running.

## Prerequisites

`clipy` is published on crates.io and installs via cargo:

```sh
cargo install clipy
```

Then start the daemon (in the background, or under a process supervisor of
your choice):

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
    config = function()
      require("nvim-clipy").setup()
    end,
  },
}
```

## Commands

`:ClipyList`, `:ClipyShow {id}`, `:ClipyCopy {id}`, `:ClipyDelete {id}`,
`:ClipyClear`, `:ClipyStatus`, `:ClipyKill`, `:ClipyPick` (Telescope, with
preview). See `:help nvim-clipy` for details, or the Lua API via
`require("nvim-clipy")`.

In the `:ClipyPick` picker: `<CR>` copies the selected entry back to the
clipboard, `<C-d>` deletes it.

## Keymaps

No default keymaps are set. A suggested bind for `:ClipyPick`:

```lua
vim.keymap.set("n", "<leader>sy", function()
  require("nvim-clipy.telescope").pick()
end, { desc = "Clipboard history" })
```

Or via lazy.nvim's `keys` spec, which lazy-loads the plugin on first press
instead of at startup:

```lua
{
  "c12i/nvim-clipy",
  keys = {
    {
      "<leader>sy",
      function() require("nvim-clipy.telescope").pick() end,
      desc = "Clipboard history",
    },
  },
  config = function()
    require("nvim-clipy").setup()
  end,
}
```

This project is [MIT](LICENSE) licensed.
