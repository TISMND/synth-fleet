extends Control
## Auditions screen — side-by-side comparison of bar bezel/frame treatments.
## Each variant uses HudBuilder.build_side_panel("game", ...) for bars — the exact
## same rendering code, shaders, HDR glow rects, and chrome panel as the in-game HUD.
## Bars render directly on root viewport so they bloom identically to the game
## (root WorldEnvironment has glow_enabled = true, LINEAR tonemapping).
## Bezels are positioned AFTER layout settles via call_deferred — bars are never
## reparented or structurally modified.

const VARIANT_WIDTH: int = 90
const VARIANT_HEIGHT: int = 500
const VARIANT_SPACING: int = 30
const FILL_RATIO: float = 0.5
const BEZEL_PAD: int = 10  # pixels of bezel frame around each bar

# Gain pulse demo
const PULSE_INTERVAL_MIN: float = 1.5
const PULSE_INTERVAL_MAX: float = 3.5
const WAVE_SPEED: float = 2.5

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _scroll: ScrollContainer
var _variants_hbox: HBoxContainer
var _title_label: Label
var _back_button: Button
var _bezel_shader: Shader
var _bezel_seg_shader: Shader
var _pulse_timer: float = 2.0

# Each variant: {name, params, no_bezel, name_label, panel_data, panel_root,
#                bar_entries: [{bar, seg, wave_pos, wave_active}],
#                bezel_rects: [ColorRect]}
var _variants: Array = []

const PRESETS: Array = [
	{
		"name": "CURRENT\nHUD",
		"params": {},
		"no_bezel": true,
	},
	{
		"name": "RECESSED\nCHANNEL",
		"params": {
			"bezel_width": 0.1,
			"corner_radius": 0.015,
			"inner_shadow_intensity": 1.2,
			"inner_shadow_softness": 0.4,
			"shadow_direction": 0.5,
			"bevel_intensity": 0.15,
			"bevel_softness": 0.6,
			"rim_intensity": 0.0,
			"metal_roughness": 0.4,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.2,
		}
	},
	{
		"name": "RAISED\nBEVEL",
		"params": {
			"bezel_width": 0.09,
			"corner_radius": 0.01,
			"inner_shadow_intensity": 0.5,
			"inner_shadow_softness": 0.3,
			"shadow_direction": 0.6,
			"bevel_intensity": 1.0,
			"bevel_softness": 0.3,
			"rim_intensity": 0.0,
			"metal_roughness": 0.3,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.0,
		}
	},
	{
		"name": "ROUNDED\nINSET",
		"params": {
			"bezel_width": 0.11,
			"corner_radius": 0.08,
			"inner_shadow_intensity": 0.9,
			"inner_shadow_softness": 0.7,
			"shadow_direction": 0.3,
			"bevel_intensity": 0.2,
			"bevel_softness": 0.9,
			"rim_intensity": 0.0,
			"metal_roughness": 0.5,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.0,
		}
	},
	{
		"name": "INDUSTRIAL\nBOLTED",
		"params": {
			"bezel_width": 0.12,
			"corner_radius": 0.005,
			"inner_shadow_intensity": 0.8,
			"inner_shadow_softness": 0.2,
			"shadow_direction": 0.4,
			"bevel_intensity": 0.4,
			"bevel_softness": 0.15,
			"rim_intensity": 0.0,
			"metal_roughness": 0.7,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.025,
			"rivet_brightness": 0.6,
			"depth_scale": 1.3,
		}
	},
	{
		"name": "SOCKET\nRECESSED",
		"per_segment": true,
		"params": {
			"socket_bezel": 0.15,
			"socket_radius": 0.08,
			"inner_shadow_intensity": 1.0,
			"inner_shadow_softness": 0.4,
			"shadow_direction": 0.5,
			"bevel_intensity": 0.2,
			"bevel_softness": 0.5,
			"rim_intensity": 0.0,
			"metal_roughness": 0.5,
			"depth_scale": 1.2,
		}
	},
	{
		"name": "SOCKET\nNEON",
		"per_segment": true,
		"params": {
			"socket_bezel": 0.12,
			"socket_radius": 0.15,
			"inner_shadow_intensity": 0.8,
			"inner_shadow_softness": 0.6,
			"shadow_direction": 0.0,
			"bevel_intensity": 0.1,
			"bevel_softness": 0.5,
			"rim_intensity": 1.2,
			"rim_width": 0.03,
			"rim_color": Color(0.3, 0.8, 1.0, 1.0),
			"metal_roughness": 0.4,
			"depth_scale": 1.0,
		}
	},
	{
		"name": "NEON\nTRIM",
		"params": {
			"bezel_width": 0.07,
			"corner_radius": 0.03,
			"inner_shadow_intensity": 1.0,
			"inner_shadow_softness": 0.6,
			"shadow_direction": 0.0,
			"bevel_intensity": 0.1,
			"bevel_softness": 0.5,
			"rim_intensity": 1.5,
			"rim_width": 0.015,
			"rim_color": Color(0.3, 0.8, 1.0, 1.0),
			"metal_roughness": 0.4,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.0,
		}
	},
	{
		"name": "DEEP\nWELL",
		"params": {
			"bezel_width": 0.14,
			"corner_radius": 0.02,
			"inner_shadow_intensity": 1.8,
			"inner_shadow_softness": 0.3,
			"shadow_direction": 0.5,
			"bevel_intensity": 0.3,
			"bevel_softness": 0.2,
			"rim_intensity": 0.0,
			"metal_roughness": 0.5,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.8,
		}
	},
	{
		"name": "CHAMFERED\nEDGE",
		"params": {
			"bezel_width": 0.1,
			"corner_radius": 0.01,
			"inner_shadow_intensity": 0.4,
			"inner_shadow_softness": 0.2,
			"shadow_direction": 0.6,
			"bevel_intensity": 1.2,
			"bevel_softness": 0.7,
			"rim_intensity": 0.0,
			"metal_roughness": 0.3,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.0,
		}
	},
	{
		"name": "RUBBER\nGASKET",
		"params": {
			"bezel_width": 0.08,
			"corner_radius": 0.04,
			"inner_shadow_intensity": 1.4,
			"inner_shadow_softness": 0.8,
			"shadow_direction": 0.0,
			"bevel_intensity": 0.05,
			"bevel_softness": 0.9,
			"rim_intensity": 0.0,
			"metal_color": Color(0.06, 0.06, 0.07, 1.0),
			"metal_roughness": 0.9,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 1.0,
		}
	},
	{
		"name": "FLUSH\nEMBEDDED",
		"params": {
			"bezel_width": 0.05,
			"corner_radius": 0.015,
			"inner_shadow_intensity": 0.6,
			"inner_shadow_softness": 0.6,
			"shadow_direction": 0.35,
			"bevel_intensity": 0.15,
			"bevel_softness": 0.5,
			"rim_intensity": 0.3,
			"rim_width": 0.005,
			"metal_roughness": 0.4,
			"brush_direction": 0,
			"brush_intensity": 0.0,
			"rivet_size": 0.0,
			"depth_scale": 0.7,
		}
	},
]


