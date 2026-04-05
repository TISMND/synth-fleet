extends Control
## Hangar Bay screen — top-down blueprint view of the player's ships on the left,
## tabbed upgrade interface (Subsystems / Augments / Vanity) on the right.

var _vhs_overlay: ColorRect

# ── Hangar (direct full-screen drawing, no SubViewport) ──
var _hangar_drawing: Control
var _ship_renderers: Array[ShipRenderer] = []
var _player_ship_renderer: ShipRenderer
var _header_ship_renderer: ShipRenderer
var _header_preview_area: Control
var _plus_overlay: Control
var _plus_pulse_time: float = 0.0
var _name_edit: LineEdit
var _class_label: Label

# ── Bay state ──
var _bay_ship_ids: Array[int] = []  # ship_id per player bay (-1 = empty)
var _selected_bay: int = 0
var _hovered_bay: int = -1
var _bay_buttons: Array[Button] = []
const PLUS_BAY_INDEX: int = 2

# ── Layout constants ──
const PLAYER_COLS: int = 4
const PLAYER_ROWS: int = 2
const SUPPORT_COLS: int = 4
const SPOT_W: float = 120.0
const SPOT_H: float = 140.0
const SUPPORT_SPOT_H: float = 210.0  # support bays are 1.5x taller
const SPACING_X: float = 200.0
const SPACING_Y: float = 180.0
const PLAYER_TOP: float = 160.0  # below the "YOUR SHIPS" header
const SUPPORT_GAP: float = 80.0  # extra gap between player and support rows
const RIGHT_PANEL_W: float = 540.0
const HANGAR_LEFT_MARGIN: float = 30.0
const HANGAR_RIGHT_GAP: float = 15.0  # gap between hangar area and right panel

# Colors: military grid pattern, blueprint colors
const FLOOR_COLOR := Color(0.01, 0.02, 0.06)
const LINE_COLOR := Color(0.2, 0.4, 0.8, 0.5)
const SPOT_FILL := Color(0.015, 0.03, 0.07, 0.4)
const ACCENT := Color(0.3, 0.6, 1.0)
const GRID_SPACING: float = 40.0
const DIVIDER_COLOR := Color(0.2, 0.4, 0.8, 0.25)
const ACTIVE_FILL := Color(0.18, 0.16, 0.04, 0.55)  # warm yellow-tinted fill for the active ship
const ACTIVE_BORDER := Color(1.0, 0.85, 0.15, 0.95)  # yellow
const PLUS_BRIGHT := Color(0.55, 0.85, 1.0, 1.0)  # bright blue for pulsing plus marker
const PUBLIC_PROFILE_COLOR := Color(0.55, 0.85, 1.0, 0.9)  # cyan-blue badge
const SELECTED_RING_COLOR := Color(0.9, 0.3, 0.7, 0.9)  # pink ring around the selected bay
const HOVER_BRIGHTEN: float = 1.5

# Ship class labels (by ship_id)
const SHIP_CLASSES: Array[String] = [
	"INTERCEPTOR", "STEALTH", "GUARDIAN", "ASSAULT", "ALL-ROUNDER",
	"MULTIROLE", "EXOTIC", "CAPITAL", "FORTRESS",
]

var _right_panel: MarginContainer

# ── Upgrade tabs ──
const TAB_NAMES := ["SUBSYSTEMS", "AUGMENTS", "VANITY"]

const AUGMENT_LAYOUT := [
	{"section": "WEAPONS", "color": Color(0.14, 0.89, 0.89), "slots": [
		{"key": "weapon_0", "label": "Weapon Slot 1", "augments": 2},
		{"key": "weapon_1", "label": "Weapon Slot 2", "augments": 1},
		{"key": "weapon_2", "label": "Weapon Slot 3", "augments": 1},
		{"key": "weapon_3", "label": "Weapon Slot 4", "augments": 1},
	]},
	{"section": "POWER CORES", "color": Color(0.9, 0.82, 0.23), "slots": [
		{"key": "core_0", "label": "Power Core 1", "augments": 2},
		{"key": "core_1", "label": "Power Core 2", "augments": 2},
	]},
	{"section": "FIELD EMITTERS", "color": Color(0.2, 0.8, 1.0), "slots": [
		{"key": "field_0", "label": "Field Emitter", "augments": 1},
	]},
]

