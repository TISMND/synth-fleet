extends Node
## Attached to the Level scene. Starts BeatClock, starts enemy spawner,
## handles scrolling background.

@export var level_bpm: float = 120.0
@export var scroll_speed: float = 50.0

var parallax_bg: ParallaxBackground
var enemy_spawner: Node
var hud: CanvasLayer
var player: CharacterBody2D


func _ready() -> void:
	parallax_bg = $"../ScrollingBG"
	enemy_spawner = $"../EnemySpawner"
	player = $"../Player"
	hud = $"../HUD"

	BeatClock.start(level_bpm)

	# Load weapon pattern from GameState onto the forward weapon
	var forward_weapon := player.get_node_or_null("ForwardMount/ForwardWeapon")
	if forward_weapon and forward_weapon is WeaponBase:
		if "forward" in GameState.weapon_patterns:
			forward_weapon.load_pattern_from_slots(GameState.weapon_patterns["forward"])

	if enemy_spawner.has_method("start_spawning"):
		enemy_spawner.start_spawning()
	if hud and player:
		# Deferred so HUD's _ready() has resolved its child node refs first
		hud.connect_to_player.call_deferred(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
	if event.is_action_pressed("return_to_menu"):
		BeatClock.stop()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _process(delta: float) -> void:
	if parallax_bg:
		parallax_bg.scroll_offset.y += scroll_speed * delta
