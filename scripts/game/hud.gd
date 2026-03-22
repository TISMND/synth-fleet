extends Control
## In-game HUD — bottom icon bar + vertical side bars for status.
## Fully themed via ThemeManager with theme_changed reactivity.
## Layout delegated to HudBuilder for single source of truth.
## Extends Control (not CanvasLayer) so bars participate in WorldEnvironment
## glow post-processing. CanvasLayer content renders after bloom and misses it.

var _credits_label: Label = null
var _menu_hint: Label = null
var _hud_result: Dictionary = {}  # HudBuilder.build_hud() result
var _weapons_hbox: HBoxContainer = null
var _weapon_icons: Array = []  # Array of dicts: {container, bg_rect, number_label, active, color}
var _core_icons: Array = []    # Array of dicts: same shape as weapon_icons
var _device_icons: Array = []  # Array of dicts: same shape as weapon_icons
var _bars: Dictionary = {}  # keyed by spec name -> {"bar": ProgressBar, "label": Label, "vertical": bool}
var _bar_segments: Dictionary = {}  # bar_name -> int segment count
var _bar_base_colors: Dictionary = {}  # bar_name -> Color
var _bar_prev_values: Dictionary = {}  # bar_name -> float (previous frame's value for change detection)
# Per-bar rolling wave state: {active: bool, position: float, speed: float}
var _bar_gain_wave: Dictionary = {}   # bar_name -> wave state dict
var _bar_drain_wave: Dictionary = {}  # bar_name -> wave state dict
const WAVE_SPEED: float = 2.5  # normalized units per second (wave traverses bar in ~0.4s)
const WAVE_MIN_CHANGE: float = 0.01  # minimum ratio change to trigger a wave
var _vhs_overlay: ColorRect = null

# Power death bar animation
var _shield_arc_container: Node2D = null  # Lightning arcs on the shield bar
var _shield_arcs: Array = []  # Active Line2D bolts on shield bar
var _shield_arc_timer: float = 0.0
var _shield_arcing: bool = false  # True during shield bleed from electric overdraw
var _power_death_active: bool = false
var _power_death_elapsed: float = 0.0
var _power_death_final: bool = false  # Final fade — kill all remaining segments fast
var _power_death_final_elapsed: float = 0.0
var _bar_kill_masks: Dictionary = {}   # bar_name -> int bitmask (bit N = segment N killed)
var _bar_flicker_timers: Dictionary = {}  # bar_name -> Array[float] (per-segment flicker countdown)
var _debug_overlay: HudDebugOverlay = null


func _ready() -> void:
	_build_ui()
	_setup_vhs_overlay()
	_setup_debug_overlay()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _setup_debug_overlay() -> void:
	_debug_overlay = HudDebugOverlay.new()
	_debug_overlay.setup(self, _hud_result, _bars)
	add_child(_debug_overlay)