const VANITY_CATEGORIES := [
	{"label": "SHIP SKIN", "id": "skin", "options": ["Default", "Chrome", "Void", "Hivemind", "Ember", "Frost", "Stealth", "Gunmetal"]},
	{"label": "ENGINE EXHAUST", "id": "exhaust", "options": ["Standard Blue", "Hot Pink", "Plasma Green", "Solar Gold", "Ghostly White"]},
	{"label": "WING TRAILS", "id": "trails", "options": ["None", "Cyan Streak", "Magenta Ribbon", "Rainbow Fade", "Ember Sparks"]},
	{"label": "CANOPY TINT", "id": "canopy", "options": ["Default Cyan", "Amber", "Crimson", "Ultraviolet", "Frosted"]},
]

const SKIN_RENDER_MODES := {
	"Default": 0, "Chrome": 1, "Void": 2, "Hivemind": 3,
	"Ember": 6, "Frost": 7, "Stealth": 11, "Gunmetal": 9,
}

var _tab_buttons: Array[Button] = []
var _tab_containers: Array[Control] = []
var _active_tab: int = 0

# Vanity state
var _vanity_selections: Dictionary = {}


func _ready() -> void:
	SynthwaveBgSetup.setup(self)
	_init_upgrade_state()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_build_layout()
	_switch_tab(0)


func _init_upgrade_state() -> void:
	for cat in VANITY_CATEGORIES:
		_vanity_selections[cat["id"]] = 0


func _process(delta: float) -> void:
	for r in _ship_renderers:
		r.time += delta
		r.queue_redraw()
	if _header_ship_renderer:
		_header_ship_renderer.time += delta
		_header_ship_renderer.queue_redraw()
	_plus_pulse_time += delta
	if _plus_overlay:
		_plus_overlay.queue_redraw()


func _build_layout() -> void:
	# Blueprint floor fills the whole screen
	var floor_rect := ColorRect.new()
	floor_rect.color = FLOOR_COLOR
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_rect)

	# Hangar markings (grid, spots, labels, divider) — drawn directly on self
	_hangar_drawing = Control.new()
	_hangar_drawing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hangar_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hangar_drawing)
	_hangar_drawing.draw.connect(_draw_hangar)

	# Place ships in bays
	_place_ships()

	# Right panel pinned to the right edge
	var right_panel := MarginContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_panel.offset_left = -RIGHT_PANEL_W
	right_panel.offset_top = 20
	right_panel.offset_right = -HANGAR_LEFT_MARGIN
	right_panel.offset_bottom = -20
	right_panel.add_theme_constant_override("margin_left", 15)
	right_panel.add_theme_constant_override("margin_right", 0)
	add_child(right_panel)
	_right_panel = right_panel
	_build_right_panel(right_panel)

	# Reposition ships/drawing when the window resizes
	resized.connect(_on_resized)
	call_deferred("_on_resized")


func _on_resized() -> void:
	_layout_ships()
	if _hangar_drawing:
		_hangar_drawing.queue_redraw()


func _ship_class_for(ship_id: int) -> String:
	if ship_id >= 0 and ship_id < SHIP_CLASSES.size():
		return SHIP_CLASSES[ship_id]
	return ""


func _ship_custom_name_for(ship_id: int) -> String:
	if ship_id < 0:
		return ""
	var key: String = str(ship_id)
	return str(GameState.custom_ship_names.get(key, ShipRegistry.get_ship_name(ship_id)))


func _on_ship_name_changed(new_text: String) -> void:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return
	GameState.custom_ship_names[str(sid)] = new_text
	GameState.save_game()


