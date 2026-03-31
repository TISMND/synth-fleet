extends Control
## Auditions screen — tabbed: Warp (locked in/out) + Events.

const SHIP_ID: int = 4  # Stiletto
const WARP_COLOR: Color = Color(0.3, 0.7, 1.0)
const VP_W: int = 420
const VP_H: int = 600

var _vhs_overlay: ColorRect
var _bg: ColorRect
var _title_label: Label
var _back_button: Button

var _active_tab: int = 0
var _tab_warp_btn: Button
var _tab_events_btn: Button
var _tab_items_btn: Button
var _tab_hud_btn: Button
var _tab_synthwave_btn: Button
var _warp_content: Control
var _events_content: ScrollContainer
var _items_content: MarginContainer
var _hud_content: MarginContainer
var _synthwave_content: Control
var _synthwave_rect: ColorRect
var _event_trigger_buttons: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_apply_theme()
	ThemeManager.theme_changed.connect(_apply_theme)


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	ThemeManager.apply_grid_background(_bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 20
	main_vbox.offset_top = 20
	main_vbox.offset_right = -20
	main_vbox.offset_bottom = -20
	main_vbox.add_theme_constant_override("separation", 12)
	add_child(main_vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	main_vbox.add_child(header)

	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.pressed.connect(_on_back)
	header.add_child(_back_button)

	_title_label = Label.new()
	_title_label.text = "AUDITIONS"
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_tab_warp_btn = Button.new()
	_tab_warp_btn.text = "WARP"
	_tab_warp_btn.toggle_mode = true
	_tab_warp_btn.button_pressed = true
	_tab_warp_btn.pressed.connect(func(): _switch_to_tab(0))
	header.add_child(_tab_warp_btn)

	_tab_events_btn = Button.new()
	_tab_events_btn.text = "EVENTS"
	_tab_events_btn.toggle_mode = true
	_tab_events_btn.pressed.connect(func(): _switch_to_tab(1))
	header.add_child(_tab_events_btn)

	_tab_items_btn = Button.new()
	_tab_items_btn.text = "ITEMS"
	_tab_items_btn.toggle_mode = true
	_tab_items_btn.pressed.connect(func(): _switch_to_tab(2))
	header.add_child(_tab_items_btn)

	_tab_hud_btn = Button.new()
	_tab_hud_btn.text = "HUD"
	_tab_hud_btn.toggle_mode = true
	_tab_hud_btn.pressed.connect(func(): _switch_to_tab(3))
	header.add_child(_tab_hud_btn)

	_tab_synthwave_btn = Button.new()
	_tab_synthwave_btn.text = "SYNTHWAVE"
	_tab_synthwave_btn.toggle_mode = true
	_tab_synthwave_btn.pressed.connect(func(): _switch_to_tab(4))
	header.add_child(_tab_synthwave_btn)

	# Warp content — two tall viewports side by side
	_warp_content = HBoxContainer.new()
	_warp_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_warp_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(_warp_content as HBoxContainer).add_theme_constant_override("separation", 40)
	(_warp_content as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(_warp_content)
	_build_warp_panels()

	_events_content = ScrollContainer.new()
	_events_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_events_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_content.visible = false
	main_vbox.add_child(_events_content)
	_build_events_content()

	var ItemsTabScript: GDScript = load("res://scripts/ui/auditions_tab.gd")
	_items_content = ItemsTabScript.new()
	_items_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_items_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_content.visible = false
	main_vbox.add_child(_items_content)

	var HudTabScript: GDScript = load("res://scripts/ui/cargo_counter_auditions.gd")
	_hud_content = HudTabScript.new()
	_hud_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hud_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hud_content.visible = false
	main_vbox.add_child(_hud_content)

	_synthwave_content = Control.new()
	_synthwave_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_synthwave_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synthwave_content.visible = false
	main_vbox.add_child(_synthwave_content)
	_build_synthwave_content()

	_setup_vhs_overlay()


func _switch_to_tab(idx: int) -> void:
	if _active_tab == idx:
		match idx:
			0: _tab_warp_btn.button_pressed = true
			1: _tab_events_btn.button_pressed = true
			2: _tab_items_btn.button_pressed = true
			3: _tab_hud_btn.button_pressed = true
			4: _tab_synthwave_btn.button_pressed = true
		return
	_active_tab = idx
	_tab_warp_btn.button_pressed = (idx == 0)
	_tab_events_btn.button_pressed = (idx == 1)
	_tab_items_btn.button_pressed = (idx == 2)
	_tab_hud_btn.button_pressed = (idx == 3)
	_tab_synthwave_btn.button_pressed = (idx == 4)
	_warp_content.visible = (idx == 0)
	_events_content.visible = (idx == 1)
	_items_content.visible = (idx == 2)
	_hud_content.visible = (idx == 3)
	_synthwave_content.visible = (idx == 4)


func _build_warp_panels() -> void:
	var in_cell := _WarpInCell.new()
	in_cell.setup()
	_warp_content.add_child(in_cell)

	var out_cell := _WarpOutCell.new()
	out_cell.setup()
	_warp_content.add_child(out_cell)


# ── Events tab ──────────────────────────────────────────────────────

func _build_events_content() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_events_content.add_child(vbox)

	var desc := Label.new()
	desc.text = "Visual effects (shake, static, lightning, dimming) only render in the game viewport.\nUse LAUNCH to open an empty game level where you can trigger events with number keys."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var launch_btn := Button.new()
	launch_btn.text = "LAUNCH EVENTS SIMULATION"
	launch_btn.pressed.connect(_on_launch_events_sim)
	vbox.add_child(launch_btn)

	vbox.add_child(HSeparator.new())

	var events: Array[GameEventData] = GameEventDataManager.load_all()
	_event_trigger_buttons.clear()
	for event_data in events:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		vbox.add_child(row)

		var label := Label.new()
		label.text = event_data.display_name
		label.custom_minimum_size.x = 200
		row.add_child(label)

		var trigger_btn := Button.new()
		trigger_btn.text = "TRIGGER"
		trigger_btn.pressed.connect(_on_trigger_event_preview.bind(event_data.id))
		row.add_child(trigger_btn)
		_event_trigger_buttons[event_data.id] = trigger_btn

	if events.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No game events defined yet. Create them in data/game_events/"
		vbox.add_child(empty_label)


func _on_trigger_event_preview(event_id: String) -> void:
	var event_data: GameEventData = GameEventDataManager.load_by_id(event_id)
	if not event_data:
		return
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0.3)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 5
	add_child(flash)
	var tw: Tween = create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.3)
	tw.tween_callback(flash.queue_free)


var _synthwave_presets: Array[Dictionary] = []
var _synthwave_preset_idx: int = 0
var _synthwave_preset_label: Label


func _build_synthwave_content() -> void:
	_synthwave_rect = ColorRect.new()
	_synthwave_rect.color = Color.WHITE
	_synthwave_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_synthwave_content.add_child(_synthwave_rect)

	var shader: Shader = load("res://assets/shaders/synthwave_bg.gdshader")
	if shader:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_synthwave_rect.material = mat

	_init_synthwave_presets()

	# ── Left control panel ──
	var panel_bg := ColorRect.new()
	panel_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	panel_bg.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel_bg.offset_right = 310
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_synthwave_content.add_child(panel_bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	scroll.offset_left = 10
	scroll.offset_top = 10
	scroll.offset_right = 300
	scroll.offset_bottom = -10
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_synthwave_content.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	# Preset nav row
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	vbox.add_child(bar)
	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(_synthwave_prev)
	bar.add_child(prev_btn)
	ThemeManager.apply_button_style(prev_btn)
	_synthwave_preset_label = Label.new()
	_synthwave_preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synthwave_preset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(_synthwave_preset_label, "header")
	bar.add_child(_synthwave_preset_label)
	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(_synthwave_next)
	bar.add_child(next_btn)
	ThemeManager.apply_button_style(next_btn)

	vbox.add_child(HSeparator.new())

	# ── SUN ──
	_sw_section(vbox, "SUN")
	_sw_slider(vbox, "sun_glow", "Glow HDR", 0.0, 2.0, 0.6)
	_sw_slider(vbox, "sun_size", "Size", 0.04, 0.22, 0.13)
	_sw_slider(vbox, "sun_x", "Position X", 0.35, 0.85, 0.63)
	_sw_color(vbox, "sun_color_top", "Top Color", Color(1.0, 0.95, 0.4))
	_sw_color(vbox, "sun_color_bot", "Bottom Color", Color(1.0, 0.2, 0.08))

	vbox.add_child(HSeparator.new())

	# ── GRID ──
	_sw_section(vbox, "GRID")
	_sw_slider(vbox, "grid_core_brightness", "Core HDR", 1.0, 12.0, 6.0)
	_sw_slider(vbox, "grid_bloom_brightness", "Bloom HDR", 0.5, 8.0, 3.0)
	_sw_slider(vbox, "grid_line_w", "Line Width", 0.001, 0.03, 0.008)
	_sw_slider(vbox, "grid_bloom_w", "Bloom Width", 0.01, 0.15, 0.06)
	_sw_color(vbox, "grid_color", "Grid Color", Color(1.0, 0.08, 0.52))
	_sw_slider(vbox, "scroll_speed", "Scroll Speed", 0.0, 2.0, 0.5)
	_sw_slider(vbox, "grid_freq", "Frequency", 0.5, 5.0, 2.0)

	vbox.add_child(HSeparator.new())

	# ── SKY ──
	_sw_section(vbox, "SKY")
	_sw_slider(vbox, "nebula_intensity", "Nebula", 0.0, 0.5, 0.12)
	_sw_slider(vbox, "star_cutoff", "Star Density", 0.85, 0.99, 0.94)
	_sw_slider(vbox, "shooting_star_rate", "Shooting Stars", 0.0, 1.0, 0.4)
	_sw_slider(vbox, "light_brightness", "Motion Lights", 0.0, 3.0, 0.5)
	_sw_slider(vbox, "light_speed", "Light Speed", 0.05, 2.0, 0.5)
	_sw_slider(vbox, "horizon", "Horizon", 0.3, 0.65, 0.5)
	_sw_color(vbox, "accent_color", "Nebula Color", Color(0.1, 0.8, 1.0))

	_apply_synthwave_preset(0)


func _sw_section(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 14)
	ThemeManager.apply_text_glow(label, "header")
	var header_font: Font = ThemeManager.get_font("font_header")
	if header_font:
		label.add_theme_font_override("font", header_font)
	parent.add_child(label)


func _sw_slider(parent: VBoxContainer, param: String, display: String,
		min_val: float, max_val: float, default_val: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = display
	label.custom_minimum_size.x = 110
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = (max_val - min_val) / 200.0
	slider.value = default_val
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	row.add_child(slider)

	var val_label := Label.new()
	val_label.custom_minimum_size.x = 40
	val_label.add_theme_font_size_override("font_size", 11)
	val_label.text = "%.3f" % default_val
	row.add_child(val_label)

	slider.value_changed.connect(func(v: float) -> void:
		val_label.text = "%.3f" % v
		_sw_set(param, v)
	)
	slider.set_meta("sw_param", param)


func _sw_color(parent: VBoxContainer, param: String, display: String, default_col: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = display
	label.custom_minimum_size.x = 110
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)

	var picker := ColorPickerButton.new()
	picker.color = default_col
	picker.custom_minimum_size = Vector2(60, 24)
	picker.edit_alpha = false
	row.add_child(picker)

	picker.color_changed.connect(func(c: Color) -> void:
		_sw_set(param, c)
	)
	picker.set_meta("sw_param", param)


func _sw_set(param: String, value: Variant) -> void:
	var mat: ShaderMaterial = _synthwave_rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(param, value)


func _sw_sync_controls(node: Node, preset: Dictionary) -> void:
	if node.has_meta("sw_param"):
		var param: String = node.get_meta("sw_param")
		if preset.has(param):
			if node is HSlider:
				node.set_value_no_signal(float(preset[param]))
				# Update the value label (sibling after the slider)
				var parent: Node = node.get_parent()
				var idx: int = node.get_index()
				if idx + 1 < parent.get_child_count():
					var val_label: Node = parent.get_child(idx + 1)
					if val_label is Label:
						val_label.text = "%.3f" % float(preset[param])
			elif node is ColorPickerButton:
				node.color = preset[param] as Color
	for child in node.get_children():
		_sw_sync_controls(child, preset)


func _init_synthwave_presets() -> void:
	_synthwave_presets.clear()
	_synthwave_presets.append({
		"name": "CLASSIC OUTRUN",
		"grid_color": Color(1.0, 0.08, 0.52),
		"accent_color": Color(0.1, 0.8, 1.0),
		"sun_color_top": Color(1.0, 0.95, 0.4),
		"sun_color_bot": Color(1.0, 0.2, 0.08),
		"sky_top": Color(0.01, 0.0, 0.06),
		"sky_mid": Color(0.08, 0.0, 0.14),
		"sky_low": Color(0.18, 0.02, 0.25),
		"nebula_intensity": 0.12,
		"sun_glow": 0.6,
		"grid_line_w": 0.008,
		"grid_bloom_w": 0.06,
		"grid_core_brightness": 6.0,
		"grid_bloom_brightness": 3.0,
		"shooting_star_rate": 0.4,
		"star_cutoff": 0.94,
		"light_brightness": 0.5,
	})


func _apply_synthwave_preset(idx: int) -> void:
	_synthwave_preset_idx = idx
	var preset: Dictionary = _synthwave_presets[idx]
	if _synthwave_preset_label:
		var count: int = _synthwave_presets.size()
		if count > 1:
			_synthwave_preset_label.text = str(preset["name"]) + "  (" + str(idx + 1) + "/" + str(count) + ")"
		else:
			_synthwave_preset_label.text = str(preset["name"])
	var mat: ShaderMaterial = _synthwave_rect.material as ShaderMaterial
	if not mat:
		return
	for key in preset:
		if key == "name":
			continue
		mat.set_shader_parameter(key, preset[key])
	# Sync sliders and color pickers to preset values
	_sw_sync_controls(_synthwave_content, preset)


func _synthwave_prev() -> void:
	var idx: int = _synthwave_preset_idx - 1
	if idx < 0:
		idx = _synthwave_presets.size() - 1
	_apply_synthwave_preset(idx)


func _synthwave_next() -> void:
	var idx: int = _synthwave_preset_idx + 1
	if idx >= _synthwave_presets.size():
		idx = 0
	_apply_synthwave_preset(idx)


func _on_launch_events_sim() -> void:
	GameState.return_scene = "res://scenes/ui/auditions_screen.tscn"
	GameState.current_level_id = "level_1"
	GameState.set_meta("events_audition", true)
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


# ── Theme ────────────────────────────────────────────────────────────

func _apply_theme() -> void:
	if _bg:
		ThemeManager.apply_grid_background(_bg)
	if _back_button:
		ThemeManager.apply_button_style(_back_button)
	if _tab_warp_btn:
		ThemeManager.apply_button_style(_tab_warp_btn)
	if _tab_events_btn:
		ThemeManager.apply_button_style(_tab_events_btn)
	if _tab_items_btn:
		ThemeManager.apply_button_style(_tab_items_btn)
	if _tab_hud_btn:
		ThemeManager.apply_button_style(_tab_hud_btn)
	if _tab_synthwave_btn:
		ThemeManager.apply_button_style(_tab_synthwave_btn)
	if _title_label:
		ThemeManager.apply_text_glow(_title_label, "header")
		_title_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_header"))
		var header_font: Font = ThemeManager.get_font("font_header")
		if header_font:
			_title_label.add_theme_font_override("font", header_font)
		_title_label.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)
	for key in _event_trigger_buttons:
		var btn: Button = _event_trigger_buttons[key]
		if is_instance_valid(btn):
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


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


# ═══════════════════════════════════════════════════════════════════════
# WARP IN — Streak + Flash, arriving from bottom
#
# Timeline: blank → orb flash appears at home → ship streaks in from
# bottom and decelerates through the flash → ship settles to normal
# ═══════════════════════════════════════════════════════════════════════

class _WarpInCell extends VBoxContainer:
	# Ship rests at center-ish of the tall viewport
	const SHIP_HOME: Vector2 = Vector2(210.0, 300.0)
	const BLANK_DUR: float = 1.0
	const EFFECT_DUR: float = 1.3
	const SETTLE_DUR: float = 0.8

	var _ship: ShipRenderer
	var _fx: _FXLayer
	var _time: float = 0.0
	var _flash_fired: bool = false

	func setup() -> void:
		_time = 0.0

	func _ready() -> void:
		add_theme_constant_override("separation", 6)

		var title := Label.new()
		title.text = "WARP IN"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 14)
		ThemeManager.apply_text_glow(title, "header")
		add_child(title)

		_build_vp()
		_ship.visible = false

	func _build_vp() -> void:
		var vpc := SubViewportContainer.new()
		vpc.stretch = true
		vpc.custom_minimum_size = Vector2(VP_W, VP_H)
		vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(vpc)
		var vp := SubViewport.new()
		vp.transparent_bg = false
		vp.size = Vector2i(VP_W, VP_H)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vpc.add_child(vp)
		VFXFactory.add_bloom_to_viewport(vp)
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.01, 0.03)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp.add_child(bg)
		var stars := _StarBG.new()
		stars.init_stars(VP_W, VP_H, 50, 500)
		vp.add_child(stars)
		_ship = ShipRenderer.new()
		_ship.ship_id = SHIP_ID
		_ship.render_mode = ShipRenderer.RenderMode.CHROME
		_ship.z_index = 1
		vp.add_child(_ship)
		_fx = _FXLayer.new()
		_fx.z_index = 2
		var fx_mat := CanvasItemMaterial.new()
		fx_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_fx.material = fx_mat
		vp.add_child(_fx)

	func _process(delta: float) -> void:
		_time += delta
		var cycle: float = BLANK_DUR + EFFECT_DUR + SETTLE_DUR
		if _time >= cycle:
			_time = fmod(_time, cycle)
			_reset()

		_fx.shapes.clear()
		_fx.tick_particles(delta)

		if _time < BLANK_DUR:
			_ship.visible = false
			# Pre-arrival streaks in final portion of blank
			if _time > BLANK_DUR * 0.5:
				var pre_t: float = (_time - BLANK_DUR * 0.5) / (BLANK_DUR * 0.5)
				if randf() < pre_t * 0.4:
					_fx.emit(Vector2(SHIP_HOME.x + randf_range(-25.0, 25.0), float(VP_H)),
						Vector2(0.0, -randf_range(150.0, 300.0)), 0.3, _hdr(1.2, 0.3), 1.0)
		elif _time < BLANK_DUR + EFFECT_DUR:
			var p: float = (_time - BLANK_DUR) / EFFECT_DUR
			_run_arrival(p)
		else:
			_ship.visible = true
			_ship.position = SHIP_HOME
			_ship.scale = Vector2.ONE
			_ship.modulate = Color.WHITE

		_fx.queue_redraw()

	func _reset() -> void:
		_ship.visible = false
		_ship.position = SHIP_HOME
		_ship.scale = Vector2.ONE
		_ship.modulate = Color.WHITE
		_flash_fired = false
		_fx.particles.clear()
		_fx.shapes.clear()

	func _hdr(m: float, a: float) -> Color:
		return Color(WARP_COLOR.r * m, WARP_COLOR.g * m, WARP_COLOR.b * m, a)

	func _run_arrival(p: float) -> void:
		# Phase layout within p 0→1:
		#   0.0–0.25: Orb flash blooms at home position (no ship yet)
		#   0.15–0.55: Ship streaks in from bottom, decelerating through the orb
		#   0.55–1.0: Ship settles, glow fades, flash particles dissipate

		var orb_start: float = 0.0
		var orb_peak: float = 0.2
		var ship_start: float = 0.15
		var ship_arrive: float = 0.55
		var settle_end: float = 1.0

		# ── Orb flash (appears before ship) ──
		if p < 0.5:
			var orb_t: float = p / 0.5
			var orb_intensity: float
			if orb_t < 0.4:
				# Bloom in
				orb_intensity = orb_t / 0.4
			else:
				# Fade out
				orb_intensity = (1.0 - orb_t) / 0.6
			orb_intensity = maxf(orb_intensity, 0.0)
			if orb_intensity > 0.01:
				var orb_r: float = 20.0 + orb_intensity * 35.0
				_fx.shapes.append([0, SHIP_HOME, orb_r,
					_hdr(4.0, orb_intensity * 0.3)])
				_fx.shapes.append([0, SHIP_HOME, orb_r * 0.5,
					Color(1.0, 1.0, 1.0, orb_intensity * 0.15)])

		# ── Flash particles (fire once near orb peak) ──
		if p >= orb_peak and not _flash_fired:
			_flash_fired = true
			for i in 6:
				var angle: float = randf() * TAU
				_fx.emit_drag(SHIP_HOME,
					Vector2(cos(angle), sin(angle)) * randf_range(25.0, 55.0),
					0.5, _hdr(4.0, 0.8), 2.5, 2.0)

		# ── Ship streak from bottom ──
		if p >= ship_start:
			_ship.visible = true
			if p < ship_arrive:
				var t: float = (p - ship_start) / (ship_arrive - ship_start)
				# Deceleration curve: fast at start, slow at end
				var ease_t: float = 1.0 - pow(1.0 - t, 3.0)
				# Start well below viewport, arrive at home
				_ship.position.y = lerpf(float(VP_H) + 80.0, SHIP_HOME.y, ease_t)
				_ship.position.x = SHIP_HOME.x
				# Stretched at start, normal at end
				var stretch: float = 1.0 - t
				_ship.scale = Vector2(
					lerpf(1.0, 0.3, stretch),
					lerpf(1.0, 3.5, stretch))
				# Bright glow at start, fading toward normal
				var glow: float = lerpf(1.0, 4.0, stretch)
				_ship.modulate = Color(
					lerpf(1.0, WARP_COLOR.r * glow, stretch),
					lerpf(1.0, WARP_COLOR.g * glow, stretch),
					lerpf(1.0, WARP_COLOR.b * glow, stretch),
					lerpf(1.0, 0.3, stretch * stretch))
				# Trail streaks above ship (ship moving up, trail below)
				if randf() < 0.5 * stretch:
					_fx.emit(Vector2(_ship.position.x + randf_range(-5.0, 5.0), _ship.position.y + 20.0),
						Vector2(randf_range(-8.0, 8.0), randf_range(60.0, 140.0)),
						0.25, _hdr(2.0, 0.5), 1.2)
				# Background streaks moving upward (matching ship direction)
				if randf() < 0.4 * stretch:
					_fx.emit(Vector2(SHIP_HOME.x + randf_range(-35.0, 35.0), float(VP_H)),
						Vector2(0.0, -randf_range(180.0, 350.0)), 0.3, _hdr(1.5, 0.3), 0.8)
			else:
				# Settling
				var settle_t: float = (p - ship_arrive) / (settle_end - ship_arrive)
				_ship.position = SHIP_HOME
				_ship.scale = Vector2.ONE
				var glow_fade: float = maxf(1.0 - settle_t * 2.5, 0.0)
				_ship.modulate = Color(
					1.0 + glow_fade * 0.5,
					1.0 + glow_fade * 0.5,
					1.0 + glow_fade * 0.5)


