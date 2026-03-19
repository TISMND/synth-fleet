class_name HudBuilder extends RefCounted
## Shared HUD builder for in-game HUD and style editor HUD preview.
## 3-panel layout: bottom bar (icons), left panel (Shield/Hull), right panel (Thermal/Electric).

const BOTTOM_BAR_HEIGHT: int = 64   # icons(40) + padding(2*12)
const SIDE_PANEL_WIDTH: int = 60    # bar(28) + padding + label space
const SIDE_PANEL_PADDING: int = 8
const PANEL_PADDING: int = 12
const WEAPON_ICON_SIZE: int = 40
const BAR_WIDTH: int = 28


static func build_hud(mode: String) -> Dictionary:
	## Top-level builder. Returns: {bottom_bar, left_panel, right_panel, weapons_hbox, mode}
	var bottom: Dictionary = _build_bottom_bar(mode)
	var left: Dictionary = build_side_panel(mode, ["SHIELD", "HULL"], {})
	var right: Dictionary = build_side_panel(mode, ["THERMAL", "ELECTRIC"], {})
	return {
		"bottom_bar": bottom,
		"left_panel": left,
		"right_panel": right,
		"weapons_hbox": bottom["weapons_hbox"],
		"mode": mode,
	}


static func _build_bottom_bar(mode: String) -> Dictionary:
	## Build the bottom bar with weapon/core/device icons only.
	## Returns: {root, border, weapons_hbox}
	var root: Control
	var border: Control

	if mode == "game":
		var bg := ColorRect.new()
		bg.color = ThemeManager.get_color("panel")
		root = bg

		var border_line := ColorRect.new()
		border_line.position = Vector2.ZERO
		border_line.size = Vector2(1920, 2)
		bg.add_child(border_line)
		border = border_line
	else:
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = BOTTOM_BAR_HEIGHT
		var style := StyleBoxFlat.new()
		style.bg_color = ThemeManager.get_color("panel")
		var accent_color: Color = ThemeManager.get_color("accent")
		style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
		style.set_border_width_all(0)
		style.border_width_top = 2
		style.set_content_margin_all(PANEL_PADDING)
		panel.add_theme_stylebox_override("panel", style)
		root = panel
		border = panel

	# Weapon icons HBox
	var weapons_hbox := HBoxContainer.new()
	weapons_hbox.add_theme_constant_override("separation", 8)
	weapons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	if mode == "game":
		weapons_hbox.position = Vector2(PANEL_PADDING, PANEL_PADDING)
		weapons_hbox.size = Vector2(1920 - PANEL_PADDING * 2, BOTTOM_BAR_HEIGHT - PANEL_PADDING * 2)
		root.add_child(weapons_hbox)
	else:
		root.add_child(weapons_hbox)

	return {
		"root": root,
		"border": border,
		"weapons_hbox": weapons_hbox,
	}


