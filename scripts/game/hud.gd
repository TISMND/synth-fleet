extends Control
## In-game HUD — bottom icon bar + vertical side bars for status.
## Fully themed via ThemeManager with theme_changed reactivity.
## Layout delegated to HudBuilder for single source of truth.
## Extends Control (not CanvasLayer) so bars participate in WorldEnvironment
## glow post-processing. CanvasLayer content renders after bloom and misses it.

var _credits_label: Label = null
var _menu_hint: Label = null
var _hud_result: Dictionary = {}  # HudBuilder.build_hud() result
var _bottom_panel: Dictionary = {}  # build_bottom_panel() result
var _comp_icons_hbox: HBoxContainer = null  # Component icons container in bottom panel
var _fg_icons_hbox_bottom: HBoxContainer = null  # Fire group icons container in bottom panel
var _weapon_icons: Array = []  # Array of dicts from _build_bezeled_icon
var _core_icons: Array = []
var _device_icons: Array = []
var _warning_labels: Array = []  # Warning label nodes from bottom panel
var _warning_rotator: _WarningRotator = null  # Upper-center cycling warning display
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

# Intro bar fill
var _intro_bar_active: bool = false


func _ready() -> void:
	_build_ui()
	_setup_vhs_overlay()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)



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

	# Warning rotator — upper center, cycles active warnings
	_warning_rotator = _WarningRotator.new()
	_warning_rotator.position = Vector2(960 - 110, 60)  # Centered horizontally, near top
	add_child(_warning_rotator)

	# Build 3-panel HUD via HudBuilder
	var side_top: float = 60.0
	var side_bottom: float = 1080.0 - HudBuilder.BOTTOM_BAR_HEIGHT - 8.0
	var side_height: float = side_bottom - side_top
	_hud_result = HudBuilder.build_hud("game", side_height)

	# Position bottom panel
	_bottom_panel = _hud_result["bottom_panel"]
	var bottom_root: ColorRect = _bottom_panel["root"]
	bottom_root.position = Vector2(0, 1080 - HudBuilder.BOTTOM_BAR_HEIGHT)
	bottom_root.size = Vector2(1920, HudBuilder.BOTTOM_BAR_HEIGHT)
	add_child(bottom_root)
	_warning_labels = _bottom_panel["warning_labels"]
	_comp_icons_hbox = _bottom_panel["comp_icons_hbox"]
	_fg_icons_hbox_bottom = _bottom_panel["fg_icons_hbox"]

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
		if icon.has("bg_rect"):
			HudBuilder.apply_bezeled_icon_theme(icon)
	for icon in _core_icons:
		if icon.has("bg_rect"):
			HudBuilder.apply_bezeled_icon_theme(icon)
	for icon in _device_icons:
		if icon.has("bg_rect"):
			HudBuilder.apply_bezeled_icon_theme(icon)


func update_health(current_shield: float, max_shield: float, current_hull: float, max_hull: float) -> void:
	_update_bar("SHIELD", current_shield, max_shield, "bar_shield")
	_update_bar("HULL", current_hull, max_hull, "bar_hull")


func update_all_bars(current_shield: float, max_shield: float, current_hull: float, max_hull: float, current_thermal: float, max_thermal: float, current_electric: float, max_electric: float) -> void:
	_update_bar("SHIELD", current_shield, max_shield, "bar_shield")
	_update_bar("HULL", current_hull, max_hull, "bar_hull")
	_update_bar("THERMAL", current_thermal, max_thermal, "bar_thermal")
	_update_bar("ELECTRIC", current_electric, max_electric, "bar_electric")
	# Update warning displays
	_update_warnings({
		"THERMAL": current_thermal / maxf(max_thermal, 1.0),
		"HULL": current_hull / maxf(max_hull, 1.0),
		"SHIELD": current_shield / maxf(max_shield, 1.0),
		"ELECTRIC": current_electric / maxf(max_electric, 1.0),
	})


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
	var hull_exempt: bool = _power_death_active and bar_name == "HULL"
	if bar.material is ShaderMaterial:
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		if _power_death_active and not hull_exempt:
			mat.set_shader_parameter("fill_ratio", 1.0)
		else:
			mat.set_shader_parameter("fill_ratio", ratio)
	# Update glow rect alpha to match fill
	var glow_rect: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
	if glow_rect:
		if not _power_death_active or hull_exempt:
			glow_rect.color.a = 0.15 * ratio
			# Keep glow rect clipped to filled portion so OFF segments stay dark
			var is_vert: bool = entry.get("vertical", false) as bool
			if is_vert:
				glow_rect.anchor_top = 1.0 - ratio
			else:
				glow_rect.anchor_right = ratio
		# During power death, glow managed by kill animation (except hull)
	else:
		# First time or after theme change — full rebuild
		var seg: int = int(_bar_segments.get(bar_name, -1))
		var is_vertical: bool = entry.get("vertical", false) as bool
		ThemeManager.apply_led_bar(bar, ThemeManager.get_color(color_key), ratio, seg, is_vertical)
		HudBuilder.update_bar_bezel(entry, seg)
		# Re-force fill_ratio if in power death (apply_led_bar resets it)
		if _power_death_active and not hull_exempt and bar.material is ShaderMaterial:
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


