extends Control

const SEEK_STEP := 5.0
const VOLUME_STEP := 0.05
const MISSING_PREFIX := "[missing] "
const THEME_2003: Theme = preload("res://themes/chrome_2003.tres")
const THEME_CYBER: Theme = preload("res://themes/cyber.tres")
const MINI_SIZE := Vector2i(560, 108)
const MINI_MIN_SIZE := Vector2i(480, 90)

@onready var _now_label: Label = %NowLabel
@onready var _time_label: Label = %TimeLabel
@onready var _status_label: Label = %StatusLabel
@onready var _seek_slider: HSlider = %SeekSlider
@onready var _play_button: Button = %PlayButton
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _playlist: ItemList = %PlaylistList
@onready var _eq_header: Label = %EqHeader
@onready var _eq_bars: EqBars = %EqBars
@onready var _play_led: ColorRect = %PlayLed
@onready var _player: AudioStreamPlayer = %Player
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _chrome: Control = %Chrome
@onready var _fullscreen_layer: Control = %FullscreenLayer
@onready var _fullscreen_bars: EqBars = %FullscreenBars
@onready var _fullscreen_button: Button = %FullscreenButton
@onready var _exit_viz_button: Button = %ExitVizButton
@onready var _skin_option: OptionButton = %SkinOption
@onready var _title_label: Label = %TitleLabel
@onready var _skin_badge: Label = %SkinBadge
@onready var _accent: ColorRect = %Accent
@onready var _full_bg: ColorRect = %FullBg
@onready var _mini_button: Button = %MiniButton
@onready var _split: Control = %Split
@onready var _lcd_row: Control = %LcdRow
@onready var _vol_label: Control = %VolLabel
@onready var _transport_spacer: Control = %Spacer
@onready var _prev_button: Button = %PrevButton
@onready var _stop_button: Button = %StopButton
@onready var _next_button: Button = %NextButton
@onready var _title_bar: Control = %TitleBar
@onready var _main_pad: MarginContainer = %MainPad
@onready var _transport: HBoxContainer = %Transport
@onready var _chrome_layout: VBoxContainer = %Layout

var _store: PlaylistStore = PlaylistStore.new()
var _paths: PackedStringArray = PackedStringArray()
var _index: int = -1
var _ignore_seek: bool = false
var _paused: bool = false
var _viz_fullscreen: bool = false
var _saved_mode: Window.Mode = Window.MODE_WINDOWED
var _saved_size: Vector2i = Vector2i(720, 480)
var _saved_position: Vector2i = Vector2i.ZERO
var _skin: String = PlaylistStore.SKIN_CYBER
var _mini_active: bool = false
var _mini_saved_mode: Window.Mode = Window.MODE_WINDOWED
var _mini_saved_size: Vector2i = Vector2i(720, 512)
var _mini_saved_position: Vector2i = Vector2i.ZERO
var _mini_saved_min: Vector2i = Vector2i(640, 440)
var _mini_saved_scale_mode: Window.ContentScaleMode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
var _mini_saved_scale_aspect: Window.ContentScaleAspect = Window.CONTENT_SCALE_ASPECT_EXPAND
var _mini_saved_scale_size: Vector2i = Vector2i(720, 512)
var _mini_button_home: Node = null
var _mini_button_index: int = 0


