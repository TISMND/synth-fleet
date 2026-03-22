class_name HudBuilder extends RefCounted
## Shared HUD builder for in-game HUD and style editor HUD preview.
## 3-panel layout: bottom bar (icons), left panel (Shield/Hull), right panel (Thermal/Electric).

const BOTTOM_BAR_HEIGHT: int = 64   # icons(40) + padding(2*12)
const SIDE_PANEL_WIDTH: int = 60    # bar(28) + padding + label space
const SIDE_PANEL_PADDING: int = 8
const PANEL_PADDING: int = 12
const WEAPON_ICON_SIZE: int = 40
const BAR_WIDTH: int = 52


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

	# Dark gunmetal chrome — replacement aesthetic from auditions
	var chrome_base := Vector4(0.02, 0.02, 0.03, 1.0)
	var chrome_params: Dictionary = {
		"base_color": chrome_base,
		"chrome_top_brightness": 0.3,
		"chrome_base_brightness": 0.15,
		"highlight_intensity": 0.06,
		"edge_brightness": 0.02,
	}

	if mode == "game":
		var bg := ColorRect.new()
		bg.color = Color.WHITE
		root = bg
		var shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("divider_y", 0.5)
			var accent_color: Color = ThemeManager.get_color("accent")
			mat.set_shader_parameter("divider_color", Vector4(accent_color.r, accent_color.g, accent_color.b, 0.5))
			for key in chrome_params:
				mat.set_shader_parameter(key, chrome_params[key])
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

		var chrome_bg := ColorRect.new()
		chrome_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		chrome_bg.color = Color.WHITE
		chrome_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader: Shader = load("res://assets/shaders/chrome_panel.gdshader") as Shader
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("divider_y", 0.5)
			var accent_color2: Color = ThemeManager.get_color("accent")
			mat.set_shader_parameter("divider_color", Vector4(accent_color2.r, accent_color2.g, accent_color2.b, 0.5))
			for key in chrome_params:
				mat.set_shader_parameter(key, chrome_params[key])
			chrome_bg.material = mat
		panel.add_child(chrome_bg)
		border = panel

	# Use VBoxContainer layout — no manual position math.
	# Structure per zone: spacer (fills top) → bar → pad → label → pad
	# Container handles repositioning when segment count changes.
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(main_vbox)

	var bars_result: Dictionary = {}
	for i in bar_names.size():
		var bar_name: String = str(bar_names[i])
		if not spec_by_name.has(bar_name):
			continue
		var spec: Dictionary = spec_by_name[bar_name]
		var color: Color = ThemeManager.resolve_bar_color(spec)
		var seg: int = int(seg_overrides.get(bar_name, ShipData.DEFAULT_SEGMENTS.get(bar_name, 8)))

		# Zone container — each zone gets equal share of panel height
		var zone := VBoxContainer.new()
		zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
		zone.add_theme_constant_override("separation", 0)
		zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		main_vbox.add_child(zone)

		# Spacer pushes bar+label to bottom of zone
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(spacer)

		# Bar — custom_minimum_size controls height, container handles position
		var bar := ProgressBar.new()
		bar.fill_mode = 3  # FILL_BOTTOM_TO_TOP
		bar.max_value = seg
		bar.value = seg
		bar.show_percentage = false
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.custom_minimum_size.x = BAR_WIDTH
		zone.add_child(bar)
		ThemeManager.apply_led_bar(bar, color, 1.0, seg, true)

		# Pad between bar and label
		var pad := Control.new()
		pad.custom_minimum_size.y = 6
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(pad)

		# Label
		var lbl := Label.new()
		lbl.text = str(short_names.get(bar_name, bar_name))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", ThemeManager.get_font_size("font_size_body"))
		zone.add_child(lbl)

		# Bottom pad
		var bottom_pad := Control.new()
		bottom_pad.custom_minimum_size.y = 8
		bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zone.add_child(bottom_pad)

		# Per-segment bezel — child of bar, auto-sizes via anchors
		var bezel_pad: float = 6.0
		var bezel_shader: Shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
		if bezel_shader:
			var bezel_rect := ColorRect.new()
			bezel_rect.color = Color.WHITE
			bezel_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bezel_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			bezel_rect.offset_left = -bezel_pad
			bezel_rect.offset_right = bezel_pad
			bezel_rect.offset_top = -bezel_pad
			bezel_rect.offset_bottom = bezel_pad
			var smat := ShaderMaterial.new()
			smat.shader = bezel_shader
			print("[BEZEL] bar=%s seg=%d min_size=%s" % [bar_name, seg, str(bar.custom_minimum_size)])
			smat.set_shader_parameter("segment_count", int(seg))
			smat.set_shader_parameter("vertical", int(1))
			smat.set_shader_parameter("socket_bezel", 0.16)
			smat.set_shader_parameter("socket_radius", 0.04)
			smat.set_shader_parameter("inner_shadow_intensity", 1.3)
			smat.set_shader_parameter("inner_shadow_softness", 0.3)
			smat.set_shader_parameter("shadow_direction", 0.5)
			smat.set_shader_parameter("bevel_intensity", 0.35)
			smat.set_shader_parameter("bevel_softness", 0.35)
			smat.set_shader_parameter("rim_intensity", 0.0)
			smat.set_shader_parameter("metal_color", Color(0.03, 0.03, 0.04, 1.0))
			smat.set_shader_parameter("metal_roughness", 0.2)
			smat.set_shader_parameter("outer_shadow_intensity", 0.8)
			smat.set_shader_parameter("outer_shadow_size", 0.09)
			smat.set_shader_parameter("depth_scale", 1.4)
			if bar.material is ShaderMaterial:
				var bar_mat: ShaderMaterial = bar.material as ShaderMaterial
				smat.set_shader_parameter("segment_gap", bar_mat.get_shader_parameter("segment_gap"))
			# edge_pad tells shader where the bar grid lives within the padded rect
			# These are set deferred once the bar has its final size
			bezel_rect.material = smat
			bar.add_child(bezel_rect)
			# Deferred edge_pad from bar's actual rendered size
			var bp: float = bezel_pad
			var sm: ShaderMaterial = smat
			var br: ProgressBar = bar
			(func() -> void:
				if not is_instance_valid(br):
					return
				var rh: float = br.size.y + bp * 2.0
				var rw: float = br.size.x + bp * 2.0
				if rh > 0.0 and rw > 0.0:
					sm.set_shader_parameter("edge_pad_x", bp / rh)
					sm.set_shader_parameter("edge_pad_y", bp / rw)
			).call_deferred()

		# Find the bezel material from the child we just added (if any)
		var bz_mat: ShaderMaterial = null
		var bz_pad: float = bezel_pad
		for child_node in bar.get_children():
			if child_node is ColorRect and child_node.material is ShaderMaterial:
				bz_mat = child_node.material as ShaderMaterial
				break
		bars_result[bar_name] = {"bar": bar, "label": lbl, "vertical": true, "bezel_mat": bz_mat, "bezel_pad": bz_pad}

	return {
		"root": root,
		"border": border,
		"bars": bars_result,
		"content": main_vbox,
	}