# ═══════════════════════════════════════════════════════════════════════
# WARP OUT — The Works (light speed + flash + rings + scatter + embers)
# ═══════════════════════════════════════════════════════════════════════

class _WarpOutCell extends VBoxContainer:
	const SHIP_HOME: Vector2 = Vector2(210.0, 300.0)
	const IDLE_DUR: float = 0.8
	const EFFECT_DUR: float = 1.3
	const BLANK_DUR: float = 1.0

	const CHARGE: float = 0.35
	const GLOW_MAX: float = 4.0
	const STRETCH_Y: float = 3.5
	const SQUEEZE_X: float = 0.3
	const EXIT_ACCEL: float = 3.5

	var _ship: ShipRenderer
	var _fx: _FXLayer
	var _time: float = 0.5  # offset so they don't sync
	var _sendoff_fired: bool = false

	func setup() -> void:
		pass

	func _ready() -> void:
		add_theme_constant_override("separation", 6)

		var title := Label.new()
		title.text = "WARP OUT"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 14)
		ThemeManager.apply_text_glow(title, "header")
		add_child(title)

		_build_vp()
		_ship.position = SHIP_HOME

	func _build_vp() -> void:
		var vpc := SubViewportContainer.new()
		vpc.stretch = true
		vpc.custom_minimum_size = Vector2(VP_W, VP_H)
		vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(vpc)
		var vp := SubViewport.new()
		vp.transparent_bg = false
		vp.size = Vector2i(VP_W, VP_H)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vpc.add_child(vp)
		VFXFactory.add_bloom_to_viewport(vp)
		var bg := ColorRect.new()
		bg.color = Color(0.01, 0.01, 0.03)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		vp.add_child(bg)
		var stars := _StarBG.new()
		stars.init_stars(VP_W, VP_H, 50, 501)
		vp.add_child(stars)
		_ship = ShipRenderer.new()
		_ship.ship_id = SHIP_ID
		_ship.render_mode = ShipRenderer.RenderMode.CHROME
		_ship.z_index = 1
		vp.add_child(_ship)
		_fx = _FXLayer.new()
		_fx.z_index = 2
		var fx_mat := CanvasItemMaterial.new()
		fx_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_fx.material = fx_mat
		vp.add_child(_fx)

	func _process(delta: float) -> void:
		_time += delta
		var cycle: float = IDLE_DUR + EFFECT_DUR + BLANK_DUR
		if _time >= cycle:
			_time = fmod(_time, cycle)
			_reset()

		_fx.shapes.clear()
		_fx.tick_particles(delta)

		if _time < IDLE_DUR:
			pass  # ship at rest
		elif _time < IDLE_DUR + EFFECT_DUR:
			var p: float = (_time - IDLE_DUR) / EFFECT_DUR
			_run_departure(p)
		else:
			_ship.visible = false

		_fx.queue_redraw()

	func _reset() -> void:
		_ship.visible = true
		_ship.position = SHIP_HOME
		_ship.scale = Vector2.ONE
		_ship.modulate = Color.WHITE
		_sendoff_fired = false
		_fx.particles.clear()
		_fx.shapes.clear()

	func _hdr(m: float, a: float) -> Color:
		return Color(WARP_COLOR.r * m, WARP_COLOR.g * m, WARP_COLOR.b * m, a)

	func _run_departure(p: float) -> void:
		# Phase 1: Charge
		if p < CHARGE:
			var t: float = p / CHARGE
			var e: float = t * t
			_ship.scale = Vector2(1.0 - e * (1.0 - SQUEEZE_X), 1.0 + e * (STRETCH_Y - 1.0))
			var g: float = 1.0 + e * (GLOW_MAX - 1.0)
			_ship.modulate = Color(
				lerpf(1.0, WARP_COLOR.r * g, e),
				lerpf(1.0, WARP_COLOR.g * g, e),
				lerpf(1.0, WARP_COLOR.b * g, e))
			if randf() < t * 0.5:
				_fx.emit(Vector2(SHIP_HOME.x + randf_range(-35.0, 35.0), float(VP_H)),
					Vector2(0.0, -randf_range(180.0, 350.0)), 0.3, _hdr(1.5, 0.4), 0.8)
			return

		# Phase 2: Exit — ship shoots upward
		var exit_end: float = CHARGE + (1.0 - CHARGE) * 0.55
		var sendoff_trigger: float = 0.4

		if p < exit_end:
			var t: float = (p - CHARGE) / (exit_end - CHARGE)
			var e: float = pow(t, EXIT_ACCEL)
			_ship.scale = Vector2(SQUEEZE_X * (1.0 - t * 0.5), STRETCH_Y + t * STRETCH_Y * 0.5)
			_ship.position.y = SHIP_HOME.y - e * 600.0
			_ship.modulate = Color(WARP_COLOR.r * GLOW_MAX, WARP_COLOR.g * GLOW_MAX,
				WARP_COLOR.b * GLOW_MAX, 1.0 - t * 0.8)
			# Trail
			if randf() < 0.7:
				_fx.emit(Vector2(_ship.position.x + randf_range(-5.0, 5.0), _ship.position.y + 25.0),
					Vector2(randf_range(-8.0, 8.0), randf_range(60.0, 150.0)), 0.3, _hdr(2.5, 0.6), 1.2)
			# Sendoff: The Works
			if t >= sendoff_trigger and not _sendoff_fired:
				_sendoff_fired = true
				for i in 5:
					var a: float = randf() * TAU
					_fx.emit_drag(SHIP_HOME, Vector2(cos(a), sin(a)) * randf_range(25.0, 50.0),
						0.4, _hdr(4.0, 0.8), 2.5, 2.0)
				for i in 8:
					var a: float = randf_range(0.7, 2.45)
					_fx.emit_drag(SHIP_HOME, Vector2(cos(a), sin(a)) * randf_range(50.0, 120.0),
						0.5, _hdr(2.5, 0.6), 1.8, 1.5)
				for i in 5:
					var a: float = randf_range(0.5, 2.65)
					_fx.emit(SHIP_HOME + Vector2(randf_range(-10.0, 10.0), 0.0),
						Vector2(cos(a), sin(a)) * randf_range(12.0, 30.0),
						randf_range(0.9, 1.5), _hdr(2.0, 0.5), randf_range(2.0, 3.0))
			# Sendoff shapes
			if _sendoff_fired:
				var st: float = (t - sendoff_trigger) / (1.0 - sendoff_trigger)
				if st < 0.4:
					_fx.shapes.append([0, SHIP_HOME, 25.0 + st * 55.0,
						_hdr(4.0, (0.4 - st) / 0.4 * 0.2)])
				var r1: float = st * 100.0
				var r2: float = maxf(st - 0.12, 0.0) / 0.88 * 75.0
				var a1: float = (1.0 - st) * 0.6
				if a1 > 0.01:
					_fx.shapes.append([1, SHIP_HOME, r1, 0.0, TAU, 48, _hdr(3.0, a1), 2.5])
				if r2 > 1.0:
					var a2: float = (1.0 - minf(st + 0.12, 1.0)) * 0.4
					if a2 > 0.01:
						_fx.shapes.append([1, SHIP_HOME, r2, 0.0, TAU, 36, _hdr(2.0, a2), 1.5])
		else:
			_ship.visible = false
			var t: float = (p - exit_end) / (1.0 - exit_end)
			var r1: float = 100.0 + t * 30.0
			var r2: float = 75.0 + t * 20.0
			var a: float = (1.0 - t) * 0.2
			if a > 0.01:
				_fx.shapes.append([1, SHIP_HOME, r1, 0.0, TAU, 48, _hdr(2.0, a), 2.0])
				_fx.shapes.append([1, SHIP_HOME, r2, 0.0, TAU, 36, _hdr(1.5, a * 0.5), 1.5])