func _build_ship_header(parent: VBoxContainer) -> void:
	# Ship preview area — fixed-size Control so the Node2D ship renderer can be centered
	_header_preview_area = Control.new()
	_header_preview_area.custom_minimum_size = Vector2(0, 120)
	_header_preview_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_preview_area.clip_contents = true
	parent.add_child(_header_preview_area)

	var initial_sid: int = _selected_ship_id()
	_header_ship_renderer = ShipRenderer.new()
	_header_ship_renderer.ship_id = maxi(initial_sid, 0)
	_header_ship_renderer.render_mode = ShipRenderer.RenderMode.CHROME
	_header_ship_renderer.animate = true
	_header_preview_area.add_child(_header_ship_renderer)
	_header_preview_area.resized.connect(_layout_header_ship)
	call_deferred("_layout_header_ship")

	# Editable name
	_name_edit = LineEdit.new()
	_name_edit.text = _ship_custom_name_for(initial_sid)
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	_name_edit.text_changed.connect(_on_ship_name_changed)
	parent.add_child(_name_edit)

	# Class subtext
	_class_label = Label.new()
	_class_label.text = _ship_class_for(initial_sid)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.add_theme_font_size_override("font_size", 12)
	var acc: Color = ThemeManager.get_color("accent")
	_class_label.add_theme_color_override("font_color", Color(acc.r, acc.g, acc.b, 0.7))
	parent.add_child(_class_label)

	# Action buttons: Activate / Make Profile
	var btn_row := HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 8)
	parent.add_child(btn_row)

	var activate_btn := Button.new()
	activate_btn.text = "ACTIVATE SHIP"
	activate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activate_btn.custom_minimum_size.y = 34
	ThemeManager.apply_button_style(activate_btn)
	activate_btn.pressed.connect(_on_activate_pressed)
	btn_row.add_child(activate_btn)

	var profile_btn := Button.new()
	profile_btn.text = "MAKE PROFILE SHIP"
	profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	profile_btn.custom_minimum_size.y = 34
	ThemeManager.apply_button_style(profile_btn)
	profile_btn.pressed.connect(_on_make_profile_pressed)
	btn_row.add_child(profile_btn)


func _refresh_header_for_selection() -> void:
	var sid: int = _selected_ship_id()
	if _header_ship_renderer and sid >= 0:
		_header_ship_renderer.ship_id = sid
		_header_ship_renderer.queue_redraw()
	if _name_edit:
		_name_edit.text = _ship_custom_name_for(sid)
	if _class_label:
		_class_label.text = _ship_class_for(sid)


func _on_activate_pressed() -> void:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return
	GameState.current_ship_index = sid
	GameState.save_game()
	if _player_ship_renderer:
		_player_ship_renderer.ship_id = sid
		_player_ship_renderer.queue_redraw()
	if _hangar_drawing:
		_hangar_drawing.queue_redraw()


func _on_make_profile_pressed() -> void:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return
	GameState.profile_ship_index = sid
	GameState.save_game()
	if _hangar_drawing:
		_hangar_drawing.queue_redraw()


func _show_placeholder_popup(message: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = message
	dlg.title = "Placeholder"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func() -> void: dlg.queue_free())
	dlg.canceled.connect(func() -> void: dlg.queue_free())


func _layout_header_ship() -> void:
	if _header_ship_renderer and _header_preview_area:
		_header_ship_renderer.position = _header_preview_area.size * 0.5


func _build_right_panel(parent: MarginContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	parent.add_child(col)

	_build_ship_header(col)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_theme_constant_override("separation", 4)
	col.add_child(tab_bar)
	for i in range(TAB_NAMES.size()):
		var tb := Button.new()
		tb.text = TAB_NAMES[i]
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size.y = 36
		ThemeManager.apply_button_style(tb)
		tb.pressed.connect(_on_tab_pressed.bind(i))
		tab_bar.add_child(tb)
		_tab_buttons.append(tb)

	# Content stack — all tabs share the same rect, only one visible at a time
	var content_stack := Control.new()
	content_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_stack.clip_contents = true
	col.add_child(content_stack)

	_build_subsystems_tab(content_stack)
	_build_augments_tab(content_stack)
	_build_vanity_tab(content_stack)

	# Back button at bottom
	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.custom_minimum_size = Vector2(160, 40)
	ThemeManager.apply_button_style(back_btn)
	back_btn.pressed.connect(_on_back)
	col.add_child(back_btn)


# ── Tab switching ──

func _on_tab_pressed(index: int) -> void:
	_switch_tab(index)


func _switch_tab(index: int) -> void:
	_active_tab = index
	for i in range(_tab_containers.size()):
		_tab_containers[i].visible = (i == index)
	var accent: Color = ThemeManager.get_color("accent")
	for i in range(_tab_buttons.size()):
		if i == index:
			_tab_buttons[i].add_theme_color_override("font_color", accent)
		else:
			_tab_buttons[i].remove_theme_color_override("font_color")


# ── Subsystems tab (placeholder until upgrade system returns) ──

func _build_subsystems_tab(parent: Control) -> void:
	var container := MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("margin_top", 40)
	parent.add_child(container)
	_tab_containers.append(container)

	var placeholder := Label.new()
	placeholder.text = "Subsystem upgrades coming soon."
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 14)
	placeholder.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	container.add_child(placeholder)