var _warning_flash_time: float = 0.0

func _update_warnings(ratios: Dictionary) -> void:
	if _warning_labels.is_empty():
		return
	_warning_flash_time += get_process_delta_time() * 3.0
	var flash: bool = fmod(_warning_flash_time, 2.0) < 1.4
	var warning_color := Color(1.0, 0.2, 0.1)

	# Find the most critical active warning
	var active_warning: String = ""
	for w in HudBuilder.WARNINGS:
		var stat: String = str(w["stat"])
		var threshold: float = float(w["threshold"])
		var above: bool = w["above"]
		var ratio: float = float(ratios.get(stat, 0.0))
		if above and ratio > threshold:
			active_warning = str(w["text"])
			break
		elif not above and ratio < threshold:
			active_warning = str(w["text"])
			break

	for lbl in _warning_labels:
		if active_warning != "" and flash:
			(lbl as Label).text = active_warning
			HudBuilder.set_warning_active(lbl, true, warning_color)
		else:
			(lbl as Label).text = ""
			HudBuilder.set_warning_active(lbl, false, warning_color)


func update_warnings_rotator(active_warnings: Array) -> void:
	## Feed the upper-center warning rotator with currently active warning IDs.
	## Each entry: {"id": "heat", "label": "HEAT", "color": Color(...), "hdr": 2.8}
	if _warning_rotator:
		_warning_rotator.set_active_warnings(active_warnings)


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
	if _shield_arc_timer <= 0.0 and _shield_arcs.size() < 4:
		_spawn_shield_arc()
		_shield_arc_timer = randf_range(0.06, 0.25)
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
	line.modulate = Color(3.4, 3.4, 3.4, 1.0)
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
		if bar_name == "HULL":
			continue  # Hull bar stays alive during power loss
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
		if bar_name == "HULL":
			continue
		var timers: Array = _bar_flicker_timers[bar_name]
		for i in timers.size():
			timers[i] = 0.0


func set_power_recovery_ratio(t: float, bar_targets: Dictionary = {}) -> void:
	## During recovery, restore segments proportionally per bar.
	## bar_targets: {bar_name: target_ratio} e.g. {"SHIELD": 0.5, "ELECTRIC": 1.0}
	## Bars not in targets default to 0.0 (stay dark).
	if not _power_death_active:
		return
	# Stop the kill animation from fighting the recovery
	_power_death_final = false
	var first_bar: bool = true
	for bar_name in _bars:
		var seg: int = int(_bar_segments.get(bar_name, 8))
		var target_ratio: float = float(bar_targets.get(bar_name, 0.0))
		# How many segments should be alive at this point in the recovery
		var alive_count: int = int(float(seg) * target_ratio * t)
		alive_count = clampi(alive_count, 0, seg)
		# Kill mask: segments at index >= alive_count are killed (dark)
		# Segments at index < alive_count are alive (lit)
		var mask: int = 0
		for i in seg:
			if i >= alive_count:
				mask = mask | (1 << i)
		if first_bar:
			print("[HUD-RECOVERY] bar=%s seg=%d target=%.1f t=%.2f alive=%d mask=%d" % [bar_name, seg, target_ratio, t, alive_count, mask])
			first_bar = false
		_bar_kill_masks[bar_name] = mask
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			(bar.material as ShaderMaterial).set_shader_parameter("segment_kill_mask", mask)
		var glow: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
		if glow:
			glow.color.a = 0.15 * target_ratio * t


