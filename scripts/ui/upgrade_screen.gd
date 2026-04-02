extends Control
## Ship Upgrade Screen — green wireframe diagram (left) with tabbed upgrade interface (right).
## Tabs: Subsystems (level upgrades), Augments (component slots), Vanity (cosmetics).

# ── Subsystems tab constants ──
const SUBSYSTEMS := ["WEAPONS", "ARMOR", "ENGINES", "POWER CORE"]
const MAX_LEVEL := 10
const BASE_COST := 500
const COST_SCALE := 1.4

# ── Layout ──
# Left side: ship wireframe in a green-framed box
const FRAME_RECT := Rect2(20, 40, 640, 700)
const SHIP_CENTER := Vector2(340, 390)

# Right side: tabbed content area
const RIGHT_X := 700
const RIGHT_Y := 40
const RIGHT_W := 1200
const RIGHT_H := 700
const TAB_HEIGHT := 40

# ── Augments tab slot definitions ──
const AUGMENT_SECTIONS := [
	{"label": "WEAPON MODS", "slots": ["wmod_0", "wmod_1", "wmod_2"], "color": Color(0.14, 0.89, 0.89)},
	{"label": "CORE CAPACITORS", "slots": ["cap_0", "cap_1"], "color": Color(0.9, 0.82, 0.23)},
	{"label": "SHIELD MATRIX", "slots": ["shield_0", "shield_1"], "color": Color(0.2, 0.8, 1.0)},
	{"label": "HULL REINFORCEMENT", "slots": ["hull_0"], "color": Color(0.5, 0.5, 0.5)},
]

# ── Vanity tab cosmetic categories ──
const VANITY_CATEGORIES := [
	{"label": "SHIP SKIN", "id": "skin", "options": ["Default", "Chrome", "Void", "Hivemind", "Ember", "Frost", "Stealth", "Gunmetal"]},
	{"label": "ENGINE EXHAUST", "id": "exhaust", "options": ["Standard Blue", "Hot Pink", "Plasma Green", "Solar Gold", "Ghostly White"]},
	{"label": "WING TRAILS", "id": "trails", "options": ["None", "Cyan Streak", "Magenta Ribbon", "Rainbow Fade", "Ember Sparks"]},
	{"label": "CANOPY TINT", "id": "canopy", "options": ["Default Cyan", "Amber", "Crimson", "Ultraviolet", "Frosted"]},
]

# HDR channels
var _hdr_ship: float = 1.8
var _hdr_ui: float = 1.6
var _hdr_arrows: float = 1.4

# Core nodes
var _vhs_overlay: ColorRect
var _bg_rect: ColorRect
var _wireframe: Node2D
var _back_button: Button
var _coord_label: Label

# Tab system
var _tab_buttons: Array[Button] = []
var _tab_containers: Array[Control] = []
var _active_tab: int = 0
const TAB_NAMES := ["SUBSYSTEMS", "AUGMENTS", "VANITY"]

# Subsystems tab state
var _subsystem_levels: Dictionary = {}
var _panel_nodes: Dictionary = {}
var _finance_panel: PanelContainer
var _bank_value_label: Label
var _cost_value_label: Label
var _confirm_button: Button
var _pending_costs: Dictionary = {}
var _original_levels: Dictionary = {}

# HDR sliders
var _hdr_sliders: Dictionary = {}
var _hdr_readouts: Dictionary = {}

# Vanity tab state
var _vanity_selections: Dictionary = {}  # {"skin": 0, "exhaust": 0, ...}


func _ready() -> void:
	_init_state()
	_build_ui()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme()
	_switch_tab(0)
	_update_subsystems_display()


func _init_state() -> void:
	for sub in SUBSYSTEMS:
		_subsystem_levels[sub] = 1
		_original_levels[sub] = 1
		_pending_costs[sub] = 0
	for cat in VANITY_CATEGORIES:
		_vanity_selections[cat["id"]] = 0


