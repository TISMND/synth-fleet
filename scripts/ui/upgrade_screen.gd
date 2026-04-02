extends Control
## Ship Upgrade Screen — metal-framed green wireframe diagram with subsystem upgrade controls.
## Visual style matches the hangar/loadout screen. Ship diagram is an independent green viewport
## framed by bar_bezel metal. Everything outside matches ThemeManager palette.

const SUBSYSTEMS := ["WEAPONS", "ARMOR", "ENGINES", "POWER CORE"]
const MAX_LEVEL := 10
const BASE_COST := 500
const COST_SCALE := 1.4

# Layout constants
const PANEL_X := 1360
const PANEL_START_Y := 200
const PANEL_SPACING := 140
const PANEL_WIDTH := 280
const PANEL_HEIGHT := 110

# Ship viewport frame — the green wireframe lives inside this metal-framed box
# Positioned center-left, large enough for the ship at SCALE 9
const FRAME_RECT := Rect2(310, 60, 700, 660)  # x, y, w, h in screen coords
const SHIP_CENTER := Vector2(660, 390)  # Center of the frame in screen coords

# HDR channels
var _hdr_ship: float = 1.8
var _hdr_ui: float = 1.6
var _hdr_arrows: float = 1.4

var _vhs_overlay: ColorRect
var _bg_rect: ColorRect
var _wireframe: Node2D
var _subsystem_levels: Dictionary = {}
var _panel_nodes: Dictionary = {}
var _back_button: Button
var _confirm_button: Button
var _coord_label: Label

# Financial pane
var _finance_panel: PanelContainer
var _bank_value_label: Label
var _cost_value_label: Label

# Audition controls
var _hdr_sliders: Dictionary = {}
var _hdr_readouts: Dictionary = {}

var _pending_costs: Dictionary = {}
var _original_levels: Dictionary = {}


func _ready() -> void:
	_init_levels()
	_build_ui()
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_theme()
	_update_all_displays()


func _init_levels() -> void:
	for sub in SUBSYSTEMS:
		_subsystem_levels[sub] = 1
		_original_levels[sub] = 1
		_pending_costs[sub] = 0


func _build_ui() -> void:
	# Dark background matching ThemeManager
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color.BLACK
	add_child(_bg_rect)

	# Ship wireframe — positioned at frame center
	_wireframe = Node2D.new()
	_wireframe.position = SHIP_CENTER
	_wireframe.set_script(preload("res://scripts/ui/upgrade_wireframe.gd"))
	add_child(_wireframe)
	_wireframe.hdr_ship = _hdr_ship
	_wireframe.hdr_arrows = _hdr_arrows
	# Pass frame bounds so wireframe can clip its grid
	_wireframe.frame_rect = FRAME_RECT
	_wireframe.ship_center = SHIP_CENTER


	# Financial pane — left column
	_build_finance_pane()

	# Upgrade panels — right side, stacked
	for i in range(SUBSYSTEMS.size()):
		var sub: String = SUBSYSTEMS[i]
		var pos := Vector2(PANEL_X, PANEL_START_Y + i * PANEL_SPACING)
		_build_subsystem_panel(sub, pos)

	# HDR tuning sliders
	_build_hdr_sliders()

	# Confirm button
	_confirm_button = Button.new()
	_confirm_button.text = "CONFIRM UPGRADES"
	_confirm_button.custom_minimum_size = Vector2(PANEL_WIDTH, 40)
	_confirm_button.position = Vector2(PANEL_X, PANEL_START_Y + SUBSYSTEMS.size() * PANEL_SPACING + 10)
	_confirm_button.size = Vector2(PANEL_WIDTH, 40)
	_confirm_button.pressed.connect(_on_confirm)
	add_child(_confirm_button)

	# Back button
	_back_button = Button.new()
	_back_button.text = "BACK"
	_back_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_back_button.offset_left = 40
	_back_button.offset_top = -60
	_back_button.offset_right = 160
	_back_button.offset_bottom = -20
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


