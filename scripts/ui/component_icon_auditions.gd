extends MarginContainer
## Component Icon auditions — 64px icons for weapons, field emitters, and power cores.
## Per-icon HDR sliders. Weapons show doubled projectiles for mirror/dual fire patterns.
## Power cores show all design variants in a catalog row for assignment.

const ICON_SIZE: int = 64
const BG_COLOR := Color(0.02, 0.02, 0.04)
const SECTION_GAP: int = 24
const ITEM_GAP: int = 12
const LABEL_COLOR := Color(0.5, 0.5, 0.6)
const NAME_COLOR := Color(0.7, 0.85, 1.0)

# Per-icon HDR tracking
var _icon_entries: Array[Dictionary] = []
var _icon_names: Array[String] = []
var _icon_sliders: Array[HSlider] = []

var _scroll: ScrollContainer
var _root_vbox: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	# Toolbar
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	outer.add_child(bar)

	var print_btn := Button.new()
	print_btn.text = "PRINT HDR VALUES"
	ThemeManager.apply_button_style(print_btn)
	print_btn.pressed.connect(_print_hdr_values)
	bar.add_child(print_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_scroll)

	_root_vbox = VBoxContainer.new()
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", SECTION_GAP)
	_scroll.add_child(_root_vbox)

	_build_weapon_icons()
	_build_field_emitter_icons()
	_build_power_core_icons()


func _print_hdr_values() -> void:
	print("── ICON HDR VALUES ──")
	for i in _icon_names.size():
		var val: float = _icon_sliders[i].value
		if not is_equal_approx(val, 1.0):
			print("  %s: %.2f" % [_icon_names[i], val])
	print("── END ──")


# ── Per-icon HDR slider ─────────────────────────────────────────────

func _add_icon_hdr_slider(parent: HBoxContainer, entry_index: int, initial: float, icon_name: String) -> void:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 5.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(80, 0)
	parent.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % initial
	val_lbl.custom_minimum_size.x = 36
	val_lbl.add_theme_color_override("font_color", LABEL_COLOR)
	val_lbl.add_theme_font_size_override("font_size", 11)
	parent.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		_apply_icon_hdr(entry_index, v))

	_icon_names.append(icon_name)
	_icon_sliders.append(slider)


func _apply_icon_hdr(entry_index: int, mult: float) -> void:
	var entry: Dictionary = _icon_entries[entry_index]
	# Weapon/beam shader materials — scale weapon_color
	var weapon_mats: Array = entry.get("weapon_mats", []) as Array
	var weapon_base_colors: Array = entry.get("weapon_base_colors", []) as Array
	for i in weapon_mats.size():
		var mat: ShaderMaterial = weapon_mats[i] as ShaderMaterial
		var base_col: Color = weapon_base_colors[i] as Color
		var scaled := Color(base_col.r * mult, base_col.g * mult, base_col.b * mult, base_col.a)
		mat.set_shader_parameter("weapon_color", scaled)
	# Field shader materials — scale brightness
	var materials: Array = entry.get("materials", []) as Array
	var mat_bases: Array = entry.get("mat_base_values", []) as Array
	for i in materials.size():
		var mat: ShaderMaterial = materials[i] as ShaderMaterial
		var base: float = mat_bases[i] as float
		mat.set_shader_parameter("brightness", base * mult)
	# Power core devices
	var devices: Array = entry.get("devices", []) as Array
	for device in devices:
		device.hdr_mult = mult
		device.queue_redraw()


# ── Weapons ──────────────────────────────────────────────────────────

