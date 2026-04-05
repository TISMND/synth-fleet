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
var _cargo_renderer: ShipRenderer
var _cargo_paint_overlay: Node2D
var _cargo_light_overlay: Node2D
var _name_edit: LineEdit
var _level_label: Label
var _class_label: Label
var _desc_label: Label

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
const PLAYER_TOP: float = 200.0  # below the back button row + "YOUR SHIPS" header
const SUPPORT_GAP: float = 80.0  # extra gap between player and support rows
const RIGHT_PANEL_W: float = 648.0  # 20% wider than original 540
const HANGAR_LEFT_MARGIN: float = 30.0
const HANGAR_RIGHT_GAP: float = 15.0  # gap between hangar area and right panel
const TOP_BAR_HEIGHT: float = 50.0  # space for the back button row at top

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
const TAB_NAMES := ["SUBSYSTEMS", "AUGMENTS", "CUSTOMIZE"]

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

const SKIN_RENDER_MODES := {
	"Default": 0, "Chrome": 1, "Void": 2, "Hivemind": 3,
	"Ember": 6, "Frost": 7, "Stealth": 11, "Gunmetal": 9,
}

var _tab_buttons: Array[Button] = []
var _tab_containers: Array[Control] = []
var _active_tab: int = 0

# Subsystem LED bar refs (keyed by stat name)
var _stat_bars: Dictionary = {}  # stat_key → {bar: ProgressBar, label: Label, plus_btn: Button}


func _ready() -> void:
	SynthwaveBgSetup.setup(self)
	_init_upgrade_state()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_build_layout()
	_switch_tab(0)


func _init_upgrade_state() -> void:
	pass  # Reserved for future upgrade state initialization


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

	# ← BACK button at top-left (screen-level, not inside the pane)
	var back_btn := Button.new()
	back_btn.text = "\u2190  BACK"
	back_btn.custom_minimum_size = Vector2(120, 40)
	back_btn.position = Vector2(HANGAR_LEFT_MARGIN, 12)
	ThemeManager.apply_button_style(back_btn)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	back_btn.add_theme_color_override("font_hover_color", ThemeManager.get_color("header"))
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	# Right panel pinned to the right edge with generous margins
	var right_panel := MarginContainer.new()
	right_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_panel.offset_left = -RIGHT_PANEL_W
	right_panel.offset_top = TOP_BAR_HEIGHT + 10
	right_panel.offset_right = -40
	right_panel.offset_bottom = -30
	right_panel.add_theme_constant_override("margin_left", 15)
	right_panel.add_theme_constant_override("margin_right", 10)
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


func _ship_description_for(ship_id: int) -> String:
	if ship_id < 0:
		return ""
	var ship_name: String = ShipRegistry.get_ship_name(ship_id).to_lower()
	var ship_data: ShipData = ShipDataManager.load_by_id(ship_name)
	if ship_data:
		return ship_data.description
	return ""


func _on_ship_name_changed(new_text: String) -> void:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return
	GameState.custom_ship_names[str(sid)] = new_text
	GameState.save_game()


func _build_ship_header(parent: VBoxContainer) -> void:
	var initial_sid: int = _selected_ship_id()
	var acc: Color = ThemeManager.get_color("accent")

	# Ship preview area
	_header_preview_area = Control.new()
	_header_preview_area.custom_minimum_size = Vector2(0, 120)
	_header_preview_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_preview_area.clip_contents = true
	parent.add_child(_header_preview_area)

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

	# Level
	_level_label = Label.new()
	_level_label.text = "Level 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_font_size_override("font_size", 13)
	_level_label.add_theme_color_override("font_color", Color(acc.r, acc.g, acc.b, 0.85))
	parent.add_child(_level_label)

	# Class
	_class_label = Label.new()
	_class_label.text = _ship_class_for(initial_sid)
	_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_class_label.add_theme_font_size_override("font_size", 12)
	_class_label.add_theme_color_override("font_color", Color(acc.r, acc.g, acc.b, 0.6))
	parent.add_child(_class_label)

	# Description
	_desc_label = Label.new()
	_desc_label.text = _ship_description_for(initial_sid)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 11)
	_desc_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	parent.add_child(_desc_label)


