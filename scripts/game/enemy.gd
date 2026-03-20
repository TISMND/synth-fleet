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
var _shield_bubble: ShieldBubbleEffect = null
var _weapon_controller: EnemyWeaponController = null

# Set externally before adding to scene tree for weapon setup
var ship_data_ref: ShipData = null
var player_ref: Node2D = null
var projectiles_container: Node2D = null


func _ready() -> void:
	add_to_group("enemies")

	# Register presence with game node for audio loop tracking
	if ship_id != "" and presence_loop_path != "":
		var game_node: Node2D = get_parent().get_parent() as Node2D
		if game_node and game_node.has_method("register_enemy_presence"):
			game_node.register_enemy_presence(ship_id, presence_loop_path)
		tree_exiting.connect(_on_presence_exit)

	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(float(maxi(grid_size.x, grid_size.y)) * 0.4, 12.0)
	shape.shape = circle
	add_child(shape)

	# Add ShipRenderer for visual drawing instead of hardcoded _draw()
	_renderer = ShipRenderer.new()
	_renderer.ship_id = -1
	_renderer.enemy_visual_id = visual_id if visual_id != "" else "sentinel"
	_renderer.render_mode = ShipRenderer.RenderMode.CHROME if render_mode_str == "chrome" else ShipRenderer.RenderMode.NEON
	_renderer.hull_color = enemy_color
	_renderer.accent_color = Color(1.0, 0.2, 0.6)
	add_child(_renderer)

	# VFX hit effects
	var vfx: VfxConfig = VfxConfigManager.load_config()
	_renderer.hull_peak_color = Color(vfx.hull_peak_r, vfx.hull_peak_g, vfx.hull_peak_b, 1.0)
	_renderer.hull_blink_speed = vfx.hull_blink_speed
	_renderer.hull_flash_duration = vfx.hull_duration
	_shield_bubble = ShieldBubbleEffect.new()
	_shield_bubble.shield_color = Color(vfx.shield_color_r, vfx.shield_color_g, vfx.shield_color_b)
	_shield_bubble.flash_duration = vfx.shield_duration
	_shield_bubble.radius_mult = vfx.shield_radius_mult
	_shield_bubble.intensity = vfx.shield_intensity
	_shield_bubble.ship_radius = ShipRenderer.get_ship_scale(-1) * 50.0
	add_child(_shield_bubble)

	# Setup weapon controller if ship data has weapon fields
	if ship_data_ref and ship_data_ref.fire_rate > 0.0 and projectiles_container:
		_weapon_controller = EnemyWeaponController.new()
		_weapon_controller.projectile_color = enemy_color
		_weapon_controller.weapons_enabled = weapons_active
		add_child(_weapon_controller)
		_weapon_controller.setup(ship_data_ref, self, player_ref, projectiles_container)


func _on_presence_exit() -> void:
	# Unregister presence with game node when leaving the tree
	var parent: Node = get_parent()
	if parent:
		var game_node: Node2D = parent.get_parent() as Node2D
		if game_node and game_node.has_method("unregister_enemy_presence"):
			game_node.unregister_enemy_presence(ship_id)


func set_melee_target(target: Node2D) -> void:
	_melee_target = target


func _process(delta: float) -> void:
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
	explosion.explosion_color = enemy_color
	explosion.explosion_size = maxf(float(maxi(grid_size.x, grid_size.y)) / 32.0, 0.8)
	explosion.global_position = global_position
	# Add to parent (enemies container) so it persists after enemy queue_free
	var container: Node = get_parent()
	if container:
		container.add_child(explosion)


func take_damage(amount: int) -> void:
	var remaining: int = amount
	if shield > 0:
		var absorbed: int = mini(remaining, shield)
		shield -= absorbed
		remaining -= absorbed
		SfxPlayer.play("enemy_shield_hit")
		if _shield_bubble:
			_shield_bubble.trigger()
	if remaining > 0:
		health -= remaining
		SfxPlayer.play("enemy_hull_hit")
		if _renderer:
			_renderer.trigger_hull_flash()
	if health <= 0:
		if _weapon_controller:
			_weapon_controller.cleanup()
		SfxPlayer.play_random_explosion()
		GameState.add_credits(10)
		_spawn_explosion()
		queue_free()


