extends Control
## Between-level shop — buy stock weapons with credits before continuing.

const STOCK_WEAPONS: Array[Dictionary] = [
	{
		"id": "dual_pulse",
		"name": "Dual Pulse",
		"description": "Fires two parallel shots",
		"price": 80,
		"pattern": "dual",
		"sample": "017_SEPH_-_Synth_Hit_C3.wav",
		"color": "#FF55AA",
	},
	{
		"id": "spread_shot",
		"name": "Spread Shot",
		"description": "Wide three-way spread",
		"price": 120,
		"pattern": "spread",
		"sample": "030_Synth_Hit_C_-_TECHNOLOGY_Zenhiser.wav",
		"color": "#55FF88",
	},
	{
		"id": "scatter_cannon",
		"name": "Scatter Cannon",
		"description": "Random burst of projectiles",
		"price": 150,
		"pattern": "scatter",
		"sample": "049_Synth_Hit_E_-_CATALYST_Zenhiser.wav",
		"color": "#FFAA33",
	},
	{
		"id": "wave_beam",
		"name": "Wave Beam",
		"description": "Sinusoidal wave pattern",
		"price": 100,
		"pattern": "wave",
		"sample": "OS_OGA_Cmin_Synth_Hit_7.wav",
		"color": "#33AAFF",
	},
]

var _credits_label: Label = null
var _items_container: VBoxContainer = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_CENTER)
	main_vbox.position = Vector2(660, 80)
	main_vbox.custom_minimum_size = Vector2(600, 0)
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)

	# Title
	var title := Label.new()
	title.text = "SUPPLY DEPOT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	main_vbox.add_child(title)

	# Credits
	_credits_label = Label.new()
	_credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_label.add_theme_font_size_override("font_size", 22)
	_credits_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	main_vbox.add_child(_credits_label)

	# Next level info
	var next_level: int = GameState.current_level
	var level_names: Array[String] = ["NEON APPROACH", "CHROME CORRIDOR", "VOLTAGE CORE"]
	var level_bpms: Array[int] = [110, 128, 140]
	if next_level < level_names.size():
		var next_info := Label.new()
		next_info.text = "NEXT: " + level_names[next_level] + " (" + str(level_bpms[next_level]) + " BPM)"
		next_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		next_info.add_theme_font_size_override("font_size", 16)
		next_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.8))
		main_vbox.add_child(next_info)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	main_vbox.add_child(sep)

	# Weapon items
	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 12)
	main_vbox.add_child(_items_container)

	_refresh_items()

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 10)
	main_vbox.add_child(sep2)

	# Continue button
	var continue_btn := Button.new()
	continue_btn.text = "CONTINUE"
	continue_btn.custom_minimum_size = Vector2(200, 40)
	continue_btn.pressed.connect(_on_continue)
	main_vbox.add_child(continue_btn)

	_update_credits()


func _refresh_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()

	var owned_ids: Array[String] = WeaponDataManager.list_ids()

	for weapon in STOCK_WEAPONS:
		var weapon_id: String = str(weapon.get("id", ""))
		var weapon_name: String = str(weapon.get("name", ""))
		var weapon_desc: String = str(weapon.get("description", ""))
		var price: int = int(weapon.get("price", 0))
		var is_owned: bool = owned_ids.has(weapon_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		_items_container.add_child(row)

		# Weapon color indicator
		var color_rect := ColorRect.new()
		color_rect.custom_minimum_size = Vector2(16, 16)
		color_rect.color = Color(str(weapon.get("color", "#FFFFFF")))
		row.add_child(color_rect)

		# Name + description
		var info_label := Label.new()
		info_label.text = weapon_name + " — " + weapon_desc
		info_label.custom_minimum_size = Vector2(350, 0)
		info_label.add_theme_font_size_override("font_size", 16)
		info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		row.add_child(info_label)

		# Price
		var price_label := Label.new()
		price_label.text = str(price) + " CR"
		price_label.custom_minimum_size = Vector2(80, 0)
		price_label.add_theme_font_size_override("font_size", 16)
		price_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		row.add_child(price_label)

		# Buy/Owned button
		var btn := Button.new()
		if is_owned:
			btn.text = "OWNED"
			btn.disabled = true
		else:
			btn.text = "BUY"
			btn.pressed.connect(_on_buy.bind(weapon))
		btn.custom_minimum_size = Vector2(80, 30)
		row.add_child(btn)


func _on_buy(weapon: Dictionary) -> void:
	var price: int = int(weapon.get("price", 0))
	if not GameState.spend_credits(price):
		return

	var weapon_id: String = str(weapon.get("id", ""))
	var data: Dictionary = {
		"id": weapon_id,
		"name": str(weapon.get("name", "")),
		"pattern": str(weapon.get("pattern", "forward")),
		"color": str(weapon.get("color", "#FFFFFF")),
		"sample": str(weapon.get("sample", "")),
		"subdivision": 1,
		"damage": 15,
		"projectile_speed": 800,
	}
	WeaponDataManager.save(weapon_id, data)

	if not GameState.owned_weapon_ids.has(weapon_id):
		GameState.owned_weapon_ids.append(weapon_id)
		GameState.save_game()

	_refresh_items()
	_update_credits()


func _update_credits() -> void:
	_credits_label.text = "CREDITS: " + str(GameState.credits)


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")
