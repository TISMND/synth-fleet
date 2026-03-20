class_name ProjectileAnimatorPreview
extends Node2D
## Live preview for the Projectile Animator tab.
## Shows animated projectile based on current style settings.
## Bullet and pulse_wave are static (shader animates via TIME).
## Beam shows its emit → sustain → end lifecycle on loop.

var _viewport_size: Vector2 = Vector2(400, 500)
var _sprite: Sprite2D = null
var _content: Node2D = null  # Container for zoom/pan
var _preview_color: Color = Color.CYAN
var _archetype: String = "bullet"
var _beam_age: float = 0.0

# Archetype params cache
var _max_length: float = 400.0
var _beam_duration: float = 0.5
var _beam_width: float = 16.0
var _expansion_rate: float = 200.0
var _max_radius: float = 200.0
var _pulse_lifetime: float = 1.0
var _ring_width: float = 8.0

# Beam lifecycle timing
var _beam_grow_time: float = 0.3
var _beam_end_time: float = 0.15
var _beam_gap_time: float = 0.5

# Zoom and pan
var _zoom: float = 1.0
var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false

const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 0.1


func _ready() -> void:
	_content = Node2D.new()
	add_child(_content)


func update_style(data: Dictionary) -> void:
	# Remove old sprite
	if _sprite and is_instance_valid(_sprite):
		_sprite.queue_free()
		_sprite = null

	_archetype = str(data.get("archetype", "bullet"))
	_preview_color = data.get("color", Color.CYAN) as Color
	_beam_age = 0.0

	# Reset zoom/pan on style change
	_zoom = 1.0
	_pan_offset = Vector2.ZERO
	_apply_zoom_pan()

	# Build a temporary ProjectileStyle from data
	var style := ProjectileStyle.new()
	style.fill_shader = str(data.get("fill_shader", "energy"))
	style.shader_params = data.get("shader_params", {}) as Dictionary
	style.mask_path = str(data.get("mask_path", ""))
	style.glow_intensity = float(data.get("glow_intensity", 1.5))
	style.base_scale = data.get("base_scale", Vector2(24, 32)) as Vector2
	style.procedural_mask_shape = str(data.get("procedural_mask_shape", ""))
	style.procedural_mask_feather = float(data.get("procedural_mask_feather", 0.3))
	style.secondary_color = data.get("secondary_color", Color(1.0, 0.3, 0.5, 1.0)) as Color

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
		_content.add_child(_sprite)
		match _archetype:
			"bullet":
				_sprite.position = Vector2(_viewport_size.x / 2.0, _viewport_size.y / 2.0)
			"pulse_wave":
				_sprite.position = Vector2(_viewport_size.x / 2.0, _viewport_size.y / 2.0)
				_sprite.modulate.a = 1.0
				_sprite.scale = Vector2(3.0, 3.0)
			"beam":
				_sprite.visible = false

	queue_redraw()


func _process(delta: float) -> void:
	if _archetype == "beam":
		_process_beam(delta)

	queue_redraw()


func _process_beam(delta: float) -> void:
	_beam_age += delta

	var sustain_time: float = maxf(_beam_duration - _beam_grow_time, 0.1)
	var total_cycle: float = _beam_grow_time + sustain_time + _beam_end_time + _beam_gap_time
	if _beam_age > total_cycle:
		_beam_age = 0.0

	if not _sprite or not is_instance_valid(_sprite):
		return

	var center_x: float = _viewport_size.x / 2.0
	var beam_base_y: float = _viewport_size.y - 40.0

	# Phase 1: Emit / grow
	if _beam_age < _beam_grow_time:
		_sprite.visible = true
		var t: float = _beam_age / _beam_grow_time
		var current_len: float = _max_length * t
		_apply_beam_transform(center_x, beam_base_y, current_len)
		_sprite.modulate.a = 1.0

	# Phase 2: Sustain
	elif _beam_age < _beam_grow_time + sustain_time:
		_sprite.visible = true
		_apply_beam_transform(center_x, beam_base_y, _max_length)
		_sprite.modulate.a = 1.0

	# Phase 3: End / fade
	elif _beam_age < _beam_grow_time + sustain_time + _beam_end_time:
		_sprite.visible = true
		var fade_t: float = (_beam_age - _beam_grow_time - sustain_time) / _beam_end_time
		_apply_beam_transform(center_x, beam_base_y, _max_length * (1.0 - fade_t * 0.3))
		_sprite.modulate.a = 1.0 - fade_t

	# Phase 4: Gap
	else:
		_sprite.visible = false


