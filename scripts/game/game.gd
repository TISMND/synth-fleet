extends Node2D
## Game orchestrator — level intro, wave-based combat, level complete, shop/victory flow.

enum GamePhase { LEVEL_INTRO, PLAYING, LEVEL_COMPLETE, GAME_OVER, VICTORY }

const LEVELS: Array[Dictionary] = [
	{
		"name": "NEON APPROACH",
		"bpm": 110,
		"credit_bonus": 50,
		"waves": [
			{"count": 4, "health": 25, "speed_min": 70.0, "speed_max": 120.0, "spawn_interval": 1.5, "delay_after": 3.0},
			{"count": 6, "health": 30, "speed_min": 80.0, "speed_max": 130.0, "spawn_interval": 1.3, "delay_after": 3.0},
			{"count": 8, "health": 35, "speed_min": 80.0, "speed_max": 140.0, "spawn_interval": 1.2, "delay_after": 3.0},
			{"count": 10, "health": 40, "speed_min": 90.0, "speed_max": 150.0, "spawn_interval": 1.0, "delay_after": 2.0},
		],
	},
	{
		"name": "CHROME CORRIDOR",
		"bpm": 128,
		"credit_bonus": 100,
		"waves": [
			{"count": 6, "health": 35, "speed_min": 90.0, "speed_max": 140.0, "spawn_interval": 1.3, "delay_after": 3.0},
			{"count": 8, "health": 40, "speed_min": 100.0, "speed_max": 150.0, "spawn_interval": 1.2, "delay_after": 3.0},
			{"count": 10, "health": 45, "speed_min": 100.0, "speed_max": 160.0, "spawn_interval": 1.0, "delay_after": 3.0},
			{"count": 12, "health": 50, "speed_min": 110.0, "speed_max": 170.0, "spawn_interval": 0.9, "delay_after": 3.0},
			{"count": 14, "health": 55, "speed_min": 110.0, "speed_max": 180.0, "spawn_interval": 0.8, "delay_after": 2.0},
		],
	},
	{
		"name": "VOLTAGE CORE",
		"bpm": 140,
		"credit_bonus": 200,
		"waves": [
			{"count": 8, "health": 45, "speed_min": 100.0, "speed_max": 160.0, "spawn_interval": 1.2, "delay_after": 3.0},
			{"count": 10, "health": 50, "speed_min": 110.0, "speed_max": 170.0, "spawn_interval": 1.0, "delay_after": 3.0},
			{"count": 12, "health": 55, "speed_min": 110.0, "speed_max": 180.0, "spawn_interval": 0.9, "delay_after": 3.0},
			{"count": 14, "health": 60, "speed_min": 120.0, "speed_max": 190.0, "spawn_interval": 0.8, "delay_after": 3.0},
			{"count": 16, "health": 65, "speed_min": 120.0, "speed_max": 200.0, "spawn_interval": 0.7, "delay_after": 3.0},
			{"count": 18, "health": 70, "speed_min": 130.0, "speed_max": 210.0, "spawn_interval": 0.6, "delay_after": 2.0},
		],
	},
]

var _phase: int = GamePhase.LEVEL_INTRO
var _current_level: int = 0
var _player: Node2D = null
var _wave_manager: WaveManager = null
var _hud: CanvasLayer = null
var _projectiles: Node2D = null
var _enemies: Node2D = null
var _parallax_bg: ParallaxBackground = null


func _ready() -> void:
	_setup_world_environment()

	# Load ship + hardpoint config from GameState
	var ship_id: String = GameState.current_ship_id
	if ship_id == "":
		_show_error("No ship selected. Go to HANGAR to choose a ship.")
		return
	var ship: ShipData = ShipDataManager.load_by_id(ship_id)
	if not ship:
		_show_error("Failed to load ship: " + ship_id)
		return
	var loadout: LoadoutData = GameState.get_loadout_data()

	# Determine current level
	_current_level = GameState.current_level
	if _current_level >= LEVELS.size():
		_current_level = 0
		GameState.current_level = 0

	var level: Dictionary = LEVELS[_current_level]
	var level_bpm: float = float(level.get("bpm", 120))

	# Set BPM before player setup so hardpoint timers use correct interval
	BeatClock.bpm = level_bpm

	# Build scene tree
	_setup_parallax()

	_projectiles = Node2D.new()
	_projectiles.name = "Projectiles"
	add_child(_projectiles)

	_enemies = Node2D.new()
	_enemies.name = "Enemies"
	add_child(_enemies)

	# Player
	_player = Node2D.new()
	_player.set_script(load("res://scripts/game/player_ship.gd"))
	_player.name = "PlayerShip"
	add_child(_player)
	_player.setup(ship, loadout, _projectiles)
	_player.position = Vector2(960, 850)
	_player.died.connect(_on_player_died)

	# Wave manager
	_wave_manager = WaveManager.new()
	_wave_manager.name = "WaveManager"
	add_child(_wave_manager)
	_wave_manager.wave_started.connect(_on_wave_started)
	_wave_manager.wave_cleared.connect(_on_wave_cleared)
	_wave_manager.all_waves_cleared.connect(_on_all_waves_cleared)

	# HUD
	_hud = CanvasLayer.new()
	_hud.set_script(load("res://scripts/game/hud.gd"))
	_hud.name = "HUD"
	add_child(_hud)

	# Wire HUD to player for hardpoint display
	_player._hud = _hud
	_player._update_hud_hardpoints()

	# Start level intro
	_start_level_intro()


