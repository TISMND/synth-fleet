extends MarginContainer
## Hardpoint Edit Screen — weapon selection for a single hardpoint.
## Simplified for loop-based audio: no piano roll, no stages. Just pick a weapon.

# UI refs
var _firing_preview: ShipFiringPreview
var _power_budget_label: Label
var _power_bar: ProgressBar
var _hp_title: Label
var _weapon_container: VBoxContainer
var _weapon_buttons: Array = []  # Array[Dictionary] {button, weapon_id}
var _back_btn: Button
var _select_label: Label
var _bg_rect: ColorRect = null
var _vhs_overlay: ColorRect = null

# State
var _ship: ShipData = null
var _hp_id: String = ""
var _hp_index: int = -1
var _hp_data: Dictionary = {}
var _weapon_ids: Array[String] = []
var _weapon_cache: Dictionary = {}
var _selected_weapon_id: String = ""


func _ready() -> void:
	_hp_id = GameState._editing_hp_id
	if _hp_id == "":
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return
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
	_ship = ShipDataManager.load_by_id(GameState.current_ship_id)
	if not _ship:
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return

	# Find hardpoint index
	for i in _ship.hardpoints.size():
		if str(_ship.hardpoints[i].get("id", "")) == _hp_id:
			_hp_index = i
			_hp_data = _ship.hardpoints[i]
			break

	# Title
	var hp_label: String = str(_hp_data.get("label", _hp_id))
	var dir_deg: float = float(_hp_data.get("direction_deg", 0.0))
	_hp_title.text = hp_label + " (" + str(int(dir_deg)) + "°)"

	# Setup firing preview with ship
	_firing_preview.set_ship(_ship)

	# Load existing config
	var config: Dictionary = GameState.hardpoint_config.get(_hp_id, {})
	_selected_weapon_id = str(config.get("weapon_id", ""))

	# Build weapon list buttons
	_rebuild_weapon_list()

	# Apply weapon to preview
	if _selected_weapon_id != "":
		_apply_weapon(_selected_weapon_id)

	_update_power_budget()


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

	# Power budget
	_power_budget_label = Label.new()
	_power_budget_label.text = "POWER: 0 / 0"
	right_vbox.add_child(_power_budget_label)

	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size = Vector2(180, 16)
	_power_bar.max_value = 1
	_power_bar.value = 0
	_power_bar.show_percentage = false
	right_vbox.add_child(_power_bar)

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

	# Power label
	_power_budget_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	if body_font:
		_power_budget_label.add_theme_font_override("font", body_font)

	# Back button
	ThemeManager.apply_button_style(_back_btn)

	# Weapon buttons
	for entry in _weapon_buttons:
		var btn: Button = entry["button"]
		ThemeManager.apply_button_style(btn)
	_update_weapon_highlights()

	# LED bar on power
	_update_power_budget()


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
	if weapon_id == "":
		GameState.set_hardpoint_weapon(_hp_id, "")
	else:
		_apply_weapon(weapon_id)
		GameState.set_hardpoint_weapon(_hp_id, weapon_id)
	_update_weapon_highlights()
	_update_power_budget()


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


# ── Power Budget ─────────────────────────────────────────────

func _update_power_budget() -> void:
	var total_power: int = 0
	var max_power: int = 0

	if _ship:
		max_power = int(_ship.stats.get("generator_power", 10))

	# Add device bonuses to max_power
	for slot_key in GameState.device_config:
		var did: String = str(GameState.device_config[slot_key])
		if did == "":
			continue
		var dev: DeviceData = DeviceDataManager.load_by_id(did)
		if dev:
			max_power += int(dev.stats_modifiers.get("generator_power", 0))

	for hp_id in GameState.hardpoint_config:
		var config: Dictionary = GameState.hardpoint_config[hp_id]
		var weapon_id: String = str(config.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				total_power += w.power_cost

	_power_budget_label.text = "POWER: " + str(total_power) + " / " + str(max_power)

	if max_power > 0:
		_power_bar.max_value = max_power
		_power_bar.value = total_power
	else:
		_power_bar.max_value = 1
		_power_bar.value = 0

	var bar_color: Color
	if total_power > max_power:
		_power_budget_label.add_theme_color_override("font_color", ThemeManager.get_color("warning"))
		bar_color = ThemeManager.get_color("bar_negative")
	else:
		_power_budget_label.add_theme_color_override("font_color", ThemeManager.get_color("positive"))
		bar_color = ThemeManager.get_color("bar_positive")

	var ratio: float = float(total_power) / maxf(float(max_power), 1.0)
	ThemeManager.apply_led_bar(_power_bar, bar_color, ratio)


# ── Navigation ───────────────────────────────────────────────

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