func _build_finance_pane() -> void:
	_finance_panel = PanelContainer.new()
	_finance_panel.position = Vector2(40, 200)
	_finance_panel.custom_minimum_size = Vector2(240, 300)
	_finance_panel.size = Vector2(240, 300)

	var bg_color: Color = ThemeManager.get_color("background")
	var accent: Color = ThemeManager.get_color("accent")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(bg_color.r + 0.02, bg_color.g + 0.02, bg_color.b + 0.03, 0.9)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	_finance_panel.add_theme_stylebox_override("panel", sb)
	add_child(_finance_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_finance_panel.add_child(vbox)

	var title := Label.new()
	title.text = "FINANCES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)
	_finance_panel.set_meta("title_label", title)

	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 4)
	vbox.add_child(sep1)

	var bank_row := _build_currency_row("BANK", str(GameState.credits))
	vbox.add_child(bank_row)
	_bank_value_label = bank_row.get_meta("value_label")

	var cost_row := _build_currency_row("UPGRADE COST", "0")
	vbox.add_child(cost_row)
	_cost_value_label = cost_row.get_meta("value_label")

	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 4)
	vbox.add_child(sep2)

	var future_label := Label.new()
	future_label.text = "— MORE COMING —"
	future_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	future_label.add_theme_font_size_override("font_size", 10)
	future_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	vbox.add_child(future_label)


func _build_currency_row(label_text: String, value_text: String) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 12)
	container.add_child(lbl)
	container.set_meta("key_label", lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 28)
	container.add_child(val)
	container.set_meta("value_label", val)

	return container


func _build_hdr_sliders() -> void:
	var container := VBoxContainer.new()
	container.position = Vector2(40, 700)
	container.custom_minimum_size = Vector2(240, 0)
	container.add_theme_constant_override("separation", 6)
	add_child(container)

	var label := Label.new()
	label.text = "HDR TUNING"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	container.add_child(label)

	_add_hdr_slider(container, "ship", "Ship", _hdr_ship)
	_add_hdr_slider(container, "ui", "UI / Fonts", _hdr_ui)
	_add_hdr_slider(container, "arrows", "Arrows / FX", _hdr_arrows)


func _add_hdr_slider(parent: VBoxContainer, key: String, display_name: String, initial: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var readout := Label.new()
	readout.text = "%s: %.2f" % [display_name, initial]
	readout.custom_minimum_size = Vector2(130, 0)
	readout.add_theme_font_size_override("font_size", 11)
	readout.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))
	row.add_child(readout)
	_hdr_readouts[key] = readout

	var slider := HSlider.new()
	slider.min_value = 1.0
	slider.max_value = 4.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(100, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_hdr_slider_changed.bind(key, display_name))
	row.add_child(slider)
	_hdr_sliders[key] = slider


func _on_hdr_slider_changed(value: float, key: String, display_name: String) -> void:
	_hdr_readouts[key].text = "%s: %.2f" % [display_name, value]
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
	_update_all_displays()


func _build_subsystem_panel(sub_name: String, pos: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.border_color = Color(0.5, 0.5, 0.5, 0.15)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

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
		"panel": panel,
		"name_label": name_label,
		"level_label": level_label,
		"cost_label": cost_label,
		"minus_btn": minus_btn,
		"plus_btn": plus_btn,
		"bar_container": bar_container,
	}


func _on_level_change(sub_name: String, delta: int) -> void:
	var current: int = _subsystem_levels[sub_name]
	var new_level: int = clampi(current + delta, _original_levels[sub_name], MAX_LEVEL)
	if new_level == current:
		return
	_subsystem_levels[sub_name] = new_level
	_recalculate_cost(sub_name)
	_update_all_displays()


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


