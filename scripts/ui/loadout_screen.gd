extends MarginContainer
## Loadout Screen — sequencer-dominant layout with piano rolls per hardpoint.
## Mario Paint Composer-style: compose melodies per hardpoint, preview playback.

const LOOP_LENGTHS: Array[int] = [4, 8, 16, 32]

# UI references
var _load_button: OptionButton
var _ship_selector: OptionButton
var _canvas: ShipCanvas
var _hull_label: Label
var _shield_label: Label
var _speed_label: Label
var _generator_label: Label
var _power_budget_label: Label
var _power_bar: ProgressBar
var _hardpoint_container: VBoxContainer
var _loop_selector: OptionButton
var _bpm_label: Label
var _status_label: Label
var _save_button: Button
var _set_active_button: Button
var _delete_button: Button
var _play_button: Button
var _stop_button: Button

# State
var _current_id: String = ""
var _current_ship: ShipData = null
var _weapon_ids: Array[String] = []
var _weapon_cache: Dictionary = {}
var _piano_rolls: Dictionary = {}        # {hp_id: PianoRoll}
var _hp_weapon_selectors: Dictionary = {} # {hp_id: OptionButton}
var _is_playing: bool = false
var _playback_step: int = -1
var _playback_timer: Timer = null


func _ready() -> void:
	_build_ui()
	_cache_weapons()
	_refresh_load_list()
	_refresh_ship_list()
	_setup_playback_timer()


func _cache_weapons() -> void:
	_weapon_ids = WeaponDataManager.list_ids()
	_weapon_cache.clear()
	for wid in _weapon_ids:
		var w: WeaponData = WeaponDataManager.load_by_id(wid)
		if w:
			_weapon_cache[wid] = w


# ── UI Construction ──────────────────────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Top bar — load/delete/new
	var top_bar := HBoxContainer.new()
	root.add_child(top_bar)

	var load_label := Label.new()
	load_label.text = "Load:"
	top_bar.add_child(load_label)

	_load_button = OptionButton.new()
	_load_button.custom_minimum_size.x = 250
	_load_button.item_selected.connect(_on_load_selected)
	top_bar.add_child(_load_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_delete_button = Button.new()
	_delete_button.text = "DELETE"
	_delete_button.pressed.connect(_on_delete)
	top_bar.add_child(_delete_button)

	var new_btn := Button.new()
	new_btn.text = "NEW"
	new_btn.pressed.connect(_on_new)
	top_bar.add_child(new_btn)

	# Main split
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 220
	root.add_child(split)

	# LEFT panel — compact ship info
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 200
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(left_vbox)

	# Ship selector row
	var ship_row := HBoxContainer.new()
	left_vbox.add_child(ship_row)

	var ship_label := Label.new()
	ship_label.text = "Ship:"
	ship_row.add_child(ship_label)

	_ship_selector = OptionButton.new()
	_ship_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ship_selector.item_selected.connect(_on_ship_selected)
	ship_row.add_child(_ship_selector)

	# Ship canvas (read-only, compact)
	var canvas_panel := PanelContainer.new()
	canvas_panel.custom_minimum_size.y = 150
	left_vbox.add_child(canvas_panel)

	_canvas = ShipCanvas.new()
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.display_only = true
	canvas_panel.add_child(_canvas)

	# Ship stats
	_hull_label = Label.new()
	_hull_label.text = "Hull: —"
	left_vbox.add_child(_hull_label)

	_shield_label = Label.new()
	_shield_label.text = "Shield: —"
	left_vbox.add_child(_shield_label)

	_speed_label = Label.new()
	_speed_label.text = "Speed: —"
	left_vbox.add_child(_speed_label)

	_generator_label = Label.new()
	_generator_label.text = "Generator: —"
	left_vbox.add_child(_generator_label)

	_add_separator(left_vbox)

	# Power budget
	_power_budget_label = Label.new()
	_power_budget_label.text = "POWER: 0 / 0"
	left_vbox.add_child(_power_budget_label)

	_power_bar = ProgressBar.new()
	_power_bar.custom_minimum_size.y = 20
	_power_bar.max_value = 1
	_power_bar.value = 0
	_power_bar.show_percentage = false
	left_vbox.add_child(_power_bar)

	# RIGHT panel — scrollable sequencer area
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(right_scroll)

	_hardpoint_container = VBoxContainer.new()
	_hardpoint_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_hardpoint_container)

	# Controls row at top of right panel
	var controls_row := HBoxContainer.new()
	_hardpoint_container.add_child(controls_row)

	var loop_label := Label.new()
	loop_label.text = "Loop:"
	controls_row.add_child(loop_label)

	_loop_selector = OptionButton.new()
	for ll in LOOP_LENGTHS:
		_loop_selector.add_item(str(ll))
	_loop_selector.selected = 3  # default 32
	_loop_selector.item_selected.connect(_on_loop_length_changed)
	controls_row.add_child(_loop_selector)

	var controls_spacer := Control.new()
	controls_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(controls_spacer)

	_bpm_label = Label.new()
	_bpm_label.text = "BPM: " + str(int(BeatClock.bpm))
	controls_row.add_child(_bpm_label)

	# Bottom bar
	var bottom_bar := HBoxContainer.new()
	root.add_child(bottom_bar)

	_play_button = Button.new()
	_play_button.text = "▶ PLAY"
	_play_button.pressed.connect(_on_play)
	bottom_bar.add_child(_play_button)

	_stop_button = Button.new()
	_stop_button.text = "■ STOP"
	_stop_button.pressed.connect(_on_stop)
	bottom_bar.add_child(_stop_button)

	var bottom_spacer1 := Control.new()
	bottom_spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer1)

	_save_button = Button.new()
	_save_button.text = "SAVE"
	_save_button.custom_minimum_size.x = 100
	_save_button.pressed.connect(_on_save)
	bottom_bar.add_child(_save_button)

	_set_active_button = Button.new()
	_set_active_button.text = "SET ACTIVE"
	_set_active_button.custom_minimum_size.x = 120
	_set_active_button.pressed.connect(_on_set_active)
	bottom_bar.add_child(_set_active_button)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.text = ""
	bottom_bar.add_child(_status_label)

	var bottom_spacer2 := Control.new()
	bottom_spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(bottom_spacer2)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.pressed.connect(_on_back)
	bottom_bar.add_child(back_btn)


