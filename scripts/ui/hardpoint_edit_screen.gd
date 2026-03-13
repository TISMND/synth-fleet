extends MarginContainer
## Hardpoint Edit Screen — Tyrian-style: ship firing preview top-left, weapon list
## top-right, compact piano roll bottom. All changes auto-save to GameState.

const LOOP_LENGTHS: Array[int] = [4, 8, 16, 32]

# UI refs
var _firing_preview: ShipFiringPreview
var _power_budget_label: Label
var _power_bar: ProgressBar
var _hp_title: Label
var _weapon_container: VBoxContainer
var _weapon_buttons: Array = []  # Array[Dictionary] {button, weapon_id}
var _loop_selector: OptionButton
var _piano_roll: PianoRoll
var _stage_buttons: Array = []  # Array[Button]
var _play_button: Button
var _stop_button: Button

# State
var _ship: ShipData = null
var _hp_id: String = ""
var _hp_index: int = -1
var _hp_data: Dictionary = {}
var _weapon_ids: Array[String] = []
var _weapon_cache: Dictionary = {}
var _selected_weapon_id: String = ""
var _stage_patterns: Dictionary = {0: [], 1: [], 2: []}
var _active_stage: int = 0
var _is_playing: bool = false
var _playback_step: int = -1
var _playback_timer: Timer = null


func _ready() -> void:
	_hp_id = GameState._editing_hp_id
	if _hp_id == "":
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return
	_cache_weapons()
	_build_ui()
	_load_data()
	_setup_playback_timer()


func _cache_weapons() -> void:
	_weapon_ids = WeaponDataManager.list_ids()
	for wid in _weapon_ids:
		var w: WeaponData = WeaponDataManager.load_by_id(wid)
		if w:
			_weapon_cache[wid] = w


func _load_data() -> void:
	_ship = ShipDataManager.load_by_id(GameState.current_ship_id)
	if not _ship:
		get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")
		return

	# Find hardpoint index
	for i in _ship.hardpoints.size():
		if str(_ship.hardpoints[i].get("id", "")) == _hp_id:
			_hp_index = i
			_hp_data = _ship.hardpoints[i]
			break

	# Title
	var hp_label: String = str(_hp_data.get("label", _hp_id))
	var dir_deg: float = float(_hp_data.get("direction_deg", 0.0))
	_hp_title.text = hp_label + " (" + str(int(dir_deg)) + "°)"

	# Setup firing preview with ship
	_firing_preview.set_ship(_ship)

	# Load existing config
	var config: Dictionary = GameState.hardpoint_config.get(_hp_id, {})
	_selected_weapon_id = str(config.get("weapon_id", ""))

	# Build weapon list buttons
	_rebuild_weapon_list()

	# Apply weapon to preview
	if _selected_weapon_id != "":
		_apply_weapon(_selected_weapon_id)

	# Load stages from config
	var saved_stages: Array = config.get("stages", [])
	var default_loop: int = LOOP_LENGTHS[3]
	for si in 3:
		var blank: Array = []
		blank.resize(default_loop)
		blank.fill(-1)
		_stage_patterns[si] = blank

	for stage in saved_stages:
		var snum: int = int(stage.get("stage_number", 1))
		var si: int = snum - 1
		if si >= 0 and si < 3:
			var pat: Array = stage.get("pattern", [])
			if pat.size() > 0:
				_stage_patterns[si] = pat.duplicate()
				var ll: int = int(stage.get("loop_length", default_loop))
				for li in LOOP_LENGTHS.size():
					if LOOP_LENGTHS[li] == ll:
						_loop_selector.selected = li
						_piano_roll.set_loop_length(ll)
						break

	_active_stage = 0
	_piano_roll.set_pattern(_stage_patterns[0])
	_update_stage_button_colors()
	_update_power_budget()