## Place per-segment bezel overlays on a side panel's bars. Call deferred after layout settles.
## panel_data is the dict returned by build_side_panel.
static func place_segment_bezels(panel_data: Dictionary) -> void:
	var root_node: Control = panel_data["root"]
	var bars: Dictionary = panel_data["bars"]
	var bezel_shader: Shader = load("res://assets/shaders/bar_bezel_segments.gdshader") as Shader
	if not bezel_shader:
		return
	var pad: float = 10.0
	var socket_params: Dictionary = {
		"socket_bezel": 0.16, "socket_radius": 0.04,
		"inner_shadow_intensity": 1.3, "inner_shadow_softness": 0.3,
		"shadow_direction": 0.5, "bevel_intensity": 0.35, "bevel_softness": 0.35,
		"rim_intensity": 0.0,
		"metal_color": Color(0.03, 0.03, 0.04, 1.0), "metal_roughness": 0.2,
		"outer_shadow_intensity": 0.8, "outer_shadow_size": 0.09,
		"depth_scale": 1.4,
	}
	var specs: Array = ThemeManager.get_status_bar_specs()
	for spec in specs:
		var bar_name: String = str(spec["name"])
		if not bars.has(bar_name):
			continue
		var entry: Dictionary = bars[bar_name]
		var bar: ProgressBar = entry["bar"]
		var seg: int = int(ShipData.DEFAULT_SEGMENTS.get(bar_name, 8))
		var bar_pos: Vector2 = bar.global_position - root_node.global_position
		var seg_rect := ColorRect.new()
		seg_rect.position = Vector2(bar_pos.x - pad, bar_pos.y - pad)
		var seg_size := Vector2(bar.size.x + pad * 2.0, bar.size.y + pad * 2.0)
		seg_rect.size = seg_size
		seg_rect.color = Color.WHITE
		seg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var smat := ShaderMaterial.new()
		smat.shader = bezel_shader
		for key in socket_params:
			smat.set_shader_parameter(key, socket_params[key])
		smat.set_shader_parameter("segment_count", seg)
		if bar.material is ShaderMaterial:
			var bar_mat: ShaderMaterial = bar.material as ShaderMaterial
			smat.set_shader_parameter("segment_gap", bar_mat.get_shader_parameter("segment_gap"))
		smat.set_shader_parameter("vertical", 1)
		if seg_size.y > 0.0 and seg_size.x > 0.0:
			smat.set_shader_parameter("edge_pad_x", pad / seg_size.y)
			smat.set_shader_parameter("edge_pad_y", pad / seg_size.x)
		seg_rect.material = smat
		root_node.add_child(seg_rect)


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