func _build_ui() -> void:
	# Top-right credits
	_credits_label = Label.new()
	_credits_label.position = Vector2(1700, 20)
	_credits_label.text = "CR: 0"
	add_child(_credits_label)

	# Menu hint
	_menu_hint = Label.new()
	_menu_hint.position = Vector2(20, 20)
	_menu_hint.text = "ESC: Menu"
	add_child(_menu_hint)

	# Build 3-panel HUD via HudBuilder
	var side_top: float = 60.0
	var side_bottom: float = 1080.0 - HudBuilder.BOTTOM_BAR_HEIGHT - 8.0
	var side_height: float = side_bottom - side_top
	_hud_result = HudBuilder.build_hud("game", side_height)

	# Position bottom bar
	var bottom_root: ColorRect = _hud_result["bottom_bar"]["root"]
	bottom_root.position = Vector2(0, 1080 - HudBuilder.BOTTOM_BAR_HEIGHT)
	bottom_root.size = Vector2(1920, HudBuilder.BOTTOM_BAR_HEIGHT)
	add_child(bottom_root)

	# Position left panel (Shield + Hull)
	var left_root: ColorRect = _hud_result["left_panel"]["root"]
	left_root.position = Vector2(0, side_top)
	left_root.size = Vector2(HudBuilder.SIDE_PANEL_WIDTH, side_height)
	add_child(left_root)

	# Position right panel (Thermal + Electric)
	var right_root: ColorRect = _hud_result["right_panel"]["root"]
	right_root.position = Vector2(1920 - HudBuilder.SIDE_PANEL_WIDTH, side_top)
	right_root.size = Vector2(HudBuilder.SIDE_PANEL_WIDTH, side_height)
	add_child(right_root)

	_weapons_hbox = _hud_result["weapons_hbox"]

	# Merge bars from both side panels into unified _bars dict
	var left_bars: Dictionary = _hud_result["left_panel"]["bars"]
	var right_bars: Dictionary = _hud_result["right_panel"]["bars"]
	for bar_name in left_bars:
		_bars[bar_name] = left_bars[bar_name]
	for bar_name in right_bars:
		_bars[bar_name] = right_bars[bar_name]


	# Initialize wave tracking and base colors
	for bar_name in _bars:
		_bar_gain_wave[bar_name] = {"active": false, "position": 0.0, "speed": WAVE_SPEED}
		_bar_drain_wave[bar_name] = {"active": false, "position": 1.0, "speed": WAVE_SPEED}
		_bar_prev_values[bar_name] = -1.0  # sentinel: first frame won't trigger wave
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			if str(spec["name"]) == bar_name:
				_bar_base_colors[bar_name] = ThemeManager.resolve_bar_color(spec)
				break


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func set_bar_segments(stats: Dictionary) -> void:
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		var seg_key: String = str(spec.get("segments_stat", ""))
		if seg_key != "":
			_bar_segments[bar_name] = int(stats.get(seg_key, -1))
	_apply_theme()


