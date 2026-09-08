#!/usr/bin/env python3
"""ShyneB0X Music Player playlist MCP (stdio, stdlib only). Local files only."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

APP_NAME = "ShyneB0X Music Player"
USER_DIR = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / APP_NAME
INBOX_ADD = USER_DIR / "inbox" / "add.json"
INBOX_CONTROL = USER_DIR / "inbox" / "control.json"
USER_STATE = USER_DIR / "player_state.json"
PROTOCOL = "2024-11-05"


def _read_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(payload, indent="\t") + "\n", encoding="utf-8")
    tmp.replace(path)


def _canon(path: str) -> str:
    return path.strip().replace("\\", "/")


def add_tracks(paths: list) -> str:
    data = _read_json(INBOX_ADD)
    existing = data.get("paths", [])
    if not isinstance(existing, list):
        existing = []
    seen = {_canon(str(p)).lower() for p in existing}
    merged = [str(p) for p in existing]
    added = 0
    for raw in paths:
        if not isinstance(raw, str) or not raw.strip():
            continue
        key = _canon(raw).lower()
        if key in seen:
            continue
        seen.add(key)
        merged.append(raw.strip())
        added += 1
    _write_json(INBOX_ADD, {"paths": merged})
    return f"queued {added} path(s); inbox has {len(merged)}"


def list_playlist() -> str:
    state = _read_json(USER_STATE)
    playlist = state.get("playlist", [])
    if not isinstance(playlist, list):
        playlist = []
    pending = _read_json(INBOX_ADD).get("paths", [])
    if not isinstance(pending, list):
        pending = []
    seen = {_canon(str(p)).lower() for p in playlist}
    merged = [str(p) for p in playlist]
    for raw in pending:
        if not isinstance(raw, str):
            continue
        key = _canon(raw).lower()
        if key in seen:
            continue
        seen.add(key)
        merged.append(raw)
    return json.dumps({"playlist": merged, "pending_inbox": pending}, indent="\t")


def write_control(op: str, query: str = "", path: str = "") -> str:
    payload: dict = {"op": op}
    if query:
        payload["query"] = query
    if path:
        payload["path"] = path
    _write_json(INBOX_CONTROL, payload)
    return f"wrote control op={op}"


TOOLS = [
    {
        "name": "add_tracks",
        "description": "Queue absolute local .mp3/.wav paths for the running player inbox. No download.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "paths": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Absolute filesystem paths",
                }
            },
            "required": ["paths"],
        },
    },
    {
        "name": "list_playlist",
        "description": "List persisted playlist plus pending inbox/add.json paths.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "play",
        "description": "Play a local track by filename query or absolute path.",
        "inputSchema": {
            "type": "object",
            "properties": {"query": {"type": "string"}},
            "required": ["query"],
        },
    },
    {
        "name": "pause",
        "description": "Pause playback.",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "stop",
        "description": "Stop playback.",
        "inputSchema": {"type": "object", "properties": {}},
    },
]


def _handle_call(name: str, arguments: dict) -> str:
    if name == "add_tracks":
        paths = arguments.get("paths", [])
        if not isinstance(paths, list):
            return "paths must be an array of strings"
        return add_tracks(paths)
    if name == "list_playlist":
        return list_playlist()
    if name == "play":
        query = str(arguments.get("query", ""))
        if not query.strip():
            return "play needs query"
        if os.path.isabs(query):
            return write_control("play", path=query)
        return write_control("play", query=query)
    if name == "pause":
        return write_control("pause")
    if name == "stop":
        return write_control("stop")
    return f"unknown tool {name}"


def _read_message() -> dict | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        decoded = line.decode("utf-8", errors="replace").strip()
        if ":" not in decoded:
            continue
        key, value = decoded.split(":", 1)
        headers[key.strip().lower()] = value.strip()
    length = int(headers.get("content-length", "0"))
    if length <= 0:
        return None
    body = sys.stdin.buffer.read(length)
    return json.loads(body.decode("utf-8"))


def _write_message(payload: dict) -> None:
    raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(raw)}\r\n\r\n".encode("ascii") + raw)
    sys.stdout.buffer.flush()


def main() -> None:
    while True:
        msg = _read_message()
        if msg is None:
            return
        method = msg.get("method", "")
        msg_id = msg.get("id")
        if method == "initialize":
            _write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "protocolVersion": PROTOCOL,
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": "shyneb0x-playlist", "version": "1.0.0"},
                    },
                }
            )
            continue
        if method == "notifications/initialized" or msg_id is None:
            continue
        if method == "tools/list":
            _write_message({"jsonrpc": "2.0", "id": msg_id, "result": {"tools": TOOLS}})
            continue
        if method == "tools/call":
            params = msg.get("params") or {}
            name = str(params.get("name", ""))
            arguments = params.get("arguments") or {}
            if not isinstance(arguments, dict):
                arguments = {}
            text = _handle_call(name, arguments)
            _write_message(
                {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {"content": [{"type": "text", "text": text}]},
                }
            )
            continue
        _write_message(
            {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {"code": -32601, "message": f"Unknown method {method}"},
            }
        )


if __name__ == "__main__":
    main()