# ── Augments tab ──

func _build_augments_tab(parent: Control) -> void:
	var container := MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.visible = false
	parent.add_child(container)
	_tab_containers.append(container)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	for section in AUGMENT_LAYOUT:
		var sec_color: Color = section["color"]
		var slots: Array = section["slots"]

		var header_panel := PanelContainer.new()
		header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hsb := StyleBoxFlat.new()
		hsb.bg_color = Color(sec_color.r, sec_color.g, sec_color.b, 0.12)
		hsb.border_color = Color(sec_color.r, sec_color.g, sec_color.b, 0.35)
		hsb.border_width_bottom = 2
		hsb.set_content_margin_all(6)
		hsb.content_margin_left = 10
		hsb.content_margin_right = 10
		header_panel.add_theme_stylebox_override("panel", hsb)
		vbox.add_child(header_panel)

		var header_label := Label.new()
		header_label.text = section["section"]
		header_label.add_theme_font_size_override("font_size", 15)
		header_label.add_theme_color_override("font_color", sec_color)
		header_panel.add_child(header_label)

		for slot_info in slots:
			var slot_label_text: String = slot_info["label"]
			var augment_count: int = slot_info["augments"]

			var slot_panel := PanelContainer.new()
			slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ssb := StyleBoxFlat.new()
			ssb.bg_color = Color(0.0, 0.0, 0.0, 0.65)
			ssb.set_corner_radius_all(4)
			ssb.content_margin_left = 10
			ssb.content_margin_right = 10
			ssb.content_margin_top = 6
			ssb.content_margin_bottom = 6
			slot_panel.add_theme_stylebox_override("panel", ssb)
			vbox.add_child(slot_panel)

			var slot_vbox := VBoxContainer.new()
			slot_vbox.add_theme_constant_override("separation", 6)
			slot_panel.add_child(slot_vbox)

			var comp_label := Label.new()
			comp_label.text = slot_label_text
			comp_label.add_theme_font_size_override("font_size", 12)
			comp_label.add_theme_color_override("font_color", Color(sec_color.r, sec_color.g, sec_color.b, 0.7))
			slot_vbox.add_child(comp_label)

			for aug_i in range(augment_count):
				var aug_row := HBoxContainer.new()
				aug_row.add_theme_constant_override("separation", 8)
				slot_vbox.add_child(aug_row)

				var pip := ColorRect.new()
				pip.custom_minimum_size = Vector2(6, 32)
				pip.color = Color(sec_color.r, sec_color.g, sec_color.b, 0.3)
				aug_row.add_child(pip)

				var aug_btn := Button.new()
				aug_btn.text = "empty"
				aug_btn.custom_minimum_size.y = 32
				aug_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				aug_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
				aug_btn.add_theme_color_override("font_color", Color(sec_color.r, sec_color.g, sec_color.b, 0.4))
				aug_btn.add_theme_color_override("font_hover_color", sec_color)
				aug_row.add_child(aug_btn)

		var spacer := Control.new()
		spacer.custom_minimum_size.y = 6
		vbox.add_child(spacer)


# ── Vanity tab ──

func _build_vanity_tab(parent: Control) -> void:
	var container := MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.visible = false
	parent.add_child(container)
	_tab_containers.append(container)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	for cat in VANITY_CATEGORIES:
		var cat_id: String = cat["id"]
		var options: Array = cat["options"]

		var header := Label.new()
		header.text = cat["label"]
		header.add_theme_font_size_override("font_size", 15)
		vbox.add_child(header)

		var sel_row := HBoxContainer.new()
		sel_row.add_theme_constant_override("separation", 12)
		sel_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(sel_row)

		var prev_btn := Button.new()
		prev_btn.text = "<"
		prev_btn.custom_minimum_size = Vector2(32, 32)
		ThemeManager.apply_button_style(prev_btn)
		prev_btn.pressed.connect(_on_vanity_change.bind(cat_id, -1))
		sel_row.add_child(prev_btn)

		var sel_label := Label.new()
		sel_label.text = str(options[0])
		sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sel_row.add_child(sel_label)

		var next_btn := Button.new()
		next_btn.text = ">"
		next_btn.custom_minimum_size = Vector2(32, 32)
		ThemeManager.apply_button_style(next_btn)
		next_btn.pressed.connect(_on_vanity_change.bind(cat_id, 1))
		sel_row.add_child(next_btn)

		var preview_row := HBoxContainer.new()
		preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_row.add_theme_constant_override("separation", 4)
		vbox.add_child(preview_row)
		for opt_i in range(options.size()):
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(20, 5)
			dot.color = ThemeManager.get_color("accent") if opt_i == 0 else Color(0.2, 0.2, 0.25, 0.5)
			preview_row.add_child(dot)

		sel_row.set_meta("sel_label", sel_label)
		sel_row.set_meta("preview_row", preview_row)
		sel_row.set_meta("cat_id", cat_id)
		sel_label.set_meta("options", options)

		var sep := HSeparator.new()
		vbox.add_child(sep)


