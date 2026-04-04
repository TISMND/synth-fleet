extends MarginContainer
## Component Icon auditions — test tiny square icons for weapons, field emitters, and power cores.
## Shows multiple icon sizes and rendering approaches side by side for comparison.

const ICON_SIZES: Array[int] = [24, 32, 48, 64]
const BG_COLOR := Color(0.02, 0.02, 0.04)
const SECTION_GAP: int = 24
const ITEM_GAP: int = 12
const LABEL_COLOR := Color(0.5, 0.5, 0.6)
const NAME_COLOR := Color(0.7, 0.85, 1.0)

# Bar type colors for power core pie charts
const BAR_COLORS: Dictionary = {
	"shield": Color(0.3, 0.6, 1.0),
	"hull": Color(0.2, 0.9, 0.3),
	"thermal": Color(1.0, 0.4, 0.1),
	"electric": Color(0.9, 0.8, 0.2),
}

var _scroll: ScrollContainer
var _root_vbox: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_root_vbox = VBoxContainer.new()
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", SECTION_GAP)
	_scroll.add_child(_root_vbox)

	_build_weapon_icons()
	_build_field_emitter_icons()
	_build_power_core_icons()


# ── Weapons ──────────────────────────────────────────────────────────

func _build_weapon_icons() -> void:
	var weapons: Array[WeaponData] = WeaponDataManager.load_all()
	if weapons.is_empty():
		return

	var section := _make_section("WEAPON ICONS")

	for weapon in weapons:
		var is_beam: bool = weapon.beam_style_id != ""
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ITEM_GAP)
		section.add_child(row)

		# Name label (fixed width)
		var name_lbl := Label.new()
		name_lbl.text = weapon.display_name
		name_lbl.custom_minimum_size.x = 180
		name_lbl.add_theme_color_override("font_color", NAME_COLOR)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		# Type tag
		var type_lbl := Label.new()
		type_lbl.text = "BEAM" if is_beam else "PROJ"
		type_lbl.custom_minimum_size.x = 50
		type_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		type_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(type_lbl)

		# Icons at each size
		for sz in ICON_SIZES:
			var cell := _make_icon_cell(sz)
			row.add_child(cell)

			if is_beam:
				var style: BeamStyle = BeamStyleManager.load_by_id(weapon.beam_style_id)
				if style:
					_add_beam_icon(cell, style, sz)
			else:
				var style: ProjectileStyle = ProjectileStyleManager.load_by_id(weapon.projectile_style_id)
				if style:
					_add_projectile_icon(cell, style, sz)

		# Size labels
		var sizes_lbl := Label.new()
		sizes_lbl.text = "  ".join(ICON_SIZES.map(func(s: int) -> String: return "%dpx" % s))
		sizes_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		sizes_lbl.add_theme_font_size_override("font_size", 11)
		row.add_child(sizes_lbl)


# ── Field Emitters ───────────────────────────────────────────────────

func _build_field_emitter_icons() -> void:
	var emitters: Array[DeviceData] = FieldEmitterDataManager.load_all()
	if emitters.is_empty():
		return

	var section := _make_section("FIELD EMITTER ICONS")

	for emitter in emitters:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ITEM_GAP)
		section.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = emitter.display_name
		name_lbl.custom_minimum_size.x = 180
		name_lbl.add_theme_color_override("font_color", NAME_COLOR)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		var type_lbl := Label.new()
		type_lbl.text = "FIELD"
		type_lbl.custom_minimum_size.x = 50
		type_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		type_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(type_lbl)

		for sz in ICON_SIZES:
			var cell := _make_icon_cell(sz)
			row.add_child(cell)

			if emitter.field_style_id != "":
				var style: FieldStyle = FieldStyleManager.load_by_id(emitter.field_style_id)
				if style:
					_add_field_icon(cell, style, sz)


# ── Power Cores ──────────────────────────────────────────────────────

