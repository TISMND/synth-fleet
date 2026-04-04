extends MarginContainer
## Skin editor — create, edit, save, and delete ship color skins.

var _time: float = 0.0
var _ship_pos := Vector2(960.0, 540.0)
var _ship_vel := Vector2.ZERO
var _bank: float = 0.0
var _ship_renderer: ShipRenderer = null
var _exhaust: EngineExhaust = null
var _vp: SubViewport = null
var _vp_size := Vector2i(1920, 1080)

# Ship selector
var _ship_index: int = 0
var _ship_label: Label = null
const SHIP_LIST: Array[Array] = [
	["STILETTO", 4],
	["CARGO SHIP", 7],
]

# Skin data
var _skins: Array[Dictionary] = []
var _skin_index: int = 0
var _skin_label: Label = null
var _dirty: bool = false

# Color pickers
var _hull_picker: ColorPickerButton = null
var _structure_picker: ColorPickerButton = null
var _trim_picker: ColorPickerButton = null
var _canopy_picker: ColorPickerButton = null

# Buttons
var _save_btn: Button = null
var _delete_btn: Button = null
var _name_edit: LineEdit = null

const SHIP_SPEED: float = 400.0
const SHIP_ACCEL: float = 1200.0
const SHIP_DECEL: float = 800.0
const SKINS_DIR: String = "res://data/skins/"


func _ready() -> void:
	_load_all_skins()
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0

	if input_dir.length() > 0.0:
		input_dir = input_dir.normalized()
		_ship_vel = _ship_vel.move_toward(input_dir * SHIP_SPEED, SHIP_ACCEL * delta)
	else:
		_ship_vel = _ship_vel.move_toward(Vector2.ZERO, SHIP_DECEL * delta)

	_ship_pos += _ship_vel * delta
	_ship_pos.x = clampf(_ship_pos.x, 80.0, float(_vp_size.x) - 80.0)
	_ship_pos.y = clampf(_ship_pos.y, 80.0, float(_vp_size.y) - 80.0)

	var target_bank: float = clampf(-_ship_vel.x / maxf(SHIP_SPEED, 1.0), -1.0, 1.0)
	_bank = lerpf(_bank, target_bank, minf(delta * 8.0, 1.0))

	if _ship_renderer:
		_ship_renderer.position = _ship_pos
		_ship_renderer.bank = _bank
	if _exhaust:
		_exhaust.position = _ship_pos
		_exhaust.update_thrust(_ship_vel.y, _bank, delta)


func _input(event: InputEvent) -> void:
	if _name_edit and _name_edit.has_focus():
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_Q or ke.keycode == KEY_COMMA:
			_cycle_skin(-1)
		elif ke.keycode == KEY_E or ke.keycode == KEY_PERIOD:
			_cycle_skin(1)
		elif ke.keycode == KEY_1:
			_cycle_ship(-1)
		elif ke.keycode == KEY_2:
			_cycle_ship(1)


# ── Skin I/O ────────────────────────────────────────────────────────

func _load_all_skins() -> void:
	_skins.clear()
	var dir := DirAccess.open(SKINS_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var path: String = SKINS_DIR + fname
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data: Dictionary = json.data as Dictionary
					_skins.append(data)
				file.close()
		fname = dir.get_next()
	dir.list_dir_end()
	_skins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.get("name", "") as String) < (b.get("name", "") as String))


func _save_current_skin() -> void:
	if _skins.is_empty():
		return
	var skin: Dictionary = _skins[_skin_index]
	var path: String = SKINS_DIR + (skin["id"] as String) + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(skin, "\t"))
		file.close()
	_dirty = false
	_update_save_btn()


func _delete_current_skin() -> void:
	if _skins.is_empty():
		return
	var skin: Dictionary = _skins[_skin_index]
	var path: String = SKINS_DIR + (skin["id"] as String) + ".json"
	DirAccess.remove_absolute(path)
	_skins.remove_at(_skin_index)
	if _skins.is_empty():
		_create_new_skin()
		return
	_skin_index = mini(_skin_index, _skins.size() - 1)
	_apply_skin_to_ui()
	_apply_colors_to_renderer()