func _ready() -> void:
	_bezel_shader = load("res://assets/shaders/bar_bezel.gdshader") as Shader
	_bezel_seg_shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	_update_pulses(delta)


func _build_ui() -> void:
	# Grid background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 16)
	var margin := 20
	main_vbox.offset_left = margin
	main_vbox.offset_top = margin
	main_vbox.offset_right = -margin
	main_vbox.offset_bottom = -margin
	add_child(main_vbox)

	# Header row
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS — Bar Bezels"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	# Scrollable area for variants
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll)

	_variants_hbox = HBoxContainer.new()
	_variants_hbox.add_theme_constant_override("separation", VARIANT_SPACING)
	_variants_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variants_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_variants_hbox)

	for i in PRESETS.size():
		_build_variant(i)

	# Bezels must be placed AFTER layout settles so we can read bar positions
	call_deferred("_place_bezels")

	_setup_vhs_overlay()


func _build_variant(index: int) -> void:
	var preset: Dictionary = PRESETS[index]
	var preset_name: String = str(preset["name"])
	var params: Dictionary = preset["params"]
	var no_bezel: bool = preset.get("no_bezel", false) as bool

	# Outer container for label + panel
	var variant_vbox := VBoxContainer.new()
	variant_vbox.add_theme_constant_override("separation", 8)
	variant_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_variants_hbox.add_child(variant_vbox)

	# Variant name label
	var name_label := Label.new()
	name_label.text = preset_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	variant_vbox.add_child(name_label)

	# Panel holder — sizing container for the HBoxContainer layout.
	# NO clip_contents — let led_glow HDR bleed naturally for root viewport bloom.
	var panel_holder := Control.new()
	panel_holder.custom_minimum_size = Vector2(VARIANT_WIDTH, VARIANT_HEIGHT)
	panel_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	variant_vbox.add_child(panel_holder)

	# Build side panel via HudBuilder — exact same code path as game HUD.
	# "game" mode creates: ColorRect with chrome_panel shader → main_vbox →
	# zones with spacer → bar → pad → label → pad. Bars stay untouched.
	var panel_data: Dictionary = HudBuilder.build_side_panel(
		"game", ["SHIELD", "HULL"], {}, float(VARIANT_HEIGHT)
	)
	var panel_root: ColorRect = panel_data["root"]
	panel_root.position = Vector2.ZERO
	panel_root.size = Vector2(VARIANT_WIDTH, VARIANT_HEIGHT)
	panel_holder.add_child(panel_root)

	# Apply fill ratio, colors, and label theming — NO structural changes to bars.
	var bars: Dictionary = panel_data["bars"]
	var bar_entries: Array = []
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not bars.has(bar_name):
			continue
		var entry: Dictionary = bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		var lbl: Label = entry["label"]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(ShipData.DEFAULT_SEGMENTS.get(bar_name, 8))
		var is_vertical: bool = entry.get("vertical", false) as bool

		# Set fill to 50%
		bar.max_value = seg
		bar.value = int(float(seg) * FILL_RATIO)
		bar.custom_minimum_size.x = HudBuilder.BAR_WIDTH
		ThemeManager.apply_led_bar(bar, color, FILL_RATIO, seg, is_vertical)

		# Theme bar label — same call as game HUD _apply_theme
		var body_font: Font = ThemeManager.get_font("font_body")
		var body_size: int = ThemeManager.get_font_size("font_size_body")
		HudBuilder.apply_bar_label_theme(lbl, color, body_font, body_size)

		bar_entries.append({
			"bar": bar,
			"seg": seg,
			"wave_pos": -1.0,
			"wave_active": false,
		})

	var per_segment: bool = preset.get("per_segment", false) as bool
	_variants.append({
		"name": preset_name,
		"params": params,
		"no_bezel": no_bezel,
		"per_segment": per_segment,
		"name_label": name_label,
		"panel_data": panel_data,
		"panel_root": panel_root,
		"bar_entries": bar_entries,
		"bezel_rects": [],
	})


