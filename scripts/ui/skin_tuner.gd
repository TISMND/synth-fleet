extends MarginContainer
## Skin Tuner — interactive color tuning for one ship part at a time.
## Adjust HSV sliders to design new skins, then print values to console.

var _ship_renderer: ShipRenderer = null
var _exhaust: EngineExhaust = null
var _vp: SubViewport = null
var _bake_vp: SubViewport = null
var _bake_sprite: Sprite2D = null
var _vp_size := Vector2i(1920, 1080)
var _time: float = 0.0

# Ship selection
var _ship_index: int = 0
var _ship_label: Label = null
var _is_enemy: bool = false

const PLAYER_SHIPS: Array[Array] = [
	["STILETTO", 4],
	["CARGO SHIP", 7],
]
const ENEMY_SHIPS: Array[Array] = [
	["BEHEMOTH", "behemoth"],
	["SPORE", "spore"],
	["MITE", "mite"],
	["POLYP", "polyp"],
	["JELLYFISH", "jellyfish"],
	["LAMPREY", "lamprey"],
	["ANEMONE", "anemone"],
	["MANTARAY", "mantaray"],
	["NAUTILUS", "nautilus"],
	["MYCELIA", "mycelia"],
	["COLOSSUS", "colossus"],
	["IRONCLAD", "ironclad"],
]

# Part selection
enum Part { HULL, ACCENT, DETAIL, CANOPY, ENGINE }
var _selected_part: int = Part.HULL
var _part_btns: Array[Button] = []
const PART_NAMES: Array[String] = ["HULL", "ACCENT", "DETAIL", "CANOPY", "ENGINE"]
const PART_KEYS: Array[String] = ["hull", "accent", "detail", "canopy", "engine"]

# Colors for each part (HSV) — start with chrome-like defaults
var _part_hues: Array[float] = [0.55, 0.95, 0.45, 0.6, 0.08]
var _part_sats: Array[float] = [0.9, 0.7, 0.8, 0.3, 0.8]
var _part_vals: Array[float] = [0.9, 0.6, 0.7, 0.18, 0.5]

# Base render mode — PAINTED first for direct color control
var _base_mode: int = ShipRenderer.RenderMode.PAINTED
var _base_mode_label: Label = null
const BASE_MODES: Array[int] = [
	ShipRenderer.RenderMode.PAINTED,
	ShipRenderer.RenderMode.CHROME,
	ShipRenderer.RenderMode.GUNMETAL,
	ShipRenderer.RenderMode.MILITIA,
	ShipRenderer.RenderMode.STEALTH,
	ShipRenderer.RenderMode.CAUTION,
	ShipRenderer.RenderMode.NEON,
	ShipRenderer.RenderMode.EMBER,
	ShipRenderer.RenderMode.FROST,
]
const BASE_MODE_NAMES: Array[String] = ["PAINTED", "CHROME", "GUNMETAL", "MILITIA", "STEALTH", "CAUTION", "NEON", "EMBER", "FROST"]
var _base_mode_index: int = 0

# Sliders
var _hue_slider: HSlider = null
var _sat_slider: HSlider = null
var _val_slider: HSlider = null
var _color_preview: ColorRect = null
var _part_label: Label = null

# Type toggle
var _type_btn: Button = null


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	if _ship_renderer:
		_ship_renderer.time = _time
		_ship_renderer.palette_override = _build_palette()
		_ship_renderer.queue_redraw()


func _build_palette() -> Dictionary:
	var palette: Dictionary = {}
	for i in PART_NAMES.size():
		var c: Color = Color.from_hsv(_part_hues[i], _part_sats[i], _part_vals[i])
		palette[PART_KEYS[i]] = c
	return palette


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_1:
			_cycle_ship(-1)
		elif ke.keycode == KEY_2:
			_cycle_ship(1)
		elif ke.keycode == KEY_Q:
			_select_part((_selected_part - 1 + PART_NAMES.size()) % PART_NAMES.size())
		elif ke.keycode == KEY_E:
			_select_part((_selected_part + 1) % PART_NAMES.size())


func _select_part(idx: int) -> void:
	_selected_part = idx
	for i in _part_btns.size():
		_part_btns[i].button_pressed = (i == idx)
	_sync_sliders_to_part()