static func build_side_panel(mode: String, bar_names: Array, seg_overrides: Dictionary) -> Dictionary:
	## Build a side panel with 2 vertical bars stacked.
	## Returns: {root, border, bars: {bar_name: {bar, label, vertical: true}}}
	var specs: Array = ThemeManager.get_status_bar_specs()
	var spec_by_name: Dictionary = {}
	for spec in specs:
		spec_by_name[str(spec["name"])] = spec

	var root: Control
	var border: Control

	if mode == "game":
		var bg := ColorRect.new()
		var panel_color: Color = ThemeManager.get_color("panel")
		bg.color = Color(panel_color.r, panel_color.g, panel_color.b, 0.7)
		root = bg

		var border_line := ColorRect.new()
		border_line.size = Vector2(2, 1)  # Will be resized by parent
		bg.add_child(border_line)
		border = border_line
	else:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		var panel_color: Color = ThemeManager.get_color("panel")
		style.bg_color = Color(panel_color.r, panel_color.g, panel_color.b, 0.7)
		var accent_color: Color = ThemeManager.get_color("accent")
		style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
		style.set_border_width_all(1)
		style.set_content_margin_all(SIDE_PANEL_PADDING)
		panel.add_theme_stylebox_override("panel", style)
		root = panel
		border = panel

	# VBox to stack the 2 bars vertically
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	if mode == "game":
		vbox.position = Vector2(SIDE_PANEL_PADDING, SIDE_PANEL_PADDING)
	root.add_child(vbox)

	var bars_result: Dictionary = {}
	for bar_name in bar_names:
		if not spec_by_name.has(bar_name):
			continue
		var spec: Dictionary = spec_by_name[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(seg_overrides.get(bar_name, ShipData.DEFAULT_SEGMENTS.get(bar_name, 8)))
		var cell: Dictionary = build_vertical_bar_cell(bar_name, color, seg, seg, seg)
		vbox.add_child(cell["vbox"])
		bars_result[bar_name] = {"bar": cell["bar"], "label": cell["label"], "vertical": true}

	return {
		"root": root,
		"border": border,
		"bars": bars_result,
		"vbox": vbox,
	}


static func build_vertical_bar_cell(text: String, color: Color, initial: int, max_val: int, seg_count: int = -1) -> Dictionary:
	## Single vertical bar cell: VBox → Label (above) + vertical ProgressBar (expand fill).
	## Returns: {vbox, label, bar}
	var short_names: Dictionary = {
		"SHIELD": "SHLD", "HULL": "HULL", "THERMAL": "THRM", "ELECTRIC": "ELEC"
	}
	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = str(short_names.get(text, text))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
	vbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.x = BAR_WIDTH
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.fill_mode = 3  # FILL_BOTTOM_TO_TOP
	bar.max_value = max_val
	bar.value = initial
	bar.show_percentage = false
	vbox.add_child(bar)

	ThemeManager.apply_led_bar(bar, color, float(initial) / maxf(float(max_val), 1.0), seg_count, true)

	return {"vbox": vbox, "label": lbl, "bar": bar}


static func build_weapon_icon(number: int, active: bool, color: Color) -> Dictionary:
	## Single 40x40 weapon/core/device icon.
	## Returns: {container, bg_rect, number_label, active, color}
	var body_font: Font = ThemeManager.get_font("font_body")

	var container := Control.new()
	container.custom_minimum_size = Vector2(WEAPON_ICON_SIZE, WEAPON_ICON_SIZE)

	var bg_rect := ColorRect.new()
	bg_rect.position = Vector2.ZERO
	bg_rect.size = Vector2(WEAPON_ICON_SIZE, WEAPON_ICON_SIZE)
	container.add_child(bg_rect)

	var number_label := Label.new()
	number_label.text = str(number)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.position = Vector2.ZERO
	number_label.size = Vector2(WEAPON_ICON_SIZE, WEAPON_ICON_SIZE)
	number_label.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_section"))
	if body_font:
		number_label.add_theme_font_override("font", body_font)
	container.add_child(number_label)

	var icon_data: Dictionary = {
		"container": container,
		"bg_rect": bg_rect,
		"number_label": number_label,
		"active": active,
		"color": color,
	}
	apply_icon_theme(icon_data)
	return icon_data


static func build_icon_separator() -> ColorRect:
	## 2px vertical divider between icon groups.
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(2, WEAPON_ICON_SIZE)
	sep.color = ThemeManager.get_color("disabled")
	return sep


static func apply_icon_theme(icon: Dictionary) -> void:
	## Active/inactive visual state for a weapon icon.
	var active: bool = icon["active"]
	var color: Color = icon["color"]
	if active:
		icon["bg_rect"].color = color
		icon["number_label"].add_theme_color_override("font_color", Color(0.05, 0.05, 0.1))
	else:
		var dim_color: Color = ThemeManager.get_color("panel").lightened(0.1)
		icon["bg_rect"].color = dim_color
		icon["number_label"].add_theme_color_override("font_color", ThemeManager.get_color("disabled"))


static func apply_bar_label_theme(lbl: Label, color: Color, font: Font, size: int) -> void:
	## Font + color + glow on a bar label.
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	if font:
		lbl.add_theme_font_override("font", font)
	ThemeManager.apply_text_glow(lbl, "body")


static func apply_hud_theme(result: Dictionary) -> void:
	## Update bg/border colors on all three HUD panels. Handles both modes.
	var accent_color: Color = ThemeManager.get_color("accent")
	var border_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
	var panel_color: Color = ThemeManager.get_color("panel")
	var mode: String = str(result["mode"])

	# Bottom bar
	var bottom: Dictionary = result["bottom_bar"]
	if mode == "game":
		bottom["root"].color = panel_color
		bottom["border"].color = border_color
	else:
		var panel: PanelContainer = bottom["root"]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = panel_color
			style.border_color = border_color

	# Side panels
	var side_panel_color := Color(panel_color.r, panel_color.g, panel_color.b, 0.7)
	for panel_key in ["left_panel", "right_panel"]:
		var side: Dictionary = result[panel_key]
		if mode == "game":
			side["root"].color = side_panel_color
			side["border"].color = border_color
		else:
			var panel: PanelContainer = side["root"]
			var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.bg_color = side_panel_color
				style.border_color = border_color