func stop_power_death_bars() -> void:
	_power_death_active = false
	_power_death_elapsed = 0.0
	_power_death_final = false
	_power_death_final_elapsed = 0.0
	# Restore hull bar modulate (was flickering during power loss)
	if _bars.has("HULL"):
		var hull_bar: ProgressBar = _bars["HULL"]["bar"]
		hull_bar.modulate.a = 1.0
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
			var is_vert: bool = entry.get("vertical", false) as bool
			if is_vert:
				glow.anchor_top = 1.0 - ratio
			else:
				glow.anchor_right = ratio


# ── Intro bar fill — all bars dark → full during level intro ──────────

func start_intro_bars() -> void:
	## Kill all bar segments for the intro (ship powering on).
	_intro_bar_active = true
	for bar_name in _bars:
		var seg: int = int(_bar_segments.get(bar_name, 8))
		var mask: int = (1 << seg) - 1  # All bits set = all segments killed
		_bar_kill_masks[bar_name] = mask
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			var mat: ShaderMaterial = bar.material as ShaderMaterial
			mat.set_shader_parameter("segment_kill_mask", mask)
			mat.set_shader_parameter("fill_ratio", 1.0)  # All segments visible for the fill effect
		var glow: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
		if glow:
			glow.color.a = 0.0
			# Collapse glow rect — no segments lit yet
			var is_vert: bool = entry.get("vertical", false) as bool
			if is_vert:
				glow.anchor_top = 1.0
			else:
				glow.anchor_right = 0.0


func process_intro_bar_fill(t: float) -> void:
	## Animate bars from dark to full. t goes 0.0 → 1.0 over the fill duration.
	if not _intro_bar_active:
		return
	for bar_name in _bars:
		var seg: int = int(_bar_segments.get(bar_name, 8))
		var alive_count: int = int(float(seg) * t)
		alive_count = clampi(alive_count, 0, seg)
		var mask: int = 0
		for i in seg:
			if i >= alive_count:
				mask = mask | (1 << i)
		_bar_kill_masks[bar_name] = mask
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			(bar.material as ShaderMaterial).set_shader_parameter("segment_kill_mask", mask)
		var glow: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
		if glow:
			glow.color.a = 0.15 * t
			# Expand glow rect as segments light up
			var is_vert: bool = entry.get("vertical", false) as bool
			if is_vert:
				glow.anchor_top = 1.0 - t
			else:
				glow.anchor_right = t


func stop_intro_bars() -> void:
	## End intro bar fill — restore normal rendering.
	_intro_bar_active = false
	for bar_name in _bars:
		_bar_kill_masks[bar_name] = 0
		var entry: Dictionary = _bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		if bar.material is ShaderMaterial:
			var mat: ShaderMaterial = bar.material as ShaderMaterial
			mat.set_shader_parameter("segment_kill_mask", 0)
			var ratio: float = bar.value / maxf(bar.max_value, 1.0)
			mat.set_shader_parameter("fill_ratio", ratio)
		var glow: ColorRect = bar.get_node_or_null("led_glow") as ColorRect
		if glow:
			var ratio: float = bar.value / maxf(bar.max_value, 1.0)
			glow.color.a = 0.15 * ratio
			var is_vert: bool = entry.get("vertical", false) as bool
			if is_vert:
				glow.anchor_top = 1.0 - ratio
			else:
				glow.anchor_right = ratio


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
		if bar_name == "HULL":
			continue  # Hull bar stays alive — handled separately below
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

	# Hull bar: subtle flicker to convey failing power, but still functional
	if _bars.has("HULL"):
		var hull_entry: Dictionary = _bars["HULL"]
		var hull_bar: ProgressBar = hull_entry["bar"]
		hull_bar.modulate.a = 0.5 + randf() * 0.5