func _build_power_core_icons() -> void:
	var cores: Array[PowerCoreData] = PowerCoreDataManager.load_all()
	if cores.is_empty():
		return

	var section := _make_section("POWER CORE ICONS")

	for core in cores:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ITEM_GAP)
		section.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = core.display_name
		name_lbl.custom_minimum_size.x = 180
		name_lbl.add_theme_color_override("font_color", NAME_COLOR)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		var type_lbl := Label.new()
		type_lbl.text = "CORE"
		type_lbl.custom_minimum_size.x = 50
		type_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		type_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(type_lbl)

		for sz in ICON_SIZES:
			var cell := _make_icon_cell(sz)
			row.add_child(cell)
			_add_power_core_icon(cell, core, sz)


# ── Helpers ──────────────────────────────────────────────────────────

func _make_section(title: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_root_vbox.add_child(section)

	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	ThemeManager.apply_text_glow(lbl, "header")
	section.add_child(lbl)

	section.add_child(HSeparator.new())
	return section


func _make_icon_cell(sz: int) -> SubViewportContainer:
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(sz, sz)
	vpc.size = Vector2(sz, sz)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(sz, sz)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	# Dark background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	return vpc


# ── Projectile Icon ─────────────────────────────────────────────────

func _add_projectile_icon(cell: SubViewportContainer, style: ProjectileStyle, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0) as SubViewport
	var sprite: Sprite2D = VFXFactory.create_styled_sprite(style, style.color)
	if not sprite:
		return

	# Scale the projectile to fit the icon with padding
	var padding: float = 4.0
	var target: float = float(sz) - padding * 2.0
	var scale_x: float = target / maxf(style.base_scale.x, 1.0)
	var scale_y: float = target / maxf(style.base_scale.y, 1.0)
	var fit_scale: float = minf(scale_x, scale_y)
	sprite.scale = Vector2(fit_scale, fit_scale)
	sprite.position = Vector2(float(sz) / 2.0, float(sz) / 2.0)

	# HDR boost for bloom pickup
	sprite.modulate = Color(style.glow_intensity, style.glow_intensity, style.glow_intensity)

	vp.add_child(sprite)


# ── Beam Icon ────────────────────────────────────────────────────────

func _add_beam_icon(cell: SubViewportContainer, style: BeamStyle, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0) as SubViewport

	# Create beam sprite — short vertical strip centered in icon
	var beam_w: int = maxi(int(clampf(style.beam_width, 4.0, float(sz) * 0.6)), 4)
	var beam_h: int = maxi(sz - 8, 4)
	var img := Image.create(beam_w, beam_h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(float(sz) / 2.0, float(sz) / 2.0)

	# Apply fill shader
	var shader: Shader = VFXFactory.get_fill_shader(style.fill_shader)
	if shader:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = shader
		shader_mat.set_shader_parameter("weapon_color", style.color)
		for param_name in style.shader_params:
			shader_mat.set_shader_parameter(param_name, float(style.shader_params[param_name]))
		if style.fill_shader == "nebula_dual":
			shader_mat.set_shader_parameter("secondary_color", style.secondary_color)
		sprite.material = shader_mat

	sprite.flip_v = style.flip_shader
	sprite.modulate = Color(style.glow_intensity, style.glow_intensity, style.glow_intensity)
	vp.add_child(sprite)


# ── Field Icon ───────────────────────────────────────────────────────

func _add_field_icon(cell: SubViewportContainer, style: FieldStyle, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0) as SubViewport

	var tex_size: int = maxi(sz - 4, 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(float(sz) / 2.0, float(sz) / 2.0)

	var mat: ShaderMaterial = VFXFactory.create_field_material(style, float(tex_size) / 2.0)
	sprite.material = mat

	sprite.modulate = Color(style.glow_intensity, style.glow_intensity, style.glow_intensity)
	vp.add_child(sprite)


# ── Power Core Icon (pie chart) ──────────────────────────────────────

func _add_power_core_icon(cell: SubViewportContainer, core: PowerCoreData, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0) as SubViewport

	var pie := _PowerCorePie.new()
	pie.core = core
	pie.icon_size = sz
	pie.position = Vector2(float(sz) / 2.0, float(sz) / 2.0)
	vp.add_child(pie)


class _PowerCorePie extends Node2D:
	## Draws a pie chart showing passive_effects distribution across bar types.
	## Wedge size = magnitude of each bar type's passive effect.
	## Ring segments show pulse_trigger count per bar type.
	var core: PowerCoreData
	var icon_size: int = 48

	func _draw() -> void:
		if not core:
			return
		var radius: float = float(icon_size) / 2.0 - 3.0
		var center := Vector2.ZERO

		# Gather passive effect magnitudes for pie slices
		var slices: Array[Dictionary] = []
		var total_magnitude: float = 0.0
		for bar_type in ["shield", "hull", "thermal", "electric"]:
			var val: float = absf(float(core.passive_effects.get(bar_type, 0.0)))
			if val > 0.0:
				var col: Color = BAR_COLORS.get(bar_type, Color.WHITE) as Color
				slices.append({"type": bar_type, "value": val, "color": col})
				total_magnitude += val

		# Gather pulse trigger counts for ring segments
		var trigger_slices: Array[Dictionary] = []
		var total_triggers: int = 0
		for bar_type in ["shield", "hull", "thermal", "electric"]:
			var triggers: Array = core.pulse_triggers.get(bar_type, []) as Array
			if triggers.size() > 0:
				var col: Color = BAR_COLORS.get(bar_type, Color.WHITE) as Color
				trigger_slices.append({"type": bar_type, "count": triggers.size(), "color": col})
				total_triggers += triggers.size()

		# If we have passive effects, draw pie chart
		if total_magnitude > 0.0:
			var angle: float = -PI / 2.0  # Start from top
			for slice in slices:
				var sweep: float = float(slice["value"]) / total_magnitude * TAU
				_draw_pie_wedge(center, radius, angle, angle + sweep, slice["color"] as Color)
				angle += sweep

			# Inner ring showing trigger distribution
			if total_triggers > 0:
				var inner_r: float = radius * 0.45
				var outer_r: float = radius * 0.65
				var ring_angle: float = -PI / 2.0
				for ts in trigger_slices:
					var sweep: float = float(ts["count"]) / float(total_triggers) * TAU
					_draw_ring_segment(center, inner_r, outer_r, ring_angle, ring_angle + sweep, ts["color"] as Color)
					ring_angle += sweep
		elif total_triggers > 0:
			# No passive effects — just draw the trigger ring full size
			var angle: float = -PI / 2.0
			for ts in trigger_slices:
				var sweep: float = float(ts["count"]) / float(total_triggers) * TAU
				_draw_pie_wedge(center, radius, angle, angle + sweep, ts["color"] as Color)
				angle += sweep
		else:
			# Fallback: empty gray circle
			draw_circle(center, radius, Color(0.15, 0.15, 0.2))

		# Thin border
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.4, 0.4, 0.5, 0.6), 1.0)

	func _draw_pie_wedge(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color) -> void:
		var segments: int = maxi(int((end_angle - start_angle) / TAU * 48.0), 3)
		var points: PackedVector2Array = PackedVector2Array()
		points.append(center)
		for i in range(segments + 1):
			var a: float = start_angle + (end_angle - start_angle) * float(i) / float(segments)
			points.append(center + Vector2(cos(a), sin(a)) * radius)
		# HDR color for bloom
		var hdr := Color(color.r * 1.8, color.g * 1.8, color.b * 1.8, 0.9)
		draw_colored_polygon(points, hdr)

	func _draw_ring_segment(center: Vector2, inner_r: float, outer_r: float, start_angle: float, end_angle: float, color: Color) -> void:
		var segments: int = maxi(int((end_angle - start_angle) / TAU * 32.0), 3)
		var points: PackedVector2Array = PackedVector2Array()
		# Outer arc forward
		for i in range(segments + 1):
			var a: float = start_angle + (end_angle - start_angle) * float(i) / float(segments)
			points.append(center + Vector2(cos(a), sin(a)) * outer_r)
		# Inner arc backward
		for i in range(segments, -1, -1):
			var a: float = start_angle + (end_angle - start_angle) * float(i) / float(segments)
			points.append(center + Vector2(cos(a), sin(a)) * inner_r)
		var hdr := Color(color.r * 2.5, color.g * 2.5, color.b * 2.5, 1.0)
		draw_colored_polygon(points, hdr)
