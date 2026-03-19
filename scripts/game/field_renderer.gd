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


func setup(style: FieldStyle, radius: float, anim_speed: float) -> void:
	_pulse_total_duration = style.pulse_total_duration
	_pulse_fade_up = style.pulse_fade_up
	_pulse_fade_out = style.pulse_fade_out
	_pulse_brightness = style.pulse_brightness

	# Create shader material
	_material = VFXFactory.create_field_material(style, radius)
	_material.set_shader_parameter("animation_speed", anim_speed)

	# Create sprite with white texture sized to radius * 2
	_sprite = Sprite2D.new()
	var tex_size: int = maxi(int(ceilf(radius * 2.0)), 4)
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)
	_sprite.material = _material

	# Additive blending for glow
	var canvas_mat := CanvasItemMaterial.new()
	canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sprite.material = _material

	add_child(_sprite)
	z_index = -1


func pulse() -> void:
	_pulse_elapsed = 0.0
	_pulse_active = true
	if _material:
		_material.set_shader_parameter("pulse_intensity", 0.0)


func set_opacity(val: float) -> void:
	if _material:
		_material.set_shader_parameter("opacity", val)


func _process(delta: float) -> void:
	if _pulse_active:
		_pulse_elapsed += delta
		if _pulse_elapsed >= _pulse_total_duration:
			_pulse_active = false
			if _material:
				_material.set_shader_parameter("pulse_intensity", 0.0)
		elif _material:
			var fade_out_start: float = _pulse_total_duration - _pulse_fade_out
			var intensity: float
			if _pulse_elapsed < _pulse_fade_up:
				# Fade up phase
				intensity = _pulse_elapsed / maxf(_pulse_fade_up, 0.001)
			elif _pulse_elapsed < fade_out_start:
				# Sustain phase (full brightness)
				intensity = 1.0
			else:
				# Fade out phase
				var remaining: float = _pulse_total_duration - _pulse_elapsed
				intensity = remaining / maxf(_pulse_fade_out, 0.001)
			_material.set_shader_parameter("pulse_intensity", clampf(intensity, 0.0, 1.0))
