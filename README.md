# ShyneB0X Music Player

A small local Windows music player. Default look is **Cyber**. The other skin is **Retro Chrome**.

The name is **ShyneB0X** (digit zero, not the letter O).

It plays files you add. No streaming, no accounts, no web search. No install. Double-click the exe and it runs. Music stays on your computer. The player remembers the last list of paths, plus volume and skin. It does not copy the audio. If a file moves, that row comes back missing.

## Download

Get the Windows app. You do not need Godot.

[Download ShyneB0X.exe](https://github.com/espnoutofbounds-spec/shyneb0x-music-player/releases/download/v1.0.0/ShyneB0X.exe)

Open that file. Nothing to install.

**Add files**, then play. **Mini** shrinks to a strip. **Full** on the strip brings the window back. **Full screen** on the EQ row opens the visualizer. Esc or Exit returns.

## Agents

Another agent on the same computer can add local tracks and play them. It cannot search the web or download music.

The player has to be open. The agent does not create an inbox folder. The first add or play creates it on that computer, under Godot user data for the app name `ShyneB0X Music Player`. On Windows:

`%APPDATA%\Godot\app_userdata\ShyneB0X Music Player\inbox\`

Full agent steps, including the MCP command, are in `AGENTS.md`. That file is for someone who cloned this repo to run the helper. Playing the app does not require it.

## If you want to change the code

The source is in this repo. Open it in Godot 4.7 only if you are editing the player. People who just want the app should use the exe above.

## License

MIT. If you use this code, keep the copyright notice (credit **ShyneB0X**).