class_name Enemy
extends Area2D
## Enemy that drifts down the screen or follows a flight path curve.
## Takes damage from projectiles, awards credits on death.

var health: int = 30
var shield: int = 0
var drift_speed: float = 100.0
var enemy_color: Color = Color(1.0, 0.3, 0.5)
var visual_id: String = ""
var render_mode_str: String = "neon"
var grid_size: Vector2i = Vector2i(32, 32)
var ship_id: String = ""                    # ShipData id for presence tracking
var presence_loop_path: String = ""         # Audio loop path for presence system

# Path-following mode (set externally; null = drift mode)
var path_curve: Curve2D = null
var path_speed: float = 200.0
var path_progress: float = 0.0  # distance traveled along curve
var path_offset: Vector2 = Vector2.ZERO  # formation slot offset
var path_origin: Vector2 = Vector2.ZERO  # x_offset from level encounter
var rotate_with_path: bool = false

# Melee chase mode
var is_melee: bool = false
var melee_speed: float = 200.0
var melee_turn_speed: float = 90.0  # degrees per second
var _melee_heading: float = PI / 2.0  # radians, starts pointing down
var _melee_target: Node2D = null

# Whether this enemy's weapons are active (set by encounter data)
var weapons_active: bool = true

var _renderer: ShipRenderer = null
var _baked_sprite: Sprite2D = null
var _flash_material: ShaderMaterial = null
var _hit_flash: float = 0.0
var _hull_flash_duration: float = 0.1
var _hull_blink_speed: float = 8.0
var _hull_flash_opacity: float = 0.5
var _shield_field: FieldRenderer = null
var _weapon_controller: EnemyWeaponController = null

# Set externally before adding to scene tree for weapon setup
var ship_data_ref: ShipData = null
var player_ref: Node2D = null
var projectiles_container: Node2D = null
var shared_renderer: EnemySharedRenderer = null


func _ready() -> void:
	add_to_group("enemies")

	collision_layer = 4
	collision_mask = 0
	var col_shape := CollisionShape2D.new()
	if ship_data_ref:
		var col_result: Dictionary = _make_collision_shape(ship_data_ref)
		col_shape.shape = col_result["shape"]
		col_shape.rotation = float(col_result["rotation"])
	else:
		var circle := CircleShape2D.new()
		circle.radius = maxf(float(maxi(grid_size.x, grid_size.y)) * 0.4, 12.0)
		col_shape.shape = circle
	add_child(col_shape)

	# Per-ship hull flash settings
	if ship_data_ref:
		_hull_flash_opacity = ship_data_ref.hull_flash_opacity
		_hull_blink_speed = ship_data_ref.hull_blink_speed
		_hull_flash_duration = ship_data_ref.hull_flash_duration

	# Try shared bake viewport first — falls back to per-instance ShipRenderer
	var vid: String = visual_id if visual_id != "" else "sentinel"
	var bake_tex: ViewportTexture = null
	if shared_renderer:
		bake_tex = shared_renderer.get_texture(vid, render_mode_str, enemy_color)

	if bake_tex:
		_baked_sprite = Sprite2D.new()
		_baked_sprite.texture = bake_tex
		_flash_material = shared_renderer.create_flash_material()
		_baked_sprite.material = _flash_material
		add_child(_baked_sprite)
		shared_renderer.ref(vid, render_mode_str, enemy_color)
	else:
		# Fallback: per-instance ShipRenderer (for unregistered appearances or no bake manager)
		_renderer = ShipRenderer.new()
		_renderer.ship_id = -1
		_renderer.enemy_visual_id = vid
		_renderer.render_mode = ShipRenderer.RenderMode.CHROME if render_mode_str == "chrome" else ShipRenderer.RenderMode.NEON
		_renderer.hull_color = enemy_color
		_renderer.accent_color = Color(1.0, 0.2, 0.6)
		if ship_data_ref:
			_renderer.hull_flash_opacity = _hull_flash_opacity
			_renderer.hull_blink_speed = _hull_blink_speed
			_renderer.hull_flash_duration = _hull_flash_duration
		add_child(_renderer)
	# Per-ship shield hit visual via FieldRenderer
	var style_id: String = ship_data_ref.shield_style_id if ship_data_ref else ""
	if style_id != "":
		var style: FieldStyle = FieldStyleManager.load_by_id(style_id)
		if style:
			_shield_field = FieldRenderer.new()
			var ship_radius: float = ShipRenderer.get_ship_scale(-1) * 50.0
			_shield_field.setup(style, ship_radius)
			_shield_field._stay_visible = false
			_shield_field.visible = false
			add_child(_shield_field)

	# Setup weapon controller if ship has a weapon assigned
	if ship_data_ref and ship_data_ref.weapon_id != "" and projectiles_container:
		_weapon_controller = EnemyWeaponController.new()
		_weapon_controller.projectile_color = enemy_color
		_weapon_controller.weapons_enabled = weapons_active
		add_child(_weapon_controller)
		_weapon_controller.setup(ship_data_ref, self, player_ref, projectiles_container)

	# Always clean up weapon controller when leaving tree (death, off-screen, etc.)
	tree_exiting.connect(_on_cleanup)