# ── UI Construction ──────────────────────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# TOP SECTION (~75% height) — firing preview left, weapon list right
	var top_hbox := HBoxContainer.new()
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_stretch_ratio = 3.0
	root.add_child(top_hbox)

	# Left — Ship firing preview in SubViewport
	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 0.45
	top_hbox.add_child(preview_panel)

	var svpc := SubViewportContainer.new()
	svpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svpc.stretch = true
	preview_panel.add_child(svpc)

	var svp := SubViewport.new()
	svp.size = Vector2i(500, 600)
	svp.transparent_bg = false
	svp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svpc.add_child(svp)

	_firing_preview = ShipFiringPreview.new()
	svp.add_child(_firing_preview)

	# Right — weapon list + power
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_stretch_ratio = 0.55
	top_hbox.add_child(right_vbox)

	_hp_title = Label.new()
	_hp_title.text = ""
	_hp_title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_hp_title.add_theme_font_size_override("font_size", 16)
	right_vbox.add_child(_hp_title)

	var select_label := Label.new()
	select_label.text = "SELECT WEAPON"
	select_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	right_vbox.add_child(select_label)

	var weapon_scroll := ScrollContainer.new()
	weapon_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	weapon_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(weapon_scroll)

	_weapon_container = VBoxContainer.new()
	_weapon_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_scroll.add_child(_weapon_container)

	# Power budget
	_power_budget_label = Label.new()
	_power_budget_label.text = "POWER: 0 / 0"
	right_vbox.add_child(_power_budget_label)

	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size.y = 16
	_power_bar.max_value = 1
	_power_bar.value = 0
	_power_bar.show_percentage = false
	right_vbox.add_child(_power_bar)

	# BOTTOM SECTION (~25% height) — stage buttons + piano roll + controls
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_hbox.size_flags_stretch_ratio = 1.0
	root.add_child(bottom_hbox)

	# Stage buttons column
	var stage_vbox := VBoxContainer.new()
	stage_vbox.custom_minimum_size.x = 40
	bottom_hbox.add_child(stage_vbox)

	for si in 3:
		var sbtn := Button.new()
		sbtn.text = str(si + 1)
		sbtn.custom_minimum_size = Vector2(40, 40)
		var bound_si: int = si
		sbtn.pressed.connect(func() -> void:
			_on_stage_button(bound_si)
		)
		stage_vbox.add_child(sbtn)
		_stage_buttons.append(sbtn)

	# Piano roll (compact)
	_piano_roll = PianoRoll.new()
	_piano_roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_piano_roll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_piano_roll.custom_minimum_size = Vector2(0, 180)
	_piano_roll.note_count = 12
	_piano_roll.base_note = 12
	_piano_roll.loop_length = _get_current_loop_length()
	_piano_roll._init_pattern()
	_piano_roll._recalc_cells()
	_piano_roll.pattern_changed.connect(_on_pattern_changed)
	bottom_hbox.add_child(_piano_roll)

	# Controls column
	var controls_vbox := VBoxContainer.new()
	controls_vbox.custom_minimum_size.x = 120
	bottom_hbox.add_child(controls_vbox)

	var loop_row := HBoxContainer.new()
	controls_vbox.add_child(loop_row)
	var loop_label := Label.new()
	loop_label.text = "Loop:"
	loop_row.add_child(loop_label)
	_loop_selector = OptionButton.new()
	for ll in LOOP_LENGTHS:
		_loop_selector.add_item(str(ll))
	_loop_selector.selected = 3
	_loop_selector.item_selected.connect(_on_loop_length_changed)
	loop_row.add_child(_loop_selector)

	_play_button = Button.new()
	_play_button.text = "PLAY"
	_play_button.pressed.connect(_on_play)
	controls_vbox.add_child(_play_button)

	_stop_button = Button.new()
	_stop_button.text = "STOP"
	_stop_button.pressed.connect(_on_stop)
	controls_vbox.add_child(_stop_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_vbox.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(_on_back)
	controls_vbox.add_child(back_btn)


# ── Weapon List ──────────────────────────────────────────────

func _rebuild_weapon_list() -> void:
	for child in _weapon_container.get_children():
		child.queue_free()
	_weapon_buttons.clear()

	# "(none)" button
	var none_btn := Button.new()
	none_btn.text = "(none)"
	none_btn.custom_minimum_size.y = 45
	none_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	none_btn.pressed.connect(func() -> void:
		_on_weapon_button_pressed("")
	)
	_weapon_container.add_child(none_btn)
	_weapon_buttons.append({"button": none_btn, "id": ""})

	for wid in _weapon_ids:
		var w: WeaponData = _weapon_cache.get(wid)
		if not w:
			continue
		var btn := Button.new()
		var display: String = w.display_name if w.display_name != "" else w.id
		btn.text = display
		btn.custom_minimum_size.y = 45
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Color indicator via left icon (use font color)
		var bound_id: String = wid
		btn.pressed.connect(func() -> void:
			_on_weapon_button_pressed(bound_id)
		)
		_weapon_container.add_child(btn)
		_weapon_buttons.append({"button": btn, "id": wid})

	_update_weapon_highlights()


func _on_weapon_button_pressed(weapon_id: String) -> void:
	_selected_weapon_id = weapon_id
	if weapon_id == "":
		_piano_roll.set_weapon_color(Color.CYAN)
		_piano_roll.set_note_duration_cells(1)
		GameState.set_hardpoint_weapon(_hp_id, "")
	else:
		_apply_weapon(weapon_id)
		GameState.set_hardpoint_weapon(_hp_id, weapon_id)
	_update_weapon_highlights()
	_update_power_budget()


func _apply_weapon(wid: String) -> void:
	var w: WeaponData = _weapon_cache.get(wid)
	if w:
		_piano_roll.set_weapon_color(Color(w.color))
		var cells: int = PianoRoll.duration_to_cells(w.note_duration)
		_piano_roll.set_note_duration_cells(cells)
		_firing_preview.set_weapon(w, _hp_index)


func _update_weapon_highlights() -> void:
	for entry in _weapon_buttons:
		var btn: Button = entry["button"]
		var wid: String = str(entry["id"])
		if wid == _selected_weapon_id:
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8))
		else:
			btn.remove_theme_color_override("font_color")


# ── Stage Buttons ────────────────────────────────────────────

