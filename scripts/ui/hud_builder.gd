class_name HudBuilder extends RefCounted
## Shared HUD builder for in-game HUD and style editor HUD preview.
## 3-panel layout: bottom bar (icons), left panel (Shield/Hull), right panel (Thermal/Electric).

const BOTTOM_BAR_HEIGHT: int = 64   # icons(40) + padding(2*12)
const SIDE_PANEL_WIDTH: int = 60    # bar(28) + padding + label space
const SIDE_PANEL_PADDING: int = 8
const PANEL_PADDING: int = 12
const WEAPON_ICON_SIZE: int = 40
const BAR_WIDTH: int = 28


static func build_hud(mode: String, panel_height: float = 948.0) -> Dictionary:
	## Top-level builder. Returns: {bottom_bar, left_panel, right_panel, weapons_hbox, mode}
	var bottom: Dictionary = _build_bottom_bar(mode)
	var left: Dictionary = build_side_panel(mode, ["SHIELD", "HULL"], {}, panel_height)
	var right: Dictionary = build_side_panel(mode, ["THERMAL", "ELECTRIC"], {}, panel_height)
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


static func build_side_panel(mode: String, bar_names: Array, seg_overrides: Dictionary, panel_height: float = 948.0) -> Dictionary:
	## Build a side panel with 2 vertical bars at fixed half-and-half positions.
	## Returns: {root, border, bars: {bar_name: {bar, label, vertical: true}}, content}
	var specs: Array = ThemeManager.get_status_bar_specs()
	var spec_by_name: Dictionary = {}
	for spec in specs:
		spec_by_name[str(spec["name"])] = spec

	var short_names: Dictionary = {
		"SHIELD": "SHLD", "HULL": "HULL", "THERMAL": "THRM", "ELECTRIC": "ELEC"
	}

	var root: Control
	var border: Control

	if mode == "game":
		var bg := ColorRect.new()
		bg.color = Color.WHITE  # Shader controls rendering
		root = bg
		# Apply chrome panel shader
		var shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("base_color", Vector4(0.12, 0.13, 0.18, 1.0))
			mat.set_shader_parameter("divider_y", 0.5)
			var accent_color: Color = ThemeManager.get_color("accent")
			mat.set_shader_parameter("divider_color", Vector4(accent_color.r, accent_color.g, accent_color.b, 0.5))
			bg.material = mat

		var border_line := ColorRect.new()
		border_line.size = Vector2(2, 1)
		bg.add_child(border_line)
		border = border_line
	else:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		var accent_color: Color = ThemeManager.get_color("accent")
		style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.4)
		style.set_border_width_all(1)
		style.set_content_margin_all(0)
		panel.add_theme_stylebox_override("panel", style)
		root = panel

		# Chrome shader on a child ColorRect filling the panel
		var chrome_bg := ColorRect.new()
		chrome_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		chrome_bg.color = Color.WHITE
		chrome_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("base_color", Vector4(0.12, 0.13, 0.18, 1.0))
			mat.set_shader_parameter("divider_y", 0.5)
			var accent_color2: Color = ThemeManager.get_color("accent")
			mat.set_shader_parameter("divider_color", Vector4(accent_color2.r, accent_color2.g, accent_color2.b, 0.5))
			chrome_bg.material = mat
		panel.add_child(chrome_bg)
		border = panel

	# Fixed-position content container
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(content)

	# Layout constants
	var mid_y: float = panel_height / 2.0
	var label_h: float = 20.0
	var bar_pad: float = 6.0
	var bar_x: float = float(SIDE_PANEL_WIDTH - BAR_WIDTH) / 2.0
	var seg_px: float = ThemeManager.get_float("led_segment_width_px")
	var gap_px: float = ThemeManager.get_float("led_segment_gap_px")

	var bars_result: Dictionary = {}
	for i in bar_names.size():
		var bar_name: String = str(bar_names[i])
		if not spec_by_name.has(bar_name):
			continue
		var spec: Dictionary = spec_by_name[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(seg_overrides.get(bar_name, ShipData.DEFAULT_SEGMENTS.get(bar_name, 8)))

		# Fixed bar height from segment count — no stretching
		var bar_height: float = float(seg) * seg_px + float(seg - 1) * gap_px
		# Label anchored to bottom of zone, bar grows upward from just above label
		var zone_bottom: float = mid_y * float(i + 1)
		var label_top: float = zone_bottom - bar_pad - label_h
		var bar_top: float = label_top - bar_pad - bar_height
		print("[HUD] %s: seg=%d seg_px=%.1f gap_px=%.1f bar_height=%.1f mid_y=%.1f zone_bottom=%.1f label_top=%.1f bar_top=%.1f panel_height=%.1f" % [bar_name, seg, seg_px, gap_px, bar_height, mid_y, zone_bottom, label_top, bar_top, panel_height])

		# Create bar
		var bar := ProgressBar.new()
		bar.fill_mode = 3  # FILL_BOTTOM_TO_TOP
		bar.max_value = seg
		bar.value = seg
		bar.show_percentage = false
		content.add_child(bar)
		ThemeManager.apply_led_bar(bar, color, 1.0, seg, true)
		bar.size_flags_vertical = Control.SIZE_FILL
		# Defer position: apply_led_bar's glow overlay inflates actual size,
		# so we wait one frame, read the real size, and anchor bottom edge above label
		var _def_bar: ProgressBar = bar
		var _def_x: float = bar_x
		var _def_label_top: float = label_top
		var _def_pad: float = bar_pad
		(func():
			var actual_h: float = _def_bar.size.y
			var anchored_top: float = _def_label_top - _def_pad - actual_h
			_def_bar.position = Vector2(_def_x, anchored_top)
		).call_deferred()

		# Create label BELOW bar
		var lbl := Label.new()
		lbl.text = str(short_names.get(bar_name, bar_name))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, label_top)
		lbl.size = Vector2(SIDE_PANEL_WIDTH, label_h)
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		content.add_child(lbl)

		bars_result[bar_name] = {"bar": bar, "label": lbl, "vertical": true}

	return {
		"root": root,
		"border": border,
		"bars": bars_result,
		"content": content,
	}



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

	# Side panels — update chrome shader divider color from accent
	for panel_key in ["left_panel", "right_panel"]:
		var side: Dictionary = result[panel_key]
		if mode == "game":
			var bg: ColorRect = side["root"] as ColorRect
			if bg and bg.material is ShaderMaterial:
				var mat: ShaderMaterial = bg.material as ShaderMaterial
				mat.set_shader_parameter("divider_color", Vector4(accent_color.r, accent_color.g, accent_color.b, 0.5))
			side["border"].color = border_color
		else:
			var panel: PanelContainer = side["root"]
			var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.border_color = border_color
			# Update chrome shader on the child ColorRect
			if panel.get_child_count() > 0:
				var chrome_bg: ColorRect = panel.get_child(0) as ColorRect
				if chrome_bg and chrome_bg.material is ShaderMaterial:
					var mat: ShaderMaterial = chrome_bg.material as ShaderMaterial
					mat.set_shader_parameter("divider_color", Vector4(accent_color.r, accent_color.g, accent_color.b, 0.5))
