extends Control
## Aesthetic Workshop — General tab with 4 Hard Neon previews + sliders,
## Weapons tab with weapon archetype browser and fire pattern preview.

var _previews: Array = []
var _controls_vbox: VBoxContainer
var _tab_container: TabContainer
var _weapons_vbox: VBoxContainer
var _weapon_preview: WeaponPreviewPanel
var _left_grid: GridContainer
var _left_weapon_container: PanelContainer

# Track current slider/color values for copy
var _current_values := {
	"glow_width": 14.0,
	"glow_intensity": 1.0,
	"core_brightness": 0.7,
	"pass_count": 4,
	"pulse_strength": 1.0,
	"ship_color": Color(0.0, 1.0, 1.0, 1.0),
	"enemy_color": Color(1.0, 0.3, 0.3, 1.0),
	"projectile_color": Color(1.0, 0.0, 0.8, 1.0),
}

const PRESETS := ["tight", "wide", "intense", "flicker"]

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
const COLORS := ["cyan", "magenta", "yellow", "green", "orange", "red", "blue", "white"]

const WEAPON_ARCHETYPES := [
	{"id": "basic_pulse", "tres": "res://resources/basic_pulse.tres"},
	{"id": "rapid_burst", "tres": "res://resources/rapid_burst.tres"},
	{"id": "dual_stream", "tres": "res://resources/dual_stream.tres"},
	{"id": "wave_shot", "tres": "res://resources/wave_shot.tres"},
	{"id": "spread_fan", "tres": "res://resources/spread_fan.tres"},
	{"id": "beam", "tres": "res://resources/beam.tres"},
	{"id": "scatter", "tres": "res://resources/scatter.tres"},
]


func _ready() -> void:
	if not BeatClock._running:
		BeatClock.start(120.0)

	# Gather the 4 preview nodes
	_left_grid = $MainVBox/HSplit/LeftPanel/Grid
	for i in range(1, 5):
		var preview: Control = get_node("MainVBox/HSplit/LeftPanel/Grid/Panel%d/VBox%d/SVC%d/SV%d/Preview%d" % [i, i, i, i, i])
		_previews.append(preview)
		preview.apply_preset(PRESETS[i - 1])

	# Create weapon preview in left panel (hidden by default)
	_build_weapon_preview()

	# Build TabContainer in right panel
	_build_tab_container()

	# Back button
	$MainVBox/BackButton.pressed.connect(func() -> void:
		BeatClock.stop()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)


func _build_tab_container() -> void:
	var right_panel: PanelContainer = $MainVBox/HSplit/RightPanel
	var controls_scroll: ScrollContainer = $MainVBox/HSplit/RightPanel/ControlsScroll

	# Remove ControlsScroll from RightPanel temporarily
	right_panel.remove_child(controls_scroll)

	# Create TabContainer
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(_tab_container)

	# --- General Tab ---
	var general_tab := Control.new()
	general_tab.name = "General"
	general_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	general_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(general_tab)

	# Re-parent controls scroll into General tab
	general_tab.add_child(controls_scroll)
	controls_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_controls_vbox = controls_scroll.get_node("ControlsVBox")
	_build_controls()

	# --- Weapons Tab ---
	var weapons_tab := Control.new()
	weapons_tab.name = "Weapons"
	weapons_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(weapons_tab)

	var weapons_scroll := ScrollContainer.new()
	weapons_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	weapons_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapons_tab.add_child(weapons_scroll)

	_weapons_vbox = VBoxContainer.new()
	_weapons_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapons_vbox.add_theme_constant_override("separation", 12)
	weapons_scroll.add_child(_weapons_vbox)

	_build_weapons_catalog()

	# Tab switch handler
	_tab_container.tab_changed.connect(_on_tab_changed)


func _build_weapon_preview() -> void:
	var left_panel: VBoxContainer = $MainVBox/HSplit/LeftPanel

	_left_weapon_container = PanelContainer.new()
	_left_weapon_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_weapon_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_weapon_container.visible = false
	left_panel.add_child(_left_weapon_container)

	var svc := SubViewportContainer.new()
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	_left_weapon_container.add_child(svc)

	var sv := SubViewport.new()
	sv.handle_input_locally = false
	sv.size = Vector2i(840, 500)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(sv)

	_weapon_preview = WeaponPreviewPanel.new()
	_weapon_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv.add_child(_weapon_preview)


func _on_tab_changed(tab_idx: int) -> void:
	if tab_idx == 0:
		# General — show grid, hide weapon preview
		_left_grid.visible = true
		_left_weapon_container.visible = false
	else:
		# Weapons — hide grid, show weapon preview
		_left_grid.visible = false
		_left_weapon_container.visible = true