# ── Ship Selection ───────────────────────────────────────────

func _refresh_ship_list() -> void:
	_ship_selector.clear()
	_ship_selector.add_item("(select ship)")
	var ids: Array[String] = ShipDataManager.list_ids()
	for id in ids:
		_ship_selector.add_item(id)


func _on_ship_selected(idx: int) -> void:
	if idx <= 0:
		_current_ship = null
		_canvas.set_lines([])
		_canvas.set_hardpoints([])
		_update_stats_display()
		_rebuild_hardpoint_panel()
		_update_power_budget()
		return
	var id: String = _ship_selector.get_item_text(idx)
	var ship: ShipData = ShipDataManager.load_by_id(id)
	if not ship:
		_status_label.text = "Failed to load ship: " + id
		return
	_current_ship = ship
	_update_ship_preview()
	_update_stats_display()
	_rebuild_hardpoint_panel()
	_update_power_budget()


func _update_ship_preview() -> void:
	if not _current_ship:
		return
	_canvas.set_grid_size(_current_ship.grid_size)
	_canvas.set_lines(_current_ship.lines.duplicate(true))
	_canvas.set_hardpoints(_current_ship.hardpoints.duplicate(true))


func _update_stats_display() -> void:
	if not _current_ship:
		_hull_label.text = "Hull: —"
		_shield_label.text = "Shield: —"
		_speed_label.text = "Speed: —"
		_generator_label.text = "Generator: —"
		return
	var stats: Dictionary = _current_ship.stats
	_hull_label.text = "Hull: " + str(int(stats.get("hull_max", 100)))
	_shield_label.text = "Shield: " + str(int(stats.get("shield_max", 50)))
	_speed_label.text = "Speed: " + str(int(stats.get("speed", 400)))
	_generator_label.text = "Generator: " + str(int(stats.get("generator_power", 10)))