func _create_new_skin() -> void:
	var id: String = "skin_" + str(Time.get_unix_time_from_system()).replace(".", "_")
	var skin: Dictionary = {
		"id": id,
		"name": "New Skin",
		"hull": "#00e6ff",
		"structure": "#ff3399",
		"trim": "#00ffb3",
		"canopy": "#141a2e",
	}
	_skins.append(skin)
	_skin_index = _skins.size() - 1
	_save_current_skin()
	_apply_skin_to_ui()
	_apply_colors_to_renderer()


# ── Skin cycling ────────────────────────────────────────────────────

func _cycle_skin(dir: int) -> void:
	if _skins.is_empty():
		return
	_skin_index = (_skin_index + dir + _skins.size()) % _skins.size()
	_dirty = false
	_apply_skin_to_ui()
	_apply_colors_to_renderer()


func _apply_skin_to_ui() -> void:
	if _skins.is_empty():
		return
	var skin: Dictionary = _skins[_skin_index]
	if _skin_label:
		_skin_label.text = skin.get("name", "???") as String
	if _name_edit:
		_name_edit.text = skin.get("name", "") as String
	if _hull_picker:
		_hull_picker.color = Color.from_string(skin.get("hull", "#ffffff") as String, Color.WHITE)
	if _structure_picker:
		_structure_picker.color = Color.from_string(skin.get("structure", "#ffffff") as String, Color.WHITE)
	if _trim_picker:
		_trim_picker.color = Color.from_string(skin.get("trim", "#ffffff") as String, Color.WHITE)
	if _canopy_picker:
		_canopy_picker.color = Color.from_string(skin.get("canopy", "#ffffff") as String, Color.WHITE)
	_update_save_btn()


func _apply_colors_to_renderer() -> void:
	if not _ship_renderer or _skins.is_empty():
		return
	var skin: Dictionary = _skins[_skin_index]
	_ship_renderer.hull_color = Color.from_string(skin.get("hull", "#ffffff") as String, Color.WHITE)
	_ship_renderer.accent_color = Color.from_string(skin.get("structure", "#ffffff") as String, Color.WHITE)
	_ship_renderer.detail_color = Color.from_string(skin.get("trim", "#ffffff") as String, Color.WHITE)
	_ship_renderer.canopy_color = Color.from_string(skin.get("canopy", "#ffffff") as String, Color.WHITE)


func _update_save_btn() -> void:
	if _save_btn:
		_save_btn.disabled = not _dirty


# ── Color picker callbacks ──────────────────────────────────────────

func _on_color_changed(color: Color, key: String) -> void:
	if _skins.is_empty():
		return
	_skins[_skin_index][key] = "#" + color.to_html(false)
	_dirty = true
	_update_save_btn()
	_apply_colors_to_renderer()


func _on_name_changed(new_name: String) -> void:
	if _skins.is_empty():
		return
	_skins[_skin_index]["name"] = new_name
	if _skin_label:
		_skin_label.text = new_name
	_dirty = true
	_update_save_btn()


# ── Ship cycling ────────────────────────────────────────────────────

func _cycle_ship(dir: int) -> void:
	_ship_index = (_ship_index + dir + SHIP_LIST.size()) % SHIP_LIST.size()
	var ship_id: int = SHIP_LIST[_ship_index][1]
	if _ship_label:
		_ship_label.text = SHIP_LIST[_ship_index][0] as String
	if _vp and _ship_renderer:
		_ship_renderer.queue_free()
		_ship_renderer = ShipRenderer.new()
		_ship_renderer.ship_id = ship_id
		_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
		_ship_renderer.use_custom_palette = true
		_ship_renderer.position = _ship_pos
		_ship_renderer.bank = _bank
		_ship_renderer.z_index = 1
		_vp.add_child(_ship_renderer)
		_apply_colors_to_renderer()
	if _vp and _exhaust:
		_exhaust.queue_free()
		_exhaust = EngineExhaust.new()
		var offsets: Array[Vector2] = ShipRenderer.get_engine_offsets(ship_id)
		var sc: float = ShipRenderer.get_ship_scale(ship_id)
		_exhaust.setup(offsets, sc)
		_exhaust.scroll_speed = 80.0
		_exhaust.position = _ship_pos
		_vp.add_child(_exhaust)
		_vp.move_child(_exhaust, _vp.get_child_count() - 2)


# ── UI construction ─────────────────────────────────────────────────

