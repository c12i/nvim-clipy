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

command("ClipyClear", function()
  require("nvim-clipy").clear()
end, { desc = "Clear all clipboard history" })

command("ClipyStatus", function()
  require("nvim-clipy").status()
end, { desc = "Show clipy daemon status" })

command("ClipyKill", function()
  require("nvim-clipy").kill()
end, { desc = "Stop the clipy daemon" })

command("ClipyStart", function()
  require("nvim-clipy").ensure_daemon(true)
end, { desc = "Start the clipy daemon if it isn't already running" })

command("ClipyPick", function()
  require("nvim-clipy.telescope").pick()
end, { desc = "Pick a clipboard history entry via Telescope" })

command("ClipyBrowse", function()
  require("nvim-clipy.browser").open()
end, { desc = "Browse clipboard history in a bottom split" })

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("nvim_clipy_autostart", { clear = true }),
  callback = function()
    require("nvim-clipy").ensure_daemon()
  end,
  desc = "Start the clipy daemon if it isn't already running",
})