func _apply_beam_transform(center_x: float, base_y: float, length: float) -> void:
	if not _sprite or not is_instance_valid(_sprite):
		return
	var tex_w: float = maxf(_sprite.texture.get_width(), 1.0)
	var tex_h: float = maxf(_sprite.texture.get_height(), 1.0)
	_sprite.scale = Vector2(_beam_width / tex_w, length / tex_h)
	_sprite.position = Vector2(center_x, base_y - length / 2.0)


func _apply_zoom_pan() -> void:
	if not _content:
		return
	var center: Vector2 = _viewport_size / 2.0
	# Scale around viewport center, then apply pan
	_content.transform = Transform2D.IDENTITY
	_content.position = center + _pan_offset * _zoom - center * _zoom
	_content.scale = Vector2(_zoom, _zoom)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_event_in_bounds(event):
		if event is InputEventMouseButton:
			_is_panning = false
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_apply_zoom_pan()
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
				_apply_zoom_pan()
				get_viewport().set_input_as_handled()
			elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
				_is_panning = true
				get_viewport().set_input_as_handled()
		else:
			if mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
				_is_panning = false
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_pan_offset += mm.relative / _zoom
		_apply_zoom_pan()
		get_viewport().set_input_as_handled()


func _is_event_in_bounds(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var local: Vector2 = (event as InputEventMouseButton).position - global_position
		return Rect2(Vector2.ZERO, _viewport_size).has_point(local)
	if event is InputEventMouseMotion:
		var local: Vector2 = (event as InputEventMouseMotion).position - global_position
		return Rect2(Vector2.ZERO, _viewport_size).has_point(local)
	return false


func _draw() -> void:
	# Background (always drawn without zoom/pan)
	draw_rect(Rect2(Vector2.ZERO, _viewport_size), Color(0.02, 0.02, 0.05, 1.0))

	# Grid with zoom/pan transform
	var center: Vector2 = _viewport_size / 2.0
	var grid_xform: Transform2D = Transform2D.IDENTITY
	grid_xform.origin = center + _pan_offset * _zoom - center * _zoom
	grid_xform = grid_xform.scaled(Vector2(_zoom, _zoom))
	draw_set_transform_matrix(grid_xform)

	var grid_color: Color = Color(0.1, 0.1, 0.15, 0.3)
	var grid_extent: float = 2000.0
	for x in range(-int(grid_extent), int(grid_extent), 40):
		draw_line(Vector2(x, 0), Vector2(x, _viewport_size.y), grid_color, 1.0)
	for y in range(-int(grid_extent), int(grid_extent), 40):
		draw_line(Vector2(0, y), Vector2(grid_extent, y), grid_color, 1.0)

	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Pulse wave fallback drawing when no sprite
	if _archetype == "pulse_wave" and (not _sprite or not is_instance_valid(_sprite)):
		draw_set_transform_matrix(grid_xform)
		_draw_pulse_wave_fallback()
		draw_set_transform_matrix(Transform2D.IDENTITY)

	# Zoom level indicator
	if _zoom != 1.0 or _pan_offset != Vector2.ZERO:
		var zoom_text: String = "%.0f%%" % (_zoom * 100.0)
		draw_string(ThemeDB.fallback_font, Vector2(8, _viewport_size.y - 8),
			zoom_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.5, 0.5, 0.6, 0.6))


func _draw_pulse_wave_fallback() -> void:
	var center: Vector2 = Vector2(_viewport_size.x / 2.0, _viewport_size.y / 2.0)
	var hdr: float = 2.0
	var radius: float = _max_radius * 0.5
	draw_arc(center, radius, 0, TAU, 48,
		Color(_preview_color.r * hdr, _preview_color.g * hdr, _preview_color.b * hdr, 0.8), _ring_width)