func _build_weapon_icons() -> void:
	var weapons: Array[WeaponData] = WeaponDataManager.load_all()
	if weapons.is_empty():
		return

	var player_weapons: Array[WeaponData] = []
	for w in weapons:
		if not w.id.begins_with("enemy_"):
			player_weapons.append(w)
	if player_weapons.is_empty():
		return

	var section := _make_section("WEAPON ICONS")

	for weapon in player_weapons:
		var is_beam: bool = weapon.beam_style_id != ""
		var is_double: bool = (weapon.mirror_mode == "mirror" or weapon.fire_pattern == "dual") and weapon.id != "laser_turret"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ITEM_GAP)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		section.add_child(row)

		# Name label
		var name_lbl := Label.new()
		name_lbl.text = weapon.display_name
		name_lbl.custom_minimum_size.x = 180
		name_lbl.add_theme_color_override("font_color", NAME_COLOR)
		name_lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(name_lbl)

		# Type tag
		var tags: String = ("BEAM" if is_beam else "PROJ") + (" x2" if is_double else "")
		var type_lbl := Label.new()
		type_lbl.text = tags
		type_lbl.custom_minimum_size.x = 70
		type_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		type_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(type_lbl)

		# Icon cell
		var cell := _make_icon_cell(ICON_SIZE)
		row.add_child(cell)

		# Register HDR entry for this icon
		var entry_idx: int = _icon_entries.size()
		_icon_entries.append({"weapon_mats": [], "weapon_base_colors": [], "materials": [], "mat_base_values": [], "devices": []})

		if is_beam:
			var style: BeamStyle = BeamStyleManager.load_by_id(weapon.beam_style_id)
			if style:
				_add_beam_icon(cell, style, is_double, entry_idx)
		else:
			var style: ProjectileStyle = ProjectileStyleManager.load_by_id(weapon.projectile_style_id)
			if style:
				var rot: float = deg_to_rad(90.0) if weapon.id == "broadside_pulse" else 0.0
				_add_projectile_icon(cell, style, weapon, is_double, entry_idx, rot)

		# HDR slider
		_add_icon_hdr_slider(row, entry_idx, 1.0, weapon.id)


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
		type_lbl.custom_minimum_size.x = 70
		type_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		type_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(type_lbl)

		var cell := _make_icon_cell(ICON_SIZE)
		row.add_child(cell)

		var entry_idx: int = _icon_entries.size()
		_icon_entries.append({"weapon_mats": [], "weapon_base_colors": [], "materials": [], "mat_base_values": [], "devices": []})

		if emitter.field_style_id != "":
			var style: FieldStyle = FieldStyleManager.load_by_id(emitter.field_style_id)
			if style:
				_add_field_icon(cell, style, entry_idx)

		_add_icon_hdr_slider(row, entry_idx, 1.0, emitter.id)


# ── Power Cores ──────────────────────────────────────────────────────

const CORE_VARIANT_NAMES: Array[String] = [
	"REACTOR", "CELL", "PISTON", "CRYSTAL", "COIL", "CAPSULE", "TURBINE", "CONDUIT",
]