func _ready() -> void:
	get_window().title = "ShyneB0X Music Player"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	_file_dialog.use_native_dialog = true
	_file_dialog.filters = PackedStringArray([
		"*.mp3,*.ogg,*.wav;Audio files",
		"*.mp3;MP3",
		"*.ogg;Ogg Vorbis",
		"*.wav;WAV",
	])
	var music_dir := OS.get_system_dir(OS.SYSTEM_DIR_MUSIC)
	if not music_dir.is_empty():
		_file_dialog.current_dir = music_dir
	%AddButton.pressed.connect(_on_add_pressed)
	%RemoveButton.pressed.connect(_on_remove_pressed)
	%PrevButton.pressed.connect(_play_relative.bind(-1))
	%PlayButton.pressed.connect(_toggle_play)
	%StopButton.pressed.connect(_stop)
	%NextButton.pressed.connect(_play_relative.bind(1))
	_seek_slider.value_changed.connect(_on_seek_changed)
	_volume_slider.value_changed.connect(_on_volume_changed)
	_playlist.item_activated.connect(_on_item_activated)
	_player.finished.connect(_on_track_finished)
	_eq_bars.demo_mode_changed.connect(_on_eq_demo_changed)
	_file_dialog.files_selected.connect(_add_files)
	_fullscreen_button.pressed.connect(_enter_fullscreen_viz)
	_exit_viz_button.pressed.connect(_exit_fullscreen_viz)
	_skin_option.clear()
	_skin_option.add_item("Retro Chrome", 0)
	_skin_option.add_item("Cyber", 1)
	_skin_option.item_selected.connect(_on_skin_selected)
	_mini_button.pressed.connect(toggle_mini)
	_now_label.gui_input.connect(_on_now_gui_input)
	get_window().files_dropped.connect(_on_files_dropped)
	tree_exiting.connect(_persist)
	DisplayServer.window_set_flag(
		DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,
		false,
		get_window().get_window_id()
	)
	var music_bus := EqBars.ensure_music_bus()
	EqBars.ensure_analyzer(music_bus)
	_player.bus = EqBars.BUS_NAME
	_restore()
	_set_idle_chrome()
	_refresh_playlist()
	_apply_volume(_volume_slider.value)
	_poll_inbox()
	_poll_control()
	var inbox_timer := Timer.new()
	inbox_timer.wait_time = 0.45
	inbox_timer.autostart = true
	inbox_timer.timeout.connect(_on_inbox_tick)
	add_child(inbox_timer)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode != KEY_ESCAPE:
		return
	if _viz_fullscreen:
		_exit_fullscreen_viz()
		get_viewport().set_input_as_handled()
	elif _mini_active:
		exit_mini()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _file_dialog.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		if _viz_fullscreen:
			_exit_fullscreen_viz()
			get_viewport().set_input_as_handled()
			return
		if _mini_active:
			exit_mini()
			get_viewport().set_input_as_handled()
			return
	match key.keycode:
		KEY_SPACE:
			_toggle_play()
			get_viewport().set_input_as_handled()
		KEY_LEFT:
			_nudge_seek(-SEEK_STEP)
			get_viewport().set_input_as_handled()
		KEY_RIGHT:
			_nudge_seek(SEEK_STEP)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_volume_slider.value = clampf(_volume_slider.value + VOLUME_STEP, 0.0, 1.0)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_volume_slider.value = clampf(_volume_slider.value - VOLUME_STEP, 0.0, 1.0)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var live := _player.playing and not _player.stream_paused
	var pos := _player.get_playback_position()
	_eq_bars.set_playback(live, pos)
	_fullscreen_bars.set_playback(live, pos)
	_update_transport_chrome()
	if _player.stream == null:
		return
	var length := _player.stream.get_length()
	_ignore_seek = true
	_seek_slider.max_value = maxf(length, 0.001)
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_seek_slider.value = pos
	_ignore_seek = false
	_time_label.text = "%s  /  %s" % [_format_time(pos), _format_time(length)]


func _restore() -> void:
	var state := _store.load_state()
	_volume_slider.value = float(state["volume"])
	var loaded: PackedStringArray = state["playlist"]
	for path in loaded:
		_paths.append(path)
	apply_skin(str(state.get("skin", PlaylistStore.SKIN_CYBER)), false)


func _persist() -> void:
	_store.save_state(_volume_slider.value, _paths, _skin)


func _on_add_pressed() -> void:
	_file_dialog.popup_centered_ratio(0.7)


func _on_files_dropped(files: PackedStringArray) -> void:
	var accepted := PackedStringArray()
	for path in files:
		if AudioLoader.is_supported(path):
			accepted.append(path)
	if accepted.size() > 0:
		_add_files(accepted)


func _add_files(files: PackedStringArray) -> void:
	var added := 0
	for path in files:
		if not AudioLoader.is_supported(path):
			continue
		if _has_track(path):
			continue
		_paths.append(_canon_path(path))
		added += 1
	if added == 0:
		return
	_refresh_playlist()
	_persist()
	_status_label.text = "Added %d file%s" % [added, "" if added == 1 else "s"]


func _on_inbox_tick() -> void:
	_poll_inbox()
	_poll_control()


func _inbox_add_path() -> String:
	return ProjectSettings.globalize_path("user://inbox/add.json")


func _inbox_control_path() -> String:
	return ProjectSettings.globalize_path("user://inbox/control.json")


func _canon_path(path: String) -> String:
	return path.strip_edges().replace("\\", "/")


func _path_key(path: String) -> String:
	return _canon_path(path).to_lower()


