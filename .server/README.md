# tts-mcp

Dev tooling, unrelated to the TTS scripts in `src/`. A zero-dependency MCP server (Node, stdio) that lets Claude talk to a running Tabletop Simulator through the [External Editor API](https://api.tabletopsimulator.com/externaleditorapi/) and screenshot its window.

Registered by `.mcp.json` at the repo root; restart Claude Code to load it.

## Tools

| Tool | Does |
|---|---|
| `tts_status` | API reachable? reply listener up? TTS window found? |
| `tts_lua` | Run Lua in Global or on an object; the Lua must `return` a value |
| `tts_log` | Buffered `print` / error / custom messages from TTS |
| `tts_objects` | List objects, filter by tag or name |
| `tts_get_scripts` | List scripts TTS holds, or fetch one body by guid |
| `tts_reload` | Save & Play (reloads the whole game) |
| `tts_screenshot` | PNG of the TTS window (Windows only, `capture.ps1`) |

## Ports

TTS listens on `39999`; the server listens on `39998` for replies. Override with `TTS_SEND_PORT` / `TTS_LISTEN_PORT`. Only one process can hold `39998`, so close other external editors (e.g. the VS Code TTS extension) while using this.

## Check

`node .server/selftest.mjs` runs the server against a fake TTS.

Screenshots copy the window's pixels from the screen, so the window must be visible (not covered or minimized).
