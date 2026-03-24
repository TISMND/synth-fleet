class_name FieldRenderer
extends Node2D
## Renders a circular field effect around the player ship using a shader-driven sprite.
## Driven by DeviceController for opacity (fade in/out) and pulse (beat triggers).

var _sprite: Sprite2D = null
var _material: ShaderMaterial = null
var _pulse_elapsed: float = 0.0
var _pulse_total_duration: float = 0.5
var _pulse_fade_up: float = 0.05
var _pulse_fade_out: float = 0.4
var _pulse_brightness: float = 2.0
var _pulse_active: bool = false
var _stay_visible: bool = true  # If false, hides after pulse ends (shield hit mode)


func setup(style: FieldStyle, radius: float, anim_speed: float = 1.0) -> void:
	_pulse_total_duration = style.pulse_total_duration
	_pulse_fade_up = style.pulse_fade_up
	_pulse_fade_out = style.pulse_fade_out
	_pulse_brightness = style.pulse_brightness

	# Create shader material
	_material = VFXFactory.create_field_material(style, radius)
	_material.set_shader_parameter("animation_speed", anim_speed)
	var vp: Viewport = get_viewport()
	var vp_size: String = str(vp.size) if vp else "null"
	print("[FIELD] shader=%s brightness=%.2f color=%s viewport=%s" % [style.field_shader, style.glow_intensity, str(style.color), vp_size])

	# Create sprite with white texture sized to radius * 2
	_sprite = Sprite2D.new()
	var tex_size: int = maxi(int(ceilf(radius * 2.0)), 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.material = _material
	add_child(_sprite)

	z_index = 1  # Fields render above ship/projectiles


func pulse() -> void:
	_pulse_elapsed = 0.0
	_pulse_active = true
	visible = true
	if _material:
		_material.set_shader_parameter("pulse_intensity", 0.0)


func set_pulse_timing(total: float, up: float, out: float) -> void:
	_pulse_total_duration = total
	_pulse_fade_up = up
	_pulse_fade_out = out


func get_pulse_intensity() -> float:
	if _material:
		return float(_material.get_shader_parameter("pulse_intensity"))
	return 0.0


func set_opacity(val: float) -> void:
	if _material:
		_material.set_shader_parameter("opacity", val)


func _process(delta: float) -> void:
	if _pulse_active:
		_pulse_elapsed += delta
		if _pulse_elapsed >= _pulse_total_duration:
			_pulse_active = false
			visible = _stay_visible
			if _material:
				_material.set_shader_parameter("pulse_intensity", 0.0)
		elif _material:
			var fade_up: float = _pulse_fade_up
			var fade_out: float = _pulse_fade_out
			# Clamp so fade_up + fade_out don't exceed total duration
			if fade_up + fade_out > _pulse_total_duration:
				var s: float = _pulse_total_duration / maxf(fade_up + fade_out, 0.001)
				fade_up *= s
				fade_out *= s
			var fade_out_start: float = _pulse_total_duration - fade_out
			var envelope: float
			if _pulse_elapsed < fade_up:
				envelope = _pulse_elapsed / maxf(fade_up, 0.001)
			elif _pulse_elapsed < fade_out_start:
				envelope = 1.0
			else:
				var remaining: float = _pulse_total_duration - _pulse_elapsed
				envelope = remaining / maxf(fade_out, 0.001)
			_material.set_shader_parameter("pulse_intensity", clampf(envelope * _pulse_brightness, 0.0, _pulse_brightness))
