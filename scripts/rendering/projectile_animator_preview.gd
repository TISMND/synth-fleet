class_name ProjectileAnimatorPreview
extends Node2D
## Live preview for the Projectile Animator tab.
## Shows animated projectile based on current style settings.

var _viewport_size: Vector2 = Vector2(400, 500)
var _sprite: Sprite2D = null
var _preview_color: Color = Color.CYAN
var _archetype: String = "bullet"
var _age: float = 0.0
var _bullet_y: float = 0.0
var _pulse_radius: float = 0.0
var _beam_age: float = 0.0

# Archetype params cache
var _max_length: float = 400.0
var _beam_duration: float = 0.5
var _beam_width: float = 16.0
var _expansion_rate: float = 200.0
var _max_radius: float = 200.0
var _pulse_lifetime: float = 1.0
var _ring_width: float = 8.0


func update_style(data: Dictionary) -> void:
	# Remove old sprite
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
		_sprite = null

	_archetype = str(data.get("archetype", "bullet"))
	_preview_color = data.get("color", Color.CYAN) as Color
	_age = 0.0
	_bullet_y = _viewport_size.y - 60.0
	_pulse_radius = 0.0
	_beam_age = 0.0

	# Build a temporary ProjectileStyle from data
	var style := ProjectileStyle.new()
	style.fill_shader = str(data.get("fill_shader", "energy"))
	style.shader_params = data.get("shader_params", {}) as Dictionary
	style.mask_path = str(data.get("mask_path", ""))
	style.glow_intensity = float(data.get("glow_intensity", 1.5))
	style.base_scale = data.get("base_scale", Vector2(24, 32)) as Vector2

	# Cache archetype params
	var ap: Dictionary = data.get("archetype_params", {}) as Dictionary
	_max_length = float(ap.get("max_length", 400.0))
	_beam_duration = float(ap.get("beam_duration", 0.5))
	_beam_width = float(ap.get("width", 16.0))
	_expansion_rate = float(ap.get("expansion_rate", 200.0))
	_max_radius = float(ap.get("max_radius", 200.0))
	_pulse_lifetime = float(ap.get("lifetime", 1.0))
	_ring_width = float(ap.get("ring_width", 8.0))

	_sprite = VFXFactory.create_styled_sprite(style, _preview_color)
	if _sprite:
		add_child(_sprite)
		_sprite.position = Vector2(_viewport_size.x / 2.0, _viewport_size.y - 60.0)

	queue_redraw()


func _process(delta: float) -> void:
	_age += delta

	match _archetype:
		"bullet":
			_process_bullet(delta)
		"beam":
			_process_beam(delta)
		"pulse_wave":
			_process_pulse_wave(delta)

	queue_redraw()


func _process_bullet(delta: float) -> void:
	_bullet_y -= 300.0 * delta
	if _bullet_y < -20.0:
		_bullet_y = _viewport_size.y - 60.0
	if _sprite and is_instance_valid(_sprite):
		_sprite.position = Vector2(_viewport_size.x / 2.0, _bullet_y)


func _process_beam(_delta: float) -> void:
	_beam_age += _delta
	# Loop beam pulse
	if _beam_age > _beam_duration + 0.3:
		_beam_age = 0.0
	if _sprite and is_instance_valid(_sprite):
		var center_x: float = _viewport_size.x / 2.0
		var beam_base_y: float = _viewport_size.y - 80.0
		if _beam_age < _beam_duration:
			_sprite.visible = true
			# Scale sprite to beam dimensions
			var length_frac: float = minf(_beam_age / (_beam_duration * 0.3), 1.0)
			var current_len: float = _max_length * length_frac
			_sprite.scale = Vector2(_beam_width / maxf(_sprite.texture.get_width(), 1.0),
				current_len / maxf(_sprite.texture.get_height(), 1.0))
			_sprite.position = Vector2(center_x, beam_base_y - current_len / 2.0)
		else:
			_sprite.visible = false


func _process_pulse_wave(delta: float) -> void:
	_pulse_radius += _expansion_rate * delta
	if _pulse_radius > _max_radius:
		_pulse_radius = 0.0
	if _sprite and is_instance_valid(_sprite):
		var scale_factor: float = _pulse_radius / maxf(_max_radius, 1.0) * 6.0
		_sprite.scale = Vector2(maxf(scale_factor, 0.1), maxf(scale_factor, 0.1))
		_sprite.modulate.a = clampf(1.0 - _pulse_radius / _max_radius, 0.1, 1.0)
		_sprite.position = Vector2(_viewport_size.x / 2.0, _viewport_size.y / 2.0)


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, _viewport_size), Color(0.02, 0.02, 0.05, 1.0))

	# Subtle grid
	var grid_color: Color = Color(0.1, 0.1, 0.15, 0.3)
	for x in range(0, int(_viewport_size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, _viewport_size.y), grid_color, 1.0)
	for y in range(0, int(_viewport_size.y), 40):
		draw_line(Vector2(0, y), Vector2(_viewport_size.x, y), grid_color, 1.0)

	# Pulse wave fallback drawing when no sprite
	if _archetype == "pulse_wave" and (not _sprite or not is_instance_valid(_sprite)):
		_draw_pulse_wave_fallback()


func _draw_pulse_wave_fallback() -> void:
	var center: Vector2 = Vector2(_viewport_size.x / 2.0, _viewport_size.y / 2.0)
	var alpha: float = clampf(1.0 - _pulse_radius / _max_radius, 0.1, 1.0)
	var hdr: float = 2.0
	draw_arc(center, _pulse_radius, 0, TAU, 48,
		Color(_preview_color.r * hdr, _preview_color.g * hdr, _preview_color.b * hdr, alpha), _ring_width)