func _sync_sliders_to_part() -> void:
	if _hue_slider:
		_hue_slider.value = _part_hues[_selected_part]
	if _sat_slider:
		_sat_slider.value = _part_sats[_selected_part]
	if _val_slider:
		_val_slider.value = _part_vals[_selected_part]
	_update_labels()


func _update_labels() -> void:
	var c: Color = Color.from_hsv(_part_hues[_selected_part], _part_sats[_selected_part], _part_vals[_selected_part])
	if _color_preview:
		_color_preview.color = c
	if _part_label:
		_part_label.text = "%s  →  Color(%.2f, %.2f, %.2f)" % [PART_NAMES[_selected_part], c.r, c.g, c.b]


func _on_hue_changed(val: float) -> void:
	_part_hues[_selected_part] = val
	_update_labels()

func _on_sat_changed(val: float) -> void:
	_part_sats[_selected_part] = val
	_update_labels()

func _on_val_changed(val: float) -> void:
	_part_vals[_selected_part] = val
	_update_labels()


func _print_values() -> void:
	print("")
	print("=== SKIN TUNER OUTPUT ===")
	for i in PART_NAMES.size():
		var c: Color = Color.from_hsv(_part_hues[i], _part_sats[i], _part_vals[i])
		print("const NEWSKIN_%s := Color(%.3f, %.3f, %.3f)" % [PART_NAMES[i].to_upper(), c.r, c.g, c.b])
	print("")
	print("# HSV values for reference:")
	for i in PART_NAMES.size():
		print("#   %s: H=%.3f  S=%.3f  V=%.3f" % [PART_NAMES[i], _part_hues[i], _part_sats[i], _part_vals[i]])
	print("=========================")
	print("")


func _cycle_ship(dir: int) -> void:
	var list: Array[Array] = ENEMY_SHIPS if _is_enemy else PLAYER_SHIPS
	_ship_index = (_ship_index + dir + list.size()) % list.size()
	if _ship_label:
		_ship_label.text = list[_ship_index][0] as String
	_rebuild_ship()


func _toggle_type() -> void:
	_is_enemy = not _is_enemy
	_ship_index = 0
	if _type_btn:
		_type_btn.text = "ENEMY" if _is_enemy else "PLAYER"
	var list: Array[Array] = ENEMY_SHIPS if _is_enemy else PLAYER_SHIPS
	if _ship_label:
		_ship_label.text = list[0][0] as String
	_rebuild_ship()


func _rebuild_ship() -> void:
	if _is_enemy:
		_rebuild_enemy()
	else:
		_rebuild_player()


func _rebuild_player() -> void:
	if not _vp:
		return
	if _ship_renderer:
		_ship_renderer.queue_free()
		_ship_renderer = null
	if _exhaust:
		_exhaust.queue_free()
		_exhaust = null
	if _bake_sprite:
		_bake_sprite.visible = false

	var ship_id: int = PLAYER_SHIPS[_ship_index][1] as int
	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = ship_id
	_ship_renderer.render_mode = _base_mode
	_ship_renderer.position = Vector2(960.0, 540.0)
	_ship_renderer.z_index = 1
	_vp.add_child(_ship_renderer)

	_exhaust = EngineExhaust.new()
	var offsets: Array[Vector2] = ShipRenderer.get_engine_offsets(ship_id)
	var sc: float = ShipRenderer.get_ship_scale(ship_id)
	_exhaust.setup(offsets, sc)
	_exhaust.scroll_speed = 80.0
	_exhaust.position = Vector2(960.0, 540.0)
	_vp.add_child(_exhaust)
	_vp.move_child(_exhaust, _vp.get_child_count() - 2)