# ── Deferred bezel placement ────────────────────────────────────

func _place_bezels() -> void:
	## Called via call_deferred after layout settles. Reads actual bar positions
	## and creates bezel ColorRects around each bar. The bezel shader's transparent
	## cutout lets the bar's LED segments show through the center.
	for variant in _variants:
		if bool(variant["no_bezel"]):
			continue
		var panel_root: ColorRect = variant["panel_root"]
		var params: Dictionary = variant["params"]
		var bars: Dictionary = variant["panel_data"]["bars"]
		var bar_entries: Array = variant["bar_entries"]
		var bezel_rects: Array = variant["bezel_rects"]
		var is_per_seg: bool = variant.get("per_segment", false) as bool

		var be_idx: int = 0
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			var bar_name: String = str(spec["name"])
			if not bars.has(bar_name):
				continue
			var entry: Dictionary = bars[bar_name]
			var bar: ProgressBar = entry["bar"]
			var seg: int = int(bar_entries[be_idx]["seg"]) if be_idx < bar_entries.size() else 8
			be_idx += 1

			# Get bar's position relative to panel_root
			var bar_local_pos: Vector2 = bar.global_position - panel_root.global_position

			# Per-segment bezels sit exactly on the bar (no padding — they tile
			# around each LED segment). Whole-bar bezels extend beyond the bar.
			var pad: float = 0.0 if is_per_seg else float(BEZEL_PAD)

			var bezel_rect := ColorRect.new()
			bezel_rect.position = Vector2(
				bar_local_pos.x - pad,
				bar_local_pos.y - pad
			)
			bezel_rect.size = Vector2(
				bar.size.x + pad * 2.0,
				bar.size.y + pad * 2.0
			)
			bezel_rect.color = Color.WHITE
			bezel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

			if is_per_seg and _bezel_seg_shader:
				# Per-segment bezel — needs segment grid params to align with LED bar
				var mat := ShaderMaterial.new()
				mat.shader = _bezel_seg_shader
				_apply_bezel_params(mat, params)
				# Pass segment grid params from the bar's LED shader
				mat.set_shader_parameter("segment_count", seg)
				if bar.material is ShaderMaterial:
					var bar_mat: ShaderMaterial = bar.material as ShaderMaterial
					mat.set_shader_parameter("segment_gap", bar_mat.get_shader_parameter("segment_gap"))
				mat.set_shader_parameter("vertical", 1)
				bezel_rect.material = mat
			elif _bezel_shader:
				var mat := ShaderMaterial.new()
				mat.shader = _bezel_shader
				_apply_bezel_params(mat, params)
				bezel_rect.material = mat

			# Add as child of panel_root — renders after main_vbox (on top).
			# Shader's transparent cutout lets bar show through.
			panel_root.add_child(bezel_rect)
			bezel_rects.append(bezel_rect)


