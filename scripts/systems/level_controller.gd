extends Node
## Attached to the Level scene. Starts BeatClock, starts enemy spawner,
## handles scrolling background.

@export var level_bpm: float = 120.0
@export var scroll_speed: float = 50.0

@onready var parallax_bg: ParallaxBackground = $"../ScrollingBG"
@onready var enemy_spawner: Node = $"../EnemySpawner"


func _ready() -> void:
	BeatClock.start(level_bpm)
	if enemy_spawner.has_method("start_spawning"):
		enemy_spawner.start_spawning()


func _process(delta: float) -> void:
	if parallax_bg:
		parallax_bg.scroll_offset.y += scroll_speed * delta