func _build_power_core_icons() -> void:
	var cores: Array[PowerCoreData] = PowerCoreDataManager.load_all()
	if cores.is_empty():
		return

	var section := _make_section("POWER CORE ICONS")

	# ── Design catalog row (all 8 variants, no specific core) ──
	var catalog_header := Label.new()
	catalog_header.text = "DESIGN CATALOG"
	catalog_header.add_theme_color_override("font_color", LABEL_COLOR)
	catalog_header.add_theme_font_size_override("font_size", 12)
	section.add_child(catalog_header)

	var catalog_row := HBoxContainer.new()
	catalog_row.add_theme_constant_override("separation", ITEM_GAP)
	section.add_child(catalog_row)

	# Use first core for glow color reference in catalog
	var ref_core: PowerCoreData = cores[0]
	for variant_idx in CORE_VARIANT_NAMES.size():
		var wrap := VBoxContainer.new()
		wrap.add_theme_constant_override("separation", 2)
		catalog_row.add_child(wrap)

		var vlbl := Label.new()
		vlbl.text = CORE_VARIANT_NAMES[variant_idx]
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vlbl.add_theme_color_override("font_color", LABEL_COLOR)
		vlbl.add_theme_font_size_override("font_size", 10)
		wrap.add_child(vlbl)

		var cell := _make_icon_cell(ICON_SIZE)
		wrap.add_child(cell)
		_add_power_core_device(cell, ref_core, variant_idx, -1)

	section.add_child(HSeparator.new())

	# ── Per-core assigned icons ──
	# core_id -> variant index
	var core_assignments: Dictionary = {
		"beam_fractal_chamber": 0,  # REACTOR
		"fiddyfiddy": 2,            # PISTON
		"low_key_core": 4,          # COIL
		"orbix80t": 6,              # TURBINE
		"p23cold": 5,               # CAPSULE
		"radial_burst_core": 3,     # CRYSTAL
	}

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

		var assigned_variant: int = core_assignments.get(core.id, 0) as int
		var variant_lbl := Label.new()
		variant_lbl.text = CORE_VARIANT_NAMES[assigned_variant]
		variant_lbl.custom_minimum_size.x = 70
		variant_lbl.add_theme_color_override("font_color", LABEL_COLOR)
		variant_lbl.add_theme_font_size_override("font_size", 12)
		row.add_child(variant_lbl)

		var entry_idx: int = _icon_entries.size()
		_icon_entries.append({"weapon_mats": [], "weapon_base_colors": [], "materials": [], "mat_base_values": [], "devices": []})

		var cell := _make_icon_cell(ICON_SIZE)
		row.add_child(cell)
		_add_power_core_device(cell, core, assigned_variant, entry_idx)

		_add_icon_hdr_slider(row, entry_idx, 1.0, core.id)


func _add_power_core_device(cell: Control, core: PowerCoreData, variant: int, entry_idx: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport

	var device := _PowerCoreDevice.new()
	device.core = core
	device.icon_size = ICON_SIZE
	device.variant = variant
	device.hdr_mult = 1.0
	device.position = Vector2(float(ICON_SIZE) / 2.0, float(ICON_SIZE) / 2.0)
	vp.add_child(device)

	if entry_idx >= 0:
		_icon_entries[entry_idx]["devices"].append(device)


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


func _make_icon_cell(sz: int) -> Control:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = Vector2(sz, sz)
	wrapper.size = Vector2(sz, sz)

	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(sz, sz)
	vpc.size = Vector2(sz, sz)
	wrapper.add_child(vpc)

	var vp := SubViewport.new()
	vp.transparent_bg = false
	vp.size = Vector2i(sz, sz)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)
	VFXFactory.add_bloom_to_viewport(vp)

	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	var border := _IconBorder.new()
	border.icon_size = sz
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(border)

	return wrapper




# ── Projectile Icon ─────────────────────────────────────────────────

func _add_projectile_icon(cell: Control, style: ProjectileStyle, weapon: WeaponData, is_double: bool, entry_idx: int, icon_rotation: float = 0.0) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport
	var sz: float = float(ICON_SIZE)

	# Determine how many to draw and spacing
	var count: int = 2 if is_double else 1
	# If rotated, swap dimensions for fitting calculation
	var vis_w: float = style.base_scale.x if is_zero_approx(icon_rotation) else style.base_scale.y
	var vis_h: float = style.base_scale.y if is_zero_approx(icon_rotation) else style.base_scale.x
	var aspect: float = vis_h / maxf(vis_w, 1.0)

	# For long/thin projectiles (aspect > 1.8), shrink vertically so they don't look like beams
	var padding: float = 8.0
	var target: float = sz - padding * 2.0
	var scale_x: float = target / maxf(vis_w, 1.0)
	var scale_y: float = target / maxf(vis_h, 1.0)
	var fit_scale: float = minf(scale_x, scale_y)

	if aspect > 1.8:
		var max_h: float = sz * 0.55
		var proj_h: float = vis_h * fit_scale
		if proj_h > max_h:
			fit_scale = max_h / vis_h

	# For double projectiles, shrink slightly and offset horizontally
	var x_offset: float = 0.0
	if count == 2:
		fit_scale *= 0.75
		x_offset = sz * 0.14

	for i in count:
		var sprite: Sprite2D = VFXFactory.create_styled_sprite(style, style.color)
		if not sprite:
			continue
		sprite.scale = Vector2(fit_scale, fit_scale)
		sprite.rotation = icon_rotation
		var x_pos: float = sz / 2.0
		if count == 2:
			x_pos = sz / 2.0 + (x_offset if i == 1 else -x_offset)
		sprite.position = Vector2(x_pos, sz / 2.0)

		# Track shader material for HDR via weapon_color scaling
		if sprite.material is ShaderMaterial:
			_icon_entries[entry_idx]["weapon_mats"].append(sprite.material)
			_icon_entries[entry_idx]["weapon_base_colors"].append(style.color)
		vp.add_child(sprite)


