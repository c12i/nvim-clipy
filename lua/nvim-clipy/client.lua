-- Low-level transport: speaks the clipy daemon's newline-delimited JSON
-- protocol over its Unix socket (see clipy-rust/src/protocol.rs). No
-- knowledge of clipboard semantics lives here, just request/response
-- plumbing.

local uv = vim.uv or vim.loop

---@class Client
---@field socket_path string
local Client = {}
Client.__index = Client

--- Creates a new Client bound to `socket_path`.
---@param socket_path string
---@return Client
function Client.new(socket_path)
  return setmetatable({ socket_path = socket_path }, Client)
end

--- Feeds `chunk` into `buffer`, invoking `on_line` for each complete
--- newline-terminated line found. Returns the leftover (possibly empty)
--- buffer to carry into the next chunk.
local function consume_lines(buffer, chunk, on_line)
  buffer = buffer .. chunk
  while true do
    local nl = buffer:find("\n", 1, true)
    if not nl then
      break
    end
    local line = buffer:sub(1, nl - 1)
    buffer = buffer:sub(nl + 1)
    if #line > 0 then
      on_line(line)
    end
  end
  return buffer
end

local function connect_err(socket_path, err)
  return string.format(
    "could not reach the clipy daemon at %s (%s)\nstart it first, e.g. in another terminal: clipy watch",
    socket_path,
    tostring(err)
  )
end

--- Sends `req` and invokes callback(err, response) exactly once.
---@param req table
---@param callback fun(err: string?, response: table?)
function Client:request(req, callback)
  local socket_path = self.socket_path
  local pipe = uv.new_pipe(false)

  pipe:connect(socket_path, function(err)
    if err then
      pipe:close()
      vim.schedule(function()
        callback(connect_err(socket_path, err))
      end)
      return
    end

    local ok, encoded = pcall(vim.json.encode, req)
    if not ok then
      pipe:close()
      vim.schedule(function()
        callback("failed to encode request: " .. tostring(encoded))
      end)
      return
    end
    pipe:write(encoded .. "\n")

    local buffer = ""
    local done = false
    pipe:read_start(function(read_err, chunk)
      if done then
        return
      end
      if read_err then
        done = true
        pipe:close()
        vim.schedule(function()
          callback("error reading from clipy daemon: " .. tostring(read_err))
        end)
        return
      end
      if not chunk then
        -- EOF without a full line: daemon closed early.
        if not done then
          done = true
          pipe:close()
          vim.schedule(function()
            callback("clipy daemon closed the connection without responding")
          end)
        end
        return
      end
      buffer = consume_lines(buffer, chunk, function(line)
        if done then
          return
        end
        done = true
        pipe:read_stop()
        pipe:close()
        local decode_ok, decoded = pcall(vim.json.decode, line)
        vim.schedule(function()
          if decode_ok then
            callback(nil, decoded)
          else
            callback("invalid response from clipy daemon: " .. line)
          end
        end)
      end)
    end)
  end)
end

--- Like `request`, but splits transport failure vs. `{status = "error"}`
--- into a single `on_err`, so callers only handle one error path.
---@param req table
---@param on_ok fun(response: table)
---@param on_err fun(message: string)
function Client:call(req, on_ok, on_err)
  self:request(req, function(err, response)
    if err then
      on_err(err)
      return
    end
    if response.status == "error" then
      on_err(response.message)
      return
    end
    on_ok(response)
  end)
end

-- uv.spawn's `env` replaces the child's environment rather than extending
-- it, so this carries over the current one (PATH, HOME, ...) plus
-- CLIPY_DATA_DIR, rather than just passing the latter alone.
local function daemon_env(socket_path)
  local env = vim.fn.environ()
  env.CLIPY_DATA_DIR = vim.fn.fnamemodify(socket_path, ":h")
  local list = {}
  for name, value in pairs(env) do
    table.insert(list, name .. "=" .. value)
  end
  return list
end

--- Spawns `clipy watch` detached at `socket_path`. Not an instance method:
--- spawning isn't tied to any particular Client.
---@param socket_path string
---@return "not_installed"|"spawn_failed"|"started"
function Client.spawn_daemon(socket_path)
  if vim.fn.executable("clipy") == 0 then
    return "not_installed"
  end

  local handle
  handle = uv.spawn("clipy", {
    args = { "watch" },
    env = daemon_env(socket_path),
    detached = true,
    stdio = { nil, nil, nil },
  }, function()
    if handle then
      handle:close()
    end
  end)

  if not handle then
    return "spawn_failed"
  end
  handle:unref()
  return "started"
end

return Client
