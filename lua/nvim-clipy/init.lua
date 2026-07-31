local Client = require("nvim-clipy.client")

local M = {}

--- Mirrors `dirs::data_dir()` on the daemon side (clipy-rust/src/daemon.rs):
--- $CLIPY_DATA_DIR if set, else the OS-conventional per-user data dir.
local function default_data_dir()
  local override = vim.env.CLIPY_DATA_DIR
  if override and override ~= "" then
    return override
  end

  if vim.fn.has("mac") == 1 then
    return vim.fn.expand("~/Library/Application Support/clipy-rust")
  end

  if vim.fn.has("win32") == 1 and vim.env.APPDATA then
    return vim.env.APPDATA .. "/clipy-rust"
  end

  local xdg_data_home = vim.env.XDG_DATA_HOME
  if xdg_data_home and xdg_data_home ~= "" then
    return xdg_data_home .. "/clipy-rust"
  end
  return vim.fn.expand("~/.local/share/clipy-rust")
end

M.config = {
  socket_path = default_data_dir() .. "/clipy.sock",
  history_limit = 30,
}

-- Recreated in M.setup() below so it never goes stale.
local client = Client.new(M.config.socket_path)

function M.setup(opts)
  -- recursively merge tables, with opts winning on conflicts
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  client = Client.new(M.config.socket_path)
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

--- Notifies for a Client.spawn_daemon() result; returns whether it started.
local function start_daemon()
  local result = Client.spawn_daemon(M.config.socket_path)
  if result == "not_installed" then
    notify(
      "`clipy` binary not found on $PATH, clipboard history daemon not started (install with `cargo install clipy`)",
      vim.log.levels.WARN
    )
    return false
  end
  if result == "spawn_failed" then
    notify("failed to start the clipy daemon", vim.log.levels.ERROR)
    return false
  end
  return true
end

--- Starts the daemon if unreachable. `verbose` (for a manual :ClipyStart)
--- also notifies on "already running"/"started"; VimEnter's call omits it
--- so it doesn't notify every startup.
function M.ensure_daemon(verbose)
  local uv = vim.uv or vim.loop
  local pipe = uv.new_pipe(false)
  pipe:connect(M.config.socket_path, function(err)
    pipe:close()
    if not err then
      if verbose then
        vim.schedule(function()
          notify("daemon already running")
        end)
      end
      return
    end
    vim.schedule(function()
      if start_daemon() and verbose then
        notify("daemon started")
      end
    end)
  end)
end

local function on_err(err)
  notify(err, vim.log.levels.ERROR)
end

--- Fetches entries as `{id, content, created_at, updated_at}` tables into
--- `callback`; on error, notifies instead of calling it.
function M.fetch(opts, callback)
  opts = opts or {}
  client:call({
    cmd = "list",
    limit = opts.limit or M.config.history_limit,
    query = opts.query,
  }, function(response)
    callback(response.entries or {})
  end, on_err)
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

function M.copy(id)
  client:call({ cmd = "copy", id = id }, function(response)
    notify(
      string.format("copied %s to the clipboard: %s", short_id(response.entry.id), preview(response.entry.content))
    )
  end, on_err)
end

function M.delete(id)
  client:call({ cmd = "delete", id = id }, function()
    notify("deleted " .. id)
  end, on_err)
end

function M.clear()
  client:call({ cmd = "clear" }, function()
    notify("cleared clipboard history")
  end, on_err)
end

function M.status()
  client:call({ cmd = "status" }, function(response)
    notify(
      string.format(
        "daemon:  running\nsocket:  %s\ndb:      %s\nentries: %d",
        response.socket_path,
        response.db_path,
        response.count
      )
    )
  end, on_err)
end

function M.kill()
  client:call({ cmd = "shutdown" }, function()
    notify("daemon stopped")
  end, on_err)
end

return M
