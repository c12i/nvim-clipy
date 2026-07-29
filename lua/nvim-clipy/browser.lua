-- Alternative to the Telescope picker: a persistent bottom split listing
-- clipboard history, meant to be left open and glanced at while you work
-- rather than opened and closed like a modal picker.

local M = {}

local buf = nil
local entries_by_line = {}

local function short_id(id)
  return id:sub(1, 8)
end

local function preview(content, width)
  width = width or 70
  local flattened = content:gsub("%s+", " ")
  if #flattened > width then
    return flattened:sub(1, width) .. "…"
  end
  return flattened
end

local function entry_at_cursor()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return entries_by_line[line]
end

local function render(entries)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  entries_by_line = {}
  local lines = {}
  if #entries == 0 then
    lines = { "(no clipboard history yet)" }
  else
    for i, entry in ipairs(entries) do
      lines[i] = string.format("%s  %s", short_id(entry.id), preview(entry.content))
      entries_by_line[i] = entry
    end
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function refresh()
  require("nvim-clipy").fetch({}, render)
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc, nowait = true, silent = true })
end

local function setup_buffer()
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "nvim-clipy"
  pcall(vim.api.nvim_buf_set_name, buf, "nvim-clipy://history")

  map("<CR>", function()
    local entry = entry_at_cursor()
    if entry then
      require("nvim-clipy").copy(entry.id)
    end
  end, "Copy entry under cursor")

  map("dd", function()
    local entry = entry_at_cursor()
    if entry then
      require("nvim-clipy").delete(entry.id)
      refresh()
    end
  end, "Delete entry under cursor")

  map("R", refresh, "Refresh clipboard history")

  map("q", "<cmd>close<cr>", "Close clipboard history")
  map("<Esc>", "<cmd>close<cr>", "Close clipboard history")
end

--- Opens (or focuses, if already open) the bottom split. Refreshes the list
--- either way.
function M.open()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local win = vim.fn.bufwinid(buf)
    if win ~= -1 then
      vim.api.nvim_set_current_win(win)
      refresh()
      return
    end
  end

  setup_buffer()
  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, buf)
  vim.api.nvim_win_set_height(0, math.min(15, math.floor(vim.o.lines * 0.4)))
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.wrap = false
  vim.wo.cursorline = true
  refresh()
end

return M