func _update_all_displays() -> void:
	var hu: float = _hdr_ui
	var accent: Color = ThemeManager.get_color("accent")
	var header_color: Color = ThemeManager.get_color("header")
	var text_color: Color = ThemeManager.get_color("text")
	var disabled_color: Color = ThemeManager.get_color("disabled")

	for sub in SUBSYSTEMS:
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
			# Gold HDR for active costs
			cost_label.add_theme_color_override("font_color", Color(0.95 * hu, 0.75 * hu, 0.2 * hu, 1.0))
		else:
			cost_label.text = "—"
			cost_label.add_theme_color_override("font_color", disabled_color)

		# Bar segments — accent color for HDR bloom
		var bar: HBoxContainer = nodes["bar_container"]
		for i in range(MAX_LEVEL):
			var seg: ColorRect = bar.get_child(i)
			if i < _original_levels[sub]:
				seg.color = Color(accent.r * hu * 0.5, accent.g * hu * 0.5, accent.b * hu * 0.5, 0.9)
			elif i < level:
				seg.color = Color(accent.r * hu, accent.g * hu, accent.b * hu, 1.0)
			else:
				seg.color = Color(0.1, 0.1, 0.12, 0.5)

		# Panel border — subtle accent
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

	# Finance pane
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

	# Finance panel styling
	var bg_color: Color = ThemeManager.get_color("background")
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Color(bg_color.r + 0.02, bg_color.g + 0.02, bg_color.b + 0.03, 0.9)
	fsb.border_color = Color(accent.r, accent.g, accent.b, 0.25)
	fsb.set_border_width_all(1)
	fsb.set_corner_radius_all(4)
	_finance_panel.add_theme_stylebox_override("panel", fsb)

	var title_lbl: Label = _finance_panel.get_meta("title_label")
	if title_lbl:
		title_lbl.add_theme_color_override("font_color", Color(header_color.r * hu, header_color.g * hu, header_color.b * hu, 0.8))

	# Currency row key labels
	var bank_row: VBoxContainer = _bank_value_label.get_parent() as VBoxContainer
	if bank_row:
		var key_lbl: Label = bank_row.get_meta("key_label")
		if key_lbl:
			key_lbl.add_theme_color_override("font_color", Color(text_color.r * 0.6, text_color.g * 0.6, text_color.b * 0.6, 0.5))
	var cost_row: VBoxContainer = _cost_value_label.get_parent() as VBoxContainer
	if cost_row:
		var key_lbl: Label = cost_row.get_meta("key_label")
		if key_lbl:
			key_lbl.add_theme_color_override("font_color", Color(text_color.r * 0.6, text_color.g * 0.6, text_color.b * 0.6, 0.5))

	if _wireframe and _wireframe.has_method("set_levels"):
		_wireframe.set_levels(_subsystem_levels.duplicate())


func _on_confirm() -> void:
	var total_cost: int = _get_total_pending_cost()
	if GameState.spend_credits(total_cost):
		for sub in SUBSYSTEMS:
			_original_levels[sub] = _subsystem_levels[sub]
			_pending_costs[sub] = 0
		_update_all_displays()


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


func _apply_theme() -> void:
	if _vhs_overlay:
		ThemeManager.apply_vhs_overlay(_vhs_overlay)

	_bg_rect.color = Color.BLACK

	var hud_font: Font = ThemeManager.get_font("font_header")
	if not hud_font:
		hud_font = ThemeManager.get_font("header")
	var body_font: Font = ThemeManager.get_font("body")

	_bank_value_label.add_theme_font_override("font", hud_font)
	_bank_value_label.add_theme_font_size_override("font_size", 28)
	_cost_value_label.add_theme_font_override("font", hud_font)
	_cost_value_label.add_theme_font_size_override("font_size", 28)

	_coord_label.add_theme_font_override("font", body_font)
	_coord_label.add_theme_font_size_override("font_size", 12)
	_coord_label.add_theme_color_override("font_color", ThemeManager.get_color("disabled"))

	ThemeManager.apply_button_style(_back_button)
	ThemeManager.apply_button_style(_confirm_button)

	for sub in SUBSYSTEMS:
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


func _on_theme_changed() -> void:
	_apply_theme()
	_update_all_displays()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
	if event is InputEventMouseMotion:
		var pos: Vector2 = (event as InputEventMouseMotion).position
		_coord_label.text = "%d, %d" % [int(pos.x), int(pos.y)]
