extends Control
## Mission Prep menu: Holographic verse select (left), action buttons (right).

var _vhs_overlay: ColorRect
var _verse_index: int = 0
var _verse_mat: ShaderMaterial
var _verse_label: Label
var _verse_counter: Label
var _grid_overlay: ColorRect

const VERSES: Array[Dictionary] = [
	{"label": "TUTORIAL", "shader": "", "hdr": 0.0},
	{"label": "NEON RIFT", "shader": "res://assets/shaders/dest_neon_void.gdshader", "hdr": 3.0},
	{"label": "FLUID", "shader": "res://assets/shaders/dest_fluid_rift.gdshader", "hdr": 3.0},
]

const VP_SIZE := Vector2i(800, 450)


func _ready() -> void:
	SynthwaveBgSetup.setup(self)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_build_verse_select()
	_connect_buttons()
	_apply_styles()


func _build_verse_select() -> void:
	var panel: MarginContainer = $HBoxContainer/VersePanel
	var hfont: Font = ThemeManager.get_font("font_header")

	# Outer container fills the panel
	var frame_margin: int = 28
	var outer := Control.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(outer)

	# Preview box: 85% size, centered via anchors
	var inset: float = 0.075
	var frame_container := Control.new()
	frame_container.anchor_left = inset
	frame_container.anchor_top = inset
	frame_container.anchor_right = 1.0 - inset
	frame_container.anchor_bottom = 1.0 - inset
	outer.add_child(frame_container)

	# SubViewportContainer inside frame
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	vpc.offset_left = frame_margin
	vpc.offset_top = frame_margin
	vpc.offset_right = -frame_margin
	vpc.offset_bottom = -frame_margin
	frame_container.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = VP_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	# Dark background inside viewport
	var bg := ColorRect.new()
	bg.color = Color(0.005, 0.005, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	# Destination shader rect
	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(shader_rect)

	_verse_mat = ShaderMaterial.new()
	shader_rect.material = _verse_mat

	# Grid overlay for Tutorial verse (visible when no destination shader)
	_grid_overlay = ColorRect.new()
	_grid_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(_grid_overlay)
	ThemeManager.apply_grid_background(_grid_overlay)

	# Frame overlay — sits just outside the viewport so brackets frame it
	var bracket_outset: int = 8
	var frame_overlay := ColorRect.new()
	frame_overlay.color = Color(1.0, 1.0, 1.0, 1.0)
	frame_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame_overlay.offset_left = frame_margin - bracket_outset
	frame_overlay.offset_top = frame_margin - bracket_outset
	frame_overlay.offset_right = -(frame_margin - bracket_outset)
	frame_overlay.offset_bottom = -(frame_margin - bracket_outset)
	frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_shader: Shader = load("res://assets/shaders/verse_frame_pulse_corners.gdshader") as Shader
	if frame_shader:
		var frame_mat := ShaderMaterial.new()
		frame_mat.shader = frame_shader
		frame_overlay.material = frame_mat
	frame_container.add_child(frame_overlay)

	# ── UI overlay: all controls inside the frame, on top of viewport + frame shader ──
	var ui_overlay := MarginContainer.new()
	ui_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_overlay.offset_left = frame_margin
	ui_overlay.offset_top = frame_margin
	ui_overlay.offset_right = -frame_margin
	ui_overlay.offset_bottom = -frame_margin
	ui_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_overlay.add_theme_constant_override("margin_left", 16)
	ui_overlay.add_theme_constant_override("margin_top", 12)
	ui_overlay.add_theme_constant_override("margin_right", 16)
	ui_overlay.add_theme_constant_override("margin_bottom", 12)
	frame_container.add_child(ui_overlay)

	var inner_col := VBoxContainer.new()
	inner_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_overlay.add_child(inner_col)

	# Title at top
	var title := Label.new()
	title.text = "SELECT VERSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(title, "header")
	title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		title.add_theme_font_override("font", hfont)
	title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	inner_col.add_child(title)

	# Spacer pushes arrows to center
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(top_spacer)

	# Arrow row in the middle
	var arrow_row := HBoxContainer.new()
	arrow_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(arrow_row)

	var left_btn := Button.new()
	left_btn.text = "\u25C1 \u25C1"
	left_btn.custom_minimum_size = Vector2(70, 100)
	_style_holo_arrow(left_btn)
	left_btn.pressed.connect(func() -> void: _cycle_verse(-1))
	arrow_row.add_child(left_btn)

	var arrow_spacer := Control.new()
	arrow_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow_row.add_child(arrow_spacer)

	var right_btn := Button.new()
	right_btn.text = "\u25B7 \u25B7"
	right_btn.custom_minimum_size = Vector2(70, 100)
	_style_holo_arrow(right_btn)
	right_btn.pressed.connect(func() -> void: _cycle_verse(1))
	arrow_row.add_child(right_btn)

	# Spacer pushes bottom labels down
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(bottom_spacer)

	# Verse name label at bottom
	_verse_label = Label.new()
	_verse_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verse_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(_verse_label, "body")
	_verse_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		_verse_label.add_theme_font_override("font", hfont)
	_verse_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	inner_col.add_child(_verse_label)

	# Counter label
	_verse_counter = Label.new()
	_verse_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verse_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(_verse_counter, "body")
	_verse_counter.add_theme_color_override("font_color", ThemeManager.get_color("text"))
	inner_col.add_child(_verse_counter)

	# Apply initial verse
	_apply_verse()


func _cycle_verse(direction: int) -> void:
	_verse_index = (_verse_index + direction) % VERSES.size()
	if _verse_index < 0:
		_verse_index += VERSES.size()
	_apply_verse()


func _apply_verse() -> void:
	var verse: Dictionary = VERSES[_verse_index]
	var shader_path: String = verse["shader"] as String

	if shader_path != "":
		var shader: Shader = load(shader_path) as Shader
		if shader:
			_verse_mat.shader = shader
			_verse_mat.set_shader_parameter("hdr_intensity", float(verse["hdr"]))
		_grid_overlay.visible = false
	else:
		# Tutorial: blank grid, no destination shader
		_verse_mat.shader = null
		_grid_overlay.visible = true

	_verse_label.text = verse["label"] as String
	_verse_counter.text = "%d / %d" % [_verse_index + 1, VERSES.size()]


func _style_holo_arrow(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", 28)

	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0.18, 0.04, 0.1, 0.85)
	sbox.border_color = Color(0.9, 0.15, 0.5, 0.7)
	sbox.border_width_left = 2
	sbox.border_width_right = 2
	sbox.border_width_top = 2
	sbox.border_width_bottom = 2
	sbox.corner_radius_top_left = 4
	sbox.corner_radius_top_right = 4
	sbox.corner_radius_bottom_left = 4
	sbox.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", sbox)

	var hover := sbox.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.28, 0.06, 0.15, 0.92)
	hover.border_color = Color(1.0, 0.25, 0.6, 0.9)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := sbox.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.35, 0.08, 0.2, 0.95)
	pressed.border_color = Color(1.0, 0.3, 0.65, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.65, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.55, 0.75, 1.0))


