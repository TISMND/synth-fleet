extends Control
## Effect Designer — Compose weapon visual effects from 4 layers.
## Left: live preview. Right: collapsible layer sections with type dropdowns + param sliders.

var _preview: EffectPreviewPanel
var _controls_vbox: VBoxContainer
var _profile: EffectProfile
var _name_edit: LineEdit

# Section containers for dynamic slider rebuild
var _muzzle_params_vbox: VBoxContainer
var _shape_params_vbox: VBoxContainer
var _trail_params_vbox: VBoxContainer
var _impact_params_vbox: VBoxContainer

const MUZZLE_TYPES := ["none", "radial_burst", "directional_flash", "ring_pulse"]
const SHAPE_TYPES := ["rect", "streak", "orb", "diamond", "arrow"]
const TRAIL_TYPES := ["none", "particle", "ribbon", "afterimage", "sparkle"]
const IMPACT_TYPES := ["none", "burst", "ring_expand", "shatter_lines", "nova_flash"]

const COLOR_MAP := {
	"cyan": Color(0, 1, 1),
	"magenta": Color(1, 0, 1),
	"yellow": Color(1, 1, 0),
	"green": Color(0, 1, 0.5),
	"orange": Color(1, 0.5, 0),
	"red": Color(1, 0.2, 0.2),
	"blue": Color(0.3, 0.3, 1),
	"white": Color(1, 1, 1),
}

# Param definitions: {param_name: [label, min, max, default, step]}
const MUZZLE_PARAM_DEFS := {
	"radial_burst": {
		"particle_count": ["Particles", 8.0, 32.0, 16.0, 1.0],
		"lifetime": ["Lifetime", 0.05, 0.4, 0.15, 0.01],
		"spread_angle": ["Spread", 90.0, 360.0, 180.0, 1.0],
		"velocity_max": ["Velocity", 40.0, 160.0, 80.0, 1.0],
	},
	"directional_flash": {
		"particle_count": ["Particles", 6.0, 24.0, 12.0, 1.0],
		"lifetime": ["Lifetime", 0.08, 0.25, 0.12, 0.01],
		"spread_angle": ["Spread", 15.0, 60.0, 30.0, 1.0],
		"velocity_max": ["Velocity", 80.0, 200.0, 120.0, 1.0],
	},
	"ring_pulse": {
		"radius_end": ["Radius", 15.0, 50.0, 30.0, 1.0],
		"lifetime": ["Lifetime", 0.1, 0.4, 0.2, 0.01],
		"segments": ["Segments", 8.0, 24.0, 16.0, 1.0],
		"line_width": ["Width", 2.0, 8.0, 4.0, 0.5],
	},
}

const SHAPE_PARAM_DEFS := {
	"rect": {
		"width": ["Width", 2.0, 8.0, 4.0, 0.5],
		"height": ["Height", 6.0, 20.0, 12.0, 0.5],
	},
	"streak": {
		"width": ["Width", 1.0, 4.0, 1.5, 0.25],
		"length": ["Length", 12.0, 40.0, 24.0, 1.0],
	},
	"orb": {
		"radius": ["Radius", 3.0, 12.0, 5.0, 0.5],
		"segments": ["Segments", 6.0, 16.0, 8.0, 1.0],
	},
	"diamond": {
		"width": ["Width", 3.0, 10.0, 6.0, 0.5],
		"height": ["Height", 8.0, 24.0, 14.0, 0.5],
	},
	"arrow": {
		"width": ["Width", 4.0, 12.0, 8.0, 0.5],
		"height": ["Height", 8.0, 20.0, 14.0, 0.5],
		"notch": ["Notch", 2.0, 8.0, 4.0, 0.5],
	},
}

# Shared shape glow params appended to all shape types
const SHAPE_GLOW_PARAM_DEFS := {
	"glow_width": ["Glow Width", 3.0, 15.0, 6.0, 0.5],
	"glow_intensity": ["Glow Intensity", 0.5, 3.0, 1.0, 0.1],
	"core_brightness": ["Core Brightness", 0.3, 1.0, 0.7, 0.05],
	"pass_count": ["Pass Count", 2.0, 6.0, 3.0, 1.0],
}