# ── Subsystem logic ──

# ── Vanity logic ──

func _on_vanity_change(cat_id: String, delta: int) -> void:
	var cat_data: Dictionary = {}
	for cat in VANITY_CATEGORIES:
		if cat["id"] == cat_id:
			cat_data = cat
			break
	if cat_data.is_empty():
		return
	var options: Array = cat_data["options"]
	var current: int = _vanity_selections[cat_id]
	var new_idx: int = (current + delta + options.size()) % options.size()
	_vanity_selections[cat_id] = new_idx

	# Skin changes update the hangar ship on the left and the header preview
	if cat_id == "skin":
		var skin_name: String = str(options[new_idx])
		var mode: int = SKIN_RENDER_MODES.get(skin_name, 0)
		if _player_ship_renderer:
			_player_ship_renderer.render_mode = mode
			_player_ship_renderer.queue_redraw()
		if _header_ship_renderer:
			_header_ship_renderer.render_mode = mode
			_header_ship_renderer.queue_redraw()

	_update_vanity_display()


func _update_vanity_display() -> void:
	if _tab_containers.size() < 3:
		return
	var accent: Color = ThemeManager.get_color("accent")
	# Walk the vanity tab and update each category row
	var container: Control = _tab_containers[2]
	var scroll: ScrollContainer = container.get_child(0) as ScrollContainer
	var vbox: VBoxContainer = scroll.get_child(0) as VBoxContainer
	for child in vbox.get_children():
		if child is HBoxContainer and child.has_meta("cat_id"):
			var cat_id: String = child.get_meta("cat_id")
			var sel_label: Label = child.get_meta("sel_label")
			var preview_row: HBoxContainer = child.get_meta("preview_row")
			var options: Array = sel_label.get_meta("options")
			var idx: int = _vanity_selections.get(cat_id, 0)
			sel_label.text = str(options[idx])
			for dot_i in range(preview_row.get_child_count()):
				var dot: ColorRect = preview_row.get_child(dot_i)
				dot.color = accent if dot_i == idx else Color(0.2, 0.2, 0.25, 0.5)


# ── Spot positions ──

func _get_hangar_area_width() -> float:
	return maxf(size.x - RIGHT_PANEL_W - HANGAR_RIGHT_GAP, 400.0)


func _get_player_spots() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var total_w: float = (PLAYER_COLS - 1) * SPACING_X
	var start_x: float = HANGAR_LEFT_MARGIN + (_get_hangar_area_width() - HANGAR_LEFT_MARGIN - total_w) / 2.0
	for row in PLAYER_ROWS:
		for col_idx in PLAYER_COLS:
			positions.append(Vector2(
				start_x + col_idx * SPACING_X,
				PLAYER_TOP + row * SPACING_Y,
			))
	return positions


func _get_support_spots() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var total_w: float = (SUPPORT_COLS - 1) * SPACING_X
	var start_x: float = HANGAR_LEFT_MARGIN + (_get_hangar_area_width() - HANGAR_LEFT_MARGIN - total_w) / 2.0
	var support_top: float = PLAYER_TOP + PLAYER_ROWS * SPACING_Y + SUPPORT_GAP
	for col_idx in SUPPORT_COLS:
		positions.append(Vector2(
			start_x + col_idx * SPACING_X,
			support_top,
		))
	return positions


func _get_divider_y() -> float:
	var player_bottom: float = PLAYER_TOP + (PLAYER_ROWS - 1) * SPACING_Y + SPOT_H / 2.0
	var support_top: float = PLAYER_TOP + PLAYER_ROWS * SPACING_Y + SUPPORT_GAP - SUPPORT_SPOT_H / 2.0
	return (player_bottom + support_top) / 2.0


# ── Place ships ──

