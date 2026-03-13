extends Control
## Aesthetic Workshop — displays 4 Hard Neon variations with interactive slider controls.

var _previews: Array = []
var _controls_vbox: VBoxContainer

const PRESETS := ["tight", "wide", "intense", "flicker"]


func _ready() -> void:
	if not BeatClock._running:
		BeatClock.start(120.0)

	# Gather the 4 preview nodes
	for i in range(1, 5):
		var preview: Control = get_node("MainVBox/HSplit/LeftPanel/Grid/Panel%d/VBox%d/SVC%d/SV%d/Preview%d" % [i, i, i, i, i])
		_previews.append(preview)
		preview.apply_preset(PRESETS[i - 1])

	# Controls container
	_controls_vbox = $MainVBox/HSplit/RightPanel/ControlsScroll/ControlsVBox

	# Build slider controls
	_build_controls()

	# Back button
	$MainVBox/BackButton.pressed.connect(func() -> void:
		BeatClock.stop()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)


func _build_controls() -> void:
	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_vbox.add_child(title)

	_add_separator()

	# Glow Width
	_add_slider("Glow Width", 4.0, 30.0, 14.0, func(val: float) -> void:
		for p in _previews:
			p.glow_width = val
			p._preset_width = val
	)

	# Glow Intensity
	_add_slider("Glow Intensity", 0.1, 3.0, 1.0, func(val: float) -> void:
		for p in _previews:
			p.glow_intensity = val
			p._preset_intensity = val
	)

	# Core Brightness
	_add_slider("Core Brightness", 0.0, 1.0, 0.7, func(val: float) -> void:
		for p in _previews:
			p.core_brightness = val
			p._preset_core_brightness = val
	)

	# Pass Count
	_add_slider("Pass Count", 2.0, 6.0, 4.0, func(val: float) -> void:
		var count := int(val)
		for p in _previews:
			p.pass_count = count
			p._preset_pass_count = count
	, 1.0)

	# Pulse Strength
	_add_slider("Pulse Strength", 0.0, 2.0, 1.0, func(val: float) -> void:
		for p in _previews:
			p.pulse_strength = val
	)

	_add_separator()

	# Ship Color
	_add_color_picker("Ship Color", Color(0.0, 1.0, 1.0), func(col: Color) -> void:
		for p in _previews:
			p.ship_color = col
	)

	# Enemy Color
	_add_color_picker("Enemy Color", Color(1.0, 0.3, 0.3), func(col: Color) -> void:
		for p in _previews:
			p.enemy_color = col
	)

	# Projectile Color
	_add_color_picker("Projectile Color", Color(1.0, 0.0, 0.8), func(col: Color) -> void:
		for p in _previews:
			p.projectile_color = col
	)


func _add_slider(label_text: String, min_val: float, max_val: float, default_val: float, callback: Callable, step: float = 0.01) -> void:
	var label := Label.new()
	label.text = label_text
	_controls_vbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = default_val
	slider.custom_minimum_size = Vector2(0, 24)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_vbox.add_child(slider)

	slider.value_changed.connect(callback)


func _add_color_picker(label_text: String, default_color: Color, callback: Callable) -> void:
	var hbox := HBoxContainer.new()
	_controls_vbox.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var picker := ColorPickerButton.new()
	picker.color = default_color
	picker.custom_minimum_size = Vector2(40, 30)
	hbox.add_child(picker)

	picker.color_changed.connect(callback)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.custom_minimum_size = Vector2(0, 8)
	_controls_vbox.add_child(sep)