const TRAIL_PARAM_DEFS := {
	"particle": {
		"amount": ["Amount", 4.0, 30.0, 10.0, 1.0],
		"lifetime": ["Lifetime", 0.1, 0.8, 0.3, 0.01],
		"spread": ["Spread", 5.0, 45.0, 15.0, 1.0],
		"velocity_max": ["Velocity", 20.0, 80.0, 40.0, 1.0],
	},
	"ribbon": {
		"length": ["Length", 5.0, 20.0, 10.0, 1.0],
		"width_start": ["Width Start", 1.0, 6.0, 3.0, 0.5],
		"width_end": ["Width End", 0.0, 2.0, 0.0, 0.25],
	},
	"afterimage": {
		"count": ["Count", 3.0, 8.0, 5.0, 1.0],
		"spacing_frames": ["Spacing", 1.0, 4.0, 2.0, 1.0],
		"fade_speed": ["Fade Speed", 1.0, 5.0, 3.0, 0.5],
	},
	"sparkle": {
		"amount": ["Amount", 6.0, 30.0, 12.0, 1.0],
		"lifetime": ["Lifetime", 0.15, 0.5, 0.25, 0.01],
		"velocity_max": ["Velocity", 15.0, 60.0, 30.0, 1.0],
	},
}

const IMPACT_PARAM_DEFS := {
	"burst": {
		"particle_count": ["Particles", 8.0, 48.0, 24.0, 1.0],
		"lifetime": ["Lifetime", 0.1, 0.6, 0.3, 0.01],
		"velocity_max": ["Velocity", 50.0, 200.0, 120.0, 1.0],
	},
	"ring_expand": {
		"radius_end": ["Radius", 20.0, 80.0, 40.0, 1.0],
		"lifetime": ["Lifetime", 0.15, 0.5, 0.25, 0.01],
		"segments": ["Segments", 12.0, 24.0, 16.0, 1.0],
	},
	"shatter_lines": {
		"line_count": ["Lines", 4.0, 12.0, 6.0, 1.0],
		"line_length": ["Length", 10.0, 40.0, 20.0, 1.0],
		"lifetime": ["Lifetime", 0.2, 0.5, 0.3, 0.01],
		"velocity": ["Velocity", 80.0, 250.0, 150.0, 1.0],
	},
	"nova_flash": {
		"radius": ["Radius", 30.0, 100.0, 50.0, 1.0],
		"lifetime": ["Lifetime", 0.08, 0.2, 0.12, 0.01],
		"intensity": ["Intensity", 0.5, 2.0, 1.0, 0.1],
	},
}


func _ready() -> void:
	if not BeatClock._running:
		BeatClock.start(120.0)

	_profile = EffectProfile.new()
	_profile.display_name = "New Effect"

	_build_ui()
	_update_preview()


