extends Control
## Mission Prep menu: verse select → mission select drill-down.
## Verse mode: preview left, buttons right.
## Mission mode: preview centers/expands, buttons below.

var _vhs_overlay: ColorRect

# ── Mode state ──
var _mode: String = "verse"  # "verse" or "mission"

# ── Verse state ──
var _verse_index: int = 0
var _verse_mat: ShaderMaterial
var _verse_label: Label
var _verse_counter: Label
var _grid_overlay: ColorRect
var _title_label: Label

# ── Viewport zoom refs ──
var _vpc: SubViewportContainer
var _clip_box: Control

# ── Internal verse arrows (hidden in mission mode) ──
var _arrow_row: HBoxContainer

# ── Mission state ──
var _mission_index: int = 0
var _mission_positions: Array[Vector2] = []
var _mission_levels: Array[LevelData] = []
var _mission_bracket: Control
var _blink_time: float = 0.0

# ── Panel refs ──
var _button_panel: MarginContainer
var _button_vbox: VBoxContainer
var _verse_buttons: Array[Button] = []
var _ready_btn: Button

# ── Mission bottom bar (hidden in verse mode) ──
var _mission_bar: VBoxContainer

const VERSES: Array[Dictionary] = [
	{"label": "NEON RIFT", "shader": "res://assets/shaders/dest_neon_void.gdshader", "hdr": 3.0, "verse_id": "verse_1"},
	{"label": "FLUID", "shader": "res://assets/shaders/dest_fluid_rift.gdshader", "hdr": 3.0, "verse_id": "verse_2"},
	{"label": "MONOLITH", "shader": "res://assets/shaders/dest_monolith.gdshader", "hdr": 3.0, "verse_id": "verse_3"},
]

const VP_SIZE := Vector2i(800, 450)
const ZOOM_SCALE: float = 3.0
const ZOOM_DURATION: float = 1.8
const BRACKET_SIZE: float = 60.0

var _zoom_tween: Tween
var _zooming: bool = false


func _ready() -> void:
	SynthwaveBgSetup.setup(self)
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	_build_verse_select()
	_build_mission_bar()
	_connect_buttons()
	_apply_styles()
	_generate_mission_positions()


func _process(delta: float) -> void:
	# Keep pivot centered as layout changes during zoom animation
	if _zooming and _vpc:
		_vpc.pivot_offset = _vpc.size / 2.0
	if _mode == "mission" and _mission_bracket and _mission_bracket.visible:
		_blink_time += delta
		_mission_bracket.modulate.a = 1.0
		_mission_bracket.queue_redraw()


