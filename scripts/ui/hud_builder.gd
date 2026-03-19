class_name HudBuilder extends RefCounted
## Shared dashboard builder for in-game HUD and style editor HUD preview.
## Single source of truth for layout, sizing, and theming of the bottom dashboard.

const PANEL_HEIGHT: int = 110
const PANEL_PADDING: int = 12
const WEAPON_ICON_SIZE: int = 40
const BAR_HEIGHT: int = 28
const BAR_LABEL_WIDTH: int = 80
const LAYOUT_ORDER: Array[int] = [0, 2, 1, 3]  # Row1: Shield, Thermal — Row2: Hull, Electric


static func build_dashboard(mode: String) -> Dictionary:
	## Build the full dashboard container.
	## "game" mode → ColorRect bg + ColorRect border (absolute positioning in CanvasLayer).
	## "preview" mode → PanelContainer + StyleBoxFlat (flow layout in ScrollContainer).
	## Returns: {root, hbox, weapons_hbox, bars_grid, border, mode}
	var root: Control
	var border: Control
	var hbox_parent: Control

	if mode == "game":
		var bg := ColorRect.new()
		bg.color = ThemeManager.get_color("panel")
		root = bg

		var border_line := ColorRect.new()
		border_line.position = Vector2.ZERO
		border_line.size = Vector2(1920, 2)
		bg.add_child(border_line)
		border = border_line

		hbox_parent = bg
	else:
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = PANEL_HEIGHT
		var style := StyleBoxFlat.new()
		style.bg_color = ThemeManager.get_color("panel")
		var accent_color: Color = ThemeManager.get_color("accent")
		style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
		style.set_border_width_all(0)
		style.border_width_top = 2
		style.set_content_margin_all(PANEL_PADDING)
		panel.add_theme_stylebox_override("panel", style)
		root = panel
		border = panel  # style editor uses the PanelContainer itself for border theming

		hbox_parent = panel

	# Main dashboard HBox
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 40)
	if mode == "game":
		hbox.position = Vector2(PANEL_PADDING, PANEL_PADDING + 4)
		hbox.size = Vector2(1920 - PANEL_PADDING * 2, PANEL_HEIGHT - PANEL_PADDING * 2 - 4)
	hbox_parent.add_child(hbox)

	# Left — Weapon icons
	var weapons_hbox := HBoxContainer.new()
	weapons_hbox.custom_minimum_size = Vector2(500, 0)
	weapons_hbox.add_theme_constant_override("separation", 8)
	weapons_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.add_child(weapons_hbox)

	# Right — Status bars 2x2 grid
	var bars_grid := GridContainer.new()
	bars_grid.columns = 2
	bars_grid.add_theme_constant_override("h_separation", 40)
	bars_grid.add_theme_constant_override("v_separation", 8)
	bars_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars_grid.custom_minimum_size.x = 640
	hbox.add_child(bars_grid)

	return {
		"root": root,
		"hbox": hbox,
		"weapons_hbox": weapons_hbox,
		"bars_grid": bars_grid,
		"border": border,
		"mode": mode,
	}


static func populate_bars(bars_grid: GridContainer, seg_overrides: Dictionary = {}) -> Dictionary:
	## Add 4 bar cells to the grid using LAYOUT_ORDER.
	## seg_overrides: optional bar_name → int segment count overrides.
	## Returns: bar_name → {"bar": ProgressBar, "label": Label}
	var result: Dictionary = {}
	var specs: Array = ThemeManager.get_status_bar_specs()
	for idx in LAYOUT_ORDER:
		var spec: Dictionary = specs[idx]
		var bar_name: String = str(spec["name"])
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(seg_overrides.get(bar_name, ShipData.DEFAULT_SEGMENTS.get(bar_name, 8)))
		var init_val: int = seg
		var cell: Dictionary = build_bar_cell(bar_name, color, init_val, seg, seg)
		bars_grid.add_child(cell["vbox"])
		result[bar_name] = {"bar": cell["bar"], "label": cell["label"]}
	return result


static func build_bar_cell(text: String, color: Color, initial: int, max_val: int, seg_count: int = -1) -> Dictionary:
	## Single bar cell: HBox(sep=6) → Label(min_x=80) + ProgressBar(min_y=28).
	## Returns: {vbox, label, bar}
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 6)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN

	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.x = BAR_LABEL_WIDTH
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = max_val
	bar.value = initial
	bar.show_percentage = false
	hbox.add_child(bar)

	ThemeManager.apply_led_bar(bar, color, float(initial) / maxf(float(max_val), 1.0), seg_count)

	return {"vbox": hbox, "label": lbl, "bar": bar}


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


static func apply_dashboard_theme(result: Dictionary) -> void:
	## Update bg/border colors on a dashboard result dict. Handles both modes.
	var accent_color: Color = ThemeManager.get_color("accent")
	var border_color := Color(accent_color.r, accent_color.g, accent_color.b, 0.4)

	if result["mode"] == "game":
		result["root"].color = ThemeManager.get_color("panel")
		result["border"].color = border_color
	else:
		# Preview mode — update StyleBoxFlat on PanelContainer
		var panel: PanelContainer = result["root"]
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			style.bg_color = ThemeManager.get_color("panel")
			style.border_color = border_color
