class_name EnemyWeaponController
extends Node
## Timer-based enemy firing system. Reads fire_pattern, fire_rate, enemy_damage,
## and projectile_speed from ShipData. Supports straight/turret/burst patterns.
## NOT beat-synced — uses a simple Timer for firing intervals.

var fire_pattern: String = "straight"
var fire_rate: float = 1.5
var enemy_damage: int = 10
var projectile_speed: float = 300.0
var burst_directions: int = 4
var projectile_color: Color = Color(1.0, 0.3, 0.5)
var weapons_enabled: bool = true

var _fire_timer: Timer = null
var _owner_enemy: Node2D = null
var _player_ref: Node2D = null
var _projectiles_container: Node2D = null


func setup(ship_data: ShipData, enemy_node: Node2D, player: Node2D, proj_container: Node2D) -> void:
	_owner_enemy = enemy_node
	_player_ref = player
	_projectiles_container = proj_container

	fire_pattern = ship_data.fire_pattern
	fire_rate = ship_data.fire_rate
	enemy_damage = ship_data.enemy_damage
	projectile_speed = ship_data.projectile_speed
	burst_directions = ship_data.burst_directions

	# Start fire timer
	_fire_timer = Timer.new()
	_fire_timer.one_shot = false
	_fire_timer.wait_time = maxf(fire_rate, 0.1)
	_fire_timer.timeout.connect(_on_fire)
	add_child(_fire_timer)

	# Add a random initial delay so enemies don't all fire at the same instant
	var initial_delay: float = randf_range(0.3, fire_rate)
	_fire_timer.start(initial_delay)


func _on_fire() -> void:
	if not weapons_enabled:
		return
	if not is_instance_valid(_owner_enemy):
		return
	if not _projectiles_container:
		return

	# Reset timer to normal interval after initial randomized shot
	if not is_equal_approx(_fire_timer.wait_time, maxf(fire_rate, 0.1)):
		_fire_timer.wait_time = maxf(fire_rate, 0.1)

	var origin: Vector2 = _owner_enemy.global_position

	match fire_pattern:
		"turret":
			_fire_turret(origin)
		"burst":
			_fire_burst(origin)
		_:  # "straight" or any unknown pattern
			_fire_straight(origin)


func _fire_straight(origin: Vector2) -> void:
	_spawn_projectile(origin, Vector2.DOWN)


func _fire_turret(origin: Vector2) -> void:
	if is_instance_valid(_player_ref):
		var dir: Vector2 = (_player_ref.global_position - origin).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector2.DOWN
		_spawn_projectile(origin, dir)
	else:
		# Fallback to straight down if no player
		_fire_straight(origin)


func _fire_burst(origin: Vector2) -> void:
	var count: int = maxi(burst_directions, 2)
	var angle_step: float = TAU / float(count)

	# Offset so one projectile always goes downward
	var base_angle: float = PI / 2.0  # 90 degrees = down in Godot coords

	for i in count:
		var angle: float = base_angle + angle_step * float(i)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		_spawn_projectile(origin, dir)


func _spawn_projectile(origin: Vector2, dir: Vector2) -> void:
	var proj := EnemyProjectile.new()
	proj.position = origin
	proj.direction = dir
	proj.speed = projectile_speed
	proj.damage = enemy_damage
	proj.projectile_color = projectile_color
	_projectiles_container.add_child(proj)


func cleanup() -> void:
	if _fire_timer:
		_fire_timer.stop()
		_fire_timer.queue_free()
		_fire_timer = null
