extends MarginContainer
## Fields Tab — visual style editor for field effects (shader + color + pulse settings).
## Styles are saved to res://data/field_styles/ and referenced by devices.

const FIELD_SHADERS: Array[String] = ["force_bubble", "hex_grid", "energy_ripple", "plasma_shield", "particle_ring", "pulse_barrier", "inner_glow", "sun_rays", "shimmer", "hologram", "gravity_well", "spiral", "warp_lens", "fountain"]

const FIELD_SHADER_PARAM_DEFS: Dictionary = {
	"force_bubble": {"refraction_strength": [0.0, 0.3, 0.05, 0.01], "edge_width": [0.0, 0.3, 0.1, 0.01], "wobble_speed": [0.0, 4.0, 1.0, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"hex_grid": {"hex_size": [0.0, 0.2, 0.08, 0.01], "line_thickness": [0.0, 0.15, 0.06, 0.01], "scroll_speed": [0.0, 3.0, 0.5, 0.1], "edge_density": [0.0, 1.0, 0.5, 0.05], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"energy_ripple": {"ring_count": [0.0, 12.0, 5.0, 1.0], "ring_width": [0.0, 0.1, 0.03, 0.01], "expansion_speed": [0.0, 3.0, 1.0, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"plasma_shield": {"turbulence_speed": [0.0, 4.0, 1.5, 0.1], "plasma_density": [0.0, 8.0, 4.0, 0.5], "edge_glow": [0.0, 3.0, 1.5, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"particle_ring": {"particle_count": [0.0, 32.0, 12.0, 1.0], "orbit_speed": [0.0, 4.0, 1.0, 0.1], "particle_size": [0.0, 0.1, 0.04, 0.01], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"pulse_barrier": {"barrier_width": [0.0, 0.2, 0.08, 0.01], "pulse_decay": [0.0, 2.0, 0.5, 0.1], "flash_intensity": [0.0, 4.0, 2.0, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"inner_glow": {"glow_falloff": [0.0, 6.0, 2.5, 0.1], "core_size": [0.0, 0.5, 0.15, 0.01], "flicker_speed": [0.0, 4.0, 1.0, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"sun_rays": {"ray_count": [0.0, 24.0, 8.0, 1.0], "ray_width": [0.0, 0.5, 0.2, 0.01], "ray_rotation_speed": [0.0, 3.0, 0.5, 0.1], "length_variance": [0.0, 1.0, 0.4, 0.05], "width_variance": [0.0, 1.0, 0.3, 0.05], "brightness_variance": [0.0, 1.0, 0.5, 0.05], "chaos_speed": [0.0, 3.0, 0.8, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"shimmer": {"wave_frequency": [0.0, 12.0, 5.0, 0.5], "distortion_strength": [0.0, 0.15, 0.05, 0.01], "rainbow_intensity": [0.0, 1.0, 0.5, 0.05], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"hologram": {"scan_frequency": [0.0, 40.0, 20.0, 1.0], "scan_speed": [0.0, 10.0, 4.0, 0.5], "jitter_intensity": [0.0, 1.0, 0.5, 0.05], "jitter_rate": [0.0, 8.0, 3.0, 0.5], "aberration": [0.0, 0.1, 0.03, 0.005], "outer_radius": [0.0, 1.0, 0.95, 0.01], "blink_interval": [0.0, 8.0, 3.0, 0.1], "blink_duration": [0.0, 1.0, 0.1, 0.01], "blink_irregularity": [0.0, 1.0, 0.5, 0.05]},
	"gravity_well": {"stream_count": [1.0, 24.0, 10.0, 1.0], "stream_speed": [0.0, 4.0, 1.5, 0.1], "stream_width": [0.01, 0.4, 0.15, 0.01], "curl_amount": [0.0, 3.0, 0.8, 0.1], "fade_sharpness": [0.5, 4.0, 2.0, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"spiral": {"arm_count": [1.0, 8.0, 3.0, 1.0], "arm_width": [0.05, 0.5, 0.25, 0.01], "wind_tightness": [0.5, 6.0, 2.5, 0.1], "rotation_speed": [0.0, 4.0, 1.0, 0.1], "trail_decay": [0.5, 4.0, 1.5, 0.1], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"warp_lens": {"warp_strength": [0.0, 0.3, 0.08, 0.01], "ripple_frequency": [1.0, 12.0, 4.0, 0.5], "ripple_speed": [0.0, 4.0, 1.5, 0.1], "edge_visibility": [0.0, 2.0, 1.0, 0.1], "chromatic_split": [0.0, 0.05, 0.01, 0.005], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
	"fountain": {"particle_count": [4.0, 48.0, 20.0, 1.0], "emit_speed": [0.2, 4.0, 1.2, 0.1], "particle_size": [0.005, 0.08, 0.03, 0.005], "spread": [0.0, 1.0, 0.3, 0.05], "lifetime_variance": [0.0, 1.0, 0.5, 0.05], "outer_radius": [0.0, 1.0, 0.95, 0.01]},
}

# UI references
var _load_button: OptionButton
var _save_button: Button
var _delete_button: Button
var _new_button: Button
var _status_label: Label
var _name_input: LineEdit
var _shader_button: OptionButton
var _color_picker: ColorPickerButton
var _brightness_slider: HSlider
var _brightness_label: Label
var _anim_speed_slider: HSlider
var _anim_speed_label: Label
var _radius_ratio_slider: HSlider
var _radius_ratio_label: Label
var _pulse_brightness_slider: HSlider
var _pulse_brightness_label: Label
var _pulse_tint_slider: HSlider
var _pulse_tint_label: Label

# Ship effect controls
var _ship_tint_strength_slider: HSlider
var _ship_tint_strength_label: Label
var _ship_active_hdr_slider: HSlider
var _ship_active_hdr_label: Label
var _ship_pulse_hdr_slider: HSlider
var _ship_pulse_hdr_label: Label

# Dynamic shader params
var _shader_params_container: VBoxContainer
var _shader_param_sliders: Dictionary = {}

# Preview
var _preview_sprite: Sprite2D = null
var _preview_material: ShaderMaterial = null
var _preview_ship_renderer: ShipRenderer = null
var _auto_pulse_timer: float = 0.0
var _pulse_elapsed: float = 0.0
var _pulse_active: bool = false

# State
var _current_id: String = ""
var _section_headers: Array[Label] = []
var _ui_ready: bool = false

const PREVIEW_RADIUS: float = 120.0


func _ready() -> void:
	_build_ui()
	_ui_ready = true
	_refresh_load_list()
	call_deferred("_update_preview")
	ThemeManager.theme_changed.connect(_apply_theme)


func _process(delta: float) -> void:
	# Auto-pulse every ~1.5s for preview
	if _pulse_brightness_slider and _pulse_brightness_slider.value <= 0.0:
		if _preview_material:
			_preview_material.set_shader_parameter("pulse_intensity", 0.0)
		_pulse_active = false
		return
	_auto_pulse_timer += delta
	if _auto_pulse_timer >= 1.5:
		_auto_pulse_timer = 0.0
		_pulse_elapsed = 0.0
		_pulse_active = true
	# Three-phase pulse envelope: fade up → sustain → fade out (hardcoded timing, brightness from slider)
	if _pulse_active and _preview_material:
		var total_dur: float = 0.5
		var fade_up: float = 0.05
		var fade_out: float = 0.4
		var pulse_bright: float = _pulse_brightness_slider.value if _pulse_brightness_slider else 2.0
		# Clamp so fade_up + fade_out don't exceed total duration
		if fade_up + fade_out > total_dur:
			var scale: float = total_dur / maxf(fade_up + fade_out, 0.001)
			fade_up *= scale
			fade_out *= scale
		_pulse_elapsed += delta
		if _pulse_elapsed >= total_dur:
			_pulse_active = false
			_preview_material.set_shader_parameter("pulse_intensity", 0.0)
		else:
			var fade_out_start: float = total_dur - fade_out
			var envelope: float
			if _pulse_elapsed < fade_up:
				envelope = _pulse_elapsed / maxf(fade_up, 0.001)
			elif _pulse_elapsed < fade_out_start:
				envelope = 1.0
			else:
				var remaining: float = total_dur - _pulse_elapsed
				envelope = remaining / maxf(fade_out, 0.001)
			_preview_material.set_shader_parameter("pulse_intensity", clampf(envelope * pulse_bright, 0.0, pulse_bright))

	# Ship modulation: HDR brightness + color tint from field
	if _preview_ship_renderer:
		var pulse_val: float = 0.0
		if _pulse_active and _preview_material:
			pulse_val = float(_preview_material.get_shader_parameter("pulse_intensity"))
		var active_hdr: float = _ship_active_hdr_slider.value if _ship_active_hdr_slider else 0.2
		var pulse_hdr: float = _ship_pulse_hdr_slider.value if _ship_pulse_hdr_slider else 0.5
		var bright: float = 1.0 + active_hdr + pulse_val * pulse_hdr
		var field_col: Color = _color_picker.color
		var tint_strength: float = _ship_tint_strength_slider.value if _ship_tint_strength_slider else 0.15
		var tint_scaled: float = tint_strength * (_brightness_slider.value / 1.5)
		var r: float = lerpf(bright, field_col.r * bright * 1.5, tint_scaled)
		var g: float = lerpf(bright, field_col.g * bright * 1.5, tint_scaled)
		var b: float = lerpf(bright, field_col.b * bright * 1.5, tint_scaled)
		_preview_ship_renderer.modulate = Color(r, g, b, 1.0)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var load_label := Label.new()
	load_label.text = "Load:"
	top_bar.add_child(load_label)

	_load_button = OptionButton.new()
	_load_button.custom_minimum_size.x = 250
	_load_button.item_selected.connect(_on_load_selected)
	top_bar.add_child(_load_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "DELETE"
	_delete_button.pressed.connect(_on_delete)
	top_bar.add_child(_delete_button)

	_new_button = Button.new()
	_new_button.text = "NEW"
	_new_button.pressed.connect(_on_new)
	top_bar.add_child(_new_button)

	# Main content: HSplitContainer
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 420
	root.add_child(split)

	# Left: Preview
	var left_panel := _build_left_panel()
	split.add_child(left_panel)

	# Right: Controls
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)

	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(right_vbox)

	_build_controls(right_vbox)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_save_button = Button.new()
	_save_button.text = "SAVE STYLE"
	_save_button.custom_minimum_size.x = 200
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var preview_label := Label.new()
	preview_label.text = "LIVE PREVIEW"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(preview_label)
	_section_headers.append(preview_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(400, 400)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.stretch = true
	vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport_container.add_child(viewport)

	VFXFactory.add_bloom_to_viewport(viewport)

	# Dark bg
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(bg)

	# Ship preview
	_preview_ship_renderer = ShipRenderer.new()
	_preview_ship_renderer.ship_id = 4  # Stiletto
	_preview_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	_preview_ship_renderer.animate = true
	_preview_ship_renderer.position = Vector2(200, 260)
	_preview_ship_renderer.scale = Vector2(0.8, 0.8)
	viewport.add_child(_preview_ship_renderer)

	# Field preview sprite
	var preview_node := Node2D.new()
	preview_node.position = Vector2(200, 260)
	viewport.add_child(preview_node)

	_preview_sprite = Sprite2D.new()
	var tex_size: int = int(PREVIEW_RADIUS * 2.0)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_preview_sprite.texture = ImageTexture.create_from_image(img)
	_preview_sprite.z_index = 1
	preview_node.add_child(_preview_sprite)

	return panel


func _build_controls(parent: VBoxContainer) -> void:
	# Name
	_add_section_header(parent, "NAME")
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Enter field style name..."
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_name_input)

	_add_separator(parent)

	# Field Shader
	_add_section_header(parent, "FIELD SHADER")
	_shader_button = OptionButton.new()
	_shader_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in FIELD_SHADERS:
		_shader_button.add_item(s)
	_shader_button.item_selected.connect(_on_shader_changed)
	parent.add_child(_shader_button)

	# Common params
	_add_section_header(parent, "COMMON")
	var brightness_row: Array = _add_slider_row(parent, "HDR Brightness:", 0.0, 4.0, 1.5, 0.1)
	_brightness_slider = brightness_row[0]
	_brightness_label = brightness_row[1]

	var anim_row: Array = _add_slider_row(parent, "Time Scale:", 0.0, 3.0, 1.0, 0.1)
	_anim_speed_slider = anim_row[0]
	_anim_speed_label = anim_row[1]

	var radius_row: Array = _add_slider_row(parent, "Inner Radius:", 0.0, 0.95, 0.8, 0.05)
	_radius_ratio_slider = radius_row[0]
	_radius_ratio_label = radius_row[1]

	# Dynamic per-shader params
	_shader_params_container = VBoxContainer.new()
	_shader_params_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_shader_params_container)
	_rebuild_shader_params("force_bubble")

	_add_separator(parent)

	# Color
	_add_section_header(parent, "COLOR")
	var color_row := HBoxContainer.new()
	parent.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Color:"
	color_label.custom_minimum_size.x = 130
	color_row.add_child(color_label)
	_color_picker = ColorPickerButton.new()
	_color_picker.color = Color(0.0, 1.0, 1.0, 1.0)
	_color_picker.custom_minimum_size = Vector2(80, 30)
	_color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_picker.color_changed.connect(func(_c: Color) -> void: _update_preview())
	color_row.add_child(_color_picker)

	_add_separator(parent)

	# Pulse
	_add_section_header(parent, "PULSE")
	var pb_row: Array = _add_slider_row(parent, "Pulse Bright:", 0.0, 4.0, 2.0, 0.1)
	_pulse_brightness_slider = pb_row[0]
	_pulse_brightness_label = pb_row[1]
	var pt_row: Array = _add_slider_row(parent, "Pulse Tint:", 0.0, 1.0, 0.0, 0.05)
	_pulse_tint_slider = pt_row[0]
	_pulse_tint_label = pt_row[1]

	_add_separator(parent)

	# Ship Effects
	_add_section_header(parent, "SHIP EFFECTS")
	var tint_row: Array = _add_slider_row(parent, "Tint Strength:", 0.0, 1.0, 0.15, 0.05)
	_ship_tint_strength_slider = tint_row[0]
	_ship_tint_strength_label = tint_row[1]

	var active_hdr_row: Array = _add_slider_row(parent, "Active HDR:", 0.0, 2.0, 0.2, 0.05)
	_ship_active_hdr_slider = active_hdr_row[0]
	_ship_active_hdr_label = active_hdr_row[1]

	var pulse_hdr_row: Array = _add_slider_row(parent, "Pulse HDR:", 0.0, 2.0, 0.5, 0.05)
	_ship_pulse_hdr_slider = pulse_hdr_row[0]
	_ship_pulse_hdr_label = pulse_hdr_row[1]


func _rebuild_shader_params(shader_name: String) -> void:
	for child in _shader_params_container.get_children():
		child.queue_free()
	_shader_param_sliders.clear()

	var defs: Dictionary = FIELD_SHADER_PARAM_DEFS.get(shader_name, {}) as Dictionary
	if defs.is_empty():
		var lbl := Label.new()
		lbl.text = "  (no parameters)"
		lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
		_shader_params_container.add_child(lbl)
		return

	for param_name in defs:
		var bounds: Array = defs[param_name]
		var row: Array = _add_slider_row(_shader_params_container, param_name + ":",
			float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
		_shader_param_sliders[param_name] = row[0]


func _on_shader_changed(_idx: int) -> void:
	var shader_name: String = _shader_button.get_item_text(_shader_button.selected)
	_rebuild_shader_params(shader_name)
	_update_preview()


func _collect_style_data() -> Dictionary:
	var shader_params: Dictionary = {}
	for param_name in _shader_param_sliders:
		var slider: HSlider = _shader_param_sliders[param_name]
		shader_params[param_name] = slider.value

	return {
		"id": _current_id if _current_id != "" else _generate_id(_name_input.text),
		"display_name": _name_input.text,
		"field_shader": _shader_button.get_item_text(_shader_button.selected),
		"shader_params": shader_params,
		"color": [_color_picker.color.r, _color_picker.color.g, _color_picker.color.b, _color_picker.color.a],
		"glow_intensity": _brightness_slider.value,
		"radius_ratio": _radius_ratio_slider.value,
		"pulse_brightness": _pulse_brightness_slider.value,
		"pulse_tint": _pulse_tint_slider.value,
		"ship_tint_strength": _ship_tint_strength_slider.value if _ship_tint_strength_slider else 0.15,
		"ship_active_hdr": _ship_active_hdr_slider.value if _ship_active_hdr_slider else 0.2,
		"ship_pulse_hdr": _ship_pulse_hdr_slider.value if _ship_pulse_hdr_slider else 0.5,
	}


func _update_preview() -> void:
	if not _ui_ready or not _preview_sprite:
		return
	var shader_name: String = _shader_button.get_item_text(_shader_button.selected)
	var shader: Shader = VFXFactory.get_field_shader(shader_name)
	if not shader:
		return

	_preview_material = ShaderMaterial.new()
	_preview_material.shader = shader
	_preview_material.set_shader_parameter("field_color", _color_picker.color)
	_preview_material.set_shader_parameter("brightness", _brightness_slider.value)
	_preview_material.set_shader_parameter("animation_speed", _anim_speed_slider.value)
	_preview_material.set_shader_parameter("radius_ratio", _radius_ratio_slider.value)
	_preview_material.set_shader_parameter("opacity", 1.0)
	_preview_material.set_shader_parameter("pulse_intensity", 0.0)
	_preview_material.set_shader_parameter("pulse_tint", _pulse_tint_slider.value)

	for param_name in _shader_param_sliders:
		var slider: HSlider = _shader_param_sliders[param_name]
		_preview_material.set_shader_parameter(param_name, slider.value)

	_preview_sprite.material = _preview_material


# ── Save / Load / Delete ──────────────────────────────────

func _on_save() -> void:
	var name_text: String = _name_input.text.strip_edges()
	if name_text == "":
		_status_label.text = "Enter a style name first!"
		return
	var data: Dictionary = _collect_style_data()
	var new_id: String = _generate_id(name_text)
	var old_id: String = _current_id
	data["id"] = new_id
	if old_id != "" and old_id != new_id:
		FieldStyleManager.rename(old_id, new_id, data)
		_status_label.text = "Renamed: " + old_id + " → " + new_id
	else:
		FieldStyleManager.save(new_id, data)
		_status_label.text = "Saved: " + new_id
	_current_id = new_id
	_refresh_load_list()


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var style: FieldStyle = FieldStyleManager.load_by_id(id)
	if not style:
		_status_label.text = "Failed to load: " + id
		return
	_populate_from_style(style)
	_status_label.text = "Loaded: " + id


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No style loaded to delete."
		return
	FieldStyleManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_current_id = ""
	_name_input.text = ""
	_shader_button.selected = 0
	_brightness_slider.value = 1.5
	_anim_speed_slider.value = 1.0
	_radius_ratio_slider.value = 0.8
	_pulse_brightness_slider.value = 2.0
	_pulse_tint_slider.value = 0.0
	if _ship_tint_strength_slider:
		_ship_tint_strength_slider.value = 0.15
	if _ship_active_hdr_slider:
		_ship_active_hdr_slider.value = 0.2
	if _ship_pulse_hdr_slider:
		_ship_pulse_hdr_slider.value = 0.5
	_color_picker.color = Color(0.0, 1.0, 1.0, 1.0)
	_rebuild_shader_params("force_bubble")
	_update_preview()
	_status_label.text = "New field style — ready to edit."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select style)")
	var ids: Array[String] = FieldStyleManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _populate_from_style(style: FieldStyle) -> void:
	_current_id = style.id
	_name_input.text = style.display_name

	var shader_idx: int = FIELD_SHADERS.find(style.field_shader)
	_shader_button.selected = shader_idx if shader_idx >= 0 else 0
	_rebuild_shader_params(style.field_shader)

	# Set shader param values
	for param_name in style.shader_params:
		if param_name in _shader_param_sliders:
			var slider: HSlider = _shader_param_sliders[param_name]
			slider.value = float(style.shader_params[param_name])

	_color_picker.color = style.color
	_brightness_slider.value = style.glow_intensity
	_radius_ratio_slider.value = style.radius_ratio
	_pulse_brightness_slider.value = style.pulse_brightness
	_pulse_tint_slider.value = style.pulse_tint
	if _ship_tint_strength_slider:
		_ship_tint_strength_slider.value = style.ship_tint_strength
	if _ship_active_hdr_slider:
		_ship_active_hdr_slider.value = style.ship_active_hdr
	if _ship_pulse_hdr_slider:
		_ship_pulse_hdr_slider.value = style.ship_pulse_hdr

	_update_preview()


func _generate_id(display_name: String) -> String:
	if display_name.strip_edges() == "":
		return "field_" + str(randi() % 10000)
	var id: String = display_name.strip_edges().to_lower().replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in id:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = "field_" + str(randi() % 10000)
	return clean


# ── UI Helpers ─────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	parent.add_child(label)
	_section_headers.append(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)


func _add_slider_row(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float, step_val: float) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 130
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default_val
	slider.step = step_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 150
	row.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(default_val)
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		if step_val >= 1.0:
			value_label.text = str(int(val))
		else:
			value_label.text = "%.2f" % val
		_update_preview()
	)

	return [slider, value_label]


func _apply_theme() -> void:
	for label in _section_headers:
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
			label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if _save_button:
		ThemeManager.apply_button_style(_save_button)
	if _delete_button:
		ThemeManager.apply_button_style(_delete_button)
	if _new_button:
		ThemeManager.apply_button_style(_new_button)