func _has_track(path: String) -> bool:
	var key := _path_key(path)
	for existing in _paths:
		if _path_key(existing) == key:
			return true
	return false


func _is_inbox_audio(path: String) -> bool:
	var ext := path.get_extension().to_lower()
	return ext == "mp3" or ext == "wav"


func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())


func _write_json_file(path: String, data: Dictionary) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


func _poll_inbox() -> void:
	var path := _inbox_add_path()
	var parsed: Variant = _read_json_file(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data := parsed as Dictionary
	var raw: Variant = data.get("paths", [])
	if not (raw is Array):
		return
	if (raw as Array).is_empty():
		return
	var accepted := PackedStringArray()
	for item: Variant in raw:
		if not (item is String):
			continue
		var abs_path := _canon_path(item as String)
		if abs_path.is_empty() or not abs_path.is_absolute_path():
			continue
		if not _is_inbox_audio(abs_path):
			continue
		if not FileAccess.file_exists(abs_path):
			continue
		accepted.append(abs_path)
	if accepted.size() > 0:
		_add_files(accepted)
	_write_json_file(path, {"paths": []})


func _poll_control() -> void:
	var path := _inbox_control_path()
	var parsed: Variant = _read_json_file(path)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data := parsed as Dictionary
	var op := str(data.get("op", "")).strip_edges().to_lower()
	if op.is_empty():
		return
	match op:
		"play":
			_inbox_play(str(data.get("query", "")), str(data.get("path", "")))
		"pause":
			if _player.playing and not _player.stream_paused:
				_player.stream_paused = true
				_paused = true
				_status_label.text = "Paused"
		"stop":
			_stop()
		_:
			_status_label.text = "Unknown control op"
	_write_json_file(path, {})


func _inbox_play(query: String, path_arg: String) -> void:
	var target := path_arg.strip_edges()
	if target.is_empty():
		target = query.strip_edges()
	if target.is_empty():
		_status_label.text = "Play needs query or path"
		return
	var idx := _match_play_target(target)
	if idx >= 0:
		_play_index(idx)
		return
	var abs_path := _canon_path(target)
	if abs_path.is_absolute_path() and _is_inbox_audio(abs_path) and FileAccess.file_exists(abs_path):
		_add_files(PackedStringArray([abs_path]))
		idx = _match_play_target(abs_path)
		if idx >= 0:
			_play_index(idx)
			return
	_status_label.text = "No matching track"


func _match_play_target(target: String) -> int:
	var canon := _canon_path(target)
	var key := _path_key(canon)
	for i in _paths.size():
		if _path_key(_paths[i]) == key:
			return i
	var want_file := canon.get_file().to_lower()
	if want_file.is_empty():
		want_file = target.get_file().to_lower()
	var file_hits: Array[int] = []
	for i in _paths.size():
		if _paths[i].get_file().to_lower() == want_file:
			file_hits.append(i)
	if file_hits.size() == 1:
		return file_hits[0]
	if file_hits.size() > 1:
		_status_label.text = "Ambiguous play query"
		return -1
	var needle := want_file
	if needle.is_empty():
		needle = target.to_lower()
	var sub_hits: Array[int] = []
	for i in _paths.size():
		if needle in _paths[i].get_file().to_lower():
			sub_hits.append(i)
	if sub_hits.size() == 1:
		return sub_hits[0]
	if sub_hits.size() > 1:
		_status_label.text = "Ambiguous play query"
		return -1
	return -1


func _on_remove_pressed() -> void:
	var selected := _playlist.get_selected_items()
	if selected.is_empty():
		return
	var remove_at := int(selected[0])
	if remove_at < 0 or remove_at >= _paths.size():
		return
	var removing_current := remove_at == _index
	_paths.remove_at(remove_at)
	if removing_current:
		_stop()
		_index = -1
		_now_label.text = "— idle —"
	elif _index > remove_at:
		_index -= 1
	_refresh_playlist()
	_persist()


func _on_item_activated(item_index: int) -> void:
	_play_index(item_index)


func _toggle_play() -> void:
	if _player.playing:
		_player.stream_paused = true
		_paused = true
		_status_label.text = "Paused"
		return
	if _paused and _player.stream != null:
		_player.stream_paused = false
		_paused = false
		_status_label.text = "Playing %s" % _now_label.text
		return
	if _index >= 0 and _index < _paths.size():
		_play_index(_index)
		return
	var start := _playlist.get_selected_items()
	if start.size() > 0:
		_play_index(int(start[0]))
		return
	_play_index(_next_playable(0, 1, false))


func _stop() -> void:
	_player.stop()
	_player.stream_paused = false
	_paused = false
	if _player.stream != null:
		_player.seek(0.0)
	_ignore_seek = true
	_seek_slider.value = 0.0
	_ignore_seek = false
	_status_label.text = "Stopped"
	_play_button.text = "Play"
	_time_label.text = "00:00  /  %s" % _format_time(_stream_length())


func _play_relative(step: int) -> void:
	if _paths.is_empty():
		return
	var from := _index
	if from < 0:
		from = 0 if step > 0 else _paths.size() - 1
	else:
		from += step
	var next := _next_playable(from, step, false)
	if next >= 0:
		_play_index(next)


func _on_track_finished() -> void:
	var next := _next_playable(_index + 1, 1, false)
	if next >= 0:
		_play_index(next)
	else:
		_stop()
		_status_label.text = "Stopped"


func _play_index(item_index: int) -> void:
	if item_index < 0 or item_index >= _paths.size():
		_status_label.text = "Playlist empty"
		return
	var path := _paths[item_index]
	if not FileAccess.file_exists(path):
		_mark_missing(item_index)
		_status_label.text = "Missing file — skipped"
		var skip := _next_playable(item_index + 1, 1, false)
		if skip >= 0 and skip != item_index:
			_play_index(skip)
		return
	var stream := AudioLoader.load_stream(path)
	if stream == null:
		_mark_missing(item_index)
		_status_label.text = "Could not load file"
		return
	_index = item_index
	_paused = false
	_player.stream = stream
	_player.stream_paused = false
	_player.play()
	_playlist.select(item_index)
	_playlist.ensure_current_is_visible()
	_now_label.text = path.get_file()
	_status_label.text = "Playing %s" % path.get_file()
	_play_button.text = "Pause"
	_seek_slider.editable = true
	var length := stream.get_length()
	_ignore_seek = true
	_seek_slider.max_value = maxf(length, 0.001)
	_seek_slider.value = 0.0
	_ignore_seek = false
	_time_label.text = "%s  /  %s" % [_format_time(0.0), _format_time(length)]


func _next_playable(start: int, step: int, wrap: bool) -> int:
	if _paths.is_empty():
		return -1
	var count := _paths.size()
	var i := start
	for _n in count:
		if i < 0 or i >= count:
			if not wrap:
				return -1
			i = (i + count) % count
		if FileAccess.file_exists(_paths[i]) and AudioLoader.is_supported(_paths[i]):
			return i
		i += step
	return -1


func _on_seek_changed(value: float) -> void:
	if _ignore_seek or _player.stream == null:
		return
	_player.seek(value)


func _nudge_seek(seconds: float) -> void:
	if _player.stream == null:
		return
	var length := _player.stream.get_length()
	var pos := clampf(_player.get_playback_position() + seconds, 0.0, maxf(length, 0.0))
	_player.seek(pos)
	_ignore_seek = true
	_seek_slider.value = pos
	_ignore_seek = false


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_persist()


func _apply_volume(linear: float) -> void:
	var v := clampf(linear, 0.0, 1.0)
	if v <= 0.001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 0.0)


