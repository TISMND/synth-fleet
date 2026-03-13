extends PreviewBase
## Hard Neon preview — Multi-pass glow polylines with white-hot cores.
## All 4 workshop panels use this script with different presets.

var _additive_mat: CanvasItemMaterial

# Preset-specific overrides (set via apply_preset)
var _preset_width: float = 14.0
var _preset_intensity: float = 1.0
var _preset_core_brightness: float = 0.7
var _preset_pass_count: int = 4


func _ready() -> void:
	super._ready()
	_additive_mat = CanvasItemMaterial.new()
	_additive_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _additive_mat


func _process(delta: float) -> void:
	super._process(delta)
	if flicker_enabled:
		var noise := sin(_time * 17.3) * 0.4 + sin(_time * 31.7) * 0.3
		glow_width = _preset_width + noise * 6.0
		glow_intensity = _preset_intensity + noise * 0.4


func apply_preset(preset_name: String) -> void:
	match preset_name:
		"tight":
			_preset_width = 8.0
			_preset_intensity = 1.0
			_preset_core_brightness = 0.85
			_preset_pass_count = 3
			flicker_enabled = false
		"wide":
			_preset_width = 28.0
			_preset_intensity = 1.0
			_preset_core_brightness = 0.5
			_preset_pass_count = 6
			flicker_enabled = false
		"intense":
			_preset_width = 18.0
			_preset_intensity = 2.5
			_preset_core_brightness = 0.9
			_preset_pass_count = 4
			flicker_enabled = false
		"flicker":
			_preset_width = 14.0
			_preset_intensity = 1.0
			_preset_core_brightness = 0.7
			_preset_pass_count = 4
			flicker_enabled = true

	glow_width = _preset_width
	glow_intensity = _preset_intensity
	core_brightness = _preset_core_brightness
	pass_count = _preset_pass_count


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, get_rect().size), Color(0.02, 0.02, 0.05, 1.0))

	var pulse := _pulse_t * pulse_strength

	# Ship
	_draw_neon_poly(closed_poly(offset_points(SHIP_POINTS, ship_pos)), ship_color, pulse)

	# Enemy
	_draw_neon_poly(closed_poly(offset_points(ENEMY_POINTS, enemy_pos)), enemy_color, pulse)

	# Projectile as rect outline
	var pr := PROJECTILE_RECT
	var proj_points := PackedVector2Array([
		projectile_pos + Vector2(pr.position.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y),
		projectile_pos + Vector2(pr.position.x + pr.size.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y + pr.size.y),
		projectile_pos + Vector2(pr.position.x, pr.position.y),
	])
	_draw_neon_poly(proj_points, projectile_color, pulse)


## Draw a polyline with N-pass glow and white-hot core.
func _draw_neon_poly(points: PackedVector2Array, color: Color, pulse: float) -> void:
	if points.size() < 2:
		return

	var total_passes := pass_count
	var glow_extra := pulse * 4.0

	for i in range(total_passes):
		# t goes from 0.0 (outermost) to 1.0 (core)
		var t := float(i) / float(total_passes - 1) if total_passes > 1 else 1.0

		# Width: wide at outer, narrow at core
		var w := lerpf(glow_width + glow_extra, 2.0, t)

		# Alpha: low at outer, high at core, scaled by intensity
		var base_alpha := lerpf(0.04, 0.85, t * t)
		var alpha := clampf(base_alpha * glow_intensity + pulse * 0.05 * (1.0 - t), 0.0, 1.0)

		# White-hot core blend
		var white_blend := 0.0
		if t > 0.6:
			white_blend = remap(t, 0.6, 1.0, 0.0, core_brightness)
		var pass_color := color.lerp(Color.WHITE, white_blend)
		pass_color.a = alpha

		draw_polyline(points, pass_color, w, true)