func _on_stage_button(stage_index: int) -> void:
	_stage_patterns[_active_stage] = _piano_roll.pattern.duplicate()
	_active_stage = stage_index
	var pat: Array = _stage_patterns.get(stage_index, [])
	if pat.is_empty():
		pat.resize(_piano_roll.loop_length)
		pat.fill(-1)
		_stage_patterns[stage_index] = pat.duplicate()
	_piano_roll.set_pattern(pat)
	_update_stage_button_colors()
	_auto_save_stages()


func _update_stage_button_colors() -> void:
	for i in _stage_buttons.size():
		var btn: Button = _stage_buttons[i]
		if i == _active_stage:
			btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.8))
		else:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))


# ── Pattern Changed ──────────────────────────────────────────

func _on_pattern_changed(_new_pattern: Array) -> void:
	_stage_patterns[_active_stage] = _piano_roll.pattern.duplicate()
	_auto_save_stages()


# ── Auto-save ────────────────────────────────────────────────

func _auto_save_stages() -> void:
	_stage_patterns[_active_stage] = _piano_roll.pattern.duplicate()
	var stages: Array = []
	for si in 3:
		var pat: Array = _stage_patterns.get(si, [])
		var has_note: bool = false
		for val in pat:
			if int(val) >= 0:
				has_note = true
				break
		if has_note:
			stages.append({
				"stage_number": si + 1,
				"loop_length": _get_current_loop_length(),
				"pattern": pat.duplicate(),
			})
	GameState.set_hardpoint_stages(_hp_id, stages)


# ── Loop Length ──────────────────────────────────────────────

func _on_loop_length_changed(_idx: int) -> void:
	var new_length: int = _get_current_loop_length()
	_piano_roll.set_loop_length(new_length)
	if _is_playing and _playback_step >= new_length:
		_playback_step = 0
	_auto_save_stages()


func _get_current_loop_length() -> int:
	if not _loop_selector:
		return 32
	var idx: int = _loop_selector.selected
	if idx >= 0 and idx < LOOP_LENGTHS.size():
		return LOOP_LENGTHS[idx]
	return 32


# ── Power Budget ─────────────────────────────────────────────

func _update_power_budget() -> void:
	var total_power: int = 0
	var max_power: int = 0

	if _ship:
		max_power = int(_ship.stats.get("generator_power", 10))

	# Add device bonuses to max_power
	for slot_key in GameState.device_config:
		var did: String = str(GameState.device_config[slot_key])
		if did == "":
			continue
		var dev: DeviceData = DeviceDataManager.load_by_id(did)
		if dev:
			max_power += int(dev.stats_modifiers.get("generator_power", 0))

	for hp_id in GameState.hardpoint_config:
		var config: Dictionary = GameState.hardpoint_config[hp_id]
		var weapon_id: String = str(config.get("weapon_id", ""))
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				total_power += w.power_cost

	_power_budget_label.text = "POWER: " + str(total_power) + " / " + str(max_power)

	if max_power > 0:
		_power_bar.max_value = max_power
		_power_bar.value = total_power
	else:
		_power_bar.max_value = 1
		_power_bar.value = 0

	if total_power > max_power:
		var red_style := StyleBoxFlat.new()
		red_style.bg_color = Color(0.8, 0.15, 0.15)
		_power_bar.add_theme_stylebox_override("fill", red_style)
		_power_budget_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		var green_style := StyleBoxFlat.new()
		green_style.bg_color = Color(0.15, 0.7, 0.3)
		_power_bar.add_theme_stylebox_override("fill", green_style)
		_power_budget_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))


# ── Playback ─────────────────────────────────────────────────

func _setup_playback_timer() -> void:
	_playback_timer = Timer.new()
	_playback_timer.one_shot = false
	_playback_timer.timeout.connect(_on_playback_tick)
	add_child(_playback_timer)


func _on_play() -> void:
	_is_playing = true
	_playback_step = 0
	_playback_timer.wait_time = BeatClock.get_beat_duration() / 8.0
	_playback_timer.start()
	_firing_preview.start()
	_on_playback_tick()


func _on_stop() -> void:
	_is_playing = false
	_playback_timer.stop()
	_playback_step = -1
	_piano_roll.set_playback_step(-1)
	_firing_preview.stop()


func _on_playback_tick() -> void:
	var current_loop: int = _get_current_loop_length()
	_piano_roll.set_playback_step(_playback_step)

	if _selected_weapon_id != "":
		if _playback_step >= 0 and _playback_step < _piano_roll.pattern.size():
			var note: int = int(_piano_roll.pattern[_playback_step])
			if note >= 0:
				_firing_preview.fire_once()
				var w: WeaponData = _weapon_cache.get(_selected_weapon_id)
				if w and w.audio_sample_path != "":
					var pitch: float = PianoRoll.get_pitch_scale(note, _piano_roll.base_note) * w.audio_pitch
					AudioManager.play_weapon_sound(w.audio_sample_path, pitch)

	_playback_step = (_playback_step + 1) % current_loop


# ── Navigation ───────────────────────────────────────────────

func _on_back() -> void:
	_on_stop()
	_firing_preview.stop()
	get_tree().change_scene_to_file("res://scenes/ui/hangar_screen.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		_on_back()