# ── Hardpoint Panel (with Piano Rolls) ──────────────────────

func _rebuild_hardpoint_panel() -> void:
	# Keep the controls row (first child), remove everything else
	var children: Array = _hardpoint_container.get_children()
	for i in range(1, children.size()):
		var child: Node = children[i]
		child.queue_free()
	_piano_rolls.clear()
	_hp_weapon_selectors.clear()

	if not _current_ship:
		return

	if _current_ship.hardpoints.size() == 0:
		var no_hp_label := Label.new()
		no_hp_label.text = "This ship has no hardpoints"
		no_hp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_hardpoint_container.add_child(no_hp_label)
		return

	for hp in _current_ship.hardpoints:
		var hp_id: String = str(hp.get("id", ""))
		var hp_label_text: String = str(hp.get("label", hp_id))
		var dir_deg: float = float(hp.get("direction_deg", 0.0))

		_add_separator(_hardpoint_container)

		# Section header
		var header := Label.new()
		header.text = "◆ " + hp_id + " \"" + hp_label_text + "\" (" + str(int(dir_deg)) + "°)"
		header.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		header.add_theme_font_size_override("font_size", 14)
		_hardpoint_container.add_child(header)

		# Weapon selector row
		var weapon_row := HBoxContainer.new()
		_hardpoint_container.add_child(weapon_row)

		var wlabel := Label.new()
		wlabel.text = "Weapon:"
		weapon_row.add_child(wlabel)

		var selector := OptionButton.new()
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.add_item("(none)")
		for wid in _weapon_ids:
			var w: WeaponData = _weapon_cache.get(wid)
			if w:
				selector.add_item(w.id)
			else:
				selector.add_item(wid)
		var bound_hp_id: String = hp_id
		selector.item_selected.connect(func(sel_idx: int) -> void:
			_on_weapon_selected_for_hp(bound_hp_id, sel_idx)
		)
		weapon_row.add_child(selector)
		_hp_weapon_selectors[hp_id] = selector

		# Piano roll
		var roll := PianoRoll.new()
		roll.custom_minimum_size = Vector2(0, 220)
		roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roll.loop_length = _get_current_loop_length()
		roll._init_pattern()
		roll._recalc_cells()
		var bound_id: String = hp_id
		roll.pattern_changed.connect(func(_new_pattern: Array) -> void:
			_on_pattern_changed(bound_id)
		)
		_hardpoint_container.add_child(roll)
		_piano_rolls[hp_id] = roll


func _on_weapon_selected_for_hp(hp_id: String, idx: int) -> void:
	var roll: PianoRoll = _piano_rolls.get(hp_id)
	if not roll:
		return

	if idx > 0:
		var selector: OptionButton = _hp_weapon_selectors.get(hp_id)
		if selector:
			var wid: String = selector.get_item_text(idx)
			var w: WeaponData = _weapon_cache.get(wid)
			if w:
				roll.set_weapon_color(Color(w.color))
				var cells: int = PianoRoll.duration_to_cells(w.note_duration)
				roll.set_note_duration_cells(cells)
	else:
		roll.set_weapon_color(Color.CYAN)
		roll.set_note_duration_cells(1)

	_update_power_budget()


func _on_pattern_changed(_hp_id: String) -> void:
	# Hook for future use (e.g., auto-save, dirty flag)
	pass


func _on_loop_length_changed(_idx: int) -> void:
	var new_length: int = _get_current_loop_length()
	for hp_id in _piano_rolls:
		var roll: PianoRoll = _piano_rolls[hp_id]
		roll.set_loop_length(new_length)

	if _is_playing:
		if _playback_step >= new_length:
			_playback_step = 0
		_playback_timer.wait_time = BeatClock.get_beat_duration() / 8.0  # 1/32 note


func _get_current_loop_length() -> int:
	var idx: int = _loop_selector.selected
	if idx >= 0 and idx < LOOP_LENGTHS.size():
		return LOOP_LENGTHS[idx]
	return 8


# ── Power Budget ─────────────────────────────────────────────

