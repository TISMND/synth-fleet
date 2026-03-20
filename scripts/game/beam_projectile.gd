class_name BeamProjectile
extends Node2D
## Sustained beam visual + hitbox attached to hardpoint position.
## Three-phase lifecycle: appear → sustain → disappear.
## Appearance modes: flow_in (grows from ship) or expand_out (expands width).

var weapon_color: Color = Color.CYAN
var damage_per_tick: float = 5.0
var beam_duration: float = 0.3
var beam_transition_time: float = 0.1
var max_length: float = 400.0
var beam_width: float = 16.0
var beam_style: BeamStyle = null
var skips_shields: bool = false
var passthrough: bool = true
var appearance_mode: String = "flow_in"
var preview_mode: bool = false
var flip_shader: bool = false
var track_node: Node2D = null  # if set, beam follows this node's global_position each frame

var _age: float = 0.0
var _damage_accumulator: float = 0.0
var _sprite: Sprite2D = null
var _collision_area: Area2D = null
var _collision_shape: CollisionShape2D = null
var _rect_shape: RectangleShape2D = null
var _overlapping_enemies: Array[Area2D] = []


func _ready() -> void:
	_setup_visual()
	if not preview_mode:
		_setup_collision()


func _setup_visual() -> void:
	_sprite = Sprite2D.new()

	# Use VFXFactory white rect for consistency with projectile system
	var tex_w: int = maxi(int(beam_width), 4)
	var tex_h: int = maxi(int(max_length), 4)
	var img := Image.create(tex_w, tex_h, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_sprite.texture = ImageTexture.create_from_image(img)

	# Apply fill shader
	var mat := ShaderMaterial.new()
	var shader_name: String = "beam"
	if beam_style:
		shader_name = beam_style.fill_shader
	mat.shader = VFXFactory.get_fill_shader(shader_name)

	var color: Color = weapon_color
	if beam_style:
		color = beam_style.color
	mat.set_shader_parameter("weapon_color", color)

	if beam_style:
		for param in beam_style.shader_params:
			mat.set_shader_parameter(str(param), float(beam_style.shader_params[param]))

	_sprite.material = mat

	# Flip shader direction if requested (reverses UV.y scroll)
	var should_flip: bool = flip_shader
	if beam_style:
		should_flip = beam_style.flip_shader
	_sprite.flip_v = should_flip

	add_child(_sprite)

	# Set initial geometry based on appearance mode
	if appearance_mode == "flow_in":
		_update_beam_geometry(0.001, 1.0)
	elif appearance_mode == "expand_out":
		_update_beam_geometry(1.0, 0.001)
	else:
		_update_beam_geometry(1.0, 1.0)


func _setup_collision() -> void:
	_collision_area = Area2D.new()
	_collision_area.collision_layer = 2
	_collision_area.collision_mask = 4
	_collision_shape = CollisionShape2D.new()
	_rect_shape = RectangleShape2D.new()
	_rect_shape.size = Vector2(beam_width, max_length)
	_collision_shape.shape = _rect_shape
	_collision_shape.position = Vector2(0, -max_length / 2.0)
	_collision_area.add_child(_collision_shape)
	add_child(_collision_area)
	_collision_area.area_entered.connect(_on_area_entered)
	_collision_area.area_exited.connect(_on_area_exited)


func _process(delta: float) -> void:
	_age += delta

	# Track parent hardpoint position
	if track_node and is_instance_valid(track_node):
		global_position = track_node.global_position

	# Auto-destroy after duration
	if _age >= beam_duration:
		queue_free()
		return

	# Determine phase and progress
	var appear_end: float = beam_transition_time
	var disappear_start: float = beam_duration - beam_transition_time
	# Clamp so disappear_start >= appear_end
	if disappear_start < appear_end:
		disappear_start = appear_end

	var length_ratio: float = 1.0
	var width_ratio: float = 1.0

	if _age < appear_end:
		# Appear phase
		var t: float = _age / maxf(appear_end, 0.001)
		if appearance_mode == "flow_in":
			length_ratio = t
			width_ratio = 1.0
		else:  # expand_out
			length_ratio = 1.0
			width_ratio = t
	elif _age >= disappear_start:
		# Disappear phase
		var t: float = (_age - disappear_start) / maxf(beam_duration - disappear_start, 0.001)
		t = clampf(t, 0.0, 1.0)
		if appearance_mode == "flow_in":
			length_ratio = 1.0 - t
			width_ratio = 1.0
		else:  # expand_out
			length_ratio = 1.0
			width_ratio = 1.0 - t

	_update_beam_geometry(length_ratio, width_ratio)

	# Damage tick — apply DPS to all tracked overlapping enemies
	if not preview_mode and not _overlapping_enemies.is_empty():
		_damage_accumulator += damage_per_tick * delta
		if _damage_accumulator >= 1.0:
			var tick_damage: int = int(_damage_accumulator)
			_damage_accumulator -= float(tick_damage)
			_apply_damage_to_tracked(tick_damage)


func _update_beam_geometry(length_ratio: float, width_ratio: float) -> void:
	var current_length: float = max_length * maxf(length_ratio, 0.001)
	var current_width: float = beam_width * maxf(width_ratio, 0.001)
	if _sprite:
		_sprite.scale = Vector2(maxf(width_ratio, 0.001), maxf(length_ratio, 0.001))
		_sprite.position = Vector2(0, -current_length / 2.0)
	if _rect_shape:
		_rect_shape.size = Vector2(current_width, current_length)
		_collision_shape.position = Vector2(0, -current_length / 2.0)


func _apply_damage_to_tracked(dmg: int) -> void:
	# Iterate backwards to safely remove invalid refs
	var i: int = _overlapping_enemies.size() - 1
	while i >= 0:
		var area: Area2D = _overlapping_enemies[i]
		if not is_instance_valid(area):
			_overlapping_enemies.remove_at(i)
		elif area.has_method("take_damage"):
			area.take_damage(dmg, skips_shields)
		i -= 1


func _on_area_entered(area: Area2D) -> void:
	if preview_mode:
		return
	if area.has_method("take_damage"):
		if area not in _overlapping_enemies:
			_overlapping_enemies.append(area)
		# Immediate first-hit damage
		var initial_dmg: int = int(maxf(damage_per_tick * 0.1, 1.0))
		area.take_damage(initial_dmg, skips_shields)


func _on_area_exited(area: Area2D) -> void:
	var idx: int = _overlapping_enemies.find(area)
	if idx >= 0:
		_overlapping_enemies.remove_at(idx)
