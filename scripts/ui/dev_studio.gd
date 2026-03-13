extends Control
## Dev Studio — tabbed container for Weapon Builder, Ship Builder, Aesthetic Workshop.


func _ready() -> void:
	$BackButton.pressed.connect(_on_back)


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		_on_back()