func _build_verse_select() -> void:
	var panel: MarginContainer = $HBoxContainer/VersePanel
	var hfont: Font = ThemeManager.get_font("font_header")

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

	# Clip box — contains the viewport, clips when zoomed
	_clip_box = Control.new()
	_clip_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip_box.offset_left = frame_margin
	_clip_box.offset_top = frame_margin
	_clip_box.offset_right = -frame_margin
	_clip_box.offset_bottom = -frame_margin
	_clip_box.clip_contents = true
	frame_container.add_child(_clip_box)

	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip_box.add_child(_vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = VP_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.005, 0.005, 0.01, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var shader_rect := ColorRect.new()
	shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(shader_rect)

	_verse_mat = ShaderMaterial.new()
	shader_rect.material = _verse_mat

	_grid_overlay = ColorRect.new()
	_grid_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grid_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(_grid_overlay)
	ThemeManager.apply_grid_background(_grid_overlay)

	# Frame overlay — sits just outside the viewport
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

	# ── UI overlay (title, arrows, labels — inside the viewport frame) ──
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
	_title_label = Label.new()
	_title_label.text = "SELECT VERSE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.apply_text_glow(_title_label, "header")
	_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
	if hfont:
		_title_label.add_theme_font_override("font", hfont)
	_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	inner_col.add_child(_title_label)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(top_spacer)

	# Internal arrow row (verse mode only)
	_arrow_row = HBoxContainer.new()
	_arrow_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(_arrow_row)

	var left_btn := Button.new()
	left_btn.text = "\u25C1 \u25C1"
	left_btn.custom_minimum_size = Vector2(70, 100)
	_style_holo_arrow(left_btn)
	left_btn.pressed.connect(func() -> void: _cycle_verse(-1))
	_arrow_row.add_child(left_btn)

	var arrow_spacer := Control.new()
	arrow_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_row.add_child(arrow_spacer)

	var right_btn := Button.new()
	right_btn.text = "\u25B7 \u25B7"
	right_btn.custom_minimum_size = Vector2(70, 100)
	_style_holo_arrow(right_btn)
	right_btn.pressed.connect(func() -> void: _cycle_verse(1))
	_arrow_row.add_child(right_btn)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_col.add_child(bottom_spacer)

	# Verse/mission name label
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

	# Mission bracket indicator (hidden until mission mode)
	_mission_bracket = Control.new()
	_mission_bracket.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mission_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mission_bracket.visible = false
	_mission_bracket.draw.connect(_draw_mission_bracket)
	ui_overlay.add_child(_mission_bracket)

	_apply_verse()


## Build the bottom button bar for mission mode (hidden initially).
## Sits at the bottom center of the screen, outside the viewport.
func _build_mission_bar() -> void:
	_mission_bar = VBoxContainer.new()
	_mission_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_mission_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mission_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mission_bar.offset_top = -120
	_mission_bar.offset_bottom = -30
	_mission_bar.offset_left = -250
	_mission_bar.offset_right = 250
	_mission_bar.add_theme_constant_override("separation", 12)
	_mission_bar.alignment = BoxContainer.ALIGNMENT_END
	_mission_bar.visible = false
	add_child(_mission_bar)

	# Row: [◁ ◁] [LAUNCH] [▷ ▷]
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	_mission_bar.add_child(btn_row)

	var ml := Button.new()
	ml.text = "\u25C1 \u25C1"
	ml.custom_minimum_size = Vector2(80, 50)
	ml.pressed.connect(func() -> void: _cycle_mission(-1))
	btn_row.add_child(ml)

	var launch := Button.new()
	launch.text = "LAUNCH"
	launch.custom_minimum_size = Vector2(160, 50)
	launch.pressed.connect(_on_launch)
	btn_row.add_child(launch)

	var mr := Button.new()
	mr.text = "\u25B7 \u25B7"
	mr.custom_minimum_size = Vector2(80, 50)
	mr.pressed.connect(func() -> void: _cycle_mission(1))
	btn_row.add_child(mr)

	# Back button centered below
	var back := Button.new()
	back.text = "BACK"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(160, 40)
	back.pressed.connect(_on_back)
	_mission_bar.add_child(back)


# ── Verse cycling ──

func _cycle_verse(direction: int) -> void:
	_verse_index = (_verse_index + direction) % VERSES.size()
	if _verse_index < 0:
		_verse_index += VERSES.size()
	_apply_verse()
	_generate_mission_positions()


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
		_verse_mat.shader = null
		_grid_overlay.visible = true

	_verse_label.text = verse["label"] as String
	_verse_counter.text = "%d / %d" % [_verse_index + 1, VERSES.size()]


# ── Mission cycling ──

func _generate_mission_positions() -> void:
	_mission_positions.clear()
	_mission_levels.clear()
	_mission_index = 0

	var verse_id: String = VERSES[_verse_index]["verse_id"] as String
	if verse_id == "":
		# Tutorial has no real levels yet — placeholder
		_mission_levels.append(null)
		_mission_positions.append(Vector2(0.5, 0.5))
		return

	# Load all levels belonging to this verse
	var all_levels: Array[LevelData] = LevelDataManager.load_all()
	for level in all_levels:
		if level.verse_id == verse_id:
			_mission_levels.append(level)
			# Stable random position seeded from level id
			var h: int = level.id.hash()
			_mission_positions.append(Vector2(
				0.2 + fmod(absf(float(h & 0xFFFF) / 65535.0), 0.6),
				0.25 + fmod(absf(float((h >> 16) & 0xFFFF) / 65535.0), 0.5),
			))

	# Fallback if no levels found
	if _mission_levels.is_empty():
		_mission_levels.append(null)
		_mission_positions.append(Vector2(0.5, 0.5))


func _cycle_mission(direction: int) -> void:
	if _mission_levels.size() <= 1:
		return
	_mission_index = (_mission_index + direction) % _mission_levels.size()
	if _mission_index < 0:
		_mission_index += _mission_levels.size()
	_blink_time = 0.0
	_update_mission_label()
	_mission_bracket.queue_redraw()


func _update_mission_label() -> void:
	var level: LevelData = _mission_levels[_mission_index] if _mission_index < _mission_levels.size() else null
	if level:
		_verse_label.text = level.display_name
		_verse_counter.text = "%d / %d" % [_mission_index + 1, _mission_levels.size()]
	else:
		_verse_label.text = "NO MISSIONS"
		_verse_counter.text = ""


func _draw_corner(center: Vector2, half: float, line_len: float, w: float, col: Color) -> void:
	# Top-left
	_mission_bracket.draw_line(Vector2(center.x - half, center.y - half), Vector2(center.x - half + line_len, center.y - half), col, w)
	_mission_bracket.draw_line(Vector2(center.x - half, center.y - half), Vector2(center.x - half, center.y - half + line_len), col, w)
	# Top-right
	_mission_bracket.draw_line(Vector2(center.x + half, center.y - half), Vector2(center.x + half - line_len, center.y - half), col, w)
	_mission_bracket.draw_line(Vector2(center.x + half, center.y - half), Vector2(center.x + half, center.y - half + line_len), col, w)
	# Bottom-left
	_mission_bracket.draw_line(Vector2(center.x - half, center.y + half), Vector2(center.x - half + line_len, center.y + half), col, w)
	_mission_bracket.draw_line(Vector2(center.x - half, center.y + half), Vector2(center.x - half, center.y + half - line_len), col, w)
	# Bottom-right
	_mission_bracket.draw_line(Vector2(center.x + half, center.y + half), Vector2(center.x + half - line_len, center.y + half), col, w)
	_mission_bracket.draw_line(Vector2(center.x + half, center.y + half), Vector2(center.x + half, center.y + half - line_len), col, w)


func _draw_mission_bracket() -> void:
	if _mission_positions.is_empty():
		return
	var pos: Vector2 = _mission_positions[_mission_index]
	var rect_size: Vector2 = _mission_bracket.size
	var center := Vector2(pos.x * rect_size.x, pos.y * rect_size.y)
	var t: float = _blink_time

	# Pulsing size — breathes between 80% and 120% of base
	var pulse: float = 1.0 + 0.2 * sin(t * 2.5)
	var half: float = BRACKET_SIZE * 0.5 * pulse
	var line_len: float = BRACKET_SIZE * 0.4 * pulse

	# Color cycling: hot pink → cyan → white → hot pink
	var hue_shift: float = fmod(t * 0.3, 1.0)
	var col_a := Color.from_hsv(fmod(0.93 + hue_shift, 1.0), 0.7, 1.0)  # cycling hue
	var col_b := Color.from_hsv(fmod(0.93 + hue_shift + 0.5, 1.0), 0.5, 1.0)  # opposite hue

	# Outer glow layer — thick, semi-transparent
	var glow_half: float = half + 6.0
	var glow_len: float = line_len + 8.0
	var glow_col := Color(col_a.r, col_a.g, col_a.b, 0.3)
	_draw_corner(center, glow_half, glow_len, 6.0, glow_col)

	# Main bracket — bright, thick
	_draw_corner(center, half, line_len, 3.0, col_a)

	# Inner accent — thinner, offset color
	var inner_half: float = half - 3.0
	var inner_len: float = line_len - 4.0
	if inner_len > 2.0:
		_draw_corner(center, inner_half, inner_len, 1.5, col_b)

	# Crosshair lines through center — subtle
	var cross_len: float = 8.0
	var cross_col := Color(col_a.r, col_a.g, col_a.b, 0.6)
	_mission_bracket.draw_line(Vector2(center.x - cross_len, center.y), Vector2(center.x + cross_len, center.y), cross_col, 1.0)
	_mission_bracket.draw_line(Vector2(center.x, center.y - cross_len), Vector2(center.x, center.y + cross_len), cross_col, 1.0)

	# Center dot — pulsing
	var dot_radius: float = 2.0 + 1.0 * sin(t * 4.0)
	_mission_bracket.draw_circle(center, dot_radius, col_a)


# ── Mode transitions ──

func _release_panel_min_size() -> void:
	# Hide the VBox so its children stop enforcing minimum width on the panel
	_button_vbox.visible = false
	_button_panel.add_theme_constant_override("margin_left", 0)
	_button_panel.add_theme_constant_override("margin_right", 0)


func _restore_panel_min_size() -> void:
	_button_vbox.visible = true
	_button_panel.add_theme_constant_override("margin_left", 20)
	_button_panel.add_theme_constant_override("margin_right", 60)


func _kill_zoom_tween() -> void:
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = null


func _enter_mission_mode() -> void:
	_mode = "mission"
	_title_label.text = "SELECT MISSION"

	# Hide internal verse arrows
	_arrow_row.visible = false

	# Show bottom mission bar
	_mission_bar.visible = true
	_apply_mission_bar_styles()

	# Animate: zoom viewport + collapse right panel simultaneously
	_zooming = true
	_vpc.pivot_offset = _vpc.size / 2.0
	_kill_zoom_tween()
	var fade_dur: float = ZOOM_DURATION * 0.4
	_zoom_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.tween_property(_vpc, "scale", Vector2(ZOOM_SCALE, ZOOM_SCALE), ZOOM_DURATION)
	_zoom_tween.tween_property(_button_panel, "size_flags_stretch_ratio", 0.0, ZOOM_DURATION)
	# Fade out buttons, then hide VBox to release minimum size so panel can fully collapse
	_zoom_tween.tween_property(_button_panel, "modulate:a", 0.0, fade_dur)
	_zoom_tween.tween_callback(_release_panel_min_size).set_delay(fade_dur)

	# After full animation: hide panel, show mission bracket
	_mission_index = 0
	_blink_time = 0.0
	_mission_bracket.visible = false
	_update_mission_label()
	_zoom_tween.chain().tween_callback(func() -> void:
		_zooming = false
		_button_panel.visible = false
		_mission_bracket.visible = true
		_mission_bracket.queue_redraw()
	)


func _exit_mission_mode() -> void:
	_mode = "verse"
	_title_label.text = "SELECT VERSE"

	# Hide mission UI
	_mission_bracket.visible = false
	_mission_bar.visible = false

	# Restore verse UI
	_arrow_row.visible = true
	_button_panel.visible = true
	_button_panel.modulate.a = 0.0
	_restore_panel_min_size()

	# Animate: unzoom + expand right panel simultaneously
	_zooming = true
	_kill_zoom_tween()
	_zoom_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	var out_duration: float = ZOOM_DURATION * 0.7
	_zoom_tween.tween_property(_vpc, "scale", Vector2.ONE, out_duration)
	_zoom_tween.tween_property(_button_panel, "size_flags_stretch_ratio", 0.7, out_duration)
	# Fade in the right panel buttons (delayed slightly so they appear as panel expands)
	_zoom_tween.tween_property(_button_panel, "modulate:a", 1.0, out_duration * 0.6).set_delay(out_duration * 0.3)

	_zoom_tween.chain().tween_callback(func() -> void:
		_zooming = false
		_vpc.pivot_offset = Vector2.ZERO
	)
	_apply_verse()


# ── Button handlers ──

func _on_ready_pressed() -> void:
	_enter_mission_mode()


func _on_launch() -> void:
	var level: LevelData = _mission_levels[_mission_index] if _mission_index < _mission_levels.size() else null
	if not level:
		return  # No valid level to launch
	GameState.current_level_id = level.id
	GameState.return_scene = "res://scenes/ui/mission_prep_menu.tscn"
	SceneLoader.load_scene("res://scenes/game/game.tscn")


func _on_back() -> void:
	if _mode == "mission":
		_exit_mission_mode()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_hangar() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_bay_screen.tscn")


func _on_loadout() -> void:
	var HangarScreen: GDScript = load("res://scripts/ui/hangar_screen.gd")
	HangarScreen.set("initial_mode", "workshop")
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_audio_mix() -> void:
	var HangarScreen: GDScript = load("res://scripts/ui/hangar_screen.gd")
	HangarScreen.set("initial_mode", "audio")
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


# ── Styling ──

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
	_button_panel = $HBoxContainer/ButtonPanel as MarginContainer
	_button_vbox = _button_panel.get_node("VBoxContainer") as VBoxContainer
	var btns: VBoxContainer = _button_vbox
	_ready_btn = btns.get_node("ReadyButton") as Button
	var back: Button = btns.get_node("BackButton") as Button

	_ready_btn.pressed.connect(_on_ready_pressed)
	back.pressed.connect(_on_back)
	btns.get_node("LoadoutButton").pressed.connect(_on_loadout)
	btns.get_node("HangarButton").pressed.connect(_on_hangar)
	btns.get_node("AudioMixButton").pressed.connect(_on_audio_mix)

	# The LaunchButton in the tscn is unused now — hide it
	btns.get_node("LaunchButton").visible = false

	# Track which buttons hide in mission mode
	_verse_buttons = [
		btns.get_node("LoadoutButton") as Button,
		btns.get_node("HangarButton") as Button,
		btns.get_node("AudioMixButton") as Button,
	]


func _apply_styles() -> void:
	var btns: VBoxContainer = _button_panel.get_node("VBoxContainer") as VBoxContainer
	for child in btns.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)


func _apply_mission_bar_styles() -> void:
	for child in _mission_bar.get_children():
		if child is Button:
			ThemeManager.apply_button_style(child as Button)
		elif child is HBoxContainer:
			for btn in child.get_children():
				if btn is Button:
					ThemeManager.apply_button_style(btn as Button)


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
	if _mission_bar.visible:
		_apply_mission_bar_styles()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