func _rebuild_enemy() -> void:
	if not _vp:
		return
	if _ship_renderer:
		_ship_renderer.queue_free()
		_ship_renderer = null
	if _exhaust:
		_exhaust.queue_free()
		_exhaust = null
	if _bake_vp == null:
		_bake_vp = SubViewport.new()
		_bake_vp.transparent_bg = true
		_bake_vp.use_hdr_2d = true
		_bake_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_vp.add_child(_bake_vp)
	if _bake_sprite == null:
		_bake_sprite = Sprite2D.new()
		_bake_sprite.position = Vector2(960, 540)
		_bake_sprite.z_index = 1
		_vp.add_child(_bake_sprite)

	_bake_sprite.visible = true

	var vid: String = ENEMY_SHIPS[_ship_index][1] as String
	var bake_size: int = EnemySharedRenderer.get_bake_size(vid)
	_bake_vp.size = Vector2i(bake_size, bake_size)

	# Load neon params from ShipData
	var neon_hdr: float = 1.0
	var neon_white: float = 0.0
	var neon_width: float = 1.0
	var ships: Array = ShipDataManager.load_all_by_type("enemy")
	for ship in ships:
		var sd: ShipData = ship as ShipData
		if sd and sd.visual_id == vid:
			neon_hdr = sd.neon_hdr
			neon_white = sd.neon_white
			neon_width = sd.neon_width
			break

	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = -1
	_ship_renderer.enemy_visual_id = vid
	_ship_renderer.render_mode = _base_mode
	_ship_renderer.neon_hdr = neon_hdr
	_ship_renderer.neon_white = neon_white
	_ship_renderer.neon_width = neon_width
	_ship_renderer.position = Vector2(bake_size / 2.0, bake_size / 2.0)
	_ship_renderer.z_index = 1

	# Clear old children from bake viewport
	for child in _bake_vp.get_children():
		child.queue_free()

	_bake_vp.add_child(_ship_renderer)
	_bake_sprite.texture = _bake_vp.get_texture()


