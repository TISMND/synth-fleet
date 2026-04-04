class_name ComponentIconBuilder
extends RefCounted
## Static utility for building 64px component icon cells used by the icon popup
## and the auditions page. Centralizes icon rendering, HDR defaults, and core assignments.

const ICON_SIZE: int = 64
const BG_COLOR := Color(0.02, 0.02, 0.04)

const HDR_DEFAULTS: Dictionary = {
	"broadside_pulse": 1.95,
	"disruptor_spread": 1.35,
	"eko_pulse_turret": 1.90,
	"everything_gun": 0.85,
	"fire_pick": 1.95,
	"laser_turret": 1.20,
	"terror_beam": 0.50,
	"the_twins": 1.90,
	"tuned_ion_pulse": 1.35,
	"v_star": 0.95,
	"fem_field_modulation_tuner": 1.95,
	"fem_heavens_orb": 1.90,
	"fem_inverted_crystal_capacitors": 3.85,
	"fem_time_sphere": 5.00,
	"beam_fractal_chamber": 0.85,
	"fiddyfiddy": 1.85,
	"low_key_core": 1.80,
	"orbix80t": 1.40,
	"p23cold": 1.45,
	"radial_burst_core": 0.70,
}

const SINGLE_ICON_OVERRIDES: Array[String] = ["laser_turret", "broadside_pulse", "v_star"]
const ROTATION_OVERRIDES: Dictionary = {
	"broadside_pulse": 90.0,  # degrees
}

const CORE_VARIANT_NAMES: Array[String] = [
	"REACTOR", "CELL", "PISTON", "CRYSTAL", "COIL", "CAPSULE", "TURBINE", "CONDUIT",
]
const CORE_ASSIGNMENTS: Dictionary = {
	"beam_fractal_chamber": 0,  # REACTOR
	"fiddyfiddy": 2,            # PISTON
	"low_key_core": 4,          # COIL
	"orbix80t": 6,              # TURBINE
	"p23cold": 5,               # CAPSULE
	"radial_burst_core": 3,     # CRYSTAL
}


# ── Cell creation ───────────────────────────────────────────────────

static func make_icon_cell(sz: int = ICON_SIZE) -> Control:
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

	var border := IconBorder.new()
	border.icon_size = sz
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_child(border)

	return wrapper


static func _get_viewport(cell: Control) -> SubViewport:
	return cell.get_child(0).get_child(0) as SubViewport


# ── Weapon icon ─────────────────────────────────────────────────────

static func add_weapon_icon(cell: Control, weapon: WeaponData) -> void:
	var is_beam: bool = weapon.beam_style_id != ""
	var is_double: bool = (weapon.mirror_mode == "mirror" or weapon.fire_pattern == "dual") and not SINGLE_ICON_OVERRIDES.has(weapon.id)
	var rot_deg: float = ROTATION_OVERRIDES.get(weapon.id, 0.0) as float
	var icon_rotation: float = deg_to_rad(rot_deg)

	if is_beam:
		var style: BeamStyle = BeamStyleManager.load_by_id(weapon.beam_style_id)
		if style:
			_add_beam_sprites(cell, style, is_double, weapon.id)
	else:
		var style: ProjectileStyle = ProjectileStyleManager.load_by_id(weapon.projectile_style_id)
		if style:
			_add_projectile_sprites(cell, style, is_double, icon_rotation, weapon.id)


static func _add_projectile_sprites(cell: Control, style: ProjectileStyle, is_double: bool, icon_rotation: float, weapon_id: String) -> void:
	var vp: SubViewport = _get_viewport(cell)
	var sz: float = float(ICON_SIZE)
	var count: int = 2 if is_double else 1

	var vis_w: float = style.base_scale.x if is_zero_approx(icon_rotation) else style.base_scale.y
	var vis_h: float = style.base_scale.y if is_zero_approx(icon_rotation) else style.base_scale.x
	var aspect: float = vis_h / maxf(vis_w, 1.0)

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

	var x_offset: float = 0.0
	if count == 2:
		fit_scale *= 0.75
		x_offset = sz * 0.14

	var hdr_mult: float = HDR_DEFAULTS.get(weapon_id, 1.0) as float

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

		# Apply HDR via weapon_color shader parameter
		if sprite.material is ShaderMaterial:
			var mat: ShaderMaterial = sprite.material as ShaderMaterial
			var col: Color = style.color
			mat.set_shader_parameter("weapon_color", Color(col.r * hdr_mult, col.g * hdr_mult, col.b * hdr_mult, col.a))
		vp.add_child(sprite)


