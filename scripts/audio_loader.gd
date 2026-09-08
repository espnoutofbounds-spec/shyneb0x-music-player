class_name AudioLoader
extends RefCounted

const EXTENSIONS: PackedStringArray = ["mp3", "ogg", "wav"]


static func is_supported(path: String) -> bool:
	return path.get_extension().to_lower() in EXTENSIONS


static func load_stream(path: String) -> AudioStream:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var ext := path.get_extension().to_lower()
	match ext:
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
		"wav":
			return AudioStreamWAV.load_from_file(path)
		_:
			return null