# ── Beam Icon ────────────────────────────────────────────────────────

func _add_beam_icon(cell: Control, style: BeamStyle, is_double: bool, entry_idx: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport
	var sz: int = ICON_SIZE

	var count: int = 2 if is_double else 1
	var beam_w: int = maxi(int(clampf(style.beam_width, 4.0, float(sz) * 0.4)), 4)
	var beam_h: int = maxi(sz - 16, 4)

	if count == 2:
		beam_w = maxi(int(float(beam_w) * 0.7), 3)

	var x_offset: float = 0.0
	if count == 2:
		x_offset = float(sz) * 0.14

	for i in count:
		var img := Image.create(beam_w, beam_h, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)

		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(img)
		var x_pos: float = float(sz) / 2.0
		if count == 2:
			x_pos = float(sz) / 2.0 + (x_offset if i == 1 else -x_offset)
		sprite.position = Vector2(x_pos, float(sz) / 2.0)

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

		# Track shader material for HDR via weapon_color scaling
		if sprite.material is ShaderMaterial:
			_icon_entries[entry_idx]["weapon_mats"].append(sprite.material)
			_icon_entries[entry_idx]["weapon_base_colors"].append(style.color)
		vp.add_child(sprite)


# ── Field Icon ───────────────────────────────────────────────────────

func _add_field_icon(cell: Control, style: FieldStyle, entry_idx: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport

	var tex_size: int = maxi(ICON_SIZE - 4, 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(float(ICON_SIZE) / 2.0, float(ICON_SIZE) / 2.0)

	var mat: ShaderMaterial = VFXFactory.create_field_material(style, float(tex_size) / 2.0)
	mat.set_shader_parameter("brightness", style.glow_intensity)
	sprite.material = mat
	_icon_entries[entry_idx]["materials"].append(mat)
	_icon_entries[entry_idx]["mat_base_values"].append(style.glow_intensity)
	vp.add_child(sprite)


# ── Power Core Device (chrome tech component) ───────────────────────

class _PowerCoreDevice extends Node2D:
	var core: PowerCoreData
	var icon_size: int = 64
	var variant: int = 0
	var hdr_mult: float = 1.0

	const CD := Color(0.12, 0.13, 0.18)
	const CM := Color(0.30, 0.32, 0.38)
	const CL := Color(0.55, 0.58, 0.65)
	const CB := Color(0.80, 0.83, 0.90)
	const CS := Color(1.0, 1.0, 1.0, 0.7)

	func _get_glow_color() -> Color:
		var best_type: String = "shield"
		var best_val: float = 0.0
		for bar_type in ["shield", "hull", "thermal", "electric"]:
			var v: float = absf(float(core.passive_effects.get(bar_type, 0.0)))
			var triggers: Array = core.pulse_triggers.get(bar_type, []) as Array
			v += float(triggers.size()) * 0.5
			if v > best_val:
				best_val = v
				best_type = bar_type
		match best_type:
			"shield": return Color(0.3, 0.55, 1.0)
			"hull": return Color(0.2, 0.9, 0.35)
			"thermal": return Color(1.0, 0.4, 0.1)
			"electric": return Color(0.9, 0.75, 0.15)
		return Color(0.4, 0.6, 1.0)

	func _draw() -> void:
		if not core:
			return
		match variant:
			0: _draw_reactor()
			1: _draw_cell()
			2: _draw_piston()
			3: _draw_crystal()
			4: _draw_coil()
			5: _draw_capsule()
			6: _draw_turbine()
			7: _draw_conduit()

	func _s(v: float) -> float:
		return v * float(icon_size) / 48.0

	func _chrome_fill(rect: Rect2) -> void:
		draw_rect(rect, CD)
		var bands: Array[Color] = [CD.lerp(CM, 0.3), CM, CL, CB]
		var h: float = rect.size.y
		for i in bands.size():
			var t0: float = float(i) / float(bands.size())
			var t1: float = float(i + 1) / float(bands.size())
			var y0: float = rect.position.y + rect.size.y - t0 * h
			var y1: float = rect.position.y + rect.size.y - t1 * h
			var band := Rect2(rect.position.x, minf(y0, y1), rect.size.x, absf(y0 - y1))
			draw_rect(band, bands[i])

	func _chrome_edges(rect: Rect2) -> void:
		var tl := rect.position
		var br := rect.position + rect.size
		var tr := Vector2(br.x, tl.y)
		var bl := Vector2(tl.x, br.y)
		draw_line(tl, tr, CL, 1.0, true)
		draw_line(tl, bl, CM, 1.0, true)
		draw_line(bl, br, CD, 1.0, true)
		draw_line(tr, br, CD, 1.0, true)

	func _chrome_rect(rect: Rect2) -> void:
		_chrome_fill(rect)
		_chrome_edges(rect)

	func _glow_rect(rect: Rect2, col: Color) -> void:
		var m: float = 2.0 * hdr_mult
		var hdr := Color(col.r * m, col.g * m, col.b * m, 0.85)
		draw_rect(rect, hdr)
		var inner := rect.grow(-maxf(_s(1.5), 1.0))
		if inner.size.x > 0.0 and inner.size.y > 0.0:
			var mc: float = 3.5 * hdr_mult
			draw_rect(inner, Color(col.r * mc, col.g * mc, col.b * mc, 0.6))

	func _glow_circle(center: Vector2, radius: float, col: Color) -> void:
		var m: float = 2.0 * hdr_mult
		var hdr := Color(col.r * m, col.g * m, col.b * m, 0.85)
		draw_circle(center, radius, hdr)
		var mc: float = 3.5 * hdr_mult
		draw_circle(center, radius * 0.5, Color(col.r * mc, col.g * mc, col.b * mc, 0.6))

	func _specular_line(rect: Rect2) -> void:
		var cx: float = rect.position.x + rect.size.x * 0.5
		var top: float = rect.position.y + _s(2.0)
		var bot: float = rect.position.y + rect.size.y - _s(2.0)
		draw_line(Vector2(cx, top), Vector2(cx, bot), CS, maxf(_s(0.8), 0.5), true)

	func _draw_reactor() -> void:
		var w: float = _s(24.0)
		var h: float = _s(38.0)
		var gc := _get_glow_color()
		var body := Rect2(-w / 2.0, -h / 2.0, w, h)
		_chrome_rect(body)
		var cap_h: float = _s(5.0)
		var cap_w: float = w + _s(4.0)
		_chrome_rect(Rect2(-cap_w / 2.0, -h / 2.0, cap_w, cap_h))
		_chrome_rect(Rect2(-cap_w / 2.0, h / 2.0 - cap_h, cap_w, cap_h))
		# Mid chrome dividers above and below glow window
		_chrome_rect(Rect2(-w / 2.0, -_s(6.0), w, _s(2.0)))
		_chrome_rect(Rect2(-w / 2.0, _s(4.0), w, _s(2.0)))
		# Compact glow window
		var gw: float = w - _s(10.0)
		var gh: float = _s(8.0)
		_glow_rect(Rect2(-gw / 2.0, -gh / 2.0, gw, gh), gc)
		# Rivets
		draw_circle(Vector2(-w / 2.0 + _s(3.0), -h / 2.0 + _s(3.0)), _s(1.2), CM)
		draw_circle(Vector2(w / 2.0 - _s(3.0), -h / 2.0 + _s(3.0)), _s(1.2), CM)
		draw_circle(Vector2(-w / 2.0 + _s(3.0), h / 2.0 - _s(3.0)), _s(1.2), CM)
		draw_circle(Vector2(w / 2.0 - _s(3.0), h / 2.0 - _s(3.0)), _s(1.2), CM)
		_specular_line(body)

	func _draw_cell() -> void:
		var w: float = _s(20.0)
		var h: float = _s(36.0)
		var gc := _get_glow_color()
		var nub_w: float = _s(8.0)
		_chrome_rect(Rect2(-nub_w / 2.0, -h / 2.0 - _s(3.0), nub_w, _s(4.0)))
		_chrome_rect(Rect2(-w / 2.0, -h / 2.0, w, h))
		# Smaller glow slots
		var seg_h: float = _s(3.0)
		var seg_w: float = w - _s(8.0)
		var gap: float = _s(8.0)
		for i in 3:
			var y: float = -h / 2.0 + _s(7.0) + float(i) * gap
			_glow_rect(Rect2(-seg_w / 2.0, y, seg_w, seg_h), gc)
		_chrome_rect(Rect2(-w / 2.0 - _s(2.5), -_s(4.0), _s(2.5), _s(8.0)))
		_chrome_rect(Rect2(w / 2.0, -_s(4.0), _s(2.5), _s(8.0)))
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	func _draw_piston() -> void:
		var w: float = _s(18.0)
		var h: float = _s(32.0)
		var gc := _get_glow_color()
		_chrome_rect(Rect2(-w / 2.0, -h / 2.0, w, h))
		var rod_w: float = _s(4.0)
		_chrome_rect(Rect2(-rod_w / 2.0, -h / 2.0 - _s(8.0), rod_w, _s(10.0)))
		_chrome_rect(Rect2(-_s(6.0), -h / 2.0 - _s(9.0), _s(12.0), _s(3.0)))
		# Narrow glow slit near top
		_glow_rect(Rect2(-w / 2.0 + _s(3.0), -h / 2.0 + _s(4.0), w - _s(6.0), _s(2.5)), gc)
		# Small exhaust port glow
		_glow_rect(Rect2(-_s(3.5), h / 2.0 - _s(5.0), _s(7.0), _s(2.5)), gc)
		# Chrome mid-plate
		_chrome_rect(Rect2(-w / 2.0, -_s(2.0), w, _s(3.0)))
		var bolt_y: float = h / 2.0 - _s(2.0)
		draw_circle(Vector2(-w / 2.0 + _s(2.5), bolt_y), _s(1.5), CL)
		draw_circle(Vector2(w / 2.0 - _s(2.5), bolt_y), _s(1.5), CL)
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	func _draw_crystal() -> void:
		var gc := _get_glow_color()
		var bw: float = _s(26.0)
		var bh: float = _s(38.0)
		var rail: float = _s(5.0)
		# Thicker bracket frame — more chrome visible
		_chrome_rect(Rect2(-bw / 2.0, -bh / 2.0, rail, bh))
		_chrome_rect(Rect2(bw / 2.0 - rail, -bh / 2.0, rail, bh))
		_chrome_rect(Rect2(-bw / 2.0, bh / 2.0 - rail, bw, rail))
		_chrome_rect(Rect2(-bw / 2.0, -bh / 2.0, bw, rail))
		# Cross brace
		_chrome_rect(Rect2(-bw / 2.0, -_s(1.0), bw, _s(2.0)))
		# Narrower crystal shard
		var cx: float = 0.0
		var cy: float = -_s(2.0)
		var cw: float = _s(7.0)
		var ch: float = _s(18.0)
		var m: float = 2.5 * hdr_mult
		var hdr := Color(gc.r * m, gc.g * m, gc.b * m, 0.9)
		var crystal_pts := PackedVector2Array([
			Vector2(cx, cy - ch / 2.0),
			Vector2(cx + cw / 2.0, cy - ch * 0.15),
			Vector2(cx + cw / 2.0, cy + ch * 0.15),
			Vector2(cx, cy + ch / 2.0),
			Vector2(cx - cw / 2.0, cy + ch * 0.15),
			Vector2(cx - cw / 2.0, cy - ch * 0.15),
		])
		draw_colored_polygon(crystal_pts, hdr)
		var mc: float = 4.0 * hdr_mult
		draw_line(Vector2(cx, cy - ch / 2.0 + _s(2.0)), Vector2(cx, cy + ch / 2.0 - _s(2.0)),
			Color(gc.r * mc, gc.g * mc, gc.b * mc, 0.7), _s(1.5), true)

	func _draw_coil() -> void:
		var gc := _get_glow_color()
		# Thinner glow rod — more coil visible
		var rod_w: float = _s(3.5)
		var rod_h: float = _s(34.0)
		_glow_rect(Rect2(-rod_w / 2.0, -rod_h / 2.0, rod_w, rod_h), gc)
		# Wider, thicker coil windings for more chrome
		var coil_w: float = _s(22.0)
		var coil_h: float = _s(4.0)
		var coil_count: int = 6
		var spacing: float = (rod_h - _s(6.0)) / float(coil_count - 1)
		for i in coil_count:
			var y: float = -rod_h / 2.0 + _s(3.0) + float(i) * spacing - coil_h / 2.0
			_chrome_rect(Rect2(-coil_w / 2.0, y, coil_w, coil_h))
		# Thicker caps
		_chrome_rect(Rect2(-_s(11.0), -rod_h / 2.0 - _s(4.0), _s(22.0), _s(5.0)))
		_chrome_rect(Rect2(-_s(11.0), rod_h / 2.0 - _s(1.0), _s(22.0), _s(5.0)))

	func _draw_capsule() -> void:
		var gc := _get_glow_color()
		var w: float = _s(20.0)
		var h: float = _s(36.0)
		var r: float = w / 2.0
		_chrome_rect(Rect2(-w / 2.0, -h / 2.0 + r, w, h - w))
		draw_circle(Vector2(0.0, -h / 2.0 + r), r, CM)
		draw_arc(Vector2(0.0, -h / 2.0 + r), r, 0.0, TAU, 24, CL, 1.0)
		draw_circle(Vector2(0.0, h / 2.0 - r), r, CD)
		draw_arc(Vector2(0.0, h / 2.0 - r), r, 0.0, TAU, 24, CM, 1.0)
		# Smaller viewport window
		_glow_circle(Vector2(0.0, -_s(3.0)), _s(4.0), gc)
		# Tiny status light
		_glow_circle(Vector2(0.0, h / 2.0 - r - _s(2.0)), _s(1.5), gc)
		# Chrome bands
		_chrome_rect(Rect2(-w / 2.0 - _s(2.0), -_s(1.5), w + _s(4.0), _s(3.0)))
		_chrome_rect(Rect2(-w / 2.0 - _s(1.0), _s(5.0), w + _s(2.0), _s(2.0)))
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	func _draw_turbine() -> void:
		var gc := _get_glow_color()
		var outer_r: float = _s(18.0)
		var inner_r: float = _s(5.0)  # Smaller core
		# Thicker outer housing
		draw_circle(Vector2.ZERO, outer_r, CD)
		draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 32, CL, _s(4.0))
		draw_arc(Vector2.ZERO, outer_r - _s(3.5), 0.0, TAU, 32, CM, _s(1.5))
		# Compact glowing core
		_glow_circle(Vector2.ZERO, inner_r, gc)
		# Wider chrome blades
		var blade_count: int = 8
		for i in blade_count:
			var angle: float = float(i) / float(blade_count) * TAU - PI / 2.0
			var from_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (inner_r + _s(1.0))
			var to_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (outer_r - _s(3.0))
			draw_line(from_pt, to_pt, CL, _s(3.0), true)
			draw_line(from_pt, to_pt, CB, _s(1.2), true)
		# Subtle glow ring between blades
		var m: float = 1.2 * hdr_mult
		var glow := Color(gc.r * m, gc.g * m, gc.b * m, 0.25)
		draw_arc(Vector2.ZERO, (inner_r + outer_r) * 0.5, 0.0, TAU, 32, glow, _s(2.0))
		# Center bolt
		draw_circle(Vector2.ZERO, _s(2.5), CB)
		draw_circle(Vector2.ZERO, _s(1.5), CS)

	func _draw_conduit() -> void:
		var gc := _get_glow_color()
		var pipe_w: float = _s(14.0)  # Wider pipe = more chrome
		var pipe_h: float = _s(40.0)
		_chrome_rect(Rect2(-pipe_w / 2.0, -pipe_h / 2.0, pipe_w, pipe_h))
		# Thicker flanges
		var flange_w: float = pipe_w + _s(8.0)
		var flange_h: float = _s(4.0)
		var flange_positions: Array[float] = [-pipe_h / 2.0, -_s(8.0), _s(6.0), pipe_h / 2.0 - flange_h]
		for fy in flange_positions:
			_chrome_rect(Rect2(-flange_w / 2.0, fy, flange_w, flange_h))
		# Narrow glow slits between flanges
		var glow_w: float = pipe_w - _s(8.0)
		_glow_rect(Rect2(-glow_w / 2.0, -pipe_h / 2.0 + _s(5.0), glow_w, _s(4.0)), gc)
		_glow_rect(Rect2(-glow_w / 2.0, -_s(3.0), glow_w, _s(4.0)), gc)
		_glow_rect(Rect2(-glow_w / 2.0, _s(11.0), glow_w, _s(3.0)), gc)
		# Side inlet stubs
		_chrome_rect(Rect2(-flange_w / 2.0 - _s(4.0), -_s(10.0), _s(4.0), _s(4.0)))
		_chrome_rect(Rect2(flange_w / 2.0, _s(4.0), _s(4.0), _s(4.0)))
		_specular_line(Rect2(-pipe_w / 2.0, -pipe_h / 2.0, pipe_w, pipe_h))


# ── Border overlay ──────────────────────────────────────────────────

class _IconBorder extends Control:
	var icon_size: int = 64

	func _draw() -> void:
		var sz: float = float(icon_size)
		var thick: float = maxf(sz / 16.0, 1.5)
		var half: float = thick / 2.0
		var dark := Color(0.15, 0.15, 0.2, 0.9)
		draw_rect(Rect2(half, half, sz - thick, sz - thick), dark, false, thick)
		var highlight := Color(0.45, 0.5, 0.6, 0.7)
		var inner_off: float = thick
		draw_line(Vector2(inner_off, inner_off), Vector2(sz - inner_off, inner_off), highlight, maxf(thick * 0.5, 1.0))
		draw_line(Vector2(inner_off, inner_off), Vector2(inner_off, sz - inner_off), highlight, maxf(thick * 0.5, 1.0))
		var shadow := Color(0.05, 0.05, 0.08, 0.8)
		draw_line(Vector2(sz - inner_off, inner_off), Vector2(sz - inner_off, sz - inner_off), shadow, maxf(thick * 0.5, 1.0))
		draw_line(Vector2(inner_off, sz - inner_off), Vector2(sz - inner_off, sz - inner_off), shadow, maxf(thick * 0.5, 1.0))
