class_name EngineExhaust
extends Node2D
## Plasma jet engine exhaust — renders behind the ship.
## Reads tuning from user://settings/engine_audition.json (same source as VFX editor).
## Attach as child of the ship node, call update_thrust() each frame.

var _time: float = 0.0
var _display_intensity: float = 0.15
var _engine_offsets: Array[Vector2] = []
var _ship_scale: float = 1.4
var _bank: float = 0.0
var scroll_speed: float = 80.0

# Cached settings
var _cone_hdr: float = 1.8
var _length_min: float = 0.3
var _length_max: float = 1.0
var _cone_width: float = 1.0
var _flicker_intensity: float = 0.5
var _nozzle_hdr: float = 2.5
var _splay_amount: float = 0.0
var _layer_count: int = 4
var _crawl_count: int = 5

const SAVE_PATH: String = "user://settings/engine_audition.json"


func _ready() -> void:
	_load_settings()
	z_index = -1  # Render behind the ship


func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var d: Dictionary = parsed as Dictionary
		_cone_hdr = float(d.get("cone_hdr", _cone_hdr))
		_length_min = float(d.get("length_min", _length_min))
		_length_max = float(d.get("length_max", _length_max))
		_cone_width = float(d.get("cone_width", _cone_width))
		_flicker_intensity = float(d.get("flicker_intensity", _flicker_intensity))
		_nozzle_hdr = float(d.get("nozzle_hdr", _nozzle_hdr))
		_splay_amount = float(d.get("splay_amount", _splay_amount))
		_layer_count = int(d.get("layer_count", _layer_count))
		_crawl_count = int(d.get("crawl_count", _crawl_count))


func setup(engine_offsets: Array[Vector2], ship_scale: float) -> void:
	_engine_offsets = engine_offsets
	_ship_scale = ship_scale


func update_thrust(velocity_y: float, bank_val: float, delta: float) -> void:
	_time += delta
	_bank = bank_val

	# Thrust intensity: scroll_speed + upward movement = more thrust
	var forward_vel: float = scroll_speed - velocity_y
	var target: float = clampf(forward_vel / scroll_speed, 0.15, 2.0)

	# Asymmetric ramp — slow buildup, faster reduction
	var ramp_speed: float = 0.8 if target > _display_intensity else 1.6
	_display_intensity = lerpf(_display_intensity, target, minf(delta * ramp_speed, 1.0))

	queue_redraw()


func _synced_flicker(t: float, param_seed: float, amount: float) -> float:
	var f1: float = sin(t * 7.3 + param_seed)
	var f2: float = sin(t * 13.1 + param_seed * 2.7)
	var f3: float = sin(t * 23.7 + param_seed * 0.3)
	var raw: float = (f1 * 0.5 + f2 * 0.3 + f3 * 0.2)
	return 1.0 - absf(raw) * amount


func _draw() -> void:
	var intensity: float = _display_intensity
	var t: float = _time
	var hdr: float = _cone_hdr
	var wid_m: float = _cone_width
	var splay: float = _splay_amount
	var layers: int = _layer_count
	var crawls: int = _crawl_count

	# Normalized intensity for length interpolation
	var norm: float = clampf((intensity - 0.15) / (2.0 - 0.15), 0.0, 1.0)
	var len_m: float = lerpf(_length_min, _length_max, norm)

	# Synced flicker (same for all engines)
	var flicker: float = _synced_flicker(t, 1.0, _flicker_intensity)
	var size_pulse: float = _synced_flicker(t * 0.8, 3.5, 0.35)
	var nozzle_flare: float = _synced_flicker(t, 13.0, 0.7)

	# Banking parallax
	var parallax_x: float = _bank * 3.0 * _ship_scale

	for ei in range(_engine_offsets.size()):
		var offset: Vector2 = _engine_offsets[ei]
		var s: float = _ship_scale
		var bx: float = offset.x * (1.0 + _bank * signf(offset.x) * 0.15) * s
		var pos := Vector2(bx + parallax_x, offset.y * s)

		var side: float = signf(offset.x) if absf(offset.x) > 0.5 else 0.0
		var splay_offset: float = side * splay

		var cone_len: float = (10.0 + intensity * 18.0) * len_m * size_pulse
		var base_w: float = (2.8 + intensity * 1.8) * wid_m

		# Layered cones
		for li in range(layers):
			var frac: float = float(li) / float(maxi(layers - 1, 1))
			var w: float = base_w * (1.0 - frac * 0.6)
			var length: float = cone_len * (1.2 - frac * 0.5)
			var alpha: float = lerpf(0.08, 0.5, frac) * intensity * flicker
			var r: float = lerpf(0.2, 0.8, frac) * hdr
			var g: float = lerpf(0.4, 0.9, frac) * hdr
			var b: float = lerpf(0.8, 1.0, frac) * hdr

			var wobble_x: float = (_synced_flicker(t * 1.3, float(li) * 2.0, 0.15) - 0.5) * 0.5
			var tip_x: float = wobble_x + splay_offset * frac
			var pts := PackedVector2Array([
				pos + Vector2(-w, 0),
				pos + Vector2(w, 0),
				pos + Vector2(tip_x, length),
			])
			draw_colored_polygon(pts, Color(r, g, b, alpha))

		# Energy crawl dots
		for ci in range(crawls):
			var crawl_phase: float = fmod(t * 3.0 + float(ci) * (1.0 / maxf(float(crawls), 1.0)), 1.0)
			var crawl_y: float = crawl_phase * cone_len * 0.8
			var crawl_splay: float = splay_offset * crawl_phase
			var crawl_wobble: float = (_synced_flicker(t, float(ci) * 4.0, 0.3) - 0.5) * base_w * 0.3
			var crawl_alpha: float = (1.0 - crawl_phase) * intensity * 0.5 * flicker
			if crawl_alpha > 0.02:
				draw_circle(pos + Vector2(crawl_splay + crawl_wobble, crawl_y), 1.0,
					Color(0.8 * hdr, 0.9 * hdr, 1.0 * hdr, crawl_alpha))

		# Nozzle
		var n_hdr: float = _nozzle_hdr * nozzle_flare
		draw_circle(pos, 3.5, Color(0.4 * n_hdr, 0.6 * n_hdr, 1.0 * n_hdr, intensity * 0.4))
		draw_circle(pos, 2.0, Color(0.6 * n_hdr, 0.8 * n_hdr, 1.0 * n_hdr, intensity * 0.9))
		draw_circle(pos, 0.8, Color(n_hdr, n_hdr, n_hdr, intensity * 0.7))