func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "SKIN EDITOR — WASD move, Q/E skins, 1/2 ship"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	# Controls row: ship selector, skin selector, color pickers, actions
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 24)
	main.add_child(controls)

	_build_ship_selector(controls)
	_build_skin_selector(controls)
	_build_color_pickers(controls)
	_build_action_buttons(controls)

	# Viewport
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(vpc)

	_vp = SubViewport.new()
	var vp: SubViewport = _vp
	vp.transparent_bg = false
	vp.size = _vp_size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var stars := _StarBG.new()
	vp.add_child(stars)

	var initial_ship_id: int = SHIP_LIST[_ship_index][1]
	_exhaust = EngineExhaust.new()
	var offsets: Array[Vector2] = ShipRenderer.get_engine_offsets(initial_ship_id)
	var sc: float = ShipRenderer.get_ship_scale(initial_ship_id)
	_exhaust.setup(offsets, sc)
	_exhaust.scroll_speed = 80.0
	vp.add_child(_exhaust)

	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = initial_ship_id
	_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	_ship_renderer.use_custom_palette = true
	_ship_renderer.z_index = 1
	vp.add_child(_ship_renderer)

	# Apply initial skin
	if not _skins.is_empty():
		_apply_skin_to_ui()
		_apply_colors_to_renderer()


func _build_ship_selector(parent: HBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)

	var lbl := Label.new()
	lbl.text = "SHIP:"
	ThemeManager.apply_text_glow(lbl, "body")
	box.add_child(lbl)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(func(): _cycle_ship(-1))
	ThemeManager.apply_button_style(prev_btn)
	box.add_child(prev_btn)

	_ship_label = Label.new()
	_ship_label.text = SHIP_LIST[_ship_index][0] as String
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_label.custom_minimum_size.x = 120
	ThemeManager.apply_text_glow(_ship_label, "header")
	box.add_child(_ship_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(func(): _cycle_ship(1))
	ThemeManager.apply_button_style(next_btn)
	box.add_child(next_btn)


func _build_skin_selector(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	box.add_child(nav)

	var lbl := Label.new()
	lbl.text = "SKIN:"
	ThemeManager.apply_text_glow(lbl, "body")
	nav.add_child(lbl)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.pressed.connect(func(): _cycle_skin(-1))
	ThemeManager.apply_button_style(prev_btn)
	nav.add_child(prev_btn)

	_skin_label = Label.new()
	_skin_label.text = _skins[_skin_index].get("name", "???") as String if not _skins.is_empty() else "---"
	_skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_label.custom_minimum_size.x = 140
	ThemeManager.apply_text_glow(_skin_label, "header")
	nav.add_child(_skin_label)

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.pressed.connect(func(): _cycle_skin(1))
	ThemeManager.apply_button_style(next_btn)
	nav.add_child(next_btn)

	# Name edit
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	box.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = "NAME:"
	ThemeManager.apply_text_glow(name_lbl, "body")
	name_row.add_child(name_lbl)

	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 140
	_name_edit.text = _skins[_skin_index].get("name", "") as String if not _skins.is_empty() else ""
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)


func _build_color_pickers(parent: HBoxContainer) -> void:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	parent.add_child(box)

	_hull_picker = _add_color_picker(box, "HULL", "hull")
	_structure_picker = _add_color_picker(box, "STRUCTURE", "structure")
	_trim_picker = _add_color_picker(box, "TRIM", "trim")
	_canopy_picker = _add_color_picker(box, "CANOPY", "canopy")


func _add_color_picker(parent: Control, label_text: String, key: String) -> ColorPickerButton:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	parent.add_child(col)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_text_glow(lbl, "body")
	col.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(50, 30)
	picker.color = Color.WHITE
	picker.edit_alpha = false
	picker.color_changed.connect(func(c: Color): _on_color_changed(c, key))
	col.add_child(picker)

	return picker


func _build_action_buttons(parent: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.pressed.connect(_create_new_skin)
	ThemeManager.apply_button_style(new_btn)
	box.add_child(new_btn)

	_save_btn = Button.new()
	_save_btn.text = "SAVE"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_save_current_skin)
	ThemeManager.apply_button_style(_save_btn)
	box.add_child(_save_btn)

	_delete_btn = Button.new()
	_delete_btn.text = "DELETE"
	_delete_btn.pressed.connect(_delete_current_skin)
	ThemeManager.apply_button_style(_delete_btn)
	box.add_child(_delete_btn)


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