static func update_bar_bezel(entry: Dictionary, seg: int) -> void:
	## Update bezel shader to match new segment count + bar size.
	var smat: ShaderMaterial = entry.get("bezel_mat") as ShaderMaterial
	if not smat:
		return
	var bar: ProgressBar = entry["bar"]
	var bezel_pad: float = float(entry.get("bezel_pad", 6.0))
	smat.set_shader_parameter("segment_count", int(seg))
	if bar.material is ShaderMaterial:
		var bar_mat: ShaderMaterial = bar.material as ShaderMaterial
		smat.set_shader_parameter("segment_gap", bar_mat.get_shader_parameter("segment_gap"))
	# Deferred: compute edge padding from bar's ACTUAL rendered size (not minimum).
	# The container may stretch the bar beyond its minimum, and the bezel rect
	# auto-sizes via anchors to match — so edge_pad must use the real size.
	var pad_val: float = bezel_pad
	var mat_ref: ShaderMaterial = smat
	var bar_ref: ProgressBar = bar
	(func() -> void:
		if not is_instance_valid(bar_ref):
			return
		var rect_h: float = bar_ref.size.y + pad_val * 2.0
		var rect_w: float = bar_ref.size.x + pad_val * 2.0
		if rect_h > 0.0 and rect_w > 0.0:
			mat_ref.set_shader_parameter("edge_pad_x", pad_val / rect_h)
			mat_ref.set_shader_parameter("edge_pad_y", pad_val / rect_w)
	).call_deferred()


static func apply_bar_label_theme(lbl: Label, color: Color, font: Font, size: int) -> void:
	## Font + HDR color + glow shader on a bar label — replacement aesthetic.
	lbl.add_theme_font_size_override("font_size", size)
	# HDR color for bloom glow (1.5x multiplier)
	var hdr_color := Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	lbl.add_theme_color_override("font_color", hdr_color)
	if font:
		lbl.add_theme_font_override("font", font)
	# Glow shader with soft aura + bloom
	var glow_shader: Shader = load("res://assets/shaders/text_glow.gdshader") as Shader
	if glow_shader:
		var mat: ShaderMaterial
		if lbl.material is ShaderMaterial:
			mat = lbl.material as ShaderMaterial
		else:
			mat = ShaderMaterial.new()
			mat.shader = glow_shader
			lbl.material = mat
		mat.set_shader_parameter("aura_size", 3.0)
		mat.set_shader_parameter("aura_intensity", 0.8)
		mat.set_shader_parameter("bloom_size", 6.0)
		mat.set_shader_parameter("bloom_intensity", 0.4)


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
