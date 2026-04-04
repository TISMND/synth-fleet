extends MarginContainer
## Component Icon auditions — test tiny square icons for weapons, field emitters, and power cores.
## Shows multiple icon sizes and rendering approaches side by side for comparison.

const ICON_SIZES: Array[int] = [24, 32, 48, 64]
const BG_COLOR := Color(0.02, 0.02, 0.04)
const SECTION_GAP: int = 24
const ITEM_GAP: int = 12
const LABEL_COLOR := Color(0.5, 0.5, 0.6)
const NAME_COLOR := Color(0.7, 0.85, 1.0)

enum BorderStyle { NONE, CORNER_LINES, METAL_FRAME, NEON_OUTLINE }
const BORDER_NAMES: Array[String] = ["NONE", "CORNERS", "METAL", "NEON"]
var _current_border: BorderStyle = BorderStyle.NONE
var _all_cells: Array[Control] = []

# Per-section HDR multipliers and tracked sprites/pies for live update
var _hdr_weapons: float = 1.0
var _hdr_fields: float = 1.0
var _hdr_cores: float = 1.0
var _weapon_sprites: Array[Dictionary] = []   # {sprite, base_intensity}
var _field_materials: Array[Dictionary] = []   # {material, base_brightness}
var _core_pies: Array = []  # Array of _PowerCoreDevice

var _scroll: ScrollContainer
var _root_vbox: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(outer)

	# Border style selector
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	outer.add_child(bar)

	var bar_label := Label.new()
	bar_label.text = "BORDER:"
	bar_label.add_theme_color_override("font_color", LABEL_COLOR)
	bar_label.add_theme_font_size_override("font_size", 14)
	bar.add_child(bar_label)

	for i in BORDER_NAMES.size():
		var btn := Button.new()
		btn.text = BORDER_NAMES[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		ThemeManager.apply_button_style(btn)
		btn.pressed.connect(_on_border_selected.bind(i, bar))
		bar.add_child(btn)

	# HDR intensity sliders per section
	var hdr_bar := HBoxContainer.new()
	hdr_bar.add_theme_constant_override("separation", 16)
	outer.add_child(hdr_bar)

	_add_hdr_slider(hdr_bar, "WEAPONS", _hdr_weapons, func(v: float) -> void:
		_hdr_weapons = v
		_apply_hdr_to_sprites(_weapon_sprites, v))
	_add_hdr_slider(hdr_bar, "FIELDS", _hdr_fields, func(v: float) -> void:
		_hdr_fields = v
		_apply_hdr_to_field_materials(v))
	_add_hdr_slider(hdr_bar, "CORES", _hdr_cores, func(v: float) -> void:
		_hdr_cores = v
		for pie in _core_pies:
			pie.hdr_mult = v
			pie.queue_redraw())

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


func _add_hdr_slider(parent: HBoxContainer, label_text: String, initial: float, on_change: Callable) -> void:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	parent.add_child(wrap)

	var lbl := Label.new()
	lbl.text = label_text + " HDR:"
	lbl.add_theme_color_override("font_color", LABEL_COLOR)
	lbl.add_theme_font_size_override("font_size", 12)
	wrap.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 5.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size.x = 120
	wrap.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % initial
	val_lbl.custom_minimum_size.x = 40
	val_lbl.add_theme_color_override("font_color", NAME_COLOR)
	val_lbl.add_theme_font_size_override("font_size", 12)
	wrap.add_child(val_lbl)

	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%.2f" % v
		on_change.call(v))


func _apply_hdr_to_sprites(entries: Array[Dictionary], mult: float) -> void:
	for entry in entries:
		var sprite: CanvasItem = entry["sprite"] as CanvasItem
		var base: float = entry["base_intensity"] as float
		var val: float = base * mult
		sprite.modulate = Color(val, val, val)


func _apply_hdr_to_field_materials(mult: float) -> void:
	for entry in _field_materials:
		var mat: ShaderMaterial = entry["material"] as ShaderMaterial
		var base: float = entry["base_brightness"] as float
		mat.set_shader_parameter("brightness", base * mult)


func _on_border_selected(index: int, bar: HBoxContainer) -> void:
	_current_border = index as BorderStyle
	# Update toggle states
	for i in range(1, bar.get_child_count()):
		var btn: Button = bar.get_child(i) as Button
		btn.set_pressed_no_signal(i - 1 == index)
	# Redraw all border overlays
	for cell in _all_cells:
		_update_border_overlay(cell)


