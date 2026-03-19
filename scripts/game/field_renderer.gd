class_name FieldRenderer
extends Node2D
## Renders a circular field effect around the player ship using a shader-driven sprite.
## Driven by DeviceController for opacity (fade in/out) and pulse (beat triggers).

var _sprite: Sprite2D = null
var _material: ShaderMaterial = null
var _pulse_timer: float = 0.0
var _pulse_duration: float = 0.3
var _pulse_brightness: float = 2.0


func setup(style: FieldStyle, radius: float, anim_speed: float) -> void:
	_pulse_duration = style.pulse_duration
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
	_pulse_timer = _pulse_duration
	if _material:
		_material.set_shader_parameter("pulse_intensity", 1.0)


func set_opacity(val: float) -> void:
	if _material:
		_material.set_shader_parameter("opacity", val)


func _process(delta: float) -> void:
	if _pulse_timer > 0.0:
		_pulse_timer = maxf(0.0, _pulse_timer - delta)
		var ratio: float = _pulse_timer / maxf(_pulse_duration, 0.001)
		if _material:
			_material.set_shader_parameter("pulse_intensity", ratio)
