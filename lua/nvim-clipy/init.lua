local client = require("nvim-clipy.client")

local M = {}

M.config = {
  socket_path = vim.fn.expand("~/Library/Application Support/clipy-rust/clipy.sock"),
  history_limit = 30,
}

function M.setup(opts)
  -- recursively merge tables, with opts winning on conflicts
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "nvim-clipy" })
end

local function preview(content, width)
  width = width or 70
  local flattened = content:gsub("%s+", " ")
  if #flattened > width then
    return flattened:sub(1, width) .. "…"
  end
  return flattened
end

local function short_id(id)
  return id:sub(1, 8)
end

--- Runs `req` and calls `on_ok(response)` unless the daemon is unreachable or
--- returns an error, in which case a notification is shown and `on_ok` is
--- never called.
local function call(req, on_ok)
  client.request(M.config.socket_path, req, function(err, response)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    if response.status == "error" then
      notify(response.message, vim.log.levels.ERROR)
      return
    end
    on_ok(response)
  end)
end

--- Fetch history entries as a plain list of `{id, content, created_at,
--- updated_at}` tables. `callback(entries)` fires on success; errors are
--- notified and `callback` is not called.
function M.fetch(opts, callback)
  opts = opts or {}
  call({
    cmd = "list",
    limit = opts.limit or M.config.history_limit,
    query = opts.query,
  }, function(response)
    callback(response.entries or {})
  end)
end

function M.list()
  M.fetch({}, function(entries)
    if #entries == 0 then
      notify("(no clipboard history yet)")
      return
    end
    local lines = {}
    for _, entry in ipairs(entries) do
      table.insert(lines, string.format("%s  %s", short_id(entry.id), preview(entry.content)))
    end
    notify(table.concat(lines, "\n"))
  end)
end

--- Opens a scratch floating window showing an entry's full content.
local function open_preview_window(entry)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(entry.content, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local width = math.max(20, math.floor(vim.o.columns * 0.7))
  local height = math.max(5, math.floor(vim.o.lines * 0.6))
  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = string.format(" %s ", short_id(entry.id)),
  })
end

function M.show(id)
  call({ cmd = "show", id = id }, function(response)
    open_preview_window(response.entry)
  end)
end

function M.copy(id)
  call({ cmd = "copy", id = id }, function(response)
    notify(
      string.format("copied %s to the clipboard: %s", short_id(response.entry.id), preview(response.entry.content))
    )
  end)
end

function M.delete(id)
  call({ cmd = "delete", id = id }, function()
    notify("deleted " .. id)
  end)
end

function M.clear()
  call({ cmd = "clear" }, function()
    notify("cleared clipboard history")
  end)
end

function M.status()
  call({ cmd = "status" }, function(response)
    notify(
      string.format(
        "daemon:  running\nsocket:  %s\ndb:      %s\nentries: %d",
        response.socket_path,
        response.db_path,
        response.count
      )
    )
  end)
end

function M.kill()
  call({ cmd = "shutdown" }, function()
    notify("daemon stopped")
  end)
end

return M