# ── Weapons ──────────────────────────────────────────────────────────

func _build_weapon_icons() -> void:
	var weapons: Array[WeaponData] = WeaponDataManager.load_all()
	if weapons.is_empty():
		return

	# Filter out enemy weapons
	var player_weapons: Array[WeaponData] = []
	for w in weapons:
		if not w.id.begins_with("enemy_"):
			player_weapons.append(w)
	if player_weapons.is_empty():
		return

	var section := _make_section("WEAPON ICONS")

	for weapon in player_weapons:
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

const CORE_VARIANT_NAMES: Array[String] = [
	"REACTOR", "CELL", "PISTON", "CRYSTAL", "COIL", "CAPSULE", "TURBINE", "CONDUIT",
]
const CORE_AUDITION_SIZE: int = 48

func _build_power_core_icons() -> void:
	var cores: Array[PowerCoreData] = PowerCoreDataManager.load_all()
	if cores.is_empty():
		return

	var section := _make_section("POWER CORE ICONS")

	# Variant label header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", ITEM_GAP)
	section.add_child(header)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 230
	header.add_child(spacer)
	for vname in CORE_VARIANT_NAMES:
		var vlbl := Label.new()
		vlbl.text = vname
		vlbl.custom_minimum_size.x = CORE_AUDITION_SIZE
		vlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vlbl.add_theme_color_override("font_color", LABEL_COLOR)
		vlbl.add_theme_font_size_override("font_size", 10)
		header.add_child(vlbl)

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

		for variant_idx in CORE_VARIANT_NAMES.size():
			var cell := _make_icon_cell(CORE_AUDITION_SIZE)
			row.add_child(cell)
			_add_power_core_icon(cell, core, CORE_AUDITION_SIZE, variant_idx)


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
	# Wrapper to hold viewport + border overlay side by side in the same space
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

	# Dark background
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)

	# Border overlay drawn on top
	var border := _IconBorder.new()
	border.icon_size = sz
	border.border_style = _current_border
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(border)

	_all_cells.append(wrapper)
	return wrapper


func _update_border_overlay(cell: Control) -> void:
	# Border overlay is the second child of the wrapper
	if cell.get_child_count() < 2:
		return
	var border: _IconBorder = cell.get_child(1) as _IconBorder
	if border:
		border.border_style = _current_border
		border.queue_redraw()


# ── Projectile Icon ─────────────────────────────────────────────────