func _apply_theme() -> void:
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")

	# HUD panel backgrounds + borders
	HudBuilder.apply_hud_theme(_hud_result)

	# Credits
	_credits_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	_credits_label.add_theme_color_override("font_color", ThemeManager.get_color("positive"))
	if body_font:
		_credits_label.add_theme_font_override("font", body_font)
	ThemeManager.apply_text_glow(_credits_label, "body")

	# Menu hint
	_menu_hint.add_theme_font_size_override("font_size", body_size)
	_menu_hint.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	if body_font:
		_menu_hint.add_theme_font_override("font", body_font)

	# Bar labels + LED bars from shared specs
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not _bars.has(bar_name):
			continue
		var entry: Dictionary = _bars[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var lbl: Label = entry["label"]
		HudBuilder.apply_bar_label_theme(lbl, color, body_font, body_size)
		var bar: ProgressBar = entry["bar"]
		var ratio: float = bar.value / maxf(bar.max_value, 1.0)
		var seg: int = int(_bar_segments.get(bar_name, -1))
		var is_vertical: bool = entry.get("vertical", false) as bool
		bar.custom_minimum_size.x = HudBuilder.BAR_WIDTH
		ThemeManager.apply_led_bar(bar, color, ratio, seg, is_vertical)
		HudBuilder.update_bar_bezel(entry, seg)
		_bar_base_colors[bar_name] = color

	# Weapon icons
	for icon in _weapon_icons:
		HudBuilder.apply_icon_theme(icon)


func update_health(current_shield: float, max_shield: float, current_hull: float, max_hull: float) -> void:
	_update_bar("SHIELD", current_shield, max_shield, "bar_shield")
	_update_bar("HULL", current_hull, max_hull, "bar_hull")


func update_all_bars(current_shield: float, max_shield: float, current_hull: float, max_hull: float, current_thermal: float, max_thermal: float, current_electric: float, max_electric: float) -> void:
	_update_bar("SHIELD", current_shield, max_shield, "bar_shield")
	_update_bar("HULL", current_hull, max_hull, "bar_hull")
	_update_bar("THERMAL", current_thermal, max_thermal, "bar_thermal")
	_update_bar("ELECTRIC", current_electric, max_electric, "bar_electric")


func _update_bar(bar_name: String, current: float, max_val: float, color_key: String) -> void:
	if not _bars.has(bar_name):
		return
	var entry: Dictionary = _bars[bar_name]
	var bar: ProgressBar = entry["bar"]
	bar.max_value = max_val
	bar.value = current
	var ratio: float = current / maxf(max_val, 1.0)

	# Detect gain/drain and trigger rolling waves
	var prev_ratio: float = float(_bar_prev_values.get(bar_name, -1.0))
	if prev_ratio >= 0.0:  # skip first frame (sentinel value)
		var delta_ratio: float = ratio - prev_ratio
		if delta_ratio > WAVE_MIN_CHANGE:
			trigger_gain_wave(bar_name)
		elif delta_ratio < -WAVE_MIN_CHANGE:
			trigger_drain_wave(bar_name)
	_bar_prev_values[bar_name] = ratio

	# Only update fill_ratio on existing shader — don't rebuild the entire LED bar
	# During power death, fill_ratio is forced to 1.0 so all segments are visible for flicker
	if bar.material is ShaderMaterial:
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		if _power_death_active:
			mat.set_shader_parameter("fill_ratio", 1.0)
		else:
			mat.set_shader_parameter("fill_ratio", ratio)
	# Update glow rect alpha to match fill
	var glow_rect: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
	if glow_rect:
		if not _power_death_active:
			glow_rect.color.a = 0.15 * ratio
		# During power death, glow managed by kill animation
	else:
		# First time or after theme change — full rebuild
		var seg: int = int(_bar_segments.get(bar_name, -1))
		var is_vertical: bool = entry.get("vertical", false) as bool
		ThemeManager.apply_led_bar(bar, ThemeManager.get_color(color_key), ratio, seg, is_vertical)
		HudBuilder.update_bar_bezel(entry, seg)
		# Re-force fill_ratio if in power death (apply_led_bar resets it)
		if _power_death_active and bar.material is ShaderMaterial:
			(bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", 1.0)


func pulse_bar(bar_name: String) -> void:
	## Trigger a gain wave on a status bar (called when a power core trigger fires).
	trigger_gain_wave(bar_name)


func trigger_gain_wave(bar_name: String) -> void:
	## Start an upward-rolling gain wave from bottom (0.0) to top (1.0).
	## If already rolling, keep it going without resetting position.
	if not _bar_gain_wave.has(bar_name):
		return
	var wave: Dictionary = _bar_gain_wave[bar_name]
	if not bool(wave.get("active", false)):
		wave["position"] = 0.0
	wave["active"] = true
	wave["speed"] = WAVE_SPEED


func trigger_drain_wave(bar_name: String) -> void:
	## Start a downward-rolling drain wave from top (1.0) to bottom (0.0).
	## If already rolling, keep it going without resetting position.
	if not _bar_drain_wave.has(bar_name):
		return
	var wave: Dictionary = _bar_drain_wave[bar_name]
	if not bool(wave.get("active", false)):
		wave["position"] = 1.0
	wave["active"] = true
	wave["speed"] = WAVE_SPEED


func update_bar_pulses(delta: float) -> void:
	## Advance rolling wave positions and update shader uniforms. Called every frame from game.
	for bar_name in _bar_gain_wave:
		var gain_wave: Dictionary = _bar_gain_wave[bar_name]
		var drain_wave: Dictionary = _bar_drain_wave[bar_name]

		# Advance gain wave (moves upward: 0 -> 1)
		if bool(gain_wave["active"]):
			var pos: float = float(gain_wave["position"])
			pos += float(gain_wave["speed"]) * delta
			if pos > 1.3:  # overshoot past end before deactivating
				gain_wave["active"] = false
				gain_wave["position"] = -1.0
			else:
				gain_wave["position"] = pos

		# Advance drain wave (moves downward: 1 -> 0)
		if bool(drain_wave["active"]):
			var pos: float = float(drain_wave["position"])
			pos -= float(drain_wave["speed"]) * delta
			if pos < -0.3:  # overshoot past end before deactivating
				drain_wave["active"] = false
				drain_wave["position"] = -1.0
			else:
				drain_wave["position"] = pos

		# Update shader uniforms
		_apply_wave_uniforms(bar_name)


func _apply_wave_uniforms(bar_name: String) -> void:
	if not _bars.has(bar_name):
		return
	var entry: Dictionary = _bars[bar_name]
	var bar: ProgressBar = entry["bar"]
	if not bar.material is ShaderMaterial:
		return
	var mat: ShaderMaterial = bar.material as ShaderMaterial
	var gain_wave: Dictionary = _bar_gain_wave[bar_name]
	var drain_wave: Dictionary = _bar_drain_wave[bar_name]
	var gain_pos: float = float(gain_wave["position"]) if bool(gain_wave["active"]) else -1.0
	var drain_pos: float = float(drain_wave["position"]) if bool(drain_wave["active"]) else -1.0
	mat.set_shader_parameter("gain_wave_pos", gain_pos)
	mat.set_shader_parameter("drain_wave_pos", drain_pos)


func update_credits(amount: int) -> void:
	_credits_label.text = "CR: " + str(amount)


# ── Shield bar lightning arcs ────────────────────────────────────────────

func start_shield_arcs() -> void:
	_shield_arcing = true
	_shield_arc_timer = 0.0
	if not _shield_arc_container:
		_shield_arc_container = Node2D.new()
		_shield_arc_container.z_index = 60  # Above HUD panels
		add_child(_shield_arc_container)


func stop_shield_arcs() -> void:
	_shield_arcing = false
	_clear_shield_arcs()


func process_shield_arcs(delta: float) -> void:
	if not _shield_arcing or not _bars.has("SHIELD"):
		return
	_shield_arc_timer -= delta
	if _shield_arc_timer <= 0.0 and _shield_arcs.size() < 2:
		_spawn_shield_arc()
		_shield_arc_timer = randf_range(0.1, 0.4)
	# Update existing arcs
	var i: int = _shield_arcs.size() - 1
	while i >= 0:
		var arc: Dictionary = _shield_arcs[i]
		arc["age"] = float(arc["age"]) + delta
		if float(arc["age"]) >= float(arc["life"]):
			(arc["line"] as Line2D).queue_free()
			_shield_arcs.remove_at(i)
		else:
			var fade: float = 1.0 - float(arc["age"]) / float(arc["life"])
			(arc["line"] as Line2D).modulate.a = fade * 3.0
		i -= 1


func _spawn_shield_arc() -> void:
	var entry: Dictionary = _bars["SHIELD"]
	var bar: ProgressBar = entry["bar"]
	# Get bar position in HUD space
	var bar_pos: Vector2 = bar.global_position - global_position
	var bar_size: Vector2 = bar.size

	# Random start/end along the bar height
	var y_start: float = bar_pos.y + randf() * bar_size.y
	var y_end: float = bar_pos.y + randf() * bar_size.y
	var x_center: float = bar_pos.x + bar_size.x * 0.5
	# Arc extends outward from the bar
	var x_offset: float = randf_range(20.0, 50.0) * (1.0 if randf() > 0.5 else -1.0)

	var segments: int = randi_range(4, 8)
	var points: PackedVector2Array = PackedVector2Array()
	var start: Vector2 = Vector2(x_center, y_start)
	var end: Vector2 = Vector2(x_center + x_offset, y_end)
	for j in segments + 1:
		var t: float = float(j) / float(segments)
		var p: Vector2 = start.lerp(end, t)
		if j > 0 and j < segments:
			p.x += randf_range(-12.0, 12.0)
			p.y += randf_range(-8.0, 8.0)
		points.append(p)

	var line := Line2D.new()
	line.points = points
	line.width = randf_range(1.0, 2.0)
	line.default_color = Color(0.5, 0.7, 1.0, 1.0)
	line.antialiased = true
	line.modulate = Color(3.3, 3.3, 3.3, 1.0)
	_shield_arc_container.add_child(line)
	_shield_arcs.append({"line": line, "life": randf_range(0.05, 0.12), "age": 0.0})


func _clear_shield_arcs() -> void:
	for arc in _shield_arcs:
		if is_instance_valid(arc["line"]):
			(arc["line"] as Line2D).queue_free()
	_shield_arcs.clear()


# ── Power death bar animation ───────────────────────────────────────────

func start_power_death_bars() -> void:
	_power_death_active = true
	_power_death_elapsed = 0.0
	_bar_kill_masks.clear()
	_bar_flicker_timers.clear()
	for bar_name in _bars:
		_bar_kill_masks[bar_name] = 0
		var seg: int = int(_bar_segments.get(bar_name, 8))
		var timers: Array[float] = []
		timers.resize(seg)
		timers.fill(0.0)
		_bar_flicker_timers[bar_name] = timers
		# Force all segments visible so flicker affects the whole bar
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			(bar.material as ShaderMaterial).set_shader_parameter("fill_ratio", 1.0)


func final_power_death_bars() -> void:
	## Kill all remaining segments rapidly — called when screen goes fully dark.
	_power_death_final = true
	_power_death_final_elapsed = 0.0
	# Stop shield arcs
	stop_shield_arcs()
	# Stop all flickering — no more revivals
	for bar_name in _bar_flicker_timers:
		var timers: Array = _bar_flicker_timers[bar_name]
		for i in timers.size():
			timers[i] = 0.0


func stop_power_death_bars() -> void:
	_power_death_active = false
	_power_death_elapsed = 0.0
	_power_death_final = false
	_power_death_final_elapsed = 0.0
	# Restore all segments and fill ratios
	for bar_name in _bars:
		_bar_kill_masks[bar_name] = 0
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			var mat: ShaderMaterial = bar.material as ShaderMaterial
			mat.set_shader_parameter("segment_kill_mask", 0)
			# Restore real fill ratio
			var ratio: float = bar.value / maxf(bar.max_value, 1.0)
			mat.set_shader_parameter("fill_ratio", ratio)
		# Restore glow rect
		var glow: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
		if glow:
			var ratio: float = bar.value / maxf(bar.max_value, 1.0)
			glow.color.a = 0.15 * ratio


func process_power_death_bars(delta: float) -> void:
	if not _power_death_active:
		return
	_power_death_elapsed += delta

	# Final death: kill remaining segments very fast, no flicker
	if _power_death_final:
		_power_death_final_elapsed += delta

	# Kill rate accelerates: ~1 seg/sec at start, ~8 seg/sec after 3 seconds
	# Final death: 20 seg/sec, no flicker
	var kill_rate: float
	if _power_death_final:
		kill_rate = 20.0
	else:
		kill_rate = lerpf(1.0, 8.0, minf(_power_death_elapsed / 3.0, 1.0))
	var kill_chance: float = kill_rate * delta

	for bar_name in _bars:
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if not bar.material is ShaderMaterial:
			continue
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		var seg: int = int(_bar_segments.get(bar_name, 8))
		var mask: int = int(_bar_kill_masks.get(bar_name, 0))
		var timers: Array = _bar_flicker_timers.get(bar_name, [])

		# Try to kill a random alive segment
		if randf() < kill_chance:
			# Find alive segments
			var alive: Array[int] = []
			for i in seg:
				if (mask >> i) & 1 == 0:
					alive.append(i)
			if not alive.is_empty():
				var target: int = alive[randi_range(0, alive.size() - 1)]
				mask = mask | (1 << target)

		# Flicker: killed segments randomly blink back on briefly (disabled during final death)
		if not _power_death_final:
			for i in seg:
				if i >= timers.size():
					break
				if (mask >> i) & 1 == 1:
					var timer: float = float(timers[i])
					if timer > 0.0:
						timer -= delta
						if timer <= 0.0:
							timer = 0.0
						timers[i] = timer
					elif randf() < 0.02:
						timers[i] = randf_range(0.03, 0.1)

		# Build effective mask (killed minus currently-flickering)
		var effective_mask: int = mask
		for i in seg:
			if i >= timers.size():
				break
			if float(timers[i]) > 0.0:
				effective_mask = effective_mask & ~(1 << i)  # Temporarily un-kill

		_bar_kill_masks[bar_name] = mask
		mat.set_shader_parameter("segment_kill_mask", effective_mask)

		# Dim glow proportionally to alive segments
		var alive_count: int = 0
		for i in seg:
			if (effective_mask >> i) & 1 == 0:
				alive_count += 1
		var glow: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
		if glow:
			var ratio: float = bar.value / maxf(bar.max_value, 1.0)
			var alive_frac: float = float(alive_count) / maxf(float(seg), 1.0)
			glow.color.a = 0.15 * ratio * alive_frac


func update_hardpoints(data: Array) -> void:
	# Clear existing icons
	for icon in _weapon_icons:
		if is_instance_valid(icon["container"]):
			icon["container"].queue_free()
	_weapon_icons.clear()

	for i in data.size():
		var entry: Dictionary = data[i]
		var active: bool = entry.get("active", false) as bool
		var color: Color = entry.get("color", Color.CYAN) as Color
		var icon_data: Dictionary = HudBuilder.build_weapon_icon(i + 1, active, color)
		_weapons_hbox.add_child(icon_data["container"])
		_weapon_icons.append(icon_data)


func update_cores(data: Array) -> void:
	# Clear existing core icons
	for icon in _core_icons:
		if is_instance_valid(icon["container"]):
			icon["container"].queue_free()
	_core_icons.clear()

	if data.is_empty():
		return

	# Separator between weapons and cores
	var sep: ColorRect = HudBuilder.build_icon_separator()
	_weapons_hbox.add_child(sep)
	_core_icons.append({"container": sep, "bg_rect": sep, "number_label": null, "active": false, "color": Color.WHITE})

	for i in data.size():
		var entry: Dictionary = data[i]
		var active: bool = entry.get("active", false) as bool
		var color: Color = entry.get("color", Color(0.6, 0.4, 1.0)) as Color
		var key_label: String = str(entry.get("key", str(i + 1)))
		var icon_data: Dictionary = HudBuilder.build_weapon_icon(0, active, color)
		# Override the number label text with the key label
		icon_data["number_label"].text = key_label
		_weapons_hbox.add_child(icon_data["container"])
		_core_icons.append(icon_data)


func update_devices(data: Array) -> void:
	# Clear existing device icons
	for icon in _device_icons:
		if is_instance_valid(icon["container"]):
			icon["container"].queue_free()
	_device_icons.clear()

	if data.is_empty():
		return

	# Separator between cores/weapons and devices
	var sep: ColorRect = HudBuilder.build_icon_separator()
	_weapons_hbox.add_child(sep)
	_device_icons.append({"container": sep, "bg_rect": sep, "number_label": null, "active": false, "color": Color.WHITE})

	for i in data.size():
		var entry: Dictionary = data[i]
		var active: bool = entry.get("active", false) as bool
		var color: Color = entry.get("color", Color(0.0, 0.8, 1.0)) as Color
		var key_label: String = str(entry.get("key", str(i + 1)))
		var icon_data: Dictionary = HudBuilder.build_weapon_icon(0, active, color)
		icon_data["number_label"].text = key_label
		_weapons_hbox.add_child(icon_data["container"])
		_device_icons.append(icon_data)
