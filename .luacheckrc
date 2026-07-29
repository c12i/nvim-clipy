std = "luajit"
cache = true

globals = {
  "vim",
}

ignore = {
  "631", -- Line is too long
  "212", -- Unused argument (common in callbacks)
  "122", -- Setting read-only field (vim.opt, vim.g are meant to be set)
}

exclude_files = {
  ".git/",
  "plugin/",
  ".luarocks/",
}