func _on_eq_demo_changed(is_demo: bool) -> void:
	_eq_header.text = "demo EQ" if is_demo else "EQ"


func _on_skin_selected(index: int) -> void:
	var id := PlaylistStore.SKIN_CYBER if index == 1 else PlaylistStore.SKIN_2003
	apply_skin(id, true)


func apply_skin(skin_id: String, persist: bool = true) -> void:
	_skin = PlaylistStore.normalize_skin(skin_id)
	var next_theme := THEME_CYBER if _skin == PlaylistStore.SKIN_CYBER else THEME_2003
	theme = next_theme
	_eq_bars.apply_palette(_skin)
	_fullscreen_bars.apply_palette(_skin)
	_title_label.text = "ShyneB0X Music Player"
	_skin_badge.text = "music player"
	if _skin == PlaylistStore.SKIN_CYBER:
		_accent.color = Color(0.15, 0.92, 1.0, 1.0)
		_full_bg.color = Color(0.03, 0.04, 0.07, 1.0)
	else:
		_accent.color = Color(0.545098, 0.870588, 0.25098, 1.0)
		_full_bg.color = Color(0.04, 0.07, 0.04, 1.0)
	_skin_option.set_block_signals(true)
	_skin_option.select(1 if _skin == PlaylistStore.SKIN_CYBER else 0)
	_skin_option.set_block_signals(false)
	_update_transport_chrome()
	if persist:
		_persist()