func _refresh_header_for_selection() -> void:
	var sid: int = _selected_ship_id()
	if _header_ship_renderer and sid >= 0:
		_header_ship_renderer.ship_id = sid
		_header_ship_renderer.queue_redraw()
	if _name_edit:
		_name_edit.text = _ship_custom_name_for(sid)
	if _level_label:
		_level_label.text = "Level 1"  # placeholder until leveling is wired
	if _class_label:
		_class_label.text = _ship_class_for(sid)
	if _desc_label:
		_desc_label.text = _ship_description_for(sid)
	_refresh_stat_bars()


func _on_activate_pressed() -> void:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return
	# Activation only moves the yellow ACTIVE marker — bay assignments are untouched.
	GameState.current_ship_index = sid
	GameState.save_game()
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
	col.add_theme_constant_override("separation", 10)
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

	# Action buttons at the bottom — these are final actions, separate from tabs
	var btn_row := HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 8)
	col.add_child(btn_row)

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


# ── Subsystems tab — LED stat bars ──

const STAT_BARS_CONFIG := [
	{"key": "shield_hp", "label": "SHIELDS", "color": Color(0.3, 0.6, 1.0)},
	{"key": "hull_hp", "label": "HULL", "color": Color(0.2, 0.9, 0.3)},
	{"key": "thermal_hp", "label": "THERMAL", "color": Color(1.0, 0.45, 0.1)},
	{"key": "electric_hp", "label": "ELECTRIC", "color": Color(0.85, 0.75, 0.2)},
]


func _build_subsystems_tab(parent: Control) -> void:
	var container := MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("margin_top", 16)
	parent.add_child(container)
	_tab_containers.append(container)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	container.add_child(vbox)

	for cfg in STAT_BARS_CONFIG:
		var stat_key: String = cfg["key"]
		var stat_label: String = cfg["label"]
		var stat_color: Color = cfg["color"]
		_build_stat_bar_row(vbox, stat_key, stat_label, stat_color)

	_refresh_stat_bars()


func _build_stat_bar_row(parent: VBoxContainer, stat_key: String, stat_label: String, bar_color: Color) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	# "+" upgrade button — hidden until leveling is wired
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(28, 28)
	plus_btn.visible = false
	ThemeManager.apply_button_style(plus_btn)
	row.add_child(plus_btn)

	# Label + value column
	var info_col := VBoxContainer.new()
	info_col.custom_minimum_size.x = 80
	info_col.add_theme_constant_override("separation", 2)
	row.add_child(info_col)

	var name_lbl := Label.new()
	name_lbl.text = stat_label
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", bar_color)
	info_col.add_child(name_lbl)

	var val_lbl := Label.new()
	val_lbl.text = "0"
	val_lbl.add_theme_font_size_override("font_size", 10)
	val_lbl.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	info_col.add_child(val_lbl)

	# LED bar
	var bar := ProgressBar.new()
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	bar.max_value = 200.0  # raw HP comparison range (not normalized)
	ThemeManager.apply_led_bar(bar, bar_color, 0.0)
	row.add_child(bar)

	_stat_bars[stat_key] = {"bar": bar, "label": val_lbl, "plus_btn": plus_btn, "color": bar_color}


func _refresh_stat_bars() -> void:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return
	var stats: Dictionary = {}
	if sid >= 0 and sid < ShipRegistry.SHIP_STATS.size():
		stats = ShipRegistry.SHIP_STATS[sid]
	for cfg in STAT_BARS_CONFIG:
		var stat_key: String = cfg["key"]
		if not _stat_bars.has(stat_key):
			continue
		var entry: Dictionary = _stat_bars[stat_key]
		var val: float = float(stats.get(stat_key, 0))
		var bar: ProgressBar = entry["bar"]
		var lbl: Label = entry["label"]
		var col: Color = entry["color"]
		bar.value = val
		lbl.text = str(int(val))
		ThemeManager.apply_led_bar(bar, col, val / bar.max_value)


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


# ── Customize tab (Skin / Paint / Lighting) ──

const SKIN_OPTIONS: Array[String] = [
	"Default", "Chrome", "Void", "Hivemind", "Ember", "Frost", "Stealth", "Gunmetal",
]

const PAINT_PATTERNS: Array[String] = [
	"(none)", "CENTER STRIPE", "WIDE BAND", "TRIPLE LINE", "NOSE CAP", "TAIL BAND",
	"THREE BANDS", "DIAG LEFT", "DIAG RIGHT", "CHEVRON", "WING CHECK", "WING TIPS",
	"WEDGE", "STARBURST", "FULL NOSE", "FULL BELLY", "FULL STERN", "TOP HALF",
	"BOTTOM HALF", "SLATS x6", "SLATS x10", "SLATS x16", "WIDE SLATS",
	"CENTER SPINE", "PORT/STARBOARD", "TRIPLE STRIPE", "CHECKERBOARD", "CROSS",
	"SIDE PANELS", "ARMOR PLATES",
]

