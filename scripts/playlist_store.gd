class_name PlaylistStore
extends RefCounted

## user://player_state.json — keys: volume (0..1), playlist (string paths), skin ("2003"|"cyber").
## Stored id "2003" is the gray "Retro Chrome" theme. Missing/empty skin = cyber.

const SAVE_PATH := "user://player_state.json"
const DEFAULT_VOLUME := 0.85
const SKIN_2003 := "2003"
const SKIN_CYBER := "cyber"


func load_state() -> Dictionary:
	var fallback := {
		"volume": DEFAULT_VOLUME,
		"playlist": PackedStringArray(),
		"skin": SKIN_CYBER,
	}
	if not FileAccess.file_exists(SAVE_PATH):
		return fallback
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("PlaylistStore: could not read %s" % SAVE_PATH)
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("PlaylistStore: ignoring malformed JSON")
		return fallback
	var data := parsed as Dictionary
	var volume := clampf(float(data.get("volume", DEFAULT_VOLUME)), 0.0, 1.0)
	var paths := PackedStringArray()
	var raw: Variant = data.get("playlist", [])
	if raw is Array:
		for item: Variant in raw:
			if item is String:
				var path := item as String
				if not path.is_empty():
					paths.append(path)
	return {
		"volume": volume,
		"playlist": paths,
		"skin": normalize_skin(str(data.get("skin", SKIN_CYBER))),
	}


func save_state(volume: float, playlist: PackedStringArray, skin: String) -> void:
	var payload := {
		"volume": clampf(volume, 0.0, 1.0),
		"playlist": Array(playlist),
		"skin": normalize_skin(skin),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("PlaylistStore: could not write %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))


static func normalize_skin(skin: String) -> String:
	if skin == SKIN_2003:
		return SKIN_2003
	return SKIN_CYBER