func _cycle_base_mode(dir: int) -> void:
	_base_mode_index = (_base_mode_index + dir + BASE_MODES.size()) % BASE_MODES.size()
	_base_mode = BASE_MODES[_base_mode_index]
	if _base_mode_label:
		_base_mode_label.text = BASE_MODE_NAMES[_base_mode_index]
	if _ship_renderer:
		_ship_renderer.render_mode = _base_mode


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "SKIN TUNER — Q/E parts, 1/2 ship, sliders to tune"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	# Top controls row
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 20)
	main.add_child(controls)

	# Type toggle
	_type_btn = Button.new()
	_type_btn.text = "PLAYER"
	_type_btn.pressed.connect(_toggle_type)
	ThemeManager.apply_button_style(_type_btn)
	controls.add_child(_type_btn)

	# Ship selector
	var ship_row := HBoxContainer.new()
	ship_row.add_theme_constant_override("separation", 8)
	controls.add_child(ship_row)

	var prev_ship := Button.new()
	prev_ship.text = "< 1"
	prev_ship.pressed.connect(func() -> void: _cycle_ship(-1))
	ThemeManager.apply_button_style(prev_ship)
	ship_row.add_child(prev_ship)

	_ship_label = Label.new()
	_ship_label.text = PLAYER_SHIPS[0][0] as String
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_label.custom_minimum_size.x = 140
	ThemeManager.apply_text_glow(_ship_label, "header")
	ship_row.add_child(_ship_label)

	var next_ship := Button.new()
	next_ship.text = "2 >"
	next_ship.pressed.connect(func() -> void: _cycle_ship(1))
	ThemeManager.apply_button_style(next_ship)
	ship_row.add_child(next_ship)

	# Base mode selector
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	controls.add_child(mode_row)

	var mode_label := Label.new()
	mode_label.text = "BASE:"
	ThemeManager.apply_text_glow(mode_label, "body")
	mode_row.add_child(mode_label)

	var prev_mode := Button.new()
	prev_mode.text = "<"
	prev_mode.pressed.connect(func() -> void: _cycle_base_mode(-1))
	ThemeManager.apply_button_style(prev_mode)
	mode_row.add_child(prev_mode)

	_base_mode_label = Label.new()
	_base_mode_label.text = BASE_MODE_NAMES[0]
	_base_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_base_mode_label.custom_minimum_size.x = 100
	ThemeManager.apply_text_glow(_base_mode_label, "header")
	mode_row.add_child(_base_mode_label)

	var next_mode := Button.new()
	next_mode.text = ">"
	next_mode.pressed.connect(func() -> void: _cycle_base_mode(1))
	ThemeManager.apply_button_style(next_mode)
	mode_row.add_child(next_mode)

	# Print button
	var print_btn := Button.new()
	print_btn.text = "PRINT VALUES"
	print_btn.pressed.connect(_print_values)
	ThemeManager.apply_button_style(print_btn)
	controls.add_child(print_btn)

	# Part selector row
	var part_row := HBoxContainer.new()
	part_row.add_theme_constant_override("separation", 8)
	main.add_child(part_row)

	var part_prefix := Label.new()
	part_prefix.text = "PART:"
	ThemeManager.apply_text_glow(part_prefix, "body")
	part_row.add_child(part_prefix)

	for i in PART_NAMES.size():
		var btn := Button.new()
		btn.text = PART_NAMES[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		var idx: int = i
		btn.pressed.connect(func() -> void: _select_part(idx))
		ThemeManager.apply_button_style(btn)
		part_row.add_child(btn)
		_part_btns.append(btn)

	# Current part info
	_part_label = Label.new()
	_part_label.text = "HULL"
	ThemeManager.apply_text_glow(_part_label, "body")
	part_row.add_child(_part_label)

	# Color preview
	_color_preview = ColorRect.new()
	_color_preview.custom_minimum_size = Vector2(40, 20)
	part_row.add_child(_color_preview)

	# Content area: sliders on left, viewport on right
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	main.add_child(content)

	# Sliders panel
	var sliders_panel := VBoxContainer.new()
	sliders_panel.custom_minimum_size.x = 300
	sliders_panel.add_theme_constant_override("separation", 12)
	content.add_child(sliders_panel)

	_hue_slider = _make_slider(sliders_panel, "HUE", 0.0, 1.0, _part_hues[0], _on_hue_changed)
	_sat_slider = _make_slider(sliders_panel, "SAT", 0.0, 1.0, _part_sats[0], _on_sat_changed)
	_val_slider = _make_slider(sliders_panel, "VAL", 0.0, 1.0, _part_vals[0], _on_val_changed)

	# All-parts color summary
	var summary_header := Label.new()
	summary_header.text = "ALL PARTS:"
	ThemeManager.apply_text_glow(summary_header, "body")
	sliders_panel.add_child(summary_header)

	for i in PART_NAMES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sliders_panel.add_child(row)
		var lbl := Label.new()
		lbl.text = PART_NAMES[i]
		lbl.custom_minimum_size.x = 70
		ThemeManager.apply_text_glow(lbl, "body")
		row.add_child(lbl)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(30, 16)
		swatch.color = Color.from_hsv(_part_hues[i], _part_sats[i], _part_vals[i])
		swatch.name = "Swatch_%d" % i
		row.add_child(swatch)

	# Viewport
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(vpc)

	_vp = SubViewport.new()
	_vp.transparent_bg = false
	_vp.size = _vp_size
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.use_hdr_2d = true
	vpc.add_child(_vp)
	VFXFactory.add_bloom_to_viewport(_vp)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp.add_child(bg)

	var stars := _StarBG.new()
	_vp.add_child(stars)

	# Build initial ship
	_rebuild_ship()
	_sync_sliders_to_part()


func _make_slider(parent: VBoxContainer, label_text: String, min_val: float, max_val: float, initial: float, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s: %.3f" % [label_text, initial]
	lbl.custom_minimum_size.x = 120
	ThemeManager.apply_text_glow(lbl, "body")
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.001
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 160
	slider.value_changed.connect(func(val: float) -> void:
		lbl.text = "%s: %.3f" % [label_text, val]
		callback.call(val)
		_update_swatches()
	)
	row.add_child(slider)

	return slider


func _update_swatches() -> void:
	# Update the summary swatches
	for i in PART_NAMES.size():
		var swatch_path: String = "Swatch_%d" % i
		var swatch: ColorRect = find_child(swatch_path, true, false) as ColorRect
		if swatch:
			swatch.color = Color.from_hsv(_part_hues[i], _part_sats[i], _part_vals[i])


class _StarBG extends Node2D:
	var _stars: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in range(60):
			_stars.append({
				"pos": Vector2(rng.randf() * 1920.0, rng.randf() * 1080.0),
				"size": rng.randf_range(0.4, 1.4),
				"bright": rng.randf_range(0.15, 0.5),
				"speed": rng.randf_range(0.3, 1.0),
			})

	func _process(delta: float) -> void:
		for s in _stars:
			(s["pos"] as Vector2).y += float(s["speed"]) * 80.0 * delta
			if (s["pos"] as Vector2).y > 1080.0:
				s["pos"] = Vector2(randf() * 1920.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		for s in _stars:
			var b: float = float(s["bright"])
			draw_circle(s["pos"] as Vector2, float(s["size"]),
				Color(b, b, b * 1.2, 0.7))