const LIGHT_PATTERNS: Array[String] = [
	"(none)", "TWIN RACING", "DOUBLE CHEVRON", "STACKED V", "TIGHT CHEVRONS",
	"NAV LIGHTS", "WING TIPS", "RUNNING LIGHTS", "CORNER MARKS", "BRIDGE SPOTS",
	"DOCKING LIGHTS", "SIGNAL ARRAY", "DECK LINES", "HULL GLOW", "PORT WINDOWS",
	"CABIN LIGHTS", "WIDE RACING", "TRIPLE BAND", "QUAD STRIPES",
]

var _skin_label: Label
var _paint_pattern_label: Label
var _paint_color_btn: ColorPickerButton
var _light_pattern_label: Label
var _light_color_btn: ColorPickerButton


func _build_vanity_tab(parent: Control) -> void:
	var container := MarginContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.visible = false
	container.add_theme_constant_override("margin_top", 12)
	parent.add_child(container)
	_tab_containers.append(container)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	# ── SKIN ──
	_build_customize_section(vbox, "SHIP SKIN", "_skin_label", SKIN_OPTIONS[0],
		func() -> void: _show_picker_modal("SKIN", SKIN_OPTIONS, _get_current_skin_index(), _on_skin_picked))

	# ── PAINT ──
	var paint_section := VBoxContainer.new()
	paint_section.add_theme_constant_override("separation", 6)
	vbox.add_child(paint_section)

	var paint_header := Label.new()
	paint_header.text = "PAINT"
	paint_header.add_theme_font_size_override("font_size", 14)
	paint_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	paint_section.add_child(paint_header)

	_paint_color_btn = ColorPickerButton.new()
	_paint_color_btn.custom_minimum_size = Vector2(0, 28)
	_paint_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_paint_color_btn.color = Color(0.85, 0.08, 0.08, 0.92)
	_paint_color_btn.edit_alpha = false
	_paint_color_btn.disabled = true
	_paint_color_btn.tooltip_text = "Select a paint pattern first"
	_paint_color_btn.color_changed.connect(_on_paint_color_changed)
	paint_section.add_child(_paint_color_btn)

	_paint_pattern_label = Label.new()
	_paint_pattern_label.text = "(none)"
	_paint_pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint_pattern_label.add_theme_font_size_override("font_size", 12)
	_paint_pattern_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	paint_section.add_child(_paint_pattern_label)

	var paint_btn := Button.new()
	paint_btn.text = "CHANGE PATTERN"
	paint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_btn.custom_minimum_size.y = 30
	ThemeManager.apply_button_style(paint_btn)
	paint_btn.pressed.connect(func() -> void:
		_show_picker_modal("PAINT PATTERN", PAINT_PATTERNS, _get_current_paint_index(), _on_paint_pattern_picked))
	paint_section.add_child(paint_btn)

	# ── LIGHTING ──
	var light_section := VBoxContainer.new()
	light_section.add_theme_constant_override("separation", 6)
	vbox.add_child(light_section)

	var light_header := Label.new()
	light_header.text = "LIGHTING"
	light_header.add_theme_font_size_override("font_size", 14)
	light_header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	light_section.add_child(light_header)

	_light_color_btn = ColorPickerButton.new()
	_light_color_btn.custom_minimum_size = Vector2(0, 28)
	_light_color_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_light_color_btn.color = Color(1.0, 0.85, 0.12)
	_light_color_btn.edit_alpha = false
	_light_color_btn.disabled = true
	_light_color_btn.tooltip_text = "Select a light pattern first"
	_light_color_btn.color_changed.connect(_on_light_color_changed)
	light_section.add_child(_light_color_btn)

	_light_pattern_label = Label.new()
	_light_pattern_label.text = "(none)"
	_light_pattern_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_light_pattern_label.add_theme_font_size_override("font_size", 12)
	_light_pattern_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	light_section.add_child(_light_pattern_label)

	var light_btn := Button.new()
	light_btn.text = "CHANGE PATTERN"
	light_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	light_btn.custom_minimum_size.y = 30
	ThemeManager.apply_button_style(light_btn)
	light_btn.pressed.connect(func() -> void:
		_show_picker_modal("LIGHT PATTERN", LIGHT_PATTERNS, _get_current_light_index(), _on_light_pattern_picked))
	light_section.add_child(light_btn)


