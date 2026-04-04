class_name ComponentIconPopup
extends PopupPanel
## Modal icon grid picker for selecting weapons, power cores, or field emitters.
## Shows 64px icon cells in a grid with names. Weapons get PLAYER/ENEMY tabs.

signal item_selected(id: String)

const CELL_SIZE: int = 64
const CELL_WIDTH: int = 100  # wider than icon to give names room
const CELL_PAD: int = 12
const NAME_HEIGHT: int = 28  # room for 2 lines
const ITEM_TOTAL_H: int = CELL_SIZE + NAME_HEIGHT + CELL_PAD
const GRID_COLUMNS: int = 5
const POPUP_WIDTH: int = (CELL_WIDTH + CELL_PAD) * GRID_COLUMNS + 40
const MAX_POPUP_HEIGHT: int = 550

const NAME_COLOR := Color(0.7, 0.85, 1.0)
const LABEL_COLOR := Color(0.5, 0.5, 0.6)

var _content: VBoxContainer
var _tab_bar: TabBar
var _scroll: ScrollContainer
var _grid: GridContainer

# Cached data for tab switching (weapons only)
var _player_weapons: Array[WeaponData] = []
var _enemy_weapons: Array[WeaponData] = []


func _init() -> void:
	# Style the popup panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.96)
	style.border_color = ThemeManager.get_color("accent")
	style.border_width_bottom = 1
	style.border_width_top = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	add_child(_content)

	# Tab bar (hidden by default, shown for weapons)
	_tab_bar = TabBar.new()
	_tab_bar.visible = false
	_tab_bar.tab_changed.connect(_on_tab_changed)
	_content.add_child(_tab_bar)

	# Scroll + grid
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", CELL_PAD)
	_grid.add_theme_constant_override("v_separation", CELL_PAD)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)


# ── Public API ──────────────────────────────────────────────────────

func setup_weapons(weapons: Array[WeaponData]) -> void:
	_player_weapons.clear()
	_enemy_weapons.clear()

	for w in weapons:
		if w.id.begins_with("enemy_"):
			_enemy_weapons.append(w)
		else:
			_player_weapons.append(w)

	if not _enemy_weapons.is_empty() and not _player_weapons.is_empty():
		_tab_bar.clear_tabs()
		_tab_bar.add_tab("PLAYER")
		_tab_bar.add_tab("ENEMY")
		_tab_bar.current_tab = 0
		_tab_bar.visible = true
	else:
		_tab_bar.visible = false

	_rebuild_weapon_grid(0)


func setup_power_cores(cores: Array[PowerCoreData]) -> void:
	_tab_bar.visible = false
	_clear_grid()

	for core in cores:
		_add_grid_item(core.id, core.display_name, func(cell: Control) -> void:
			ComponentIconBuilder.add_power_core_icon(cell, core))


func setup_field_emitters(emitters: Array[DeviceData]) -> void:
	_tab_bar.visible = false
	_clear_grid()

	for emitter in emitters:
		_add_grid_item(emitter.id, emitter.display_name, func(cell: Control) -> void:
			ComponentIconBuilder.add_field_emitter_icon(cell, emitter))


func show_centered() -> void:
	# Calculate height from grid content
	var row_count: int = ceili(float(_grid.get_child_count()) / float(GRID_COLUMNS))
	var grid_h: int = row_count * ITEM_TOTAL_H + (row_count - 1) * CELL_PAD
	var total_h: int = mini(grid_h + 60, MAX_POPUP_HEIGHT)  # 60 for margins/tab
	if _tab_bar.visible:
		total_h = mini(total_h + 30, MAX_POPUP_HEIGHT)

	size = Vector2i(POPUP_WIDTH, total_h)
	popup_centered()


# ── Internal ────────────────────────────────────────────────────────

func _on_tab_changed(tab_idx: int) -> void:
	_rebuild_weapon_grid(tab_idx)


func _rebuild_weapon_grid(tab_idx: int) -> void:
	var weapons: Array[WeaponData] = _player_weapons if tab_idx == 0 else _enemy_weapons
	_clear_grid()

	for weapon in weapons:
		_add_grid_item(weapon.id, weapon.display_name, func(cell: Control) -> void:
			ComponentIconBuilder.add_weapon_icon(cell, weapon))


func _clear_grid() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()


func _add_grid_item(id: String, display_name: String, icon_builder: Callable) -> void:
	var item := VBoxContainer.new()
	item.custom_minimum_size.x = CELL_WIDTH
	item.add_theme_constant_override("separation", 2)

	# Clickable button wrapping the icon — centered within wider cell
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CELL_WIDTH, CELL_SIZE)
	btn.flat = true
	btn.clip_contents = true

	# Hover style
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(ThemeManager.get_color("accent"), 0.2)
	hover_style.corner_radius_top_left = 2
	hover_style.corner_radius_top_right = 2
	hover_style.corner_radius_bottom_left = 2
	hover_style.corner_radius_bottom_right = 2
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed style
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(ThemeManager.get_color("accent"), 0.35)
	pressed_style.corner_radius_top_left = 2
	pressed_style.corner_radius_top_right = 2
	pressed_style.corner_radius_bottom_left = 2
	pressed_style.corner_radius_bottom_right = 2
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# Empty normal style so it's transparent by default
	var normal_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.pressed.connect(_on_item_pressed.bind(id))
	item.add_child(btn)

	# Build icon cell inside the button — centered horizontally
	var cell: Control = ComponentIconBuilder.make_icon_cell(CELL_SIZE)
	cell.position.x = float(CELL_WIDTH - CELL_SIZE) / 2.0
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_mouse_filter_recursive(cell, Control.MOUSE_FILTER_IGNORE)
	btn.add_child(cell)

	# Deferred icon building — viewport needs to be in tree first
	icon_builder.call_deferred(cell)

	# Name label — 2 lines, centered, wrapping
	var lbl := Label.new()
	lbl.text = display_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size = Vector2(CELL_WIDTH, NAME_HEIGHT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.max_lines_visible = 2
	lbl.add_theme_color_override("font_color", NAME_COLOR)
	lbl.add_theme_font_size_override("font_size", 10)
	item.add_child(lbl)

	_grid.add_child(item)


func _on_item_pressed(id: String) -> void:
	item_selected.emit(id)
	hide()


func _set_mouse_filter_recursive(node: Control, filter: Control.MouseFilter) -> void:
	node.mouse_filter = filter
	for child in node.get_children():
		if child is Control:
			_set_mouse_filter_recursive(child as Control, filter)
