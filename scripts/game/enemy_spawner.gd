extends Node
## Timer-based enemy spawner. Creates enemies at random positions along the top of the screen.

var _spawn_timer: Timer = null
var _enemies_container: Node2D = null
var _spawn_interval: float = 1.5

const ENEMY_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.5),
	Color(0.5, 1.0, 0.3),
	Color(1.0, 0.8, 0.2),
	Color(0.3, 0.5, 1.0),
	Color(1.0, 0.4, 0.9),
	Color(0.3, 1.0, 0.8),
]


func setup(container: Node2D) -> void:
	_enemies_container = container


func start() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = _spawn_interval
	_spawn_timer.timeout.connect(_on_spawn)
	add_child(_spawn_timer)
	_spawn_timer.start()


func stop() -> void:
	if _spawn_timer:
		_spawn_timer.stop()


func _on_spawn() -> void:
	if not _enemies_container:
		return
	var enemy := Enemy.new()
	enemy.position = Vector2(randf_range(100.0, 1820.0), -30.0)
	enemy.drift_speed = randf_range(80.0, 150.0)
	enemy.health = randi_range(20, 50)
	enemy.enemy_color = ENEMY_COLORS[randi() % ENEMY_COLORS.size()]
	_enemies_container.add_child(enemy)
