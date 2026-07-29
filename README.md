# nvim-clipy

A Neovim client for the [clipy](../clipy-rust) clipboard-history daemon.
Talks directly to the daemon's Unix socket over `vim.uv` (no shelling out to
the `clipy` CLI), so the daemon must be running:

```sh
clipy watch > /tmp/clipy.log 2>&1 &
```

## Installation (local development)

While developing, point lazy.nvim at this directory directly instead of a
GitHub repo: no `owner/repo` needed:

```lua
-- lua/plugins/nvim-clipy.lua
return {
  {
    name = "nvim-clipy",
    dir = vim.fn.expand("~/coding/nvim-clipy"),
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

## Layout

- `lua/nvim-clipy/client.lua`: transport only -- speaks the daemon's
  newline-delimited JSON protocol over its Unix socket via `vim.uv`.
- `lua/nvim-clipy/init.lua`: the module `require("nvim-clipy")` resolves to.
  Holds `setup(opts)`, plugin state, and the public API built on `client.lua`.
- `lua/nvim-clipy/telescope.lua`: the `:ClipyPick` picker. Only loaded when
  actually invoked, so telescope.nvim is an optional dependency.
- `lua/telescope/_extensions/nvim-clipy.lua`: registers the picker as
  `:Telescope nvim-clipy`.
- `plugin/nvim-clipy.lua`: auto-sourced by Neovim at startup (no `require()`
  needed). This is where user commands typically get defined.
- `doc/nvim-clipy.txt`: `:help nvim-clipy` source, in vimdoc format.