func _update_power_budget() -> void:
	var total_power: int = 0
	var max_power: int = 0

	if _current_ship:
		max_power = int(_current_ship.stats.get("generator_power", 10))

	for hp_id in _hp_weapon_selectors:
		var selector: OptionButton = _hp_weapon_selectors[hp_id]
		if selector.selected > 0:
			var wid: String = selector.get_item_text(selector.selected)
			var w: WeaponData = _weapon_cache.get(wid)
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


# ── Playback System ─────────────────────────────────────────

func _setup_playback_timer() -> void:
	_playback_timer = Timer.new()
	_playback_timer.one_shot = false
	_playback_timer.timeout.connect(_on_playback_tick)
	add_child(_playback_timer)


func _on_play() -> void:
	if _piano_rolls.is_empty():
		_status_label.text = "No hardpoints to play."
		return
	_is_playing = true
	_playback_step = 0
	_playback_timer.wait_time = BeatClock.get_beat_duration() / 8.0  # 1/32 note
	_playback_timer.start()
	# Fire first tick immediately
	_on_playback_tick()


func _on_stop() -> void:
	_is_playing = false
	_playback_timer.stop()
	_playback_step = -1
	for hp_id in _piano_rolls:
		var roll: PianoRoll = _piano_rolls[hp_id]
		roll.set_playback_step(-1)


func _on_playback_tick() -> void:
	var current_loop: int = _get_current_loop_length()

	for hp_id in _piano_rolls:
		var roll: PianoRoll = _piano_rolls[hp_id]
		roll.set_playback_step(_playback_step)

		# Play sound if weapon selected and note is active
		var selector: OptionButton = _hp_weapon_selectors.get(hp_id)
		if not selector or selector.selected <= 0:
			continue
		if _playback_step < 0 or _playback_step >= roll.pattern.size():
			continue
		var note: int = int(roll.pattern[_playback_step])
		if note < 0:
			continue
		var wid: String = selector.get_item_text(selector.selected)
		var w: WeaponData = _weapon_cache.get(wid)
		if w and w.audio_sample_path != "":
			var pitch: float = PianoRoll.get_pitch_scale(note) * w.audio_pitch
			AudioManager.play_weapon_sound(w.audio_sample_path, pitch)

	_playback_step = (_playback_step + 1) % current_loop


# ── Save / Load / Delete ────────────────────────────────────

func _collect_loadout_data() -> Dictionary:
	var assignments: Dictionary = {}
	for hp_id in _hp_weapon_selectors:
		var selector: OptionButton = _hp_weapon_selectors[hp_id]
		var weapon_id: String = ""
		if selector.selected > 0:
			weapon_id = selector.get_item_text(selector.selected)
		var roll: PianoRoll = _piano_rolls.get(hp_id)
		var stages: Array = []
		if roll:
			stages.append({
				"stage_number": 1,
				"loop_length": _get_current_loop_length(),
				"pattern": roll.pattern.duplicate(),
			})
		assignments[hp_id] = {
			"weapon_id": weapon_id,
			"stages": stages,
		}
	var ship_id: String = ""
	if _current_ship:
		ship_id = _current_ship.id
	return {
		"ship_id": ship_id,
		"hardpoint_assignments": assignments,
	}


func _on_save() -> void:
	if not _current_ship:
		_status_label.text = "Select a ship first!"
		return
	if _current_id == "":
		_current_id = _generate_id(_current_ship.display_name)
	var data: Dictionary = _collect_loadout_data()
	LoadoutDataManager.save(_current_id, data)
	_status_label.text = "Saved: " + _current_id
	_refresh_load_list()


func _on_set_active() -> void:
	if _current_id == "":
		_status_label.text = "Save the loadout first!"
		return
	GameState.current_loadout_id = _current_id
	GameState.save_game()
	_status_label.text = "Active loadout set: " + _current_id


func _on_load_selected(idx: int) -> void:
	if idx <= 0:
		return
	var id: String = _load_button.get_item_text(idx)
	var loadout: LoadoutData = LoadoutDataManager.load_by_id(id)
	if not loadout:
		_status_label.text = "Failed to load: " + id
		return
	_current_id = id
	_populate_from_loadout(loadout)
	_status_label.text = "Loaded: " + id