func update_hardpoints(data: Array) -> void:
	if not _comp_icons_hbox:
		return
	# First call: build icons. Subsequent calls: just toggle active state.
	if _weapon_icons.size() != data.size():
		# Rebuild — slot count changed (loadout change)
		for icon in _weapon_icons:
			if is_instance_valid(icon["container"]):
				icon["container"].queue_free()
		_weapon_icons.clear()
		var bezel_shader: Shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
		for i in data.size():
			var entry: Dictionary = data[i]
			var color: Color = entry.get("color", Color.CYAN) as Color
			var active: bool = entry.get("active", false) as bool
			var icon_data: Dictionary = HudBuilder._build_bezeled_icon(str(i + 1), active, color, bezel_shader)
			_comp_icons_hbox.add_child(icon_data["container"])
			_weapon_icons.append(icon_data)
	else:
		# Same count — just update active state
		for i in data.size():
			var active: bool = data[i].get("active", false) as bool
			_weapon_icons[i]["active"] = active
			HudBuilder.apply_bezeled_icon_theme(_weapon_icons[i])


func update_cores(data: Array) -> void:
	if not _comp_icons_hbox:
		return
	if _core_icons.size() != data.size():
		for icon in _core_icons:
			if icon.has("container") and is_instance_valid(icon["container"]):
				icon["container"].queue_free()
		_core_icons.clear()
		if data.is_empty():
			return
		var bezel_shader: Shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
		# Separator
		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(2, HudBuilder.BOTTOM_ICON_SIZE)
		sep.color = ThemeManager.get_color("disabled")
		_comp_icons_hbox.add_child(sep)
		for i in data.size():
			var entry: Dictionary = data[i]
			var color: Color = entry.get("color", Color(0.6, 0.4, 1.0)) as Color
			var active: bool = entry.get("active", false) as bool
			var slot_num: int = _weapon_icons.size() + i + 1
			var icon_data: Dictionary = HudBuilder._build_bezeled_icon(str(slot_num), active, color, bezel_shader)
			_comp_icons_hbox.add_child(icon_data["container"])
			_core_icons.append(icon_data)
	else:
		for i in data.size():
			var active: bool = data[i].get("active", false) as bool
			_core_icons[i]["active"] = active
			HudBuilder.apply_bezeled_icon_theme(_core_icons[i])


func update_devices(data: Array) -> void:
	if not _comp_icons_hbox:
		return
	if _device_icons.size() != data.size():
		for icon in _device_icons:
			if icon.has("container") and is_instance_valid(icon["container"]):
				icon["container"].queue_free()
		_device_icons.clear()
		if data.is_empty():
			return
		var bezel_shader: Shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
		# Separator
		var sep := ColorRect.new()
		sep.custom_minimum_size = Vector2(2, HudBuilder.BOTTOM_ICON_SIZE)
		sep.color = ThemeManager.get_color("disabled")
		_comp_icons_hbox.add_child(sep)
		for i in data.size():
			var entry: Dictionary = data[i]
			var color: Color = entry.get("color", Color(0.0, 0.8, 1.0)) as Color
			var active: bool = entry.get("active", false) as bool
			var slot_num: int = _weapon_icons.size() + _core_icons.size() + i + 1
			var icon_data: Dictionary = HudBuilder._build_bezeled_icon(str(slot_num), active, color, bezel_shader)
			_comp_icons_hbox.add_child(icon_data["container"])
			_device_icons.append(icon_data)
	else:
		for i in data.size():
			var active: bool = data[i].get("active", false) as bool
			_device_icons[i]["active"] = active
			HudBuilder.apply_bezeled_icon_theme(_device_icons[i])


# ── Warning Rotator — upper-center cycling warning display ───────────────