func _build_ui() -> void:
	# Black background
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color.BLACK
	add_child(_bg_rect)

	# Ship wireframe — left side
	_wireframe = Node2D.new()
	_wireframe.position = SHIP_CENTER
	_wireframe.set_script(preload("res://scripts/ui/upgrade_wireframe.gd"))
	add_child(_wireframe)
	_wireframe.hdr_ship = _hdr_ship
	_wireframe.hdr_arrows = _hdr_arrows
	_wireframe.frame_rect = FRAME_RECT
	_wireframe.ship_center = SHIP_CENTER

	# Tab bar
	_build_tab_bar()

	# Tab content containers (only one visible at a time)
	_build_subsystems_tab()
	_build_augments_tab()
	_build_vanity_tab()

	# HDR sliders — bottom left under the ship
	_build_hdr_sliders()

	# Back button
	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_back_button.offset_left = 20
	_back_button.offset_top = -50
	_back_button.offset_right = 140
	_back_button.offset_bottom = -14
	_back_button.pressed.connect(_on_back)
	add_child(_back_button)

	# Cursor coordinates
	_coord_label = Label.new()
	_coord_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_coord_label.offset_top = -26
	_coord_label.offset_bottom = -6
	_coord_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coord_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coord_label)


# ── Tab System ──────────────────────────────────────────────

func _build_tab_bar() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(RIGHT_X, RIGHT_Y)
	bar.custom_minimum_size = Vector2(RIGHT_W, TAB_HEIGHT)
	bar.add_theme_constant_override("separation", 4)
	add_child(bar)

	for i in range(TAB_NAMES.size()):
		var btn := Button.new()
		btn.text = TAB_NAMES[i]
		btn.custom_minimum_size = Vector2(160, TAB_HEIGHT)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		bar.add_child(btn)
		_tab_buttons.append(btn)


func _on_tab_pressed(index: int) -> void:
	_switch_tab(index)


func _switch_tab(index: int) -> void:
	_active_tab = index
	for i in range(_tab_containers.size()):
		_tab_containers[i].visible = (i == index)
	# Style active tab differently
	var accent: Color = ThemeManager.get_color("accent")
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		if i == index:
			btn.add_theme_color_override("font_color", accent)
		else:
			btn.remove_theme_color_override("font_color")


# ── Subsystems Tab ──────────────────────────────────────────

func _build_subsystems_tab() -> void:
	var container := Control.new()
	container.position = Vector2(RIGHT_X, RIGHT_Y + TAB_HEIGHT + 10)
	container.size = Vector2(RIGHT_W, RIGHT_H - TAB_HEIGHT - 10)
	add_child(container)
	_tab_containers.append(container)

	# Finance pane at top
	_build_finance_pane(container)

	# Subsystem panels below finance
	var panel_y := 200
	for i in range(SUBSYSTEMS.size()):
		var sub: String = SUBSYSTEMS[i]
		_build_subsystem_panel(container, sub, Vector2(0, panel_y + i * 130))

	# Confirm button
	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRM UPGRADES"
	_confirm_button.custom_minimum_size = Vector2(260, 36)
	_confirm_button.position = Vector2(0, panel_y + SUBSYSTEMS.size() * 130 + 10)
	_confirm_button.size = Vector2(260, 36)
	_confirm_button.pressed.connect(_on_confirm)
	container.add_child(_confirm_button)


func _build_finance_pane(parent: Control) -> void:
	_finance_panel = PanelContainer.new()
	_finance_panel.position = Vector2(0, 0)
	_finance_panel.custom_minimum_size = Vector2(500, 160)
	_finance_panel.size = Vector2(500, 160)

	var accent: Color = ThemeManager.get_color("accent")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	_finance_panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(_finance_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 60)
	_finance_panel.add_child(hbox)

	# Bank column
	var bank_col := _build_currency_column("FINANCES", "BANK", str(GameState.credits))
	hbox.add_child(bank_col)
	_bank_value_label = bank_col.get_meta("value_label")
	_finance_panel.set_meta("title_label", bank_col.get_meta("title_label"))

	# Cost column
	var cost_col := VBoxContainer.new()
	cost_col.add_theme_constant_override("separation", 4)
	hbox.add_child(cost_col)

	var cost_key := Label.new()
	cost_key.text = "UPGRADE COST"
	cost_key.add_theme_font_size_override("font_size", 12)
	cost_col.add_child(cost_key)
	cost_col.set_meta("key_label", cost_key)

	_cost_value_label = Label.new()
	_cost_value_label.text = "0"
	_cost_value_label.add_theme_font_size_override("font_size", 28)
	cost_col.add_child(_cost_value_label)