static func _add_beam_sprites(cell: Control, style: BeamStyle, is_double: bool, weapon_id: String) -> void:
	var vp: SubViewport = _get_viewport(cell)
	var sz: int = ICON_SIZE
	var count: int = 2 if is_double else 1
	var beam_w: int = maxi(int(clampf(style.beam_width, 4.0, float(sz) * 0.4)), 4)
	var beam_h: int = maxi(sz - 16, 4)

	if count == 2:
		beam_w = maxi(int(float(beam_w) * 0.7), 3)

	var x_offset: float = 0.0
	if count == 2:
		x_offset = float(sz) * 0.14

	var hdr_mult: float = HDR_DEFAULTS.get(weapon_id, 1.0) as float

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
			var col: Color = style.color
			shader_mat.set_shader_parameter("weapon_color", Color(col.r * hdr_mult, col.g * hdr_mult, col.b * hdr_mult, col.a))
			for param_name in style.shader_params:
				shader_mat.set_shader_parameter(param_name, float(style.shader_params[param_name]))
			if style.fill_shader == "nebula_dual":
				shader_mat.set_shader_parameter("secondary_color", style.secondary_color)
			sprite.material = shader_mat

		sprite.flip_v = style.flip_shader
		vp.add_child(sprite)


# ── Field emitter icon ──────────────────────────────────────────────

static func add_field_emitter_icon(cell: Control, emitter: DeviceData) -> void:
	if emitter.field_style_id == "":
		return
	var style: FieldStyle = FieldStyleManager.load_by_id(emitter.field_style_id)
	if not style:
		return

	var vp: SubViewport = _get_viewport(cell)
	var tex_size: int = maxi(ICON_SIZE - 4, 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)

	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = Vector2(float(ICON_SIZE) / 2.0, float(ICON_SIZE) / 2.0)

	var hdr_mult: float = HDR_DEFAULTS.get(emitter.id, 1.0) as float
	var mat: ShaderMaterial = VFXFactory.create_field_material(style, float(tex_size) / 2.0)
	mat.set_shader_parameter("brightness", style.glow_intensity * hdr_mult)
	sprite.material = mat
	vp.add_child(sprite)


# ── Power core icon ─────────────────────────────────────────────────

static func add_power_core_icon(cell: Control, core: PowerCoreData, variant_override: int = -1) -> void:
	var vp: SubViewport = _get_viewport(cell)
	var variant: int = variant_override if variant_override >= 0 else (CORE_ASSIGNMENTS.get(core.id, 0) as int)
	var hdr_mult: float = HDR_DEFAULTS.get(core.id, 1.0) as float

	var device := PowerCoreDevice.new()
	device.core = core
	device.icon_size = ICON_SIZE
	device.variant = variant
	device.hdr_mult = hdr_mult
	device.position = Vector2(float(ICON_SIZE) / 2.0, float(ICON_SIZE) / 2.0)
	vp.add_child(device)


# ── Icon border (metal frame) ──────────────────────────────────────

class IconBorder extends Control:
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


# ── Power core device (chrome tech drawing) ────────────────────────