func _process(delta: float) -> void:
	# Scroll parallax
	if _parallax_bg:
		_parallax_bg.scroll_offset.y += 80.0 * delta

	# Update HUD
	if _hud and _player and _phase != GamePhase.GAME_OVER and _phase != GamePhase.VICTORY:
		_hud.update_health(_player.shield, _player.shield_max, _player.hull, _player.hull_max)
		_hud.update_credits(GameState.credits)


func _start_level_intro() -> void:
	_phase = GamePhase.LEVEL_INTRO
	var level: Dictionary = LEVELS[_current_level]
	var level_name: String = str(level.get("name", "UNKNOWN"))
	var level_bpm: float = float(level.get("bpm", 120))

	# Start BeatClock and LoopMixer during intro
	BeatClock.start(level_bpm)

	# Load atmosphere loops if defined
	var atmo_loops: Array = level.get("atmosphere_loops", [])
	for atmo in atmo_loops:
		var atmo_id: String = str(atmo.get("id", ""))
		var atmo_path: String = str(atmo.get("path", ""))
		if atmo_id != "" and atmo_path != "":
			LoopMixer.add_loop(atmo_id, atmo_path, "Master", 0.0, false)

	# Start all loops (atmosphere unmuted, weapon loops muted by their controllers)
	LoopMixer.start_all()

	if _hud:
		_hud.show_level_intro(level_name, _current_level + 1)
		_hud.update_level(level_name, _current_level + 1)

	# 3s delay then start playing
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.timeout.connect(_start_playing)
	add_child(timer)
	timer.start()


func _start_playing() -> void:
	_phase = GamePhase.PLAYING
	if _hud:
		_hud.hide_level_intro()

	var level: Dictionary = LEVELS[_current_level]
	var waves: Array = level.get("waves", [])
	_wave_manager.setup(waves, _enemies)
	_wave_manager.start()


func _on_wave_started(wave_index: int, total_waves: int) -> void:
	if _hud:
		_hud.update_wave(wave_index + 1, total_waves)


func _on_wave_cleared(wave_index: int, total_waves: int) -> void:
	pass


func _on_all_waves_cleared() -> void:
	_phase = GamePhase.LEVEL_COMPLETE
	var level: Dictionary = LEVELS[_current_level]
	var bonus: int = int(level.get("credit_bonus", 0))

	GameState.add_credits(bonus)
	BeatClock.stop()
	LoopMixer.remove_all_loops()
	if _player:
		_player.stop_all()

	if _hud:
		_hud.show_level_complete(bonus)

	# 3s delay then shop or victory
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.timeout.connect(_after_level_complete)
	add_child(timer)
	timer.start()


func _after_level_complete() -> void:
	var next_level: int = _current_level + 1
	if next_level >= LEVELS.size():
		_show_victory()
	else:
		GameState.current_level = next_level
		GameState.save_game()
		get_tree().change_scene_to_file("res://scenes/ui/shop.tscn")


func _on_player_died() -> void:
	_phase = GamePhase.GAME_OVER
	BeatClock.stop()
	LoopMixer.remove_all_loops()
	if _wave_manager:
		_wave_manager.stop()
	if _player:
		_player.stop_all()
	if _hud:
		_hud.show_game_over()


func _show_victory() -> void:
	_phase = GamePhase.VICTORY
	GameState.reset_campaign()
	if _hud:
		_hud.show_victory()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_return_to_menu()
		return
	if (_phase == GamePhase.GAME_OVER or _phase == GamePhase.VICTORY) and event is InputEventKey and event.pressed:
		_return_to_menu()


func _return_to_menu() -> void:
	BeatClock.stop()
	LoopMixer.remove_all_loops()
	if _wave_manager:
		_wave_manager.stop()
	if _player:
		_player.stop_all()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _show_error(msg: String) -> void:
	var label := Label.new()
	label.text = msg
	label.position = Vector2(500, 500)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	add_child(label)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 3.0
	timer.timeout.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	add_child(timer)
	timer.start()


func _setup_world_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8
	env.set_glow_level(0, true)
	env.set_glow_level(1, true)
	env.set_glow_level(2, true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	world_env.environment = env
	add_child(world_env)


func _setup_parallax() -> void:
	_parallax_bg = ParallaxBackground.new()
	_parallax_bg.name = "ParallaxBG"
	add_child(_parallax_bg)
	_add_star_layer(0.3, 80, Color(0.3, 0.3, 0.5, 0.5), 1)
	_add_star_layer(0.7, 50, Color(0.5, 0.5, 0.8, 0.7), 2)


func _add_star_layer(motion_scale: float, star_count: int, color: Color, seed_val: int) -> void:
	var layer := ParallaxLayer.new()
	layer.motion_scale = Vector2(0, motion_scale)
	layer.motion_mirroring = Vector2(0, 1200)
	_parallax_bg.add_child(layer)

	var stars := _StarField.new()
	stars.star_count = star_count
	stars.star_color = color
	stars.star_seed = seed_val
	stars.size = Vector2(1920, 1200)
	layer.add_child(stars)


class _StarField extends Control:
	var star_count: int = 60
	var star_color: Color = Color(0.5, 0.5, 0.8, 0.6)
	var star_seed: int = 1
	var _positions: PackedVector2Array = PackedVector2Array()
	var _sizes: PackedFloat32Array = PackedFloat32Array()

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = star_seed
		for i in star_count:
			_positions.append(Vector2(rng.randf() * 1920.0, rng.randf() * 1200.0))
			_sizes.append(rng.randf_range(1.0, 2.5))

	func _draw() -> void:
		for i in _positions.size():
			draw_circle(_positions[i], _sizes[i], star_color)
