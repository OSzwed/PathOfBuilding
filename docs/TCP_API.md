# PoB API: Embedded TCP Server

The embedded TCP server exposes the same JSON actions as the stdio server, but listens on localhost for TCP connections.

- Enable with env var `POB_API_TCP=1`
- Port via `POB_API_TCP_PORT` (default `31337`)
- Bind address: `127.0.0.1`

## Startup

When enabled, the GUI process loads `API/TcpServer.lua` and starts a nonblocking server. On client connect, it sends a single JSON line:

```json
{"ok":true,"ready":true,"version":{"number":"...","branch":"...","platform":"..."}}
```

Subsequent communication is line-delimited JSON requests and responses, one per line.

## Example

```
# In the environment that runs Path of Building GUI
export POB_API_TCP=1
export POB_API_TCP_PORT=31337  # optional

# Then from another shell:
nc 127.0.0.1 31337
{"action":"ping"}
{"ok":true,"pong":true}
```

## Actions

Actions and response shapes match the stdio API. See `API_README.md` for examples such as `version`, `load_build_xml`, `get_stats`, `get_tree`, `set_tree`, etc.