class PowerCoreDevice extends Node2D:
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
		_chrome_rect(Rect2(-w / 2.0, -_s(6.0), w, _s(2.0)))
		_chrome_rect(Rect2(-w / 2.0, _s(4.0), w, _s(2.0)))
		var gw: float = w - _s(10.0)
		var gh: float = _s(8.0)
		_glow_rect(Rect2(-gw / 2.0, -gh / 2.0, gw, gh), gc)
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
		_chrome_rect(Rect2(-rod_w / 2.0, h / 2.0 - _s(2.0), rod_w, _s(10.0)))
		_chrome_rect(Rect2(-_s(6.0), -h / 2.0 - _s(9.0), _s(12.0), _s(3.0)))
		_chrome_rect(Rect2(-_s(6.0), h / 2.0 + _s(6.0), _s(12.0), _s(3.0)))
		var slit_w: float = w - _s(6.0)
		_glow_rect(Rect2(-slit_w / 2.0, -h / 2.0 + _s(4.0), slit_w, _s(2.5)), gc)
		_glow_rect(Rect2(-slit_w / 2.0, h / 2.0 - _s(6.5), slit_w, _s(2.5)), gc)
		_chrome_rect(Rect2(-w / 2.0, -_s(2.0), w, _s(3.0)))
		draw_circle(Vector2(-w / 2.0 + _s(2.5), -h / 2.0 + _s(2.0)), _s(1.5), CL)
		draw_circle(Vector2(w / 2.0 - _s(2.5), -h / 2.0 + _s(2.0)), _s(1.5), CL)
		draw_circle(Vector2(-w / 2.0 + _s(2.5), h / 2.0 - _s(2.0)), _s(1.5), CL)
		draw_circle(Vector2(w / 2.0 - _s(2.5), h / 2.0 - _s(2.0)), _s(1.5), CL)
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	func _draw_crystal() -> void:
		var gc := _get_glow_color()
		var bw: float = _s(26.0)
		var bh: float = _s(38.0)
		var rail: float = _s(5.0)
		_chrome_rect(Rect2(-bw / 2.0, -bh / 2.0, rail, bh))
		_chrome_rect(Rect2(bw / 2.0 - rail, -bh / 2.0, rail, bh))
		_chrome_rect(Rect2(-bw / 2.0, bh / 2.0 - rail, bw, rail))
		_chrome_rect(Rect2(-bw / 2.0, -bh / 2.0, bw, rail))
		_chrome_rect(Rect2(-bw / 2.0, -_s(1.0), bw, _s(2.0)))
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
		var rod_w: float = _s(6.0)
		var rod_h: float = _s(34.0)
		_glow_rect(Rect2(-rod_w / 2.0, -rod_h / 2.0, rod_w, rod_h), gc)
		var coil_w: float = _s(20.0)
		var coil_h: float = _s(3.0)
		var coil_count: int = 6
		var spacing: float = (rod_h - _s(6.0)) / float(coil_count - 1)
		for i in coil_count:
			var y: float = -rod_h / 2.0 + _s(3.0) + float(i) * spacing - coil_h / 2.0
			_chrome_rect(Rect2(-coil_w / 2.0, y, coil_w, coil_h))
		_chrome_rect(Rect2(-_s(10.0), -rod_h / 2.0 - _s(3.0), _s(20.0), _s(4.0)))
		_chrome_rect(Rect2(-_s(10.0), rod_h / 2.0 - _s(1.0), _s(20.0), _s(4.0)))

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
		_glow_circle(Vector2(0.0, -_s(3.0)), _s(4.0), gc)
		_glow_circle(Vector2(0.0, h / 2.0 - r - _s(2.0)), _s(1.5), gc)
		_chrome_rect(Rect2(-w / 2.0 - _s(2.0), -_s(1.5), w + _s(4.0), _s(3.0)))
		_chrome_rect(Rect2(-w / 2.0 - _s(1.0), _s(5.0), w + _s(2.0), _s(2.0)))
		_specular_line(Rect2(-w / 2.0, -h / 2.0, w, h))

	func _draw_turbine() -> void:
		var gc := _get_glow_color()
		var outer_r: float = _s(18.0)
		var inner_r: float = _s(5.0)
		draw_circle(Vector2.ZERO, outer_r, CD)
		draw_arc(Vector2.ZERO, outer_r, 0.0, TAU, 32, CL, _s(4.0))
		draw_arc(Vector2.ZERO, outer_r - _s(3.5), 0.0, TAU, 32, CM, _s(1.5))
		_glow_circle(Vector2.ZERO, inner_r, gc)
		var blade_count: int = 8
		for i in blade_count:
			var angle: float = float(i) / float(blade_count) * TAU - PI / 2.0
			var from_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (inner_r + _s(1.0))
			var to_pt: Vector2 = Vector2(cos(angle), sin(angle)) * (outer_r - _s(3.0))
			draw_line(from_pt, to_pt, CL, _s(3.0), true)
			draw_line(from_pt, to_pt, CB, _s(1.2), true)
		var m: float = 1.2 * hdr_mult
		var glow := Color(gc.r * m, gc.g * m, gc.b * m, 0.25)
		draw_arc(Vector2.ZERO, (inner_r + outer_r) * 0.5, 0.0, TAU, 32, glow, _s(2.0))
		draw_circle(Vector2.ZERO, _s(2.5), CB)
		draw_circle(Vector2.ZERO, _s(1.5), CS)

	func _draw_conduit() -> void:
		var gc := _get_glow_color()
		var pipe_w: float = _s(14.0)
		var pipe_h: float = _s(40.0)
		_chrome_rect(Rect2(-pipe_w / 2.0, -pipe_h / 2.0, pipe_w, pipe_h))
		var flange_w: float = pipe_w + _s(8.0)
		var flange_h: float = _s(4.0)
		var flange_positions: Array[float] = [-pipe_h / 2.0, -_s(8.0), _s(6.0), pipe_h / 2.0 - flange_h]
		for fy in flange_positions:
			_chrome_rect(Rect2(-flange_w / 2.0, fy, flange_w, flange_h))
		var glow_w: float = pipe_w - _s(8.0)
		_glow_rect(Rect2(-glow_w / 2.0, -pipe_h / 2.0 + _s(5.0), glow_w, _s(4.0)), gc)
		_glow_rect(Rect2(-glow_w / 2.0, -_s(3.0), glow_w, _s(4.0)), gc)
		_glow_rect(Rect2(-glow_w / 2.0, _s(11.0), glow_w, _s(3.0)), gc)
		_chrome_rect(Rect2(-flange_w / 2.0 - _s(4.0), -_s(10.0), _s(4.0), _s(4.0)))
		_chrome_rect(Rect2(flange_w / 2.0, _s(4.0), _s(4.0), _s(4.0)))
		_specular_line(Rect2(-pipe_w / 2.0, -pipe_h / 2.0, pipe_w, pipe_h))
