extends MarginContainer
## Hardpoint Edit Screen — weapon selection for an external slot.
## Reads GameState._editing_slot_key (ext_0, ext_1, ext_2).

# UI refs
var _firing_preview: ShipFiringPreview
var _hp_title: Label
var _weapon_container: VBoxContainer
var _weapon_buttons: Array = []  # Array[Dictionary] {button, weapon_id}
var _back_btn: Button
var _select_label: Label
var _bg_rect: ColorRect = null
var _vhs_overlay: ColorRect = null

# State
var _slot_key: String = ""
var _hp_index: int = -1
var _ship: ShipData = null
var _weapon_ids: Array[String] = []
var _weapon_cache: Dictionary = {}
var _selected_weapon_id: String = ""


func _ready() -> void:
	_slot_key = GameState._editing_slot_key
	if _slot_key == "":
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return
	# Map slot key to hp_index: ext_0→0, ext_1→1, ext_2→2
	_hp_index = int(_slot_key.replace("ext_", ""))
	_cache_weapons()
	_build_ui()
	_load_data()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_apply_theme)
	call_deferred("_apply_theme")


func _cache_weapons() -> void:
	_weapon_ids = WeaponDataManager.list_ids()
	for wid in _weapon_ids:
		var w: WeaponData = WeaponDataManager.load_by_id(wid)
		if w:
			_weapon_cache[wid] = w


func _load_data() -> void:
	_ship = ShipRegistry.build_ship_data(GameState.current_ship_index)
	if not _ship:
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return

	# Title from slot key
	var slot_num: int = _hp_index + 1
	_hp_title.text = "EXTERNAL SLOT " + str(slot_num)

	# Setup firing preview with ship
	_firing_preview.set_ship(_ship)

	# Load existing config
	var slot_data: Dictionary = GameState.slot_config.get(_slot_key, {})
	_selected_weapon_id = str(slot_data.get("weapon_id", ""))

	# Build weapon list buttons
	_rebuild_weapon_list()

	# Apply weapon to preview
	if _selected_weapon_id != "":
		_apply_weapon(_selected_weapon_id)


# ── UI Construction ──────────────────────────────────────────

func _build_ui() -> void:
	# Grid background
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.show_behind_parent = true
	add_child(_bg_rect)
	move_child(_bg_rect, 0)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# TOP SECTION — firing preview left, weapon list right
	var top_hbox := HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(top_hbox)

	# Left — Ship firing preview in SubViewport
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.45
	top_hbox.add_child(preview_panel)

	var svpc := SubViewportContainer.new()
	svpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svpc.stretch = true
	preview_panel.add_child(svpc)

	var svp := SubViewport.new()
	svp.size = Vector2i(500, 600)
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svpc.add_child(svp)

	# Add bloom to preview viewport
	VFXFactory.add_bloom_to_viewport(svp)

	_firing_preview = ShipFiringPreview.new()
	svp.add_child(_firing_preview)

	# Right — weapon list + power
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.55
	top_hbox.add_child(right_vbox)

	_hp_title = Label.new()
	_hp_title.text = ""
	right_vbox.add_child(_hp_title)

	_select_label = Label.new()
	_select_label.text = "SELECT WEAPON"
	right_vbox.add_child(_select_label)

	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(weapon_scroll)

	_weapon_container = VBoxContainer.new()
	_weapon_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_scroll.add_child(_weapon_container)

	# Bottom — back button
	var bottom_hbox := HBoxContainer.new()
	root.add_child(bottom_hbox)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	_back_btn = Button.new()
	_back_btn.text = "BACK"
	_back_btn.pressed.connect(_on_back)
	bottom_hbox.add_child(_back_btn)


func _setup_vhs_overlay() -> void:
	var root_node: Node = get_parent() if get_parent() else self
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	root_node.add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _apply_theme() -> void:
	# Grid background
	if _bg_rect:
		ThemeManager.apply_grid_background(_bg_rect)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)

	var body_font: Font = ThemeManager.get_font("font_body")
	var header_font: Font = ThemeManager.get_font("font_header")

	# Title
	_hp_title.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_hp_title.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_title"))
	if header_font:
		_hp_title.add_theme_font_override("font", header_font)
	ThemeManager.apply_header_chrome(_hp_title)

	# Select label
	_select_label.add_theme_color_override("font_color", ThemeManager.get_color("dimmed"))
	_select_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	if body_font:
		_select_label.add_theme_font_override("font", body_font)

	# Back button
	ThemeManager.apply_button_style(_back_btn)

	# Weapon buttons
	for entry in _weapon_buttons:
		var btn: Button = entry["button"]
		ThemeManager.apply_button_style(btn)
	_update_weapon_highlights()


# ── Weapon List ──────────────────────────────────────────────

func _rebuild_weapon_list() -> void:
	for child in _weapon_container.get_children():
		child.queue_free()
	_weapon_buttons.clear()

	# "(none)" button
	var none_btn := Button.new()
	none_btn.text = "(none)"
	none_btn.custom_minimum_size.y = 45
	none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	ThemeManager.apply_button_style(none_btn)
	none_btn.pressed.connect(func() -> void:
		_on_weapon_button_pressed("")
	)
	_weapon_container.add_child(none_btn)
	_weapon_buttons.append({"button": none_btn, "id": ""})

	for wid in _weapon_ids:
		var w: WeaponData = _weapon_cache.get(wid)
		if not w:
			continue
		var btn := Button.new()
		var display: String = w.display_name if w.display_name != "" else w.id
		btn.text = display
		btn.custom_minimum_size.y = 45
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_button_style(btn)
		var bound_id: String = wid
		btn.pressed.connect(func() -> void:
			_on_weapon_button_pressed(bound_id)
		)
		_weapon_container.add_child(btn)
		_weapon_buttons.append({"button": btn, "id": wid})

	_update_weapon_highlights()


func _on_weapon_button_pressed(weapon_id: String) -> void:
	_selected_weapon_id = weapon_id
	GameState.set_slot_weapon(_slot_key, weapon_id)
	if weapon_id != "":
		_apply_weapon(weapon_id)
	_update_weapon_highlights()


func _apply_weapon(wid: String) -> void:
	var w: WeaponData = _weapon_cache.get(wid)
	if w:
		_firing_preview.set_weapon(w, _hp_index)


func _update_weapon_highlights() -> void:
	for entry in _weapon_buttons:
		var btn: Button = entry["button"]
		var wid: String = str(entry["id"])
		if wid == _selected_weapon_id:
			btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		else:
			btn.remove_theme_color_override("font_color")


# ── Navigation ───────────────────────────────────────────────

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
