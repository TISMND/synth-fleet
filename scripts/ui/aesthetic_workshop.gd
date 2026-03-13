extends Control
## Aesthetic Workshop — displays 4 visual style variations side-by-side.

func _ready() -> void:
	if not BeatClock._running:
		BeatClock.start(120.0)
	$VBox/BackButton.pressed.connect(func() -> void:
		BeatClock.stop()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