static func _make_collision_shape(ship: ShipData) -> Dictionary:
	## Returns {"shape": Shape2D, "rotation": float} — rotation needed for horizontal capsules.
	var w: float = ship.collision_width
	var h: float = ship.collision_height
	match ship.collision_shape:
		"rectangle":
			var rect := RectangleShape2D.new()
			rect.size = Vector2(w, h)
			return {"shape": rect, "rotation": 0.0}
		"capsule":
			var cap := CapsuleShape2D.new()
			if w > h:
				cap.radius = h * 0.5
				cap.height = maxf(w, h)
				return {"shape": cap, "rotation": PI * 0.5}
			else:
				cap.radius = w * 0.5
				cap.height = maxf(h, w)
				return {"shape": cap, "rotation": 0.0}
		_:  # "circle"
			var circle := CircleShape2D.new()
			circle.radius = w * 0.5
			return {"shape": circle, "rotation": 0.0}


func _on_cleanup() -> void:
	if _weapon_controller:
		_weapon_controller.cleanup()
		_weapon_controller = null
	if _baked_sprite and shared_renderer:
		var vid: String = visual_id if visual_id != "" else "sentinel"
		shared_renderer.unref(vid, render_mode_str, enemy_color)


func set_melee_target(target: Node2D) -> void:
	_melee_target = target


func _process(delta: float) -> void:
	# Baked sprite hit flash (per-instance, independent of shared viewport)
	if _hit_flash > 0.0 and _flash_material:
		_hit_flash -= delta
		var t: float = clampf(_hit_flash / maxf(_hull_flash_duration, 0.001), 0.0, 1.0)
		var on: bool = fmod(t * _hull_blink_speed, 2.0) > 1.0
		_flash_material.set_shader_parameter("flash_mix", _hull_flash_opacity if on else 0.0)
		if _hit_flash <= 0.0:
			_hit_flash = 0.0
			_flash_material.set_shader_parameter("flash_mix", 0.0)

	# Store position before movement for lead prediction
	set_meta("_prev_pos", global_position)
	set_meta("_prev_dt", delta)

	if is_melee:
		# Melee chase mode — turn-rate-limited steering toward player
		if is_instance_valid(_melee_target):
			var desired_angle: float = (_melee_target.global_position - global_position).angle()
			var max_turn: float = deg_to_rad(melee_turn_speed) * delta
			_melee_heading = rotate_toward(_melee_heading, desired_angle, max_turn)
		position += Vector2(cos(_melee_heading), sin(_melee_heading)) * melee_speed * delta
		rotation = _melee_heading - PI / 2.0
		# Wider despawn bounds so chasers can loop back
		if position.y > 2420 or position.y < -500 or position.x < -500 or position.x > 2420:
			queue_free()
	elif path_curve != null and path_curve.point_count >= 2:
		# Path-following mode
		path_progress += path_speed * delta
		var total_len: float = path_curve.get_baked_length()
		if path_progress >= total_len:
			queue_free()
			return
		var curve_pos: Vector2 = path_curve.sample_baked(path_progress)
		position = curve_pos + path_offset + path_origin
		if rotate_with_path:
			var behind: float = maxf(path_progress - 10.0, 0.0)
			var ahead: float = minf(path_progress + 10.0, total_len)
			var dir: Vector2 = path_curve.sample_baked(ahead) - path_curve.sample_baked(behind)
			if dir.length_squared() > 0.01:
				rotation = dir.angle() - PI / 2.0
		# Despawn if off screen
		if position.y > 1200 or position.y < -200 or position.x < -200 or position.x > 2120:
			queue_free()
	else:
		# Drift mode (legacy)
		position.y += drift_speed * delta
		if position.y > 1130:
			queue_free()


func _spawn_explosion() -> void:
	var explosion: ExplosionEffect = ExplosionEffect.new()
	if ship_data_ref:
		explosion.explosion_color = ship_data_ref.explosion_color
		explosion.explosion_size = ship_data_ref.explosion_size
		explosion.enable_screen_shake = ship_data_ref.enable_screen_shake
	else:
		explosion.explosion_color = enemy_color
		explosion.explosion_size = maxf(float(maxi(grid_size.x, grid_size.y)) / 32.0, 0.8)
	explosion.global_position = global_position
	# Add to parent (enemies container) so it persists after enemy queue_free
	var container: Node = get_parent()
	if container:
		container.add_child(explosion)


func take_damage(amount: int, skips_shields: bool = false) -> void:
	var remaining: int = amount
	if shield > 0 and not skips_shields:
		var absorbed: int = mini(remaining, shield)
		shield -= absorbed
		remaining -= absorbed
		SfxPlayer.play("enemy_shield_hit")
		if _shield_field:
			_shield_field.pulse()
	if remaining > 0:
		health -= remaining
		SfxPlayer.play("enemy_hull_hit")
		if _baked_sprite:
			_hit_flash = _hull_flash_duration
		elif _renderer:
			_renderer.trigger_hull_flash()
	if health <= 0:
		if _weapon_controller:
			_weapon_controller.cleanup()
			_weapon_controller = null
		SfxPlayer.play_random_explosion()
		GameState.add_credits(10)
		_spawn_explosion()
		queue_free()