func toggle_mini() -> void:
	if _mini_active:
		exit_mini()
	else:
		enter_mini()


func enter_mini() -> void:
	if _mini_active:
		return
	if _viz_fullscreen:
		_exit_fullscreen_viz()
	var win := get_window()
	if win.mode == Window.MODE_MINIMIZED:
		win.mode = Window.MODE_WINDOWED
	_mini_saved_mode = win.mode
	_mini_saved_size = win.size
	_mini_saved_position = win.position
	_mini_saved_min = win.min_size
	_mini_saved_scale_mode = win.content_scale_mode
	_mini_saved_scale_aspect = win.content_scale_aspect
	_mini_saved_scale_size = win.content_scale_size
	_set_mini_chrome(true)
	_mini_active = true
	_mini_button.text = "Full"
	_apply_mini_window_size()
	call_deferred("_apply_mini_window_size")


func exit_mini() -> void:
	if not _mini_active:
		return
	var win := get_window()
	var win_id := win.get_window_id()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false, win_id)
	_set_mini_chrome(false)
	win.content_scale_mode = _mini_saved_scale_mode
	win.content_scale_aspect = _mini_saved_scale_aspect
	win.content_scale_size = _mini_saved_scale_size
	win.min_size = _mini_saved_min
	if win.mode == Window.MODE_MINIMIZED:
		win.mode = Window.MODE_WINDOWED
	win.mode = _mini_saved_mode
	if _mini_saved_mode == Window.MODE_WINDOWED:
		win.size = _mini_saved_size
		win.position = _mini_saved_position
		DisplayServer.window_set_size(_mini_saved_size, win_id)
		DisplayServer.window_set_position(_mini_saved_position, win_id)
	_mini_active = false
	_mini_button.text = "Mini"


func is_mini() -> bool:
	return _mini_active


func _apply_mini_window_size() -> void:
	if not _mini_active:
		return
	var win := get_window()
	var win_id := win.get_window_id()
	win.mode = Window.MODE_WINDOWED
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	win.min_size = MINI_MIN_SIZE
	win.size = MINI_SIZE
	DisplayServer.window_set_size(MINI_SIZE, win_id)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, win_id)


func _set_mini_chrome(mini: bool) -> void:
	_split.visible = not mini
	_lcd_row.visible = not mini
	_prev_button.visible = not mini
	_stop_button.visible = not mini
	_vol_label.visible = not mini
	_volume_slider.visible = not mini
	_transport_spacer.visible = not mini
	_title_bar.visible = not mini
	_accent.visible = not mini
	_play_button.visible = true
	_next_button.visible = true
	_seek_slider.visible = true
	_now_label.visible = true
	if mini:
		_dock_mini_button_in_transport()
		_chrome_layout.add_theme_constant_override("separation", 2)
		_main_pad.add_theme_constant_override("margin_left", 6)
		_main_pad.add_theme_constant_override("margin_top", 4)
		_main_pad.add_theme_constant_override("margin_right", 6)
		_main_pad.add_theme_constant_override("margin_bottom", 4)
		_now_label.add_theme_font_size_override("font_size", 18)
		_play_button.add_theme_font_size_override("font_size", 16)
		_next_button.add_theme_font_size_override("font_size", 16)
		_mini_button.add_theme_font_size_override("font_size", 16)
		_seek_slider.custom_minimum_size = Vector2(0, 8)
		_play_button.custom_minimum_size = Vector2(120, 48)
		_next_button.custom_minimum_size = Vector2(120, 48)
		_mini_button.custom_minimum_size = Vector2(120, 48)
		_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mini_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_play_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_next_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_mini_button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_transport.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_main_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		_restore_mini_button_home()
		_chrome_layout.remove_theme_constant_override("separation")
		_main_pad.remove_theme_constant_override("margin_left")
		_main_pad.remove_theme_constant_override("margin_top")
		_main_pad.remove_theme_constant_override("margin_right")
		_main_pad.remove_theme_constant_override("margin_bottom")
		_now_label.remove_theme_font_size_override("font_size")
		_play_button.remove_theme_font_size_override("font_size")
		_next_button.remove_theme_font_size_override("font_size")
		_mini_button.remove_theme_font_size_override("font_size")
		_seek_slider.custom_minimum_size = Vector2(0, 18)
		_play_button.custom_minimum_size = Vector2(80, 34)
		_next_button.custom_minimum_size = Vector2(72, 34)
		_mini_button.custom_minimum_size = Vector2(56, 24)
		_play_button.size_flags_horizontal = Control.SIZE_FILL
		_next_button.size_flags_horizontal = Control.SIZE_FILL
		_mini_button.size_flags_horizontal = Control.SIZE_FILL
		_play_button.size_flags_vertical = Control.SIZE_FILL
		_next_button.size_flags_vertical = Control.SIZE_FILL
		_mini_button.size_flags_vertical = Control.SIZE_FILL
		_transport.size_flags_vertical = Control.SIZE_FILL
		_main_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _dock_mini_button_in_transport() -> void:
	var home := _mini_button.get_parent()
	if home == _transport:
		return
	_mini_button_home = home
	_mini_button_index = _mini_button.get_index()
	_mini_button.reparent(_transport)
	_transport.move_child(_mini_button, _transport.get_child_count() - 1)