func _build_controls() -> void:
	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_vbox.add_child(title)

	_add_separator()

	# Glow Width
	_add_slider("Glow Width", 4.0, 30.0, 14.0, func(val: float) -> void:
		_current_values["glow_width"] = val
		for p in _previews:
			p.glow_width = val
			p._preset_width = val
	)

	# Glow Intensity
	_add_slider("Glow Intensity", 0.1, 3.0, 1.0, func(val: float) -> void:
		_current_values["glow_intensity"] = val
		for p in _previews:
			p.glow_intensity = val
			p._preset_intensity = val
	)

	# Core Brightness
	_add_slider("Core Brightness", 0.0, 1.0, 0.7, func(val: float) -> void:
		_current_values["core_brightness"] = val
		for p in _previews:
			p.core_brightness = val
			p._preset_core_brightness = val
	)

	# Pass Count
	_add_slider("Pass Count", 2.0, 6.0, 4.0, func(val: float) -> void:
		var count := int(val)
		_current_values["pass_count"] = count
		for p in _previews:
			p.pass_count = count
			p._preset_pass_count = count
	, 1.0)

	# Pulse Strength
	_add_slider("Pulse Strength", 0.0, 2.0, 1.0, func(val: float) -> void:
		_current_values["pulse_strength"] = val
		for p in _previews:
			p.pulse_strength = val
	)

	_add_separator()

	# Ship Color
	_add_color_picker("Ship Color", Color(0.0, 1.0, 1.0), func(col: Color) -> void:
		_current_values["ship_color"] = col
		for p in _previews:
			p.ship_color = col
	)

	# Enemy Color
	_add_color_picker("Enemy Color", Color(1.0, 0.3, 0.3), func(col: Color) -> void:
		_current_values["enemy_color"] = col
		for p in _previews:
			p.enemy_color = col
	)

	# Projectile Color
	_add_color_picker("Projectile Color", Color(1.0, 0.0, 0.8), func(col: Color) -> void:
		_current_values["projectile_color"] = col
		for p in _previews:
			p.projectile_color = col
	)

	_add_separator()

	# Copy Settings Button
	var copy_btn := Button.new()
	copy_btn.text = "COPY SETTINGS"
	copy_btn.custom_minimum_size = Vector2(0, 36)
	_controls_vbox.add_child(copy_btn)
	copy_btn.pressed.connect(_copy_settings)


func _copy_settings() -> void:
	var sc: Color = _current_values["ship_color"]
	var ec: Color = _current_values["enemy_color"]
	var pc: Color = _current_values["projectile_color"]
	var text := "{\n"
	text += '  "glow_width": %s,\n' % _current_values["glow_width"]
	text += '  "glow_intensity": %s,\n' % _current_values["glow_intensity"]
	text += '  "core_brightness": %s,\n' % _current_values["core_brightness"]
	text += '  "pass_count": %s,\n' % _current_values["pass_count"]
	text += '  "pulse_strength": %s,\n' % _current_values["pulse_strength"]
	text += '  "ship_color": "Color(%s, %s, %s, %s)",\n' % [snapped(sc.r, 0.01), snapped(sc.g, 0.01), snapped(sc.b, 0.01), snapped(sc.a, 0.01)]
	text += '  "enemy_color": "Color(%s, %s, %s, %s)",\n' % [snapped(ec.r, 0.01), snapped(ec.g, 0.01), snapped(ec.b, 0.01), snapped(ec.a, 0.01)]
	text += '  "projectile_color": "Color(%s, %s, %s, %s)"\n' % [snapped(pc.r, 0.01), snapped(pc.g, 0.01), snapped(pc.b, 0.01), snapped(pc.a, 0.01)]
	text += "}"
	DisplayServer.clipboard_set(text)


func _build_weapons_catalog() -> void:
	var cat_title := Label.new()
	cat_title.text = "WEAPON ARCHETYPES"
	cat_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapons_vbox.add_child(cat_title)

	for archetype in WEAPON_ARCHETYPES:
		var weapon: WeaponData = load(archetype["tres"])
		if not weapon:
			continue
		_add_weapon_card(weapon)


func _add_weapon_card(weapon: WeaponData) -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.15, 1.0)
	style.border_color = Color(0.2, 0.2, 0.4, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)
	_weapons_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Name (bold)
	var name_label := Label.new()
	name_label.text = weapon.display_name
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)

	# Description
	var desc_label := Label.new()
	desc_label.text = weapon.description
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	vbox.add_child(desc_label)

	# Subdivision
	var sub_names := {1: "Quarter", 2: "Eighth", 3: "Triplet"}
	var sub_label := Label.new()
	sub_label.text = "Subdivision: %s" % sub_names.get(weapon.subdivision, "Quarter")
	sub_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	sub_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(sub_label)

	# Color selector row
	var color_hbox := HBoxContainer.new()
	color_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(color_hbox)

	var color_label := Label.new()
	color_label.text = "Color: "
	color_label.add_theme_font_size_override("font_size", 13)
	color_hbox.add_child(color_label)

	for color_name in COLORS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(22, 22)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = COLOR_MAP[color_name]
		btn_style.set_corner_radius_all(3)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style)
		btn.add_theme_stylebox_override("pressed", btn_style)
		color_hbox.add_child(btn)
		btn.pressed.connect(func() -> void:
			_weapon_preview.set_preview_color(color_name)
		)

	# Buttons row
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_hbox)

	var preview_btn := Button.new()
	preview_btn.text = "PREVIEW"
	preview_btn.custom_minimum_size = Vector2(0, 30)
	preview_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hbox.add_child(preview_btn)
	preview_btn.pressed.connect(func() -> void:
		_weapon_preview.set_weapon(weapon)
		# Ensure weapon preview is visible
		_left_grid.visible = false
		_left_weapon_container.visible = true
	)

	var edit_btn := Button.new()
	edit_btn.text = "EDIT PATTERN"
	edit_btn.custom_minimum_size = Vector2(0, 30)
	edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hbox.add_child(edit_btn)
	edit_btn.pressed.connect(func() -> void:
		# Set the weapon as forward mount before navigating
		GameState.current_loadout["forward"] = weapon.id
		get_tree().change_scene_to_file("res://scenes/ui/weapon_customizer.tscn")
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
