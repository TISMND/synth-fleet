extends Control
## Auditions screen — side-by-side speck style previews for comparing colors,
## shapes, and effects. Each slab shows a dark viewport with twinkling specks
## scrolling upward, labeled with the style name.

const SLAB_WIDTH: int = 280
const SLAB_HEIGHT: int = 400
const SPECK_COUNT: int = 80
const SCROLL_SPEED: float = 40.0

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button
var _slabs: Array = []  # Array of slab dicts for _process updates

# Audition presets — each is a color/shape/effect combo to compare
const PRESETS: Array = [
	{
		"name": "Cool Blue (default)",
		"colors": [
			{"color": Color(0.3, 0.3, 0.55, 0.4), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.5, 0.5, 0.8, 0.55), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(0.7, 0.7, 1.0, 0.7), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Warm Amber",
		"colors": [
			{"color": Color(0.5, 0.35, 0.15, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.8, 0.55, 0.2, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(1.0, 0.75, 0.3, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Neon Pink",
		"colors": [
			{"color": Color(0.4, 0.15, 0.3, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.7, 0.2, 0.5, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(1.0, 0.4, 0.7, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Pale Violet",
		"colors": [
			{"color": Color(0.35, 0.25, 0.5, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.55, 0.4, 0.8, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(0.75, 0.6, 1.0, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Mint Green",
		"colors": [
			{"color": Color(0.2, 0.4, 0.35, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.3, 0.65, 0.55, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(0.5, 0.9, 0.75, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Pure White",
		"colors": [
			{"color": Color(0.4, 0.4, 0.4, 0.3), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.65, 0.65, 0.65, 0.45), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(0.9, 0.9, 0.95, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Synth Cyan",
		"colors": [
			{"color": Color(0.1, 0.35, 0.45, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.15, 0.6, 0.75, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(0.3, 0.85, 1.0, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Gold Dust",
		"colors": [
			{"color": Color(0.45, 0.35, 0.1, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.75, 0.6, 0.15, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(1.0, 0.85, 0.3, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Deep Red",
		"colors": [
			{"color": Color(0.4, 0.12, 0.1, 0.35), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.7, 0.18, 0.15, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(1.0, 0.3, 0.25, 0.6), "size_min": 1.0, "size_max": 2.2},
		],
	},
	{
		"name": "Mixed Cool/Warm",
		"colors": [
			{"color": Color(0.3, 0.3, 0.55, 0.4), "size_min": 0.6, "size_max": 1.4},
			{"color": Color(0.7, 0.5, 0.3, 0.5), "size_min": 0.8, "size_max": 1.8},
			{"color": Color(0.9, 0.8, 0.95, 0.65), "size_min": 1.0, "size_max": 2.2},
		],
	},
]


func _ready() -> void:
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	for slab in _slabs:
		var scroll_val: float = slab["scroll"]
		scroll_val += SCROLL_SPEED * delta
		slab["scroll"] = scroll_val
		var fields: Array = slab["fields"]
		for field in fields:
			var f: _AuditionSpeckField = field as _AuditionSpeckField
			if f:
				f.scroll_y = scroll_val * f.motion_scale
				f.queue_redraw()


func _build_ui() -> void:
	# Grid background
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	# Main scroll
	var main_scroll := ScrollContainer.new()
	main_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_scroll.offset_left = 20
	main_scroll.offset_top = 20
	main_scroll.offset_right = -20
	main_scroll.offset_bottom = -20
	add_child(main_scroll)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_scroll.add_child(main_vbox)

	# Header
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header_hbox)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header_hbox.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS — Speck Styles"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(_title_label)

	# Slab grid — wrap flow of preset slabs
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 16)
	flow.add_theme_constant_override("v_separation", 16)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(flow)

	for i in PRESETS.size():
		_build_slab(i, flow)

	_setup_vhs_overlay()


func _build_slab(index: int, parent: HFlowContainer) -> void:
	var preset: Dictionary = PRESETS[index]
	var preset_name: String = str(preset["name"])
	var color_layers: Array = preset["colors"]

	var slab_vbox := VBoxContainer.new()
	slab_vbox.add_theme_constant_override("separation", 4)
	parent.add_child(slab_vbox)

	# Label
	var label := Label.new()
	label.text = preset_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slab_vbox.add_child(label)
	ThemeManager.apply_text_glow(label, "body")

	# Viewport for dark preview
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(SLAB_WIDTH, SLAB_HEIGHT)
	vpc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slab_vbox.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(SLAB_WIDTH, SLAB_HEIGHT)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	VFXFactory.add_bloom_to_viewport(vp)

	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.04, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	# Build 3 speck sub-layers with different motion scales
	var fields: Array = []
	var motion_scales: Array[float] = [0.25, 0.5, 0.75]
	var counts: Array[int] = [50, 30, 15]

	for layer_idx in range(color_layers.size()):
		var layer_def: Dictionary = color_layers[layer_idx]
		var col: Color = layer_def["color"]
		var s_min: float = float(layer_def["size_min"])
		var s_max: float = float(layer_def["size_max"])
		var ms: float = motion_scales[layer_idx] if layer_idx < motion_scales.size() else 0.5
		var count: int = counts[layer_idx] if layer_idx < counts.size() else 30

		var field := _AuditionSpeckField.new()
		field.speck_count = count
		field.speck_color = col
		field.speck_size_min = s_min
		field.speck_size_max = s_max
		field.speck_seed = index * 100 + layer_idx * 10
		field.motion_scale = ms
		field.field_width = float(SLAB_WIDTH)
		field.field_height = float(SLAB_HEIGHT)
		field.size = Vector2(SLAB_WIDTH, SLAB_HEIGHT)
		vp.add_child(field)
		fields.append(field)

	# Etch grid overlay — same shader as level 1 background, layered on top of specks
	var etch_shader: Shader = load("res://assets/shaders/bg_synthwave_pulse.gdshader") as Shader
	if etch_shader:
		var etch_rect := ColorRect.new()
		etch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		etch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = etch_shader
		etch_rect.material = mat
		vp.add_child(etch_rect)

	_slabs.append({
		"scroll": 0.0,
		"fields": fields,
		"label": label,
	})


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
	for slab in _slabs:
		var lbl: Label = slab["label"]
		ThemeManager.apply_text_glow(lbl, "body")


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


# ── Audition speck field (self-contained, no ParallaxLayer needed) ──

class _AuditionSpeckField extends Control:
	var speck_count: int = 40
	var speck_color: Color = Color(0.5, 0.5, 0.8, 0.6)
	var speck_size_min: float = 0.8
	var speck_size_max: float = 2.0
	var speck_seed: int = 1
	var motion_scale: float = 0.5
	var scroll_y: float = 0.0
	var field_width: float = 280.0
	var field_height: float = 400.0
	var _positions: PackedVector2Array = PackedVector2Array()
	var _sizes: PackedFloat32Array = PackedFloat32Array()
	var _phases: PackedFloat32Array = PackedFloat32Array()
	var _speeds: PackedFloat32Array = PackedFloat32Array()
	var _time: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = speck_seed
		# Generate enough specks to tile vertically
		for i in speck_count:
			_positions.append(Vector2(rng.randf() * field_width, rng.randf() * field_height))
			_sizes.append(rng.randf_range(speck_size_min, speck_size_max))
			_phases.append(rng.randf() * TAU)
			_speeds.append(rng.randf_range(0.8, 2.5))

	func _process(delta: float) -> void:
		_time += delta

	func _draw() -> void:
		for i in _positions.size():
			var base_pos: Vector2 = _positions[i]
			# Scroll: wrap vertically
			var y: float = fmod(base_pos.y - scroll_y, field_height)
			if y < 0.0:
				y += field_height
			var pos := Vector2(base_pos.x, y)

			var twinkle: float = 0.6 + 0.4 * sin(_time * _speeds[i] + _phases[i])
			var col := Color(speck_color.r, speck_color.g, speck_color.b, speck_color.a * twinkle)
			var r: float = _sizes[i] * (0.85 + 0.15 * twinkle)
			draw_circle(pos, r, col)