func _build_customize_section(parent: VBoxContainer, title: String, label_field: String,
	default_text: String, on_change: Callable) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)
	parent.add_child(section)

	var header := Label.new()
	header.text = title
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	section.add_child(header)

	var lbl := Label.new()
	lbl.text = default_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	section.add_child(lbl)
	set(label_field, lbl)

	var btn := Button.new()
	btn.text = "CHANGE"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 30
	ThemeManager.apply_button_style(btn)
	btn.pressed.connect(on_change)
	section.add_child(btn)


# ── Customize picker modal ──

var _picker_overlay: Control = null


func _show_picker_modal(title: String, options: Array, current_index: int, on_picked: Callable) -> void:
	if _picker_overlay:
		_picker_overlay.queue_free()

	# Semi-transparent fullscreen backdrop
	_picker_overlay = Control.new()
	_picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_picker_overlay)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.65)
	_picker_overlay.add_child(backdrop)

	# Centered panel
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(500, 350)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.08, 0.95)
	sb.border_color = ThemeManager.get_color("accent")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	_picker_overlay.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", ThemeManager.get_color("header"))
	col.add_child(title_lbl)

	# Ship preview
	var preview_area := Control.new()
	preview_area.custom_minimum_size = Vector2(0, 140)
	preview_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_area.clip_contents = true
	col.add_child(preview_area)

	var preview_ship := ShipRenderer.new()
	var sid: int = _selected_ship_id()
	preview_ship.ship_id = maxi(sid, 0)
	preview_ship.render_mode = ShipRenderer.RenderMode.CHROME
	preview_ship.animate = true
	preview_area.add_child(preview_ship)
	preview_area.resized.connect(func() -> void:
		preview_ship.position = preview_area.size * 0.5)
	preview_ship.call_deferred("set", "position", Vector2(250, 70))

	# Cycling row: [<] Label [>]
	var picker_index: Array[int] = [clampi(current_index, 0, options.size() - 1)]
	var sel_lbl := Label.new()
	sel_lbl.text = str(options[picker_index[0]])
	sel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sel_lbl.add_theme_font_size_override("font_size", 16)
	sel_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))

	var cycle_row := HBoxContainer.new()
	cycle_row.add_theme_constant_override("separation", 12)
	cycle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(cycle_row)

	var prev_btn := Button.new()
	prev_btn.text = "\u25C1"
	prev_btn.custom_minimum_size = Vector2(48, 36)
	ThemeManager.apply_button_style(prev_btn)
	cycle_row.add_child(prev_btn)

	cycle_row.add_child(sel_lbl)

	var next_btn := Button.new()
	next_btn.text = "\u25B7"
	next_btn.custom_minimum_size = Vector2(48, 36)
	ThemeManager.apply_button_style(next_btn)
	cycle_row.add_child(next_btn)

	# Dot indicators
	var dot_row := HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.add_theme_constant_override("separation", 3)
	col.add_child(dot_row)
	for i in options.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 4)
		dot.color = ThemeManager.get_color("accent") if i == picker_index[0] else Color(0.2, 0.2, 0.25, 0.5)
		dot_row.add_child(dot)

	# Apply live preview when cycling
	var update_preview := func(delta: int) -> void:
		picker_index[0] = (picker_index[0] + delta + options.size()) % options.size()
		sel_lbl.text = str(options[picker_index[0]])
		# Update dots
		for di in dot_row.get_child_count():
			var d: ColorRect = dot_row.get_child(di)
			d.color = ThemeManager.get_color("accent") if di == picker_index[0] else Color(0.2, 0.2, 0.25, 0.5)
		# Live skin preview on the modal ship
		if title == "SKIN":
			var mode: int = SKIN_RENDER_MODES.get(str(options[picker_index[0]]), 0)
			preview_ship.render_mode = mode
			preview_ship.queue_redraw()
	prev_btn.pressed.connect(func() -> void: update_preview.call(-1))
	next_btn.pressed.connect(func() -> void: update_preview.call(1))

	# Confirm / Cancel row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.custom_minimum_size = Vector2(140, 36)
	ThemeManager.apply_button_style(confirm_btn)
	confirm_btn.pressed.connect(func() -> void:
		on_picked.call(picker_index[0])
		_close_picker_modal())
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(140, 36)
	ThemeManager.apply_button_style(cancel_btn)
	cancel_btn.pressed.connect(_close_picker_modal)
	btn_row.add_child(cancel_btn)


