# ShyneB0X Music Player

A small local music player. Default look is **Cyber**. The other skin is **Retro Chrome**.

The name is **ShyneB0X** (digit zero, not the letter O).

It plays files you add. No streaming, no accounts, no web search. Music stays on the computer that has the files. The player remembers the last list of paths, plus volume and skin. It does not copy the audio. If a file moves, that row comes back missing.

## After you download

This repo is the source. The Windows exe is not in Git.

1. Install Godot 4.7.
2. Open this folder as a project.
3. Press Play.

**Add files**, then play. **Mini** shrinks to a strip. **Full** on the strip brings the window back. **Full screen** on the EQ row opens the visualizer. Esc or Exit returns.

Want a double-click app? Use the Windows Desktop export preset. It writes `build/ShyneB0X.exe` on your machine. That file stays out of Git. On Windows, Godot needs [rcedit](https://github.com/electron/rcedit/releases/download/v2.0.0/rcedit-x64.exe) if you want the icon stamped onto the exe.

## Agents on the machine that downloaded this

Another agent can add local tracks and play them. It cannot search the web or download music. Full steps are in `AGENTS.md`.

1. Python 3. No pip install.
2. Working directory is this repo (the folder that contains `tools/`).
3. Start the player, then point the agent at:

```
python tools/playlist-mcp/server.py
```

On Windows, use `py` instead if `python` is not on PATH.

Tools: `add_tracks`, `list_playlist`, `play`, `pause`, `stop`. Pass absolute `.mp3` or `.wav` paths that already exist on that computer. No URLs.

Do not create an inbox folder. Do not use an `inbox` folder inside this repo. The first `add_tracks`, `play`, `pause`, or `stop` creates the inbox in Godot user data for **this** install, under the app name `ShyneB0X Music Player`. On Windows that folder is:

`%APPDATA%\Godot\app_userdata\ShyneB0X Music Player\inbox\`

`add.json` queues paths. `control.json` is play, pause, or stop. The player polls about every 0.45 seconds, then clears the file. Send one control at a time. If the player is closed, paths queue and nothing plays until it is open.

## License

MIT. If you use this code, keep the copyright notice (credit **ShyneB0X**).