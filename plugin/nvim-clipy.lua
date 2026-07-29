-- Files under plugin/ are auto-sourced by Neovim at startup (no require() needed).
-- Guard against double-loading if the plugin manager sources this more than once.
if vim.g.loaded_nvim_clipy then
  return
end
vim.g.loaded_nvim_clipy = true

local function command(name, fn, opts)
  vim.api.nvim_create_user_command(name, fn, opts or {})
end

command("ClipyList", function()
  require("nvim-clipy").list()
end, { desc = "List clipboard history" })

command("ClipyShow", function(args)
  require("nvim-clipy").show(args.args)
end, { nargs = 1, desc = "Show a clipboard history entry's full content" })

command("ClipyCopy", function(args)
  require("nvim-clipy").copy(args.args)
end, { nargs = 1, desc = "Copy a clipboard history entry back to the clipboard" })

command("ClipyDelete", function(args)
  require("nvim-clipy").delete(args.args)
end, { nargs = 1, desc = "Delete a clipboard history entry" })

command("ClipyClear", function()
  require("nvim-clipy").clear()
end, { desc = "Clear all clipboard history" })

command("ClipyStatus", function()
  require("nvim-clipy").status()
end, { desc = "Show clipy daemon status" })

command("ClipyKill", function()
  require("nvim-clipy").kill()
end, { desc = "Stop the clipy daemon" })

command("ClipyPick", function()
  require("nvim-clipy.telescope").pick()
end, { desc = "Pick a clipboard history entry via Telescope" })
