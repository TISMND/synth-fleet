extends Control
## Mission Prep menu: Change Ship, Loadout, Crew, Audio Mix, Tutorial, Launch, Back.

var _vhs_overlay: ColorRect


func _ready() -> void:
	_setup_vhs_overlay()
	ThemeManager.theme_changed.connect(_on_theme_changed)

	$VBoxContainer/ChangeShipButton.pressed.connect(_on_change_ship)
	$VBoxContainer/LoadoutButton.pressed.connect(_on_loadout)
	$VBoxContainer/CrewButton.pressed.connect(_on_crew)
	$VBoxContainer/AudioMixButton.pressed.connect(_on_audio_mix)
	$VBoxContainer/TutorialButton.pressed.connect(_on_tutorial)
	$VBoxContainer/LaunchButton.pressed.connect(_on_launch)
	$VBoxContainer/BackButton.pressed.connect(_on_back)

	_apply_styles()


func _on_change_ship() -> void:
	pass  # Greyed out for demo


func _on_loadout() -> void:
	var HangarScreen: GDScript = load("res://scripts/ui/hangar_screen.gd")
	HangarScreen.set("initial_mode", "workshop")
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_crew() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/upgrade_screen.tscn")


func _on_audio_mix() -> void:
	var HangarScreen: GDScript = load("res://scripts/ui/hangar_screen.gd")
	HangarScreen.set("initial_mode", "audio")
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _on_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/tutorial_screen.tscn")


func _on_launch() -> void:
	GameState.current_level_id = "level_1"
	GameState.return_scene = "res://scenes/ui/mission_prep_menu.tscn"
	SceneLoader.load_scene("res://scenes/game/game.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _apply_styles() -> void:
	for child in $VBoxContainer.get_children():
		if child is Button:
			var btn: Button = child as Button
			ThemeManager.apply_button_style(btn)
			# Darken backgrounds for readability against bright hangar backdrop
			for state in ["normal", "hover", "pressed", "focus"]:
				var sb: StyleBox = btn.get_theme_stylebox(state)
				if sb and sb is StyleBoxFlat:
					var dark: StyleBoxFlat = (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
					if state == "hover":
						dark.bg_color = Color(0.18, 0.18, 0.18, 0.95)
					elif state == "pressed":
						dark.bg_color = Color(0.12, 0.12, 0.12, 0.95)
					else:
						dark.bg_color = Color(0.06, 0.06, 0.06, 0.95)
					btn.add_theme_stylebox_override(state, dark)


func _setup_vhs_overlay() -> void:
	var vhs_layer := CanvasLayer.new()
	vhs_layer.layer = 10
	add_child(vhs_layer)
	_vhs_overlay = ColorRect.new()
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vhs_layer.add_child(_vhs_overlay)
	ThemeManager.apply_vhs_overlay(_vhs_overlay)


func _on_theme_changed() -> void:
	ThemeManager.apply_vhs_overlay(_vhs_overlay)
	_apply_styles()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