func _reposition_bezels() -> void:
	## Re-reads bar positions and updates bezel rects. Called after theme changes
	## that might change segment count → bar height → bar position.
	for variant in _variants:
		if bool(variant["no_bezel"]):
			continue
		var panel_root: ColorRect = variant["panel_root"]
		var bars: Dictionary = variant["panel_data"]["bars"]
		var bezel_rects: Array = variant["bezel_rects"]
		var is_per_seg: bool = variant.get("per_segment", false) as bool
		var pad: float = 0.0 if is_per_seg else float(BEZEL_PAD)

		var bezel_idx: int = 0
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			var bar_name: String = str(spec["name"])
			if not bars.has(bar_name):
				continue
			if bezel_idx >= bezel_rects.size():
				break
			var bar: ProgressBar = bars[bar_name]["bar"]
			var bezel_rect: ColorRect = bezel_rects[bezel_idx]

			var bar_local_pos: Vector2 = bar.global_position - panel_root.global_position
			bezel_rect.position = Vector2(
				bar_local_pos.x - pad,
				bar_local_pos.y - pad
			)
			bezel_rect.size = Vector2(
				bar.size.x + pad * 2.0,
				bar.size.y + pad * 2.0
			)
			bezel_idx += 1


func _apply_bezel_params(mat: ShaderMaterial, params: Dictionary) -> void:
	for key in params:
		var value = params[key]
		mat.set_shader_parameter(key, value)


# ── Gain pulse animation ────────────────────────────────────────

func _update_pulses(delta: float) -> void:
	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_trigger_random_pulse()
		_pulse_timer = randf_range(PULSE_INTERVAL_MIN, PULSE_INTERVAL_MAX)

	# Advance all active waves
	for variant in _variants:
		var bar_entries: Array = variant["bar_entries"]
		for entry in bar_entries:
			if not bool(entry["wave_active"]):
				continue
			var pos: float = float(entry["wave_pos"])
			pos += WAVE_SPEED * delta
			if pos > 1.3:
				entry["wave_active"] = false
				entry["wave_pos"] = -1.0
			else:
				entry["wave_pos"] = pos

			# Update shader uniform — same as game HUD _apply_wave_uniforms
			var bar: ProgressBar = entry["bar"]
			if bar.material is ShaderMaterial:
				var mat: ShaderMaterial = bar.material as ShaderMaterial
				var wave_val: float = float(entry["wave_pos"]) if bool(entry["wave_active"]) else -1.0
				mat.set_shader_parameter("gain_wave_pos", wave_val)


func _trigger_random_pulse() -> void:
	if _variants.is_empty():
		return
	var vi: int = randi_range(0, _variants.size() - 1)
	var variant: Dictionary = _variants[vi]
	var bar_entries: Array = variant["bar_entries"]
	if bar_entries.is_empty():
		return
	var bi: int = randi_range(0, bar_entries.size() - 1)
	var entry: Dictionary = bar_entries[bi]
	if not bool(entry["wave_active"]):
		entry["wave_pos"] = 0.0
	entry["wave_active"] = true


# ── Theme ────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)

	var body_font: Font = ThemeManager.get_font("font_body")
	var body_size: int = ThemeManager.get_font_size("font_size_body")
	var accent: Color = ThemeManager.get_color("accent")

	for variant in _variants:
		# Variant name label
		var name_lbl: Label = variant["name_label"]
		name_lbl.add_theme_font_size_override("font_size", body_size)
		name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("body"))
		if body_font:
			name_lbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(name_lbl, "body")

		# Chrome panel divider accent
		var panel_root: ColorRect = variant["panel_root"]
		if panel_root.material is ShaderMaterial:
			var chrome_mat: ShaderMaterial = panel_root.material as ShaderMaterial
			chrome_mat.set_shader_parameter("divider_color", Vector4(accent.r, accent.g, accent.b, 0.5))

		# Re-apply LED bars and bar labels — pass stored segment count (never -1)
		var panel_data: Dictionary = variant["panel_data"]
		var bars: Dictionary = panel_data["bars"]
		var bar_entries: Array = variant["bar_entries"]
		var be_idx: int = 0
		var specs: Array = ThemeManager.get_status_bar_specs()
		for spec in specs:
			var bar_name: String = str(spec["name"])
			if not bars.has(bar_name):
				continue
			var entry: Dictionary = bars[bar_name]
			var color: Color = ThemeManager.resolve_bar_color(spec)
			var bar: ProgressBar = entry["bar"]
			var is_vertical: bool = entry.get("vertical", false) as bool
			var seg: int = int(bar_entries[be_idx]["seg"]) if be_idx < bar_entries.size() else 8
			bar.custom_minimum_size.x = HudBuilder.BAR_WIDTH
			ThemeManager.apply_led_bar(bar, color, FILL_RATIO, seg, is_vertical)
			HudBuilder.apply_bar_label_theme(entry["label"], color, body_font, body_size)
			be_idx += 1

	# Reposition bezels after bars may have changed size
	call_deferred("_reposition_bezels")


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
