-- Lightweight TCP JSON API server embedded into the GUI process.
-- Uses LuaSocket; listens on 127.0.0.1:POB_API_TCP_PORT (default 31337).

local ok_socket, socket = pcall(require, 'socket')
if not ok_socket then
  ConPrintf('[API/TcpServer] LuaSocket not available; TCP API disabled')
  return
end

-- JSON
local ok_json, json = pcall(require, 'dkjson')
if not ok_json then
  local base = rawget(_G, 'POB_SCRIPT_DIR') or '.'
  local candidates = {
    base .. '/runtime/lua/dkjson.lua',
    base .. '/../runtime/lua/dkjson.lua',
    'runtime/lua/dkjson.lua',
    '../runtime/lua/dkjson.lua',
  }
  for _, p in ipairs(candidates) do
    local ok2, mod = pcall(dofile, p)
    if ok2 and type(mod) == 'table' then json = mod; ok_json = true; break end
  end
  if not ok_json then error('[API/TcpServer] dkjson not found') end
end

local function j_encode(tbl) return json.encode(tbl, { indent = false }) end
local function j_decode(txt) return json.decode(txt) end

-- Load common handlers
local API = require('API.Handlers')
local handlers = API.handlers
local function get_version_meta()
  return API.version_meta()
end

-- Server state
local srv
local clients = {}
local buffers = {}

local function sendLine(client, tbl)
  local ok, msg = pcall(j_encode, tbl)
  if not ok then msg = '{"ok":false,"error":"encode error"}' end
  client:send(msg .. "\n")
end

local function handleLine(client, line)
  local ok, req = pcall(j_decode, line)
  if not ok or type(req) ~= 'table' then
    sendLine(client, { ok = false, error = 'invalid json' })
    return
  end
  local action = req.action
  local params = req.params or {}
  local handler = handlers[action]
  if not handler then
    sendLine(client, { ok = false, error = 'unknown action: ' .. tostring(action) })
    return
  end
  local ok2, res = pcall(handler, params)
  if not ok2 then
    sendLine(client, { ok = false, error = 'exception: ' .. tostring(res) })
  else
    sendLine(client, res)
  end
end

function API_TCP_INIT()
  local port = tonumber(os.getenv('POB_API_TCP_PORT') or '31337') or 31337
  srv = assert(socket.tcp())
  assert(srv:setoption('reuseaddr', true))
  assert(srv:bind('127.0.0.1', port))
  assert(srv:listen(16))
  srv:settimeout(0)
  ConPrintf('[API/TcpServer] Listening on 127.0.0.1:%d', port)
end

function API_TCP_TICK()
  -- accept new client(s)
  local client = srv and srv:accept()
  while client do
    client:settimeout(0)
    table.insert(clients, client)
    buffers[client] = ''
    sendLine(client, { ok = true, ready = true, version = get_version_meta() })
    client = srv:accept()
  end

  if #clients == 0 then return end
  -- poll readable
  local readable = socket.select(clients, nil, 0)
  for _, c in ipairs(readable) do
    local line, err, partial = c:receive('*l')
    if line then
      handleLine(c, line)
    elseif err == 'closed' then
      -- cleanup
      buffers[c] = nil
      for i, cc in ipairs(clients) do if cc == c then table.remove(clients, i); break end end
    end
  end
end