# ═══════════════════════════════════════════════════════════════════════
# FX drawing layer
# ═══════════════════════════════════════════════════════════════════════

class _FXLayer extends Node2D:
	var shapes: Array = []
	var particles: Array = []

	func emit(pos: Vector2, vel: Vector2, life: float, col: Color, sz: float) -> void:
		if particles.size() < 80:
			particles.append({"p": pos, "v": vel, "l": life, "ml": life, "c": col, "s": sz})

	func emit_drag(pos: Vector2, vel: Vector2, life: float, col: Color, sz: float, drag: float) -> void:
		if particles.size() < 80:
			particles.append({"p": pos, "v": vel, "l": life, "ml": life, "c": col, "s": sz, "drag": drag})

	func tick_particles(delta: float) -> void:
		var i: int = particles.size() - 1
		while i >= 0:
			var pt: Dictionary = particles[i]
			pt["l"] -= delta
			if pt["l"] <= 0.0:
				particles.remove_at(i)
			else:
				var pos: Vector2 = pt["p"]
				var vel: Vector2 = pt["v"]
				pt["p"] = pos + vel * delta
				if pt.has("drag"):
					pt["v"] = vel * (1.0 - float(pt["drag"]) * delta)
			i -= 1

	func _draw() -> void:
		for s in shapes:
			var cmd: int = int(s[0])
			if cmd == 0:
				draw_circle(s[1] as Vector2, s[2] as float, s[3] as Color)
			elif cmd == 1:
				draw_arc(s[1] as Vector2, s[2] as float, s[3] as float,
					s[4] as float, s[5] as int, s[6] as Color, s[7] as float)
			elif cmd == 2:
				draw_line(s[1] as Vector2, s[2] as Vector2, s[3] as Color, s[4] as float)
			elif cmd == 3:
				draw_rect(s[1] as Rect2, s[2] as Color)

		for pt in particles:
			var t: float = float(pt["l"]) / maxf(float(pt["ml"]), 0.001)
			var base_a: float = float(pt["c"].a)
			var a: float = t * base_a
			if a < 0.01:
				continue
			var c: Color = pt["c"] as Color
			var pos: Vector2 = pt["p"] as Vector2
			var sz: float = float(pt["s"])
			draw_circle(pos, sz * 2.5, Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, a * 0.15))
			draw_circle(pos, sz, Color(c.r, c.g, c.b, a))


# ═══════════════════════════════════════════════════════════════════════
# Static star background
# ═══════════════════════════════════════════════════════════════════════

class _StarBG extends Node2D:
	var _stars: Array = []

	func init_stars(w: int, h: int, count: int, seed_val: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		for i in count:
			_stars.append({
				"pos": Vector2(rng.randf() * float(w), rng.randf() * float(h)),
				"size": rng.randf_range(0.4, 1.4),
				"bright": rng.randf_range(0.15, 0.5),
			})

	func _draw() -> void:
		for s in _stars:
			var b: float = float(s["bright"])
			draw_circle(s["pos"] as Vector2, float(s["size"]),
				Color(b, b, b * 1.2, 0.7))