func _build_ui() -> void:
	# Root layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Title bar
	var title := Label.new()
	title.text = "EFFECT DESIGNER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 1, 1))
	main_vbox.add_child(title)

	# HSplit: preview left, controls right
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hsplit.split_offset = 420
	main_vbox.add_child(hsplit)

	# Left: preview in SubViewport
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.custom_minimum_size = Vector2(400, 0)
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.02, 0.02, 0.05)
	left_panel.add_theme_stylebox_override("panel", left_style)
	hsplit.add_child(left_panel)

	var svc := SubViewportContainer.new()
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	left_panel.add_child(svc)

	var sv := SubViewport.new()
	sv.handle_input_locally = false
	sv.size = Vector2i(420, 500)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	_preview = EffectPreviewPanel.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv.add_child(_preview)

	# Right: controls scroll
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.custom_minimum_size = Vector2(300, 0)
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.04, 0.04, 0.08)
	right_panel.add_theme_stylebox_override("panel", right_style)
	hsplit.add_child(right_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll)

	_controls_vbox = VBoxContainer.new()
	_controls_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(_controls_vbox)

	# Name field
	var name_hbox := HBoxContainer.new()
	_controls_vbox.add_child(name_hbox)
	var name_label := Label.new()
	name_label.text = "Name:"
	name_hbox.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.text = "New Effect"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_hbox.add_child(_name_edit)
	_name_edit.text_changed.connect(func(new_text: String) -> void:
		_profile.display_name = new_text
		_update_preview()
	)

	# Color selector
	_add_separator()
	_add_color_row()

	# Muzzle section
	_add_separator()
	_muzzle_params_vbox = _add_layer_section("MUZZLE", MUZZLE_TYPES, _profile.muzzle_type,
		func(idx: int) -> void:
			_profile.muzzle_type = MUZZLE_TYPES[idx]
			_profile.muzzle_params = {}
			_rebuild_muzzle_params()
			_update_preview()
	)
	_rebuild_muzzle_params()

	# Shape section
	_add_separator()
	_shape_params_vbox = _add_layer_section("SHAPE", SHAPE_TYPES, _profile.shape_type,
		func(idx: int) -> void:
			_profile.shape_type = SHAPE_TYPES[idx]
			_profile.shape_params = {}
			_rebuild_shape_params()
			_update_preview()
	)
	_rebuild_shape_params()

	# Trail section
	_add_separator()
	_trail_params_vbox = _add_layer_section("TRAIL", TRAIL_TYPES, _profile.trail_type,
		func(idx: int) -> void:
			_profile.trail_type = TRAIL_TYPES[idx]
			_profile.trail_params = {}
			_rebuild_trail_params()
			_update_preview()
	)
	_rebuild_trail_params()

	# Impact section
	_add_separator()
	_impact_params_vbox = _add_layer_section("IMPACT", IMPACT_TYPES, _profile.impact_type,
		func(idx: int) -> void:
			_profile.impact_type = IMPACT_TYPES[idx]
			_profile.impact_params = {}
			_rebuild_impact_params()
			_update_preview()
	)
	_rebuild_impact_params()

	# Save / Load / Back buttons
	_add_separator()
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	_controls_vbox.add_child(btn_hbox)

	var save_btn := Button.new()
	save_btn.text = "SAVE"
	save_btn.custom_minimum_size = Vector2(0, 36)
	save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hbox.add_child(save_btn)
	save_btn.pressed.connect(_save_profile)

	var load_btn := Button.new()
	load_btn.text = "LOAD"
	load_btn.custom_minimum_size = Vector2(0, 36)
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hbox.add_child(load_btn)
	load_btn.pressed.connect(_load_profile_dialog)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(0, 40)
	_controls_vbox.add_child(back_btn)
	back_btn.pressed.connect(func() -> void:
		BeatClock.stop()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)


func _add_color_row() -> void:
	var label := Label.new()
	label.text = "Preview Color"
	_controls_vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	_controls_vbox.add_child(hbox)

	for color_name in COLOR_MAP:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(22, 22)
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_MAP[color_name]
		style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		hbox.add_child(btn)
		var c_name: String = color_name  # capture
		btn.pressed.connect(func() -> void:
			if _preview and COLOR_MAP.has(c_name):
				_preview.projectile_color = COLOR_MAP[c_name]
		)


func _add_layer_section(title_text: String, types: Array, current_type: String, on_type_changed: Callable) -> VBoxContainer:
	var header := Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", Color(0.5, 1.0, 0.8))
	_controls_vbox.add_child(header)

	# Type dropdown
	var type_hbox := HBoxContainer.new()
	_controls_vbox.add_child(type_hbox)
	var type_label := Label.new()
	type_label.text = "Type:"
	type_hbox.add_child(type_label)

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in types:
		option.add_item(t.replace("_", " ").to_upper())
	# Select current
	var idx := types.find(current_type)
	if idx >= 0:
		option.selected = idx
	type_hbox.add_child(option)
	option.item_selected.connect(on_type_changed)

	# Params container
	var params_vbox := VBoxContainer.new()
	params_vbox.add_theme_constant_override("separation", 4)
	_controls_vbox.add_child(params_vbox)

	return params_vbox