class _WarningRotator extends Control:
	## Cycles through active warnings: 500ms visible, 500ms off, then next warning.
	## Draws procedurally with HDR colors (same pipeline as ships/bars on root viewport).
	const BOX_W: float = 220.0
	const BOX_H: float = 50.0
	const CYCLE_ON: float = 0.5   # seconds visible
	const CYCLE_OFF: float = 0.5  # seconds dark
	const HULL_DAMAGED_DURATION: float = 2.0  # seconds before "HULL DAMAGED" auto-clears

	# Style params (preset 9: corner marks chromatic)
	const BORDER_W: float = 2.0
	const GLOW_LAYERS: int = 4
	const GLOW_SPREAD: float = 3.0
	const SCANLINE_SPACING: float = 3.0
	const SCANLINE_ALPHA: float = 0.35
	const SCANLINE_SCROLL: float = 45.0
	const FLICKER_SPEED: float = 7.0
	const FLICKER_AMOUNT: float = 0.22

	var _active_warnings: Array = []  # Array of {id, label, color, hdr}
	var _cycle_timer: float = 0.0
	var _current_index: int = 0
	var _showing: bool = true
	var _time: float = 0.0

	func _ready() -> void:
		size = Vector2(BOX_W, BOX_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_active_warnings(warnings: Array) -> void:
		_active_warnings = warnings
		if _active_warnings.is_empty():
			_current_index = 0
			visible = false
			return
		visible = true
		if _current_index >= _active_warnings.size():
			_current_index = 0

	func _process(delta: float) -> void:
		_time += delta
		if _active_warnings.is_empty():
			return
		_cycle_timer += delta
		var cycle_total: float = CYCLE_ON + CYCLE_OFF
		if _cycle_timer >= cycle_total:
			_cycle_timer -= cycle_total
			_current_index = (_current_index + 1) % _active_warnings.size()
		_showing = _cycle_timer < CYCLE_ON
		queue_redraw()

	func _draw() -> void:
		if _active_warnings.is_empty() or not _showing:
			return
		if _current_index >= _active_warnings.size():
			return

		var warning: Dictionary = _active_warnings[_current_index]
		var col: Color = warning.get("color", Color.RED)
		var hdr: float = float(warning.get("hdr", 2.8))
		var label_text: String = str(warning.get("label", "WARNING"))

		var flicker: float = 1.0 - FLICKER_AMOUNT * (0.5 + 0.5 * sin(_time * FLICKER_SPEED + sin(_time * 2.3) * 3.0))
		var w: float = BOX_W
		var h: float = BOX_H

		# Glow layers
		for gi in range(GLOW_LAYERS, 0, -1):
			var t: float = float(gi) / float(GLOW_LAYERS)
			var expand: float = t * GLOW_SPREAD * float(GLOW_LAYERS)
			var glow_alpha: float = (1.0 - t) * 0.15 * flicker
			var glow_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, glow_alpha)
			draw_rect(Rect2(Vector2(-expand, -expand), Vector2(w + expand * 2.0, h + expand * 2.0)),
				glow_col, false, BORDER_W + expand * 0.5)

		# Main border
		draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)),
			Color(col.r * hdr, col.g * hdr, col.b * hdr, 0.9 * flicker), false, BORDER_W)

		# Corner marks
		var cm_len: float = 10.0
		var cm_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, 0.7 * flicker)
		var cm_off: float = -3.0
		draw_line(Vector2(cm_off, cm_off), Vector2(cm_off + cm_len, cm_off), cm_col, 1.5)
		draw_line(Vector2(cm_off, cm_off), Vector2(cm_off, cm_off + cm_len), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off - cm_len, cm_off), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, cm_off), Vector2(w - cm_off, cm_off + cm_len), cm_col, 1.5)
		draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off + cm_len, h - cm_off), cm_col, 1.5)
		draw_line(Vector2(cm_off, h - cm_off), Vector2(cm_off, h - cm_off - cm_len), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off - cm_len, h - cm_off), cm_col, 1.5)
		draw_line(Vector2(w - cm_off, h - cm_off), Vector2(w - cm_off, h - cm_off - cm_len), cm_col, 1.5)

		# Scanlines
		var scan_col := Color(col.r * hdr * 0.5, col.g * hdr * 0.5, col.b * hdr * 0.5, SCANLINE_ALPHA * flicker)
		var scroll_offset: float = fmod(_time * SCANLINE_SCROLL, SCANLINE_SPACING)
		var y: float = scroll_offset
		while y < h:
			draw_line(Vector2(BORDER_W, y), Vector2(w - BORDER_W, y), scan_col, 1.0)
			y += SCANLINE_SPACING

		# Label text — draw_string centered
		var font: Font = ThemeManager.get_font("font_header")
		if not font:
			font = ThemeDB.fallback_font
		var font_size: int = 22
		var text_size: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_x: float = (w - text_size.x) * 0.5
		var text_y: float = (h + text_size.y * 0.6) * 0.5
		var text_col := Color(col.r * hdr, col.g * hdr, col.b * hdr, 0.95 * flicker)
		draw_string(font, Vector2(text_x, text_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
