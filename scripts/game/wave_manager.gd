class_name WaveManager
extends Node
## Scripted wave sequencer — spawns enemies in waves with configurable counts/stats.

signal wave_started(wave_index: int, total_waves: int)
signal wave_cleared(wave_index: int, total_waves: int)
signal all_waves_cleared

var _waves: Array = []
var _enemies_container: Node2D = null
var _current_wave: int = 0
var _enemies_spawned: int = 0
var _enemies_to_spawn: int = 0
var _enemies_alive: int = 0
var _spawn_timer: Timer = null
var _delay_timer: Timer = null

const ENEMY_COLORS: Array[Color] = [
	Color(1.0, 0.3, 0.5),
	Color(0.5, 1.0, 0.3),
	Color(1.0, 0.8, 0.2),
	Color(0.3, 0.5, 1.0),
	Color(1.0, 0.4, 0.9),
	Color(0.3, 1.0, 0.8),
]


func setup(waves: Array, enemies_container: Node2D) -> void:
	_waves = waves
	_enemies_container = enemies_container


func start() -> void:
	_current_wave = 0
	_start_wave(0)


func stop() -> void:
	if _spawn_timer:
		_spawn_timer.stop()
	if _delay_timer:
		_delay_timer.stop()


func _start_wave(index: int) -> void:
	if index >= _waves.size():
		all_waves_cleared.emit()
		return

	_current_wave = index
	var wave: Dictionary = _waves[index]
	_enemies_to_spawn = int(wave.get("count", 5))
	_enemies_spawned = 0
	_enemies_alive = 0

	wave_started.emit(index, _waves.size())

	var interval: float = float(wave.get("spawn_interval", 1.0))

	if _spawn_timer:
		_spawn_timer.queue_free()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = interval
	_spawn_timer.timeout.connect(_on_spawn)
	add_child(_spawn_timer)
	_spawn_timer.start()


func _on_spawn() -> void:
	if not _enemies_container:
		return

	var wave: Dictionary = _waves[_current_wave]
	var health_val: int = int(wave.get("health", 30))
	var speed_min: float = float(wave.get("speed_min", 80.0))
	var speed_max: float = float(wave.get("speed_max", 150.0))

	var enemy := Enemy.new()
	enemy.position = Vector2(randf_range(100.0, 1820.0), -30.0)
	enemy.drift_speed = randf_range(speed_min, speed_max)
	enemy.health = health_val
	enemy.enemy_color = ENEMY_COLORS[randi() % ENEMY_COLORS.size()]
	enemy.tree_exiting.connect(_on_enemy_exited, CONNECT_ONE_SHOT)
	_enemies_container.add_child(enemy)

	_enemies_spawned += 1
	_enemies_alive += 1

	if _enemies_spawned >= _enemies_to_spawn:
		_spawn_timer.stop()


func _on_enemy_exited() -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0 and _enemies_spawned >= _enemies_to_spawn:
		_on_wave_complete()


func _on_wave_complete() -> void:
	wave_cleared.emit(_current_wave, _waves.size())

	var wave: Dictionary = _waves[_current_wave]
	var delay: float = float(wave.get("delay_after", 2.0))

	var next_index: int = _current_wave + 1
	if next_index >= _waves.size():
		# Small delay before signaling all cleared
		if _delay_timer:
			_delay_timer.queue_free()
		_delay_timer = Timer.new()
		_delay_timer.one_shot = true
		_delay_timer.wait_time = delay
		_delay_timer.timeout.connect(func() -> void:
			all_waves_cleared.emit()
		)
		add_child(_delay_timer)
		_delay_timer.start()
		return

	if _delay_timer:
		_delay_timer.queue_free()
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	_delay_timer.wait_time = delay
	_delay_timer.timeout.connect(_start_wave.bind(next_index))
	add_child(_delay_timer)
	_delay_timer.start()