func _place_ships() -> void:
	# Populate bay → ship_id map. Bay 0 holds the player's current active ship,
	# bay 1 holds the Switchblade, remaining bays are empty (-1).
	_bay_ship_ids = [GameState.current_ship_index, 0, -1, -1, -1, -1, -1, -1]
	# Initial selection = the bay that holds the active ship
	_selected_bay = _find_bay_for_ship(GameState.current_ship_index)
	if _selected_bay < 0:
		_selected_bay = 0

	# Ship renderer for bay 0 — the current active ship
	var ship := ShipRenderer.new()
	ship.ship_id = _bay_ship_ids[0]
	ship.render_mode = ShipRenderer.RenderMode.CHROME
	ship.animate = true
	add_child(ship)
	_ship_renderers.append(ship)
	_player_ship_renderer = ship

	# Ship renderer for bay 1 — the Switchblade
	var switchblade := ShipRenderer.new()
	switchblade.ship_id = _bay_ship_ids[1]
	switchblade.render_mode = ShipRenderer.RenderMode.CHROME
	switchblade.animate = true
	add_child(switchblade)
	_ship_renderers.append(switchblade)

	# Click/hover areas for each player bay (8 total)
	for i in PLAYER_COLS * PLAYER_ROWS:
		_add_bay_button(i)

	# Plus marker on bay 03 (ship store) — pulses intensely
	_plus_overlay = Control.new()
	_plus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plus_overlay.draw.connect(_draw_plus_marker_pulsing)
	add_child(_plus_overlay)

	# Cargo ship placeholder in support bay 01
	var cargo_overlay := Control.new()
	cargo_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	cargo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cargo_overlay.draw.connect(func() -> void:
		var sup_spot: Vector2 = _get_support_spots()[0]
		_draw_cargo_placeholder(cargo_overlay, sup_spot)
	)
	add_child(cargo_overlay)


func _find_bay_for_ship(ship_id: int) -> int:
	for i in _bay_ship_ids.size():
		if _bay_ship_ids[i] == ship_id:
			return i
	return -1


func _add_bay_button(bay_index: int) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.size = Vector2(SPOT_W, SPOT_H)
	btn.set_meta("bay_index", bay_index)
	btn.pressed.connect(_on_bay_clicked.bind(bay_index))
	btn.mouse_entered.connect(_on_bay_hover_enter.bind(bay_index))
	btn.mouse_exited.connect(_on_bay_hover_exit.bind(bay_index))
	add_child(btn)
	_bay_buttons.append(btn)


func _on_bay_clicked(bay_index: int) -> void:
	if bay_index == PLUS_BAY_INDEX:
		_show_placeholder_popup("More ships coming soon")
		return
	if _bay_ship_ids[bay_index] < 0:
		return  # empty bay
	_selected_bay = bay_index
	_refresh_header_for_selection()
	if _hangar_drawing:
		_hangar_drawing.queue_redraw()


func _on_bay_hover_enter(bay_index: int) -> void:
	_hovered_bay = bay_index
	if _hangar_drawing:
		_hangar_drawing.queue_redraw()


func _on_bay_hover_exit(bay_index: int) -> void:
	if _hovered_bay == bay_index:
		_hovered_bay = -1
		if _hangar_drawing:
			_hangar_drawing.queue_redraw()


func _selected_ship_id() -> int:
	if _selected_bay >= 0 and _selected_bay < _bay_ship_ids.size():
		return _bay_ship_ids[_selected_bay]
	return -1


func _layout_ships() -> void:
	var player_spots: Array[Vector2] = _get_player_spots()
	if _ship_renderers.size() >= 2:
		_ship_renderers[0].position = player_spots[0]
		_ship_renderers[1].position = player_spots[1]
	# Position every bay click/hover button
	for btn in _bay_buttons:
		var bay_idx: int = btn.get_meta("bay_index")
		if bay_idx < player_spots.size():
			var c: Vector2 = player_spots[bay_idx]
			btn.position = Vector2(c.x - SPOT_W / 2.0, c.y - SPOT_H / 2.0)


# ── Hangar drawing ──

