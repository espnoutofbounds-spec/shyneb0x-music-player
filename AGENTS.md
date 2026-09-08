# Agent setup (after you download this repo)

This file is for an agent on the machine that cloned the repo. The player does not download music. You only add local `.mp3` / `.wav` paths that already exist on that computer.

The display name is **ShyneB0X** (digit zero, not the letter O).

## What you need

1. This repo, checked out on the same machine as the music files.
2. Python 3. No pip install. The MCP server uses the standard library only.
3. The player running, so it can see new tracks. Either press F5 in Godot 4.7, or run the exported `ShyneB0X.exe` after it exists. If the player is closed, `add_tracks` only queues files. Nothing plays until the player is open and polling.

## Register the MCP

stdio server. Working directory must be the repo root (the folder that contains `tools/`).

```json
{
  "mcpServers": {
    "shyneb0x-playlist": {
      "command": "python",
      "args": ["tools/playlist-mcp/server.py"]
    }
  }
}
```

On Windows, if `python` is not on PATH, use `py` instead. Set the client working directory to the repo root. Do not pass an API key. There is none.

## Tools

- `add_tracks` — queue absolute local `.mp3` / `.wav` paths
- `list_playlist` — current list plus anything still waiting in the inbox
- `play` — play a name or path already on disk (adds it first if needed)
- `pause`
- `stop`

Do not search the web. Do not pass a URL. Do not pass a relative path.

## Where the inbox lives

Not in this repo. Do not create an inbox folder by hand, and do not use the repo `inbox` folder. The first `add_tracks`, `play`, `pause`, or `stop` creates the Godot user-data inbox if it is missing. The player creates that same folder when it writes a file back.

The player and the MCP share Godot user data:

`%APPDATA%\Godot\app_userdata\ShyneB0X Music Player\inbox\`

- `add.json` — paths to append
- `control.json` — play, pause, or stop, then the player clears it

The player polls about every 0.45 seconds. Send one control at a time. A second write in that window can be dropped.

## Quick check

1. Start the player.
2. Call `add_tracks` with one real local `.wav` or `.mp3`.
3. Call `list_playlist` and confirm the path is there.
4. Call `play` with that file name. The player should show it playing.