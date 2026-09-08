class_name EqBars
extends Control

signal demo_mode_changed(is_demo: bool)

const BUS_NAME := "Music"
const FREQ_MIN := 40.0
const FREQ_MAX := 14000.0
const MIN_DB := 72.0
const MAG_GAIN := 5.0
const PEAK_FALL := 1.15
const HEIGHT_LERP := 10.0
const BAND_OVERLAP := 0.82

@export var bar_count: int = 18

var demo_mode: bool = false
var _playing: bool = false
var _position: float = 0.0
var _bar_count: int = 18
var _heights: PackedFloat32Array = PackedFloat32Array()
var _peaks: PackedFloat32Array = PackedFloat32Array()
var _bus_index: int = -1
var _effect_index: int = -1
var _pal_bg: Color = Color(0.04, 0.07, 0.04, 1.0)
var _pal_well: Color = Color(0.08, 0.14, 0.07, 1.0)
var _pal_low: Color = Color(0.42, 0.88, 0.22, 1.0)
var _pal_mid: Color = Color(0.92, 0.88, 0.22, 1.0)
var _pal_high: Color = Color(0.92, 0.38, 0.18, 1.0)
var _pal_peak: Color = Color(0.85, 1.0, 0.55, 0.9)


func _ready() -> void:
	_bar_count = maxi(bar_count, 8)
	_heights.resize(_bar_count)
	_peaks.resize(_bar_count)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_bus_index = ensure_music_bus()
	_effect_index = ensure_analyzer(_bus_index)
	set_process(true)


func set_playback(playing: bool, position: float) -> void:
	_playing = playing
	_position = position


func apply_palette(skin: String) -> void:
	if skin == PlaylistStore.SKIN_CYBER:
		_pal_bg = Color(0.03, 0.04, 0.07, 1.0)
		_pal_well = Color(0.06, 0.08, 0.12, 1.0)
		_pal_low = Color(0.15, 0.92, 1.0, 1.0)
		_pal_mid = Color(0.95, 0.22, 0.85, 1.0)
		_pal_high = Color(1.0, 0.75, 0.2, 1.0)
		_pal_peak = Color(0.85, 1.0, 1.0, 0.95)
	else:
		_pal_bg = Color(0.04, 0.07, 0.04, 1.0)
		_pal_well = Color(0.08, 0.14, 0.07, 1.0)
		_pal_low = Color(0.42, 0.88, 0.22, 1.0)
		_pal_mid = Color(0.92, 0.88, 0.22, 1.0)
		_pal_high = Color(0.92, 0.38, 0.18, 1.0)
		_pal_peak = Color(0.85, 1.0, 0.55, 0.9)
	queue_redraw()


static func ensure_music_bus() -> int:
	var idx := AudioServer.get_bus_index(BUS_NAME)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, BUS_NAME)
	AudioServer.set_bus_send(idx, &"Master")
	return idx


static func ensure_analyzer(bus_idx: int) -> int:
	if bus_idx < 0:
		return -1
	var count := AudioServer.get_bus_effect_count(bus_idx)
	for i in count:
		var fx := AudioServer.get_bus_effect(bus_idx, i)
		if fx is AudioEffectSpectrumAnalyzer:
			return i
	var analyzer := AudioEffectSpectrumAnalyzer.new()
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
	analyzer.buffer_length = 2.0
	AudioServer.add_bus_effect(bus_idx, analyzer)
	return AudioServer.get_bus_effect_count(bus_idx) - 1


func _process(delta: float) -> void:
	var targets := PackedFloat32Array()
	targets.resize(_bar_count)
	if _playing:
		if _fill_from_spectrum(targets):
			if demo_mode:
				demo_mode = false
				demo_mode_changed.emit(false)
		else:
			_enter_demo()
			_fill_demo(targets)
	else:
		for i in _bar_count:
			targets[i] = 0.0
	for i in _bar_count:
		var fall := PEAK_FALL * delta
		if targets[i] >= _heights[i]:
			_heights[i] = lerpf(_heights[i], targets[i], clampf(HEIGHT_LERP * delta, 0.0, 1.0))
		else:
			_heights[i] = maxf(targets[i], _heights[i] - fall)
		if _heights[i] >= _peaks[i]:
			_peaks[i] = _heights[i]
		else:
			_peaks[i] = maxf(0.0, _peaks[i] - fall * 0.45)
	queue_redraw()


func _enter_demo() -> void:
	if demo_mode:
		return
	demo_mode = true
	demo_mode_changed.emit(true)


func _fill_from_spectrum(out_targets: PackedFloat32Array) -> bool:
	if _bus_index < 0 or _effect_index < 0:
		return false
	var inst := AudioServer.get_bus_effect_instance(_bus_index, _effect_index) as AudioEffectSpectrumAnalyzerInstance
	if inst == null:
		return false
	var prev_hz := FREQ_MIN
	for i in _bar_count:
		var t := float(i + 1) / float(_bar_count)
		var hz := FREQ_MIN * pow(FREQ_MAX / FREQ_MIN, t)
		var from_hz := maxf(FREQ_MIN, prev_hz * BAND_OVERLAP)
		var mag: Vector2 = inst.get_magnitude_for_frequency_range(
			from_hz,
			hz,
			AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_MAX
		)
		var energy := mag.length() * MAG_GAIN
		var n := clampf((MIN_DB + linear_to_db(maxf(energy, 1e-12))) / MIN_DB, 0.0, 1.0)
		out_targets[i] = sqrt(n)
		prev_hz = hz
	return true


func _fill_demo(out_targets: PackedFloat32Array) -> void:
	var t := _position
	for i in _bar_count:
		var phase := t * (1.15 + float(i) * 0.31) + float(i) * 0.4
		var envelope := 0.35 + 0.65 * absf(sin(t * 2.05 + float(i) * 0.12))
		out_targets[i] = clampf(absf(sin(phase)) * envelope, 0.0, 1.0)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, _pal_bg)
	var gap := 3.0 if _bar_count <= 24 else 2.0
	var inner := rect.grow(-4.0)
	var bar_w := (inner.size.x - gap * float(_bar_count - 1)) / float(_bar_count)
	if bar_w <= 1.0:
		return
	for i in _bar_count:
		var x := inner.position.x + float(i) * (bar_w + gap)
		draw_rect(Rect2(x, inner.position.y, bar_w, inner.size.y), _pal_well)
		var h := inner.size.y * clampf(_heights[i], 0.0, 1.0)
		if h < 1.0:
			continue
		var y := inner.position.y + inner.size.y - h
		var col := _pal_low
		if _heights[i] > 0.72:
			col = _pal_mid
		if _heights[i] > 0.9:
			col = _pal_high
		draw_rect(Rect2(x, y, bar_w, h), col)
		var peak_y := inner.position.y + inner.size.y - inner.size.y * clampf(_peaks[i], 0.0, 1.0)
		draw_rect(Rect2(x, peak_y, bar_w, 2.0), _pal_peak)