func _close_picker_modal() -> void:
	if _picker_overlay and is_instance_valid(_picker_overlay):
		_picker_overlay.queue_free()
		_picker_overlay = null


# ── Customize callbacks ──

func _get_current_skin_index() -> int:
	var sid: int = _selected_ship_id()
	if sid < 0:
		return 0
	# Check which skin the header renderer is showing
	if _header_ship_renderer:
		for i in SKIN_OPTIONS.size():
			if SKIN_RENDER_MODES.get(SKIN_OPTIONS[i], 0) == _header_ship_renderer.render_mode:
				return i
	return 0


func _get_current_paint_index() -> int:
	return 0  # placeholder — not yet persisted per player ship


func _get_current_light_index() -> int:
	return 0


func _on_skin_picked(index: int) -> void:
	var skin_name: String = SKIN_OPTIONS[index]
	var mode: int = SKIN_RENDER_MODES.get(skin_name, 0)
	for r in _ship_renderers:
		if r.has_meta("bay_index") and int(r.get_meta("bay_index")) == _selected_bay:
			r.render_mode = mode
			r.queue_redraw()
			break
	if _header_ship_renderer:
		_header_ship_renderer.render_mode = mode
		_header_ship_renderer.queue_redraw()
	if _skin_label:
		_skin_label.text = skin_name


func _on_paint_pattern_picked(index: int) -> void:
	var pattern: String = PAINT_PATTERNS[index] if index > 0 else ""
	if _paint_pattern_label:
		_paint_pattern_label.text = PAINT_PATTERNS[index]
	if _paint_color_btn:
		_paint_color_btn.disabled = (pattern == "")
		_paint_color_btn.tooltip_text = "" if pattern != "" else "Select a paint pattern first"


func _on_paint_color_changed(_color: Color) -> void:
	pass  # Will wire to ShipData persistence later


func _on_light_pattern_picked(index: int) -> void:
	var pattern: String = LIGHT_PATTERNS[index] if index > 0 else ""
	if _light_pattern_label:
		_light_pattern_label.text = LIGHT_PATTERNS[index]
	if _light_color_btn:
		_light_color_btn.disabled = (pattern == "")
		_light_color_btn.tooltip_text = "" if pattern != "" else "Select a light pattern first"


func _on_light_color_changed(_color: Color) -> void:
	pass  # Will wire to ShipData persistence later


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
	# Bay layout is persisted in GameState — never recomputed from current_ship_index.
	_bay_ship_ids = GameState.bay_ship_ids.duplicate()
	# Initial selection = the bay that holds the active ship (if any)
	_selected_bay = _find_bay_for_ship(GameState.current_ship_index)
	if _selected_bay < 0:
		_selected_bay = 0

	# Spawn a ShipRenderer for every non-empty bay
	for i in _bay_ship_ids.size():
		var sid: int = _bay_ship_ids[i]
		if sid < 0:
			continue
		var ship := ShipRenderer.new()
		ship.ship_id = sid
		ship.render_mode = ShipRenderer.RenderMode.CHROME
		ship.animate = true
		ship.set_meta("bay_index", i)
		add_child(ship)
		_ship_renderers.append(ship)
		if i == 0:
			_player_ship_renderer = ship

	# Click/hover areas for each player bay (8 total)
	for i in PLAYER_COLS * PLAYER_ROWS:
		_add_bay_button(i)

	# Plus markers on empty ship-store bays — pulses softly
	_plus_overlay = Control.new()
	_plus_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plus_overlay.draw.connect(_draw_plus_marker_pulsing)
	add_child(_plus_overlay)

	# Real cargo ship in support bay A (loaded from data/ships/cargo_ship.json)
	_place_cargo_ship()