func _draw_hangar() -> void:
	var hangar_w: float = _get_hangar_area_width()
	var screen_h: float = size.y

	# Floor grid — only across the hangar area (leaves the right pane alone)
	var grid_col := Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.08)
	var x: float = 0.0
	while x < hangar_w:
		_hangar_drawing.draw_line(Vector2(x, 0), Vector2(x, screen_h), grid_col, 1.0)
		x += GRID_SPACING
	var y: float = 0.0
	while y < screen_h:
		_hangar_drawing.draw_line(Vector2(0, y), Vector2(hangar_w, y), grid_col, 1.0)
		y += GRID_SPACING

	var hfont: Font = ThemeManager.get_font("font_header")
	var bfont: Font = ThemeManager.get_font("font_body")

	# "YOUR SHIPS" label top-left
	if hfont:
		_hangar_drawing.draw_string(hfont, Vector2(20, 35), "YOUR SHIPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)

	# Player spots — draw with state flags
	var player_spots: Array[Vector2] = _get_player_spots()
	var active_bay: int = _find_bay_for_ship(GameState.current_ship_index)
	var profile_bay: int = _find_bay_for_ship(GameState.profile_ship_index)
	for i in player_spots.size():
		_draw_bay(
			player_spots[i], i + 1, SPOT_H,
			i == active_bay, i == _selected_bay, i == _hovered_bay,
		)

	# "PUBLIC PROFILE" badge under whichever bay holds the profile ship
	if hfont and profile_bay >= 0 and profile_bay < player_spots.size():
		var pp_center: Vector2 = player_spots[profile_bay]
		var badge_w: float = 120.0
		var badge_x: float = pp_center.x - badge_w / 2.0
		var badge_y: float = pp_center.y + SPOT_H / 2.0 + 18
		_hangar_drawing.draw_string(hfont, Vector2(badge_x, badge_y), "PUBLIC PROFILE", HORIZONTAL_ALIGNMENT_CENTER, badge_w, 11, PUBLIC_PROFILE_COLOR)

	# Divider line between player and support rows
	var div_y: float = _get_divider_y()
	_hangar_drawing.draw_line(Vector2(20, div_y), Vector2(hangar_w - 20, div_y), DIVIDER_COLOR, 1.0)

	# "SUPPORT" label
	if hfont:
		var support_label_y: float = div_y + 20
		_hangar_drawing.draw_string(hfont, Vector2(20, support_label_y), "SUPPORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6))

	# Support spots (taller than player spots)
	var support_spots: Array[Vector2] = _get_support_spots()
	for i in support_spots.size():
		_draw_bay(support_spots[i], i + 1 + player_spots.size(), SUPPORT_SPOT_H, false)


func _draw_bay(pos: Vector2, bay_num: int, spot_h: float, active: bool, selected: bool, hovered: bool) -> void:
	var rect := Rect2(pos.x - SPOT_W / 2, pos.y - spot_h / 2, SPOT_W, spot_h)

	# Fill and border — active bay gets a yellow look
	var fill_col: Color = ACTIVE_FILL if active else SPOT_FILL
	var border_col: Color = ACTIVE_BORDER if active else LINE_COLOR
	var border_w: float = 3.0 if active else 2.0
	if hovered:
		fill_col = _brighten(fill_col, HOVER_BRIGHTEN)
		border_col = _brighten(border_col, HOVER_BRIGHTEN)
		border_w += 1.0
	_hangar_drawing.draw_rect(rect, fill_col)
	_hangar_drawing.draw_rect(rect, border_col, false, border_w)

	# Dashed center line
	var dash_y: float = rect.position.y
	while dash_y < rect.end.y:
		var end_y: float = minf(dash_y + 8.0, rect.end.y)
		_hangar_drawing.draw_line(Vector2(pos.x, dash_y), Vector2(pos.x, end_y), Color(border_col.r, border_col.g, border_col.b, 0.2), 1.0)
		dash_y += 16.0

	# Selected ring — drawn just outside the bay
	if selected:
		var ring_rect := Rect2(rect.position.x - 4, rect.position.y - 4, rect.size.x + 8, rect.size.y + 8)
		_hangar_drawing.draw_rect(ring_rect, SELECTED_RING_COLOR, false, 2.0)

	# Bay number
	var font: Font = ThemeManager.get_font("font_header")
	if font:
		var num_col: Color = ACTIVE_BORDER if active else ACCENT
		if hovered:
			num_col = _brighten(num_col, HOVER_BRIGHTEN)
		_hangar_drawing.draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 16), "%02d" % bay_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, num_col)

	# ACTIVE label above the bay
	if active and font:
		var label_w: float = 70.0
		var label_x: float = pos.x - label_w / 2.0
		var label_y: float = rect.position.y - 10
		_hangar_drawing.draw_string(font, Vector2(label_x, label_y), "ACTIVE", HORIZONTAL_ALIGNMENT_CENTER, label_w, 13, ACTIVE_BORDER)


