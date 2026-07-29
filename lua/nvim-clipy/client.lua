-- Low-level transport: speaks the clipy daemon's newline-delimited JSON
-- protocol over its Unix socket (see clipy-rust/src/protocol.rs). No
-- knowledge of clipboard semantics lives here, just request/response
-- plumbing.

local uv = vim.uv or vim.loop

local M = {}

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

--- Send a single request and invoke callback(err, response) exactly once.
--- `response` is the decoded JSON table on success (err is nil).
function M.request(socket_path, req, callback)
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
        -- EOF without a full line -- daemon closed early.
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

return M
