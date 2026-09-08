# ShyneB0X Music Player

A small local music player made in Godot 4. Default look is **Cyber**. The other skin is **Retro Chrome**.

Not a library app. It plays files you add. No streaming, no accounts.

## Run in the editor

1. Open this project folder in Godot 4.7.
2. Press F5.
3. **Add files**, then Play.
4. **Full screen** on the EQ row opens the visualizer. Esc or Exit returns.
5. **Mini** shrinks to a strip. **Full** on the strip brings the main window back.

## Agent inbox (local files only)

This player does **not** search the web, download, or use YouTube. Another agent can only add **absolute** `.mp3` / `.wav` paths already on that machine.

The editor and the exported exe poll the same Godot user-data inbox. MCP writes those same files. Do not use the repo `inbox` folder.

**Add** (the running player polls this file):

`%APPDATA%\Godot\app_userdata\ShyneB0X Music Player\inbox\add.json`

```json
{"paths": ["C:\\Music\\track.wav"]}
```

**Play / pause / stop** (polled the same way, then cleared):

`%APPDATA%\Godot\app_userdata\ShyneB0X Music Player\inbox\control.json`

```json
{"op": "play", "query": "track.wav"}
```

The player appends new accepted paths (no duplicates), then rewrites `add.json` to `{"paths":[]}`. After applying a control op it clears `control.json`. Poll interval is about 0.45s, plus once on launch after playlist restore.

**MCP** ships in the repo too. It is not inside the Windows exe. Python 3, stdlib only, no pip install. From the project folder:

```
python tools/playlist-mcp/server.py
```

Point the agent at that command. Tools: `add_tracks`, `list_playlist`, `play`, `pause`, `stop`. The server writes the inbox files only. It does **not** write Godot `user://player_state.json` while the player may be running. `list_playlist` reads `%APPDATA%\Godot\app_userdata\ShyneB0X Music Player\player_state.json` and merges pending `add.json` from that same user-data inbox folder.

## Export

The Windows `.exe` is the player only. The MCP stays in `tools/playlist-mcp` and is not bundled into the exe. This repo is not published yet.

## License

MIT. If you use this code, keep the copyright notice (credit **ShyneB0X**).