func _build_currency_column(title: String, key_text: String, value_text: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(title_lbl)
	col.set_meta("title_label", title_lbl)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	col.add_child(sep)

	var key_lbl := Label.new()
	key_lbl.text = key_text
	key_lbl.add_theme_font_size_override("font_size", 12)
	col.add_child(key_lbl)
	col.set_meta("key_label", key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value_text
	val_lbl.add_theme_font_size_override("font_size", 28)
	col.add_child(val_lbl)
	col.set_meta("value_label", val_lbl)

	return col


func _build_subsystem_panel(parent: Control, sub_name: String, pos: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(500, 110)
	panel.size = Vector2(500, 110)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.border_color = Color(0.5, 0.5, 0.5, 0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = sub_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	var level_row := HBoxContainer.new()
	level_row.alignment = BoxContainer.ALIGNMENT_CENTER
	level_row.add_theme_constant_override("separation", 12)
	vbox.add_child(level_row)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(32, 32)
	minus_btn.pressed.connect(_on_level_change.bind(sub_name, -1))
	level_row.add_child(minus_btn)

	var level_label := Label.new()
	level_label.text = "LVL 1"
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.custom_minimum_size = Vector2(80, 0)
	level_row.add_child(level_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(32, 32)
	plus_btn.pressed.connect(_on_level_change.bind(sub_name, 1))
	level_row.add_child(plus_btn)

	var cost_label := Label.new()
	cost_label.text = "—"
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(cost_label)

	var bar_container := HBoxContainer.new()
	bar_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_container.add_theme_constant_override("separation", 3)
	vbox.add_child(bar_container)

	for i in range(MAX_LEVEL):
		var seg := ColorRect.new()
		seg.custom_minimum_size = Vector2(18, 6)
		seg.color = Color(0.1, 0.1, 0.12, 0.5)
		bar_container.add_child(seg)

	_panel_nodes[sub_name] = {
		"panel": panel, "name_label": name_label, "level_label": level_label,
		"cost_label": cost_label, "minus_btn": minus_btn, "plus_btn": plus_btn,
		"bar_container": bar_container,
	}


# ── Augments Tab ────────────────────────────────────────────

func _build_augments_tab() -> void:
	var container := Control.new()
	container.position = Vector2(RIGHT_X, RIGHT_Y + TAB_HEIGHT + 10)
	container.size = Vector2(RIGHT_W, RIGHT_H - TAB_HEIGHT - 10)
	container.visible = false
	add_child(container)
	_tab_containers.append(container)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(520, 660)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	for section in AUGMENT_SECTIONS:
		var sec_color: Color = section["color"]
		var slots: Array = section["slots"]

		# Section header — colored bar, matching hangar style
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
		header_label.text = section["label"]
		header_label.add_theme_font_size_override("font_size", 16)
		header_label.add_theme_color_override("font_color", sec_color)
		header_panel.add_child(header_label)

		# Slot rows
		for slot_key in slots:
			var slot_panel := PanelContainer.new()
			slot_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ssb := StyleBoxFlat.new()
			ssb.bg_color = Color(0.0, 0.0, 0.0, 0.65)
			ssb.set_corner_radius_all(4)
			ssb.content_margin_left = 8
			ssb.content_margin_right = 8
			ssb.content_margin_top = 4
			ssb.content_margin_bottom = 4
			slot_panel.add_theme_stylebox_override("panel", ssb)
			vbox.add_child(slot_panel)

			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			slot_panel.add_child(row)

			var slot_btn := Button.new()
			slot_btn.text = "empty"
			slot_btn.custom_minimum_size.y = 46
			slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			slot_btn.add_theme_color_override("font_color", Color(sec_color.r, sec_color.g, sec_color.b, 0.5))
			slot_btn.add_theme_color_override("font_hover_color", sec_color)
			row.add_child(slot_btn)

		# Spacer between sections
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 4
		vbox.add_child(spacer)


# ── Vanity Tab ──────────────────────────────────────────────

func _build_vanity_tab() -> void:
	var container := Control.new()
	container.position = Vector2(RIGHT_X, RIGHT_Y + TAB_HEIGHT + 10)
	container.size = Vector2(RIGHT_W, RIGHT_H - TAB_HEIGHT - 10)
	container.visible = false
	add_child(container)
	_tab_containers.append(container)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(520, 660)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	scroll.add_child(vbox)

	for cat in VANITY_CATEGORIES:
		var cat_id: String = cat["id"]
		var options: Array = cat["options"]

		# Category header
		var header := Label.new()
		header.text = cat["label"]
		header.add_theme_font_size_override("font_size", 16)
		vbox.add_child(header)

		# Current selection display + prev/next arrows
		var sel_row := HBoxContainer.new()
		sel_row.add_theme_constant_override("separation", 12)
		sel_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(sel_row)

		var prev_btn := Button.new()
		prev_btn.text = "<"
		prev_btn.custom_minimum_size = Vector2(36, 36)
		prev_btn.pressed.connect(_on_vanity_change.bind(cat_id, -1))
		sel_row.add_child(prev_btn)

		var sel_label := Label.new()
		sel_label.text = str(options[0])
		sel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sel_label.custom_minimum_size = Vector2(200, 0)
		sel_row.add_child(sel_label)

		var next_btn := Button.new()
		next_btn.text = ">"
		next_btn.custom_minimum_size = Vector2(36, 36)
		next_btn.pressed.connect(_on_vanity_change.bind(cat_id, 1))
		sel_row.add_child(next_btn)

		# Preview strip — small colored indicators showing all options
		var preview_row := HBoxContainer.new()
		preview_row.alignment = BoxContainer.ALIGNMENT_CENTER
		preview_row.add_theme_constant_override("separation", 4)
		vbox.add_child(preview_row)

		for opt_i in range(options.size()):
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(24, 6)
			if opt_i == 0:
				dot.color = ThemeManager.get_color("accent")
			else:
				dot.color = Color(0.2, 0.2, 0.25, 0.5)
			preview_row.add_child(dot)

		# Store references for updates
		sel_label.set_meta("cat_id", cat_id)
		sel_label.set_meta("options", options)
		sel_row.set_meta("sel_label", sel_label)
		sel_row.set_meta("preview_row", preview_row)
		sel_row.set_meta("cat_id", cat_id)

		# Separator
		var sep := HSeparator.new()
		vbox.add_child(sep)


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

	# Update the display — find the sel_row by walking tab container
	_update_vanity_display()


func _update_vanity_display() -> void:
	var vanity_container: Control = _tab_containers[2]
	var scroll: ScrollContainer = vanity_container.get_child(0)
	var vbox: VBoxContainer = scroll.get_child(0)
	var accent: Color = ThemeManager.get_color("accent")

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
				if dot_i == idx:
					dot.color = accent
				else:
					dot.color = Color(0.2, 0.2, 0.25, 0.5)


# ── HDR Sliders ─────────────────────────────────────────────

func _build_hdr_sliders() -> void:
	var container := VBoxContainer.new()
	container.position = Vector2(20, 770)
	container.custom_minimum_size = Vector2(200, 0)
	container.add_theme_constant_override("separation", 4)
	add_child(container)

	var label := Label.new()
	label.text = "HDR TUNING"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	container.add_child(label)

	_add_hdr_slider(container, "ship", "Ship", _hdr_ship)
	_add_hdr_slider(container, "ui", "UI", _hdr_ui)
	_add_hdr_slider(container, "arrows", "FX", _hdr_arrows)


func _add_hdr_slider(parent: VBoxContainer, key: String, display_name: String, initial: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var readout := Label.new()
	readout.text = "%s: %.1f" % [display_name, initial]
	readout.custom_minimum_size = Vector2(70, 0)
	readout.add_theme_font_size_override("font_size", 10)
	readout.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	row.add_child(readout)
	_hdr_readouts[key] = readout

	var slider := HSlider.new()
	slider.min_value = 1.0
	slider.max_value = 4.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(80, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_hdr_slider_changed.bind(key, display_name))
	row.add_child(slider)
	_hdr_sliders[key] = slider


func _on_hdr_slider_changed(value: float, key: String, display_name: String) -> void:
	_hdr_readouts[key].text = "%s: %.1f" % [display_name, value]
	match key:
		"ship":
			_hdr_ship = value
			if _wireframe:
				_wireframe.hdr_ship = value
		"ui":
			_hdr_ui = value
		"arrows":
			_hdr_arrows = value
			if _wireframe:
				_wireframe.hdr_arrows = value
	_update_subsystems_display()


# ── Subsystems Logic ────────────────────────────────────────

func _on_level_change(sub_name: String, delta: int) -> void:
	var current: int = _subsystem_levels[sub_name]
	var new_level: int = clampi(current + delta, _original_levels[sub_name], MAX_LEVEL)
	if new_level == current:
		return
	_subsystem_levels[sub_name] = new_level
	_recalculate_cost(sub_name)
	_update_subsystems_display()


func _recalculate_cost(sub_name: String) -> void:
	var orig: int = _original_levels[sub_name]
	var target: int = _subsystem_levels[sub_name]
	var total: int = 0
	for lvl in range(orig, target):
		total += int(BASE_COST * pow(COST_SCALE, lvl))
	_pending_costs[sub_name] = total


func _get_total_pending_cost() -> int:
	var total: int = 0
	for sub in SUBSYSTEMS:
		total += _pending_costs[sub]
	return total


func _update_subsystems_display() -> void:
	var hu: float = _hdr_ui
	var accent: Color = ThemeManager.get_color("accent")
	var header_color: Color = ThemeManager.get_color("header")
	var disabled_color: Color = ThemeManager.get_color("disabled")

	for sub in SUBSYSTEMS:
		if not _panel_nodes.has(sub):
			continue
		var nodes: Dictionary = _panel_nodes[sub]
		var level: int = _subsystem_levels[sub]

		var label: Label = nodes["level_label"]
		label.text = "LVL %d" % level
		label.add_theme_color_override("font_color", Color(accent.r * hu, accent.g * hu, accent.b * hu, 1.0))

		var name_lbl: Label = nodes["name_label"]
		name_lbl.add_theme_color_override("font_color", Color(header_color.r * hu, header_color.g * hu, header_color.b * hu, 1.0))

		var cost_label: Label = nodes["cost_label"]
		if _pending_costs[sub] > 0:
			cost_label.text = "%d CR" % _pending_costs[sub]
			cost_label.add_theme_color_override("font_color", Color(0.95 * hu, 0.75 * hu, 0.2 * hu, 1.0))
		else:
			cost_label.text = "—"
			cost_label.add_theme_color_override("font_color", disabled_color)

		var bar: HBoxContainer = nodes["bar_container"]
		for i in range(MAX_LEVEL):
			var seg: ColorRect = bar.get_child(i)
			if i < _original_levels[sub]:
				seg.color = Color(accent.r * hu * 0.5, accent.g * hu * 0.5, accent.b * hu * 0.5, 0.9)
			elif i < level:
				seg.color = Color(accent.r * hu, accent.g * hu, accent.b * hu, 1.0)
			else:
				seg.color = Color(0.1, 0.1, 0.12, 0.5)

		var panel: PanelContainer = nodes["panel"]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.0, 0.0, 0.0, 0.65)
		sb.border_color = Color(accent.r, accent.g, accent.b, 0.15)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", sb)

		var minus_btn: Button = nodes["minus_btn"]
		var plus_btn: Button = nodes["plus_btn"]
		minus_btn.disabled = (level <= _original_levels[sub])
		plus_btn.disabled = (level >= MAX_LEVEL)

	# Finance
	_bank_value_label.text = str(GameState.credits)
	_bank_value_label.add_theme_color_override("font_color", Color(0.95 * hu, 0.75 * hu, 0.2 * hu, 1.0))

	var total_cost: int = _get_total_pending_cost()
	_cost_value_label.text = str(total_cost)
	if total_cost > GameState.credits:
		_cost_value_label.add_theme_color_override("font_color", Color(1.0 * hu, 0.2 * hu, 0.15 * hu, 1.0))
		_confirm_button.disabled = true
	elif total_cost > 0:
		_cost_value_label.add_theme_color_override("font_color", Color(0.95 * hu, 0.75 * hu, 0.2 * hu, 1.0))
		_confirm_button.disabled = false
	else:
		_cost_value_label.add_theme_color_override("font_color", disabled_color)
		_confirm_button.disabled = true

	if _wireframe and _wireframe.has_method("set_levels"):
		_wireframe.set_levels(_subsystem_levels.duplicate())


func _on_confirm() -> void:
	var total_cost: int = _get_total_pending_cost()
	if GameState.spend_credits(total_cost):
		for sub in SUBSYSTEMS:
			_original_levels[sub] = _subsystem_levels[sub]
			_pending_costs[sub] = 0
		_update_subsystems_display()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/mission_prep_menu.tscn")


# ── VHS / Theme ─────────────────────────────────────────────

func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _apply_theme() -> void:
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)

	var hud_font: Font = ThemeManager.get_font("font_header")
	if not hud_font:
		hud_font = ThemeManager.get_font("header")
	var body_font: Font = ThemeManager.get_font("body")
	var header_color: Color = ThemeManager.get_color("header")

	# Finance fonts
	_bank_value_label.add_theme_font_override("font", hud_font)
	_bank_value_label.add_theme_font_size_override("font_size", 28)
	_cost_value_label.add_theme_font_override("font", hud_font)
	_cost_value_label.add_theme_font_size_override("font_size", 28)

	# Coord
	_coord_label.add_theme_font_override("font", body_font)
	_coord_label.add_theme_font_size_override("font_size", 12)
	_coord_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))

	# Buttons
	ThemeManager.apply_button_style(_back_button)
	ThemeManager.apply_button_style(_confirm_button)
	for btn in _tab_buttons:
		ThemeManager.apply_button_style(btn)

	# Subsystem panels
	for sub in SUBSYSTEMS:
		if not _panel_nodes.has(sub):
			continue
		var nodes: Dictionary = _panel_nodes[sub]
		ThemeManager.apply_button_style(nodes["minus_btn"])
		ThemeManager.apply_button_style(nodes["plus_btn"])
		var name_lbl: Label = nodes["name_label"]
		name_lbl.add_theme_font_override("font", body_font)
		ThemeManager.apply_text_glow(name_lbl, "body")
		var lvl_lbl: Label = nodes["level_label"]
		lvl_lbl.add_theme_font_override("font", body_font)
		var cost_lbl: Label = nodes["cost_label"]
		cost_lbl.add_theme_font_override("font", body_font)

	# Finance title
	var title_lbl: Label = _finance_panel.get_meta("title_label")
	if title_lbl:
		title_lbl.add_theme_font_override("font", body_font)
		title_lbl.add_theme_color_override("font_color", Color(header_color.r, header_color.g, header_color.b, 0.8))
		ThemeManager.apply_text_glow(title_lbl, "header")

	# Re-style active tab
	_switch_tab(_active_tab)


func _on_theme_changed() -> void:
	_apply_theme()
	_update_subsystems_display()
	_update_vanity_display()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		_coord_label.text = "%d, %d" % [int(pos.x), int(pos.y)]
