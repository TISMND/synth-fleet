extends CanvasLayer
## In-game HUD — bottom icon bar + vertical side bars for status.
## Fully themed via ThemeManager with theme_changed reactivity.
## Layout delegated to HudBuilder for single source of truth.

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
		ThemeManager.apply_led_bar(bar, color, ratio, seg, is_vertical)
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
	if bar.material is ShaderMaterial:
		var mat: ShaderMaterial = bar.material as ShaderMaterial
		mat.set_shader_parameter("fill_ratio", ratio)
	else:
		# First time or after theme change — full rebuild
		var seg: int = int(_bar_segments.get(bar_name, -1))
		var is_vertical: bool = entry.get("vertical", false) as bool
		ThemeManager.apply_led_bar(bar, ThemeManager.get_color(color_key), ratio, seg, is_vertical)


func pulse_bar(bar_name: String) -> void:
	## Trigger a gain wave on a status bar (called when a power core trigger fires).
	trigger_gain_wave(bar_name)


func trigger_gain_wave(bar_name: String) -> void:
	## Start an upward-rolling gain wave from bottom (0.0) to top (1.0).
	if not _bar_gain_wave.has(bar_name):
		return
	var wave: Dictionary = _bar_gain_wave[bar_name]
	wave["active"] = true
	wave["position"] = 0.0
	wave["speed"] = WAVE_SPEED


func trigger_drain_wave(bar_name: String) -> void:
	## Start a downward-rolling drain wave from top (1.0) to bottom (0.0).
	if not _bar_drain_wave.has(bar_name):
		return
	var wave: Dictionary = _bar_drain_wave[bar_name]
	wave["active"] = true
	wave["position"] = 1.0
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