func _populate_from_loadout(loadout: LoadoutData) -> void:
	# Find and select ship
	var ship_id: String = loadout.ship_id
	var found_ship: bool = false
	for i in _ship_selector.item_count:
		if _ship_selector.get_item_text(i) == ship_id:
			_ship_selector.selected = i
			_on_ship_selected(i)
			found_ship = true
			break
	if not found_ship:
		_status_label.text = "Ship not found: " + ship_id
		return

	# Set weapon selectors and patterns per hardpoint
	var assignments: Dictionary = loadout.hardpoint_assignments
	for hp_id in assignments:
		var assignment: Dictionary = assignments[hp_id]
		var weapon_id: String = str(assignment.get("weapon_id", ""))

		# Set weapon selector
		if weapon_id != "":
			var selector: OptionButton = _hp_weapon_selectors.get(hp_id)
			if not selector:
				continue
			var found_weapon: bool = false
			for i in selector.item_count:
				if selector.get_item_text(i) == weapon_id:
					selector.selected = i
					_on_weapon_selected_for_hp(hp_id, i)
					found_weapon = true
					break
			if not found_weapon:
				_status_label.text = "Warning: weapon '" + weapon_id + "' not found"

		# Set note_duration_cells from weapon data before loading pattern
		if weapon_id != "":
			var w: WeaponData = _weapon_cache.get(weapon_id)
			if w:
				var roll_dur: PianoRoll = _piano_rolls.get(hp_id)
				if roll_dur:
					var cells: int = PianoRoll.duration_to_cells(w.note_duration)
					roll_dur.set_note_duration_cells(cells)

		# Load pattern from stages
		var stages: Array = assignment.get("stages", [])
		if stages.size() > 0:
			var stage: Dictionary = stages[0]
			var loop_len: int = int(stage.get("loop_length", 8))
			# Set loop selector to match
			for li in LOOP_LENGTHS.size():
				if LOOP_LENGTHS[li] == loop_len:
					_loop_selector.selected = li
					_on_loop_length_changed(li)
					break
			var saved_pattern: Array = stage.get("pattern", [])
			var roll: PianoRoll = _piano_rolls.get(hp_id)
			if roll and saved_pattern.size() > 0:
				roll.set_pattern(saved_pattern)


func _on_delete() -> void:
	if _current_id == "":
		_status_label.text = "No loadout loaded to delete."
		return
	LoadoutDataManager.delete(_current_id)
	_status_label.text = "Deleted: " + _current_id
	_current_id = ""
	_on_new()
	_refresh_load_list()


func _on_new() -> void:
	_on_stop()
	_current_id = ""
	_current_ship = null
	_ship_selector.selected = 0
	_canvas.set_lines([])
	_canvas.set_hardpoints([])
	_canvas.set_grid_size(Vector2i(32, 32))
	_update_stats_display()
	_rebuild_hardpoint_panel()
	_update_power_budget()
	_status_label.text = "New loadout — select a ship."


func _refresh_load_list() -> void:
	_load_button.clear()
	_load_button.add_item("(select loadout)")
	var ids: Array[String] = LoadoutDataManager.list_ids()
	for id in ids:
		_load_button.add_item(id)


func _on_back() -> void:
	_on_stop()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("return_to_menu"):
		_on_back()


func _generate_id(display_name: String) -> String:
	var base: String = display_name.strip_edges().to_lower().replace(" ", "_")
	var valid_chars: String = "abcdefghijklmnopqrstuvwxyz0123456789_"
	var clean: String = ""
	for c in base:
		if valid_chars.contains(c):
			clean += c
	if clean == "":
		clean = str(randi() % 10000)
	return "loadout_" + clean + "_" + str(randi() % 10000)


# ── UI Helpers ───────────────────────────────────────────────

func _add_section_header(parent: Control, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	label.add_theme_font_size_override("font_size", 14)
	parent.add_child(label)
	return label


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)