func _add_projectile_icon(cell: Control, style: ProjectileStyle, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport
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
	var gi: float = style.glow_intensity * _hdr_weapons
	sprite.modulate = Color(gi, gi, gi)
	_weapon_sprites.append({"sprite": sprite, "base_intensity": style.glow_intensity})

	vp.add_child(sprite)


# ── Beam Icon ────────────────────────────────────────────────────────

func _add_beam_icon(cell: Control, style: BeamStyle, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport

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
	var gi: float = style.glow_intensity * _hdr_weapons
	sprite.modulate = Color(gi, gi, gi)
	_weapon_sprites.append({"sprite": sprite, "base_intensity": style.glow_intensity})
	vp.add_child(sprite)


# ── Field Icon ───────────────────────────────────────────────────────

func _add_field_icon(cell: Control, style: FieldStyle, sz: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport

	var tex_size: int = maxi(sz - 4, 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(float(sz) / 2.0, float(sz) / 2.0)

	var mat: ShaderMaterial = VFXFactory.create_field_material(style, float(tex_size) / 2.0)
	mat.set_shader_parameter("brightness", style.glow_intensity * _hdr_fields)
	sprite.material = mat
	_field_materials.append({"material": mat, "base_brightness": style.glow_intensity})
	vp.add_child(sprite)


# ── Power Core Icon (chrome device) ──────────────────────────────────

func _add_power_core_icon(cell: Control, core: PowerCoreData, sz: int, variant: int) -> void:
	var vp: SubViewport = cell.get_child(0).get_child(0) as SubViewport

	var device := _PowerCoreDevice.new()
	device.core = core
	device.icon_size = sz
	device.variant = variant
	device.hdr_mult = _hdr_cores
	device.position = Vector2(float(sz) / 2.0, float(sz) / 2.0)
	_core_pies.append(device)
	vp.add_child(device)


class _PowerCoreDevice extends Node2D:
	## Draws chrome-style vertical tech components with glowing colored internals.
	## Each variant is a different device silhouette.
	var core: PowerCoreData
	var icon_size: int = 48
	var variant: int = 0
	var hdr_mult: float = 1.0

	# Chrome palette
	const CD := Color(0.12, 0.13, 0.18)
	const CM := Color(0.30, 0.32, 0.38)
	const CL := Color(0.55, 0.58, 0.65)
	const CB := Color(0.80, 0.83, 0.90)
	const CS := Color(1.0, 1.0, 1.0, 0.7)

	func _get_glow_color() -> Color:
		## Derive a glow color from the core's dominant bar type.
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
		## Horizontal chrome bands across a rect (bottom dark, top bright).
		draw_rect(rect, CD)
		var bands: Array[Color] = [
			CD.lerp(CM, 0.3), CM, CL, CB,
		]
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
		draw_line(tl, tr, CL, 1.0, true)  # top highlight
		draw_line(tl, bl, CM, 1.0, true)   # left
		draw_line(bl, br, CD, 1.0, true)   # bottom shadow
		draw_line(tr, br, CD, 1.0, true)   # right shadow

	func _chrome_rect(rect: Rect2) -> void:
		_chrome_fill(rect)
		_chrome_edges(rect)

	func _glow_rect(rect: Rect2, col: Color) -> void:
		var m: float = 2.0 * hdr_mult
		var hdr := Color(col.r * m, col.g * m, col.b * m, 0.85)
		draw_rect(rect, hdr)
		# Bright center core
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
		## Thin vertical specular gleam down the center.
		var cx: float = rect.position.x + rect.size.x * 0.5
		var top: float = rect.position.y + _s(2.0)
		var bot: float = rect.position.y + rect.size.y - _s(2.0)
		draw_line(Vector2(cx, top), Vector2(cx, bot), CS, maxf(_s(0.8), 0.5), true)


	# ── Variant 0: REACTOR — tall hex body with central glow window ──
	func _draw_reactor() -> void:
		var w: float = _s(24.0)
		var h: float = _s(38.0)
		var gc := _get_glow_color()
		# Main body
		var body := Rect2(-w / 2.0, -h / 2.0, w, h)
		_chrome_rect(body)
		# Top/bottom caps (wider)
		var cap_h: float = _s(5.0)
		var cap_w: float = w + _s(4.0)
		_chrome_rect(Rect2(-cap_w / 2.0, -h / 2.0, cap_w, cap_h))
		_chrome_rect(Rect2(-cap_w / 2.0, h / 2.0 - cap_h, cap_w, cap_h))
		# Central glow window
		var gw: float = w - _s(8.0)
		var gh: float = _s(14.0)
		_glow_rect(Rect2(-gw / 2.0, -gh / 2.0, gw, gh), gc)
		# Rivets
		draw_circle(Vector2(-w / 2.0 + _s(3.0), -h / 2.0 + _s(3.0)), _s(1.2), CM)
		draw_circle(Vector2(w / 2.0 - _s(3.0), -h / 2.0 + _s(3.0)), _s(1.2), CM)
		_specular_line(body)

	# ── Variant 1: CELL — battery-style stacked segments ──
	func _draw_cell() -> void:
		var w: float = _s(20.0)
		var h: float = _s(36.0)
		var gc := _get_glow_color()
		# Terminal nub
		var nub_w: float = _s(8.0)
		_chrome_rect(Rect2(-nub_w / 2.0, -h / 2.0 - _s(3.0), nub_w, _s(4.0)))
		# Main body
		_chrome_rect(Rect2(-w / 2.0, -h / 2.0, w, h))
		# Glow segments (3 horizontal slots)
		var seg_h: float = _s(5.0)
		var seg_w: float = w - _s(6.0)
		var gap: float = _s(8.0)
		for i in 3:
			var y: float = -h / 2.0 + _s(6.0) + float(i) * gap
			_glow_rect(Rect2(-seg_w / 2.0, y, seg_w, seg_h), gc)
		# Side contacts
		_chrome_rect(Rect2(-w / 2.0 - _s(2.5), -_s(4.0), _s(2.5), _s(8.0)))
		_chrome_rect(Rect2(w / 2.0, -_s(4.0), _s(2.5), _s(8.0)))
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	# ── Variant 2: PISTON — mechanical cylinder with piston rod ──
	func _draw_piston() -> void:
		var w: float = _s(18.0)
		var h: float = _s(32.0)
		var gc := _get_glow_color()
		# Cylinder body
		_chrome_rect(Rect2(-w / 2.0, -h / 2.0, w, h))
		# Piston rod (thin, extends top)
		var rod_w: float = _s(4.0)
		_chrome_rect(Rect2(-rod_w / 2.0, -h / 2.0 - _s(8.0), rod_w, _s(10.0)))
		# Rod cap
		_chrome_rect(Rect2(-_s(6.0), -h / 2.0 - _s(9.0), _s(12.0), _s(3.0)))
		# Glow ring (horizontal slot near top of cylinder)
		_glow_rect(Rect2(-w / 2.0 + _s(2.0), -h / 2.0 + _s(4.0), w - _s(4.0), _s(4.0)), gc)
		# Exhaust port glow at bottom
		_glow_rect(Rect2(-_s(5.0), h / 2.0 - _s(6.0), _s(10.0), _s(4.0)), gc)
		# Mounting bolts
		var bolt_y: float = h / 2.0 - _s(2.0)
		draw_circle(Vector2(-w / 2.0 + _s(2.5), bolt_y), _s(1.5), CL)
		draw_circle(Vector2(w / 2.0 - _s(2.5), bolt_y), _s(1.5), CL)
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	# ── Variant 3: CRYSTAL — angular shard held in a chrome bracket ──
	func _draw_crystal() -> void:
		var gc := _get_glow_color()
		# Bracket frame (U-shape via two side rails + bottom bar)
		var bw: float = _s(26.0)
		var bh: float = _s(38.0)
		var rail: float = _s(4.0)
		_chrome_rect(Rect2(-bw / 2.0, -bh / 2.0, rail, bh))  # left rail
		_chrome_rect(Rect2(bw / 2.0 - rail, -bh / 2.0, rail, bh))  # right rail
		_chrome_rect(Rect2(-bw / 2.0, bh / 2.0 - rail, bw, rail))  # bottom bar
		_chrome_rect(Rect2(-bw / 2.0, -bh / 2.0, bw, rail))  # top bar
		# Crystal shard — diamond shape, glowing
		var cx: float = 0.0
		var cy: float = -_s(2.0)
		var cw: float = _s(10.0)
		var ch: float = _s(24.0)
		var m: float = 2.5 * hdr_mult
		var hdr := Color(gc.r * m, gc.g * m, gc.b * m, 0.9)
		var crystal_pts := PackedVector2Array([
			Vector2(cx, cy - ch / 2.0),         # top point
			Vector2(cx + cw / 2.0, cy - ch * 0.15),  # upper right
			Vector2(cx + cw / 2.0, cy + ch * 0.15),  # lower right
			Vector2(cx, cy + ch / 2.0),          # bottom point
			Vector2(cx - cw / 2.0, cy + ch * 0.15),  # lower left
			Vector2(cx - cw / 2.0, cy - ch * 0.15),  # upper left
		])
		draw_colored_polygon(crystal_pts, hdr)
		# Bright core line
		var mc: float = 4.0 * hdr_mult
		draw_line(Vector2(cx, cy - ch / 2.0 + _s(3.0)), Vector2(cx, cy + ch / 2.0 - _s(3.0)),
			Color(gc.r * mc, gc.g * mc, gc.b * mc, 0.7), _s(2.0), true)

	# ── Variant 4: COIL — winding around a glowing core rod ──
	func _draw_coil() -> void:
		var gc := _get_glow_color()
		var rod_w: float = _s(6.0)
		var rod_h: float = _s(34.0)
		# Central glow rod
		_glow_rect(Rect2(-rod_w / 2.0, -rod_h / 2.0, rod_w, rod_h), gc)
		# Chrome coil windings (horizontal bars at intervals)
		var coil_w: float = _s(20.0)
		var coil_h: float = _s(3.0)
		var coil_count: int = 6
		var spacing: float = (rod_h - _s(6.0)) / float(coil_count - 1)
		for i in coil_count:
			var y: float = -rod_h / 2.0 + _s(3.0) + float(i) * spacing - coil_h / 2.0
			_chrome_rect(Rect2(-coil_w / 2.0, y, coil_w, coil_h))
		# Top/bottom chrome caps
		_chrome_rect(Rect2(-_s(10.0), -rod_h / 2.0 - _s(3.0), _s(20.0), _s(4.0)))
		_chrome_rect(Rect2(-_s(10.0), rod_h / 2.0 - _s(1.0), _s(20.0), _s(4.0)))

	# ── Variant 5: CAPSULE — rounded pill shape with viewport window ──
	func _draw_capsule() -> void:
		var gc := _get_glow_color()
		var w: float = _s(20.0)
		var h: float = _s(36.0)
		var r: float = w / 2.0
		# Capsule body (rect + circles for top/bottom rounding)
		_chrome_rect(Rect2(-w / 2.0, -h / 2.0 + r, w, h - w))
		# Top dome
		draw_circle(Vector2(0.0, -h / 2.0 + r), r, CM)
		draw_arc(Vector2(0.0, -h / 2.0 + r), r, 0.0, TAU, 24, CL, 1.0)
		# Bottom dome
		draw_circle(Vector2(0.0, h / 2.0 - r), r, CD)
		draw_arc(Vector2(0.0, h / 2.0 - r), r, 0.0, TAU, 24, CM, 1.0)
		# Viewport window (circular glow)
		_glow_circle(Vector2(0.0, -_s(3.0)), _s(6.0), gc)
		# Status light at bottom
		_glow_circle(Vector2(0.0, h / 2.0 - r - _s(2.0)), _s(2.5), gc)
		# Chrome band across middle
		_chrome_rect(Rect2(-w / 2.0 - _s(2.0), -_s(1.5), w + _s(4.0), _s(3.0)))
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	# ── Variant 6: TURBINE — circular housing with radial blades ──
	func _draw_turbine() -> void:
		var gc := _get_glow_color()
		var outer_r: float = _s(18.0)
		var inner_r: float = _s(8.0)
		# Outer housing ring
		draw_circle(Vector2.ZERO, outer_r, CD)
		draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 32, CL, _s(3.0))
		draw_arc(Vector2.ZERO, outer_r - _s(2.5), 0.0, TAU, 32, CM, _s(1.0))
		# Inner glowing core
		_glow_circle(Vector2.ZERO, inner_r, gc)
		# Radial chrome blades
		var blade_count: int = 6
		for i in blade_count:
			var angle: float = float(i) / float(blade_count) * TAU - PI / 2.0
			var from_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (inner_r + _s(1.0))
			var to_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (outer_r - _s(2.0))
			draw_line(from_pt, to_pt, CL, _s(2.5), true)
			draw_line(from_pt, to_pt, CB, _s(1.0), true)
		# Glow between blades (arc segments)
		var m: float = 1.5 * hdr_mult
		var glow := Color(gc.r * m, gc.g * m, gc.b * m, 0.4)
		draw_arc(Vector2.ZERO, (inner_r + outer_r) * 0.5, 0.0, TAU, 32, glow, _s(4.0))
		# Center bolt
		draw_circle(Vector2.ZERO, _s(2.5), CB)
		draw_circle(Vector2.ZERO, _s(1.5), CS)

	# ── Variant 7: CONDUIT — vertical pipe with multiple glow segments ──
	func _draw_conduit() -> void:
		var gc := _get_glow_color()
		var pipe_w: float = _s(12.0)
		var pipe_h: float = _s(40.0)
		# Main vertical pipe
		_chrome_rect(Rect2(-pipe_w / 2.0, -pipe_h / 2.0, pipe_w, pipe_h))
		# Junction flanges (wider discs at intervals)
		var flange_w: float = pipe_w + _s(8.0)
		var flange_h: float = _s(3.0)
		var flange_positions: Array[float] = [-pipe_h / 2.0, -_s(8.0), _s(6.0), pipe_h / 2.0 - flange_h]
		for fy in flange_positions:
			_chrome_rect(Rect2(-flange_w / 2.0, fy, flange_w, flange_h))
		# Glow segments between flanges
		var glow_w: float = pipe_w - _s(4.0)
		_glow_rect(Rect2(-glow_w / 2.0, -pipe_h / 2.0 + _s(4.0), glow_w, _s(8.0)), gc)
		_glow_rect(Rect2(-glow_w / 2.0, -_s(4.0), glow_w, _s(8.0)), gc)
		_glow_rect(Rect2(-glow_w / 2.0, _s(10.0), glow_w, _s(6.0)), gc)
		# Side inlet stubs
		_chrome_rect(Rect2(-flange_w / 2.0 - _s(4.0), -_s(10.0), _s(4.0), _s(4.0)))
		_chrome_rect(Rect2(flange_w / 2.0, _s(4.0), _s(4.0), _s(4.0)))
		_specular_line(Rect2(-pipe_w / 2.0, -pipe_h / 2.0, pipe_w, pipe_h))


class _IconBorder extends Control:
	## Draws a decorative border overlay on top of an icon cell.
	var icon_size: int = 48
	var border_style: int = BorderStyle.NONE  # uses parent enum values

	func _draw() -> void:
		var sz: float = float(icon_size)
		match border_style:
			BorderStyle.NONE:
				return
			BorderStyle.CORNER_LINES:
				_draw_corner_lines(sz)
			BorderStyle.METAL_FRAME:
				_draw_metal_frame(sz)
			BorderStyle.NEON_OUTLINE:
				_draw_neon_outline(sz)

	func _draw_corner_lines(sz: float) -> void:
		var line_len: float = maxf(sz * 0.25, 3.0)
		var inset: float = 1.0
		var thick: float = maxf(sz / 24.0, 1.0)
		var col := Color(0.6, 0.7, 0.9, 0.8)
		# Top-left
		draw_line(Vector2(inset, inset), Vector2(inset + line_len, inset), col, thick)
		draw_line(Vector2(inset, inset), Vector2(inset, inset + line_len), col, thick)
		# Top-right
		draw_line(Vector2(sz - inset, inset), Vector2(sz - inset - line_len, inset), col, thick)
		draw_line(Vector2(sz - inset, inset), Vector2(sz - inset, inset + line_len), col, thick)
		# Bottom-left
		draw_line(Vector2(inset, sz - inset), Vector2(inset + line_len, sz - inset), col, thick)
		draw_line(Vector2(inset, sz - inset), Vector2(inset, sz - inset - line_len), col, thick)
		# Bottom-right
		draw_line(Vector2(sz - inset, sz - inset), Vector2(sz - inset - line_len, sz - inset), col, thick)
		draw_line(Vector2(sz - inset, sz - inset), Vector2(sz - inset, sz - inset - line_len), col, thick)

	func _draw_metal_frame(sz: float) -> void:
		var thick: float = maxf(sz / 16.0, 1.5)
		var half: float = thick / 2.0
		# Outer dark edge
		var dark := Color(0.15, 0.15, 0.2, 0.9)
		draw_rect(Rect2(half, half, sz - thick, sz - thick), dark, false, thick)
		# Inner bright bevel (top-left highlight)
		var highlight := Color(0.45, 0.5, 0.6, 0.7)
		var inner_off: float = thick
		draw_line(Vector2(inner_off, inner_off), Vector2(sz - inner_off, inner_off), highlight, maxf(thick * 0.5, 1.0))
		draw_line(Vector2(inner_off, inner_off), Vector2(inner_off, sz - inner_off), highlight, maxf(thick * 0.5, 1.0))
		# Shadow edge (bottom-right)
		var shadow := Color(0.05, 0.05, 0.08, 0.8)
		draw_line(Vector2(sz - inner_off, inner_off), Vector2(sz - inner_off, sz - inner_off), shadow, maxf(thick * 0.5, 1.0))
		draw_line(Vector2(inner_off, sz - inner_off), Vector2(sz - inner_off, sz - inner_off), shadow, maxf(thick * 0.5, 1.0))

	func _draw_neon_outline(sz: float) -> void:
		var neon_col := Color(0.2, 0.6, 1.0)
		var thick: float = maxf(sz / 20.0, 1.0)
		var half: float = thick / 2.0
		# Outer glow pass (wider, dimmer)
		var glow := Color(neon_col.r * 1.5, neon_col.g * 1.5, neon_col.b * 1.5, 0.3)
		draw_rect(Rect2(half, half, sz - thick, sz - thick), glow, false, thick * 3.0)
		# Core line (bright HDR for bloom pickup)
		var core := Color(neon_col.r * 3.0, neon_col.g * 3.0, neon_col.b * 3.0, 0.95)
		draw_rect(Rect2(half, half, sz - thick, sz - thick), core, false, thick)