func _connect_buttons() -> void:
	var btns: VBoxContainer = $HBoxContainer/ButtonPanel/VBoxContainer
	btns.get_node("ChangeShipButton").pressed.connect(_on_change_ship)
	btns.get_node("LoadoutButton").pressed.connect(_on_loadout)
	btns.get_node("CrewButton").pressed.connect(_on_crew)
	btns.get_node("AudioMixButton").pressed.connect(_on_audio_mix)
	btns.get_node("LaunchButton").pressed.connect(_on_launch)
	btns.get_node("BackButton").pressed.connect(_on_back)


func _on_change_ship() -> void:
	pass  # Greyed out for demo


func _on_loadout() -> void:
	var HangarScreen: GDScript = load("res://scripts/ui/hangar_screen.gd")
	HangarScreen.set("initial_mode", "workshop")
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_crew() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_screen.tscn")


func _on_audio_mix() -> void:
	var HangarScreen: GDScript = load("res://scripts/ui/hangar_screen.gd")
	HangarScreen.set("initial_mode", "audio")
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_launch() -> void:
	GameState.current_level_id = "level_1"
	GameState.return_scene = "res://scenes/ui/mission_prep_menu.tscn"
	SceneLoader.load_scene("res://scenes/game/game.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _apply_styles() -> void:
	var btns: VBoxContainer = $HBoxContainer/ButtonPanel/VBoxContainer
	for child in btns.get_children():
		if child is Button:
			var btn: Button = child as Button
			ThemeManager.apply_button_style(btn)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_styles()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