func _restore_mini_button_home() -> void:
	if _mini_button_home == null:
		return
	if _mini_button.get_parent() != _mini_button_home:
		_mini_button.reparent(_mini_button_home)
		var idx := mini(_mini_button_index, _mini_button_home.get_child_count() - 1)
		_mini_button_home.move_child(_mini_button, idx)
	_mini_button_home = null


func _on_now_gui_input(event: InputEvent) -> void:
	if not _mini_active:
		return
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or not mouse.double_click:
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	exit_mini()
	get_viewport().set_input_as_handled()


func _enter_fullscreen_viz() -> void:
	if _viz_fullscreen:
		return
	var win := get_window()
	_saved_mode = win.mode
	_saved_size = win.size
	_saved_position = win.position
	_viz_fullscreen = true
	_chrome.visible = false
	_fullscreen_layer.visible = true
	win.mode = Window.MODE_FULLSCREEN


func _exit_fullscreen_viz() -> void:
	if not _viz_fullscreen:
		return
	_viz_fullscreen = false
	var win := get_window()
	win.mode = _saved_mode
	if _saved_mode == Window.MODE_WINDOWED:
		win.size = _saved_size
		win.position = _saved_position
	_fullscreen_layer.visible = false
	_chrome.visible = true


func _refresh_playlist() -> void:
	_playlist.clear()
	for i in _paths.size():
		var path := _paths[i]
		var title := path.get_file()
		var missing := not FileAccess.file_exists(path)
		if missing:
			title = MISSING_PREFIX + title
		_playlist.add_item(title)
		_playlist.set_item_metadata(i, path)
		if missing:
			_playlist.set_item_custom_fg_color(i, Color(0.75, 0.55, 0.35, 1.0))
	if _index >= 0 and _index < _paths.size():
		_playlist.select(_index)


func _mark_missing(item_index: int) -> void:
	if item_index < 0 or item_index >= _playlist.item_count:
		return
	var title := _paths[item_index].get_file()
	_playlist.set_item_text(item_index, MISSING_PREFIX + title)
	_playlist.set_item_custom_fg_color(item_index, Color(0.75, 0.55, 0.35, 1.0))


func _set_idle_chrome() -> void:
	_now_label.text = "— idle —"
	_time_label.text = "--:--  /  --:--"
	_status_label.text = "Stopped"
	_play_button.text = "Play"
	_eq_header.text = "EQ"
	_seek_slider.min_value = 0.0
	_seek_slider.max_value = 1.0
	_seek_slider.value = 0.0
	_seek_slider.editable = false


func _update_transport_chrome() -> void:
	var cyber := _skin == PlaylistStore.SKIN_CYBER
	if _player.playing:
		_play_button.text = "Pause"
		_play_led.color = Color(0.15, 0.95, 1.0, 1.0) if cyber else Color(0.55, 1.0, 0.28, 1.0)
	elif _paused:
		_play_button.text = "Play"
		_play_led.color = Color(1.0, 0.35, 0.85, 1.0) if cyber else Color(0.72, 0.78, 0.22, 1.0)
	else:
		_play_button.text = "Play"
		_play_led.color = Color(0.12, 0.22, 0.28, 1.0) if cyber else Color(0.22, 0.28, 0.18, 1.0)


func _stream_length() -> float:
	if _player.stream == null:
		return 0.0
	return _player.stream.get_length()


static func _format_time(seconds: float) -> String:
	if seconds < 0.0 or is_nan(seconds) or is_inf(seconds):
		return "--:--"
	var total := int(floor(seconds))
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]
