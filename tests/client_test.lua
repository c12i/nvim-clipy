-- Exercises Client against a real clipy daemon. Run via tests/run.sh.

vim.opt.rtp:prepend(vim.fn.getcwd())
local Client = require("nvim-clipy.client")

local passed, failed = 0, 0

local function check(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("ok   - " .. name)
  else
    failed = failed + 1
    print("FAIL - " .. name .. ": " .. tostring(err))
  end
end

local function wait_until(predicate, timeout)
  assert(vim.wait(timeout or 2000, predicate, 10), "condition was not met in time")
end

local function daemon_env(data_dir)
  local env = vim.fn.environ()
  env.CLIPY_DATA_DIR = data_dir
  local list = {}
  for name, value in pairs(env) do
    table.insert(list, name .. "=" .. value)
  end
  return list
end

local function spawn_daemon()
  local uv = vim.uv or vim.loop
  local data_dir = vim.fn.tempname()
  vim.fn.mkdir(data_dir, "p")
  local socket_path = data_dir .. "/clipy.sock"

  local handle = uv.spawn("clipy", {
    args = { "watch" },
    env = daemon_env(data_dir),
    stdio = { nil, nil, nil },
  }, function() end)
  assert(handle, "failed to spawn clipy daemon")
  wait_until(function()
    return uv.fs_stat(socket_path) ~= nil
  end, 5000)

  return {
    socket_path = socket_path,
    db_path = data_dir .. "/history.db",
    stop = function()
      pcall(function()
        uv.process_kill(handle, "sigterm")
      end)
      vim.fn.delete(data_dir, "rf")
    end,
  }
end

local function seed_entry(db_path, id, content, created_at, updated_at)
  local escaped = content:gsub("'", "''")
  local sql = string.format(
    "INSERT INTO history (id, content, created_at, updated_at) VALUES ('%s', '%s', %d, %d);",
    id,
    escaped,
    created_at,
    updated_at
  )
  vim.fn.system({ "sqlite3", db_path, sql })
  assert(vim.v.shell_error == 0, "failed to seed test entry")
end

check("Client.new gives independent instances sharing methods", function()
  local a = Client.new("/a")
  local b = Client.new("/b")
  assert(a.socket_path == "/a")
  assert(b.socket_path == "/b")
  assert(a.request == b.request)
  assert(getmetatable(a) == Client)
end)

check("Client.spawn_daemon returns not_installed when clipy is missing", function()
  local real_executable = vim.fn.executable
  vim.fn.executable = function(name)
    if name == "clipy" then
      return 0
    end
    return real_executable(name)
  end
  local result = Client.spawn_daemon("/tmp/wherever/clipy.sock")
  vim.fn.executable = real_executable
  assert(result == "not_installed", "expected not_installed, got " .. tostring(result))
end)

local daemon = spawn_daemon()

check("request() returns a Status response for a fresh daemon", function()
  local client = Client.new(daemon.socket_path)
  local err, response
  client:request({ cmd = "status" }, function(e, r)
    err, response = e, r
  end)
  wait_until(function()
    return response ~= nil
  end)
  assert(err == nil, "expected no error, got " .. tostring(err))
  assert(response.status == "status")
  assert(response.count == 0)
end)

check("call() routes a protocol-level error to on_err, not on_ok", function()
  local client = Client.new(daemon.socket_path)
  local ok_called, err_message
  client:call({ cmd = "delete", id = "doesnotexist" }, function()
    ok_called = true
  end, function(msg)
    err_message = msg
  end)
  wait_until(function()
    return err_message ~= nil
  end)
  assert(not ok_called, "on_ok should not have been called")
  assert(err_message:find("doesnotexist", 1, true), "expected message to mention the id")
end)

check("call() routes a transport-level failure to on_err", function()
  local client = Client.new("/tmp/definitely-not-a-real-clipy-socket.sock")
  local err_message
  client:call({ cmd = "status" }, function()
    error("on_ok should not be called for an unreachable daemon")
  end, function(msg)
    err_message = msg
  end)
  wait_until(function()
    return err_message ~= nil
  end)
  assert(err_message:find("could not reach", 1, true))
end)

check("call() delivers a seeded entry through list", function()
  seed_entry(daemon.db_path, "aaa111", "hello from a test", 1700000000, 1700000100)
  local client = Client.new(daemon.socket_path)
  local entries
  client:call({ cmd = "list", limit = 20 }, function(response)
    entries = response.entries
  end, function(err)
    error(err)
  end)
  wait_until(function()
    return entries ~= nil
  end)
  assert(#entries == 1, "expected 1 entry, got " .. #entries)
  assert(entries[1].id == "aaa111")
  assert(entries[1].content == "hello from a test")
end)

daemon.stop()

print(string.format("\n%d passed, %d failed", passed, failed))
vim.cmd("cquit " .. (failed > 0 and 1 or 0))