func _rebuild_muzzle_params() -> void:
	_clear_children(_muzzle_params_vbox)
	if not MUZZLE_PARAM_DEFS.has(_profile.muzzle_type):
		return
	var defs: Dictionary = MUZZLE_PARAM_DEFS[_profile.muzzle_type]
	for param_name in defs:
		var def: Array = defs[param_name]
		_add_param_slider(_muzzle_params_vbox, def[0], def[1], def[2],
			_profile.muzzle_params.get(param_name, def[3]), def[4],
			func(val: float) -> void:
				_profile.muzzle_params[param_name] = val
				_update_preview()
		)


func _rebuild_shape_params() -> void:
	_clear_children(_shape_params_vbox)
	if SHAPE_PARAM_DEFS.has(_profile.shape_type):
		var defs: Dictionary = SHAPE_PARAM_DEFS[_profile.shape_type]
		for param_name in defs:
			var def: Array = defs[param_name]
			_add_param_slider(_shape_params_vbox, def[0], def[1], def[2],
				_profile.shape_params.get(param_name, def[3]), def[4],
				func(val: float) -> void:
					_profile.shape_params[param_name] = val
					_update_preview()
			)
	# Shared glow params
	for param_name in SHAPE_GLOW_PARAM_DEFS:
		var def: Array = SHAPE_GLOW_PARAM_DEFS[param_name]
		_add_param_slider(_shape_params_vbox, def[0], def[1], def[2],
			_profile.shape_params.get(param_name, def[3]), def[4],
			func(val: float) -> void:
				_profile.shape_params[param_name] = val
				_update_preview()
		)


func _rebuild_trail_params() -> void:
	_clear_children(_trail_params_vbox)
	if not TRAIL_PARAM_DEFS.has(_profile.trail_type):
		return
	var defs: Dictionary = TRAIL_PARAM_DEFS[_profile.trail_type]
	for param_name in defs:
		var def: Array = defs[param_name]
		_add_param_slider(_trail_params_vbox, def[0], def[1], def[2],
			_profile.trail_params.get(param_name, def[3]), def[4],
			func(val: float) -> void:
				_profile.trail_params[param_name] = val
				_update_preview()
		)


func _rebuild_impact_params() -> void:
	_clear_children(_impact_params_vbox)
	if not IMPACT_PARAM_DEFS.has(_profile.impact_type):
		return
	var defs: Dictionary = IMPACT_PARAM_DEFS[_profile.impact_type]
	for param_name in defs:
		var def: Array = defs[param_name]
		_add_param_slider(_impact_params_vbox, def[0], def[1], def[2],
			_profile.impact_params.get(param_name, def[3]), def[4],
			func(val: float) -> void:
				_profile.impact_params[param_name] = val
				_update_preview()
		)


func _add_param_slider(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, default_val: float, step: float, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100, 0)
	label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 20)
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.text = str(snapped(default_val, step))
	value_label.custom_minimum_size = Vector2(45, 0)
	value_label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		value_label.text = str(snapped(val, step))
		callback.call(val)
	)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 8)
	_controls_vbox.add_child(sep)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _update_preview() -> void:
	if _preview:
		_preview.set_effect_profile(_profile)


func _save_profile() -> void:
	# Generate ID from name
	if _profile.display_name == "":
		_profile.display_name = "Untitled"
	_profile.id = _profile.display_name.to_lower().replace(" ", "_")
	var path := "res://resources/effects/%s.tres" % _profile.id
	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute("res://resources/effects")
	var err := ResourceSaver.save(_profile, path)
	if err == OK:
		print("Effect saved to: %s" % path)
	else:
		push_error("Failed to save effect: %s" % error_string(err))


func _load_profile_dialog() -> void:
	var dir := DirAccess.open("res://resources/effects")
	if not dir:
		print("No saved effects found.")
		return

	# Find all .tres files
	var files: PackedStringArray = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.is_empty():
		print("No saved effects found.")
		return

	# Load the most recent one (simple approach — could add a proper file picker)
	var path := "res://resources/effects/%s" % files[files.size() - 1]
	var loaded := load(path)
	if loaded is EffectProfile:
		_profile = loaded.duplicate() as EffectProfile
		_name_edit.text = _profile.display_name
		_rebuild_muzzle_params()
		_rebuild_shape_params()
		_rebuild_trail_params()
		_rebuild_impact_params()
		_update_preview()
		print("Loaded effect: %s" % path)