func _brighten(c: Color, factor: float) -> Color:
	return Color(minf(c.r * factor, 1.0), minf(c.g * factor, 1.0), minf(c.b * factor, 1.0), c.a)


func _draw_plus_marker_pulsing() -> void:
	var player_spots: Array[Vector2] = _get_player_spots()
	if player_spots.size() <= PLUS_BAY_INDEX:
		return
	var t: float = 0.5 + 0.5 * sin(_plus_pulse_time * 3.5)  # faster pulse
	var color: Color = ACCENT.lerp(PLUS_BRIGHT, t)
	# Intensify: brighten further when near peak, boost alpha of glow
	color = _brighten(color, 1.0 + 0.6 * t)
	_draw_plus_marker(_plus_overlay, player_spots[PLUS_BAY_INDEX], color, 1.0 + 0.15 * t)


func _draw_plus_marker(canvas: Control, pos: Vector2, accent: Color, scale_factor: float = 1.0) -> void:
	var half: float = 30.0 * scale_factor
	var blen: float = 10.0 * scale_factor
	var bcol := Color(accent.r, accent.g, accent.b, 0.9)
	var bw: float = 2.5 * scale_factor

	canvas.draw_line(Vector2(pos.x - half, pos.y - half), Vector2(pos.x - half + blen, pos.y - half), bcol, bw)
	canvas.draw_line(Vector2(pos.x - half, pos.y - half), Vector2(pos.x - half, pos.y - half + blen), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y - half), Vector2(pos.x + half - blen, pos.y - half), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y - half), Vector2(pos.x + half, pos.y - half + blen), bcol, bw)
	canvas.draw_line(Vector2(pos.x - half, pos.y + half), Vector2(pos.x - half + blen, pos.y + half), bcol, bw)
	canvas.draw_line(Vector2(pos.x - half, pos.y + half), Vector2(pos.x - half, pos.y + half - blen), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y + half), Vector2(pos.x + half - blen, pos.y + half), bcol, bw)
	canvas.draw_line(Vector2(pos.x + half, pos.y + half), Vector2(pos.x + half, pos.y + half - blen), bcol, bw)

	var plus_size: float = 14.0 * scale_factor
	var plus_w: float = 3.5 * scale_factor
	# Outer glow for intensity
	var glow := Color(accent.r, accent.g, accent.b, 0.35)
	canvas.draw_line(Vector2(pos.x - plus_size, pos.y), Vector2(pos.x + plus_size, pos.y), glow, plus_w + 4.0)
	canvas.draw_line(Vector2(pos.x, pos.y - plus_size), Vector2(pos.x, pos.y + plus_size), glow, plus_w + 4.0)
	# Core plus
	canvas.draw_line(Vector2(pos.x - plus_size, pos.y), Vector2(pos.x + plus_size, pos.y), accent, plus_w)
	canvas.draw_line(Vector2(pos.x, pos.y - plus_size), Vector2(pos.x, pos.y + plus_size), accent, plus_w)


func _draw_cargo_placeholder(canvas: Control, pos: Vector2) -> void:
	# Draw a simple cargo ship silhouette placeholder
	var col := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
	# Boxy hull outline
	var hw: float = 20.0
	var hh: float = 30.0
	canvas.draw_rect(Rect2(pos.x - hw, pos.y - hh, hw * 2, hh * 2), Color(col.r, col.g, col.b, 0.1))
	canvas.draw_rect(Rect2(pos.x - hw, pos.y - hh, hw * 2, hh * 2), col, false, 1.5)
	# Cargo bay lines
	canvas.draw_line(Vector2(pos.x - hw + 4, pos.y - 8), Vector2(pos.x + hw - 4, pos.y - 8), Color(col.r, col.g, col.b, 0.2), 1.0)
	canvas.draw_line(Vector2(pos.x - hw + 4, pos.y + 8), Vector2(pos.x + hw - 4, pos.y + 8), Color(col.r, col.g, col.b, 0.2), 1.0)
	# Label
	var font: Font = ThemeManager.get_font("font_body")
	if font:
		canvas.draw_string(font, Vector2(pos.x - 22, pos.y + hh + 16), "CARGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)


# ── Utility ──

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mission_prep_menu.tscn")


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
	_update_vanity_display()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