func _place_cargo_ship() -> void:
	var cargo: ShipData = ShipDataManager.load_by_id("cargo_ship")
	_cargo_renderer = ShipRenderer.new()
	_cargo_renderer.ship_id = -1
	_cargo_renderer.enemy_visual_id = cargo.visual_id if cargo else "dreadnought"
	_cargo_renderer.render_mode = NpcShip._render_mode_from_string(cargo.render_mode) if cargo else ShipRenderer.RenderMode.CHROME
	_cargo_renderer.animate = true
	if cargo:
		_cargo_renderer.neon_hdr = cargo.neon_hdr
		_cargo_renderer.neon_white = cargo.neon_white
		_cargo_renderer.neon_width = cargo.neon_width
	add_child(_cargo_renderer)
	_ship_renderers.append(_cargo_renderer)

	# Attach the same paint/light overlays used at runtime so this preview matches gameplay
	if cargo:
		var overlays: Array[Node2D] = ShipCosmetics.build_overlays(
			cargo.visual_id,
			cargo.paint_pattern, cargo.paint_color,
			cargo.light_pattern, cargo.light_color,
		)
		if overlays[0]:
			_cargo_paint_overlay = overlays[0]
			_cargo_paint_overlay.z_index = 2
			add_child(_cargo_paint_overlay)
		if overlays[1]:
			_cargo_light_overlay = overlays[1]
			_cargo_light_overlay.z_index = 3
			add_child(_cargo_light_overlay)


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
	for r in _ship_renderers:
		if not r.has_meta("bay_index"):
			continue
		var bay_idx: int = r.get_meta("bay_index")
		if bay_idx >= 0 and bay_idx < player_spots.size():
			r.position = player_spots[bay_idx]
	# Position every bay click/hover button
	for btn in _bay_buttons:
		var bay_idx2: int = btn.get_meta("bay_index")
		if bay_idx2 < player_spots.size():
			var c: Vector2 = player_spots[bay_idx2]
			btn.position = Vector2(c.x - SPOT_W / 2.0, c.y - SPOT_H / 2.0)
	# Cargo ship + its overlays ride along with support bay A
	var support_spots: Array[Vector2] = _get_support_spots()
	if _cargo_renderer and support_spots.size() > 0:
		_cargo_renderer.position = support_spots[0]
		if _cargo_paint_overlay:
			_cargo_paint_overlay.position = support_spots[0]
		if _cargo_light_overlay:
			_cargo_light_overlay.position = support_spots[0]


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

	# "YOUR SHIPS" label below the back button row
	if hfont:
		_hangar_drawing.draw_string(hfont, Vector2(20, TOP_BAR_HEIGHT + 30), "YOUR SHIPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ACCENT)

	# Player spots — draw with state flags
	var player_spots: Array[Vector2] = _get_player_spots()
	var active_bay: int = _find_bay_for_ship(GameState.current_ship_index)
	var profile_bay: int = _find_bay_for_ship(GameState.profile_ship_index)
	for i in player_spots.size():
		_draw_bay(
			player_spots[i], "%02d" % (i + 1), SPOT_H,
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
		var letter: String = char(65 + i)  # A, B, C, D
		_draw_bay(support_spots[i], letter, SUPPORT_SPOT_H, false, false, false)


func _draw_bay(pos: Vector2, bay_label: String, spot_h: float, active: bool, selected: bool, hovered: bool) -> void:
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
		_hangar_drawing.draw_string(font, Vector2(rect.position.x + 4, rect.position.y + 16), bay_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, num_col)

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
	var support_spots: Array[Vector2] = _get_support_spots()
	var t: float = 0.5 + 0.5 * sin(_plus_pulse_time * 3.5)
	var color: Color = ACCENT.lerp(PLUS_BRIGHT, t)
	# Strong color swing — brightness lifts with the pulse
	color = _brighten(color, 1.0 + 0.9 * t)
	if player_spots.size() > PLUS_BAY_INDEX:
		_draw_plus_marker(_plus_overlay, player_spots[PLUS_BAY_INDEX], color)
	if support_spots.size() > 1:
		_draw_plus_marker(_plus_overlay, support_spots[1], color)


func _draw_plus_marker(canvas: Control, pos: Vector2, accent: Color) -> void:
	var plus_size: float = 14.0
	var plus_w: float = 3.5
	# Outer glow — modulates color intensity rather than size
	var glow := Color(accent.r, accent.g, accent.b, 0.35)
	canvas.draw_line(Vector2(pos.x - plus_size, pos.y), Vector2(pos.x + plus_size, pos.y), glow, plus_w + 4.0)
	canvas.draw_line(Vector2(pos.x, pos.y - plus_size), Vector2(pos.x, pos.y + plus_size), glow, plus_w + 4.0)
	# Core plus
	canvas.draw_line(Vector2(pos.x - plus_size, pos.y), Vector2(pos.x + plus_size, pos.y), accent, plus_w)
	canvas.draw_line(Vector2(pos.x, pos.y - plus_size), Vector2(pos.x, pos.y + plus_size), accent, plus_w)


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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
