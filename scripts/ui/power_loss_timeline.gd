extends Control
## Power Loss Event Timeline — visualizes the deterministic SFX cue sequence
## with phase bands, cue markers, playback cursor, and per-cue editing controls.
## Timing data sourced from PowerLossSequence (single source of truth with game).

# All power loss event IDs — the complete set managed by this screen
const POWER_LOSS_EVENT_IDS: Array[String] = [
	"electric_sparks",
	"powerdown_shields_bleed",
	"powerdown_drift_start",
	"powerdown_engines_dying",
	"power_failure",
	"powerdown_crt_flicker_start",
	"powerdown_screen_75",
	"powerdown_screen_50",
	"powerdown_screen_25",
	"monitor_static",
	"monitor_shutoff",
	"powerdown_final_death",
	"reboot_char_thunk",
	"reboot_line_beep",
	"powerup_electric_restored",
	"powerup_core_regen",
	"powerup_restored",
	"powerup_bars_charging",
	"powerup_screen_on",
	"powerup_systems_online",
]

# Thermal vent event IDs — separate emergency sequence
const THERMAL_VENT_EVENT_IDS: Array[String] = [
	"purge_start",
	"purge_venting",
	"purge_complete",
	"purge_engines_restored",
]

const THERMAL_VENT_LABELS: Array[String] = [
	"PURGE START",
	"VENTING (50%)",
	"PURGE COMPLETE",
	"ENGINES RESTORED",
]

const THERMAL_VENT_DESCRIPTIONS: Array[String] = [
	"Vents open — hiss/whoosh as emergency cooling begins",
	"Midpoint — thermal at 50%, active venting sound",
	"Thermal cleared — vents close, components reactivate",
	"Engines back to full power — thrust restored",
]

# 0 = power loss, 1 = thermal vent
var _active_event_type: int = 0
var _event_dropdown: OptionButton

# Thermal vent UI
var _vent_panel: VBoxContainer  # Container for the thermal vent view
var _vent_cue_btns: Array = []  # 4 buttons for selecting a cue

var _config: SfxConfig
var _phases: Array[Dictionary] = []
var _cues: Array[Dictionary] = []
var _typing_regions: Array[Dictionary] = []
var _static_times: Array[float] = []
var _total_duration: float = 0.0

# Timeline drawing
var _timeline_control: Control  # Custom _draw() node for the timeline
var _timeline_scroll: ScrollContainer
const TIMELINE_HEIGHT: float = 160.0
const TIMELINE_MARGIN_LEFT: float = 10.0
const TIMELINE_MARGIN_RIGHT: float = 10.0
const MARKER_SIZE: float = 8.0
const PHASE_BAND_Y: float = 20.0
const PHASE_BAND_HEIGHT: float = 50.0
const MARKER_Y: float = 80.0
const LABEL_Y: float = 105.0
const TYPING_BAR_Y: float = 130.0
const TYPING_BAR_HEIGHT: float = 12.0

# Non-linear time mapping: give more visual space to dense early phases
# Breakpoints define how timeline seconds map to normalized [0,1] visual space
# [0-6s] -> [0.0 - 0.40]  (drift+blackout: dense cues)
# [6-reboot_end] -> [0.40 - 0.80]  (reboot: sparse but long)
# [reboot_end - end] -> [0.80 - 1.0]  (recovery: moderate)
var _time_breakpoints: Array[Dictionary] = []  # {time_start, time_end, vis_start, vis_end}

# Playback
var _playback_active: bool = false
var _playback_time: float = 0.0
var _next_cue_idx: int = 0
var _next_static_idx: int = 0
var _typing_player: AudioStreamPlayer  # For reboot_char_thunk looping sound
var _typing_active: bool = false

# Selection — track by event_id so non-cue events (reboot_char_thunk etc.) work too
var _selected_cue_idx: int = -1  # Index into _cues, or -1 if selected via dropdown
var _selected_event_id_str: String = ""  # The actual selected event ID

# UI refs
var _play_btn: Button
var _stop_btn: Button
var _time_label: Label
var _phase_label: Label
var _detail_panel: VBoxContainer  # Per-cue editing controls
var _detail_title: Label
var _detail_event_selector: OptionButton  # Dropdown to pick any power loss event
var _detail_file_btn: OptionButton
var _detail_vol_slider: HSlider
var _detail_vol_label: Label
var _detail_clip_slider: HSlider
var _detail_clip_label: Label
var _detail_fade_slider: HSlider
var _detail_fade_label: Label
var _detail_preview_btn: Button
var _detail_stop_btn: Button
var _preview_player: AudioStreamPlayer

# SFX file list for dropdown
var _sfx_files: Array[String] = []


func _ready() -> void:
	_config = SfxConfigManager.load_config()
	_sfx_files = _scan_sfx_files()
	_reload_sequence_data()
	_build_ui()
	_populate_from_config()
	# Select first event by default
	if POWER_LOSS_EVENT_IDS.size() > 0:
		_select_event(POWER_LOSS_EVENT_IDS[0])


func _reload_sequence_data() -> void:
	_phases = PowerLossSequence.get_phases()
	_cues = PowerLossSequence.get_cues()
	_typing_regions = PowerLossSequence.get_typing_regions()
	_static_times = PowerLossSequence.get_static_burst_times()
	_total_duration = PowerLossSequence.get_total_duration()
	_build_time_breakpoints()


func _build_time_breakpoints() -> void:
	_time_breakpoints.clear()
	# Find phase boundaries
	var death_time: float = 0.0
	var reboot_end: float = 0.0
	for p in _phases:
		if str(p["name"]) == "BLACKOUT":
			death_time = float(p["end_time"])
		elif str(p["name"]) == "RECOVERY":
			reboot_end = float(p["start_time"])

	_time_breakpoints = [
		{"time_start": 0.0, "time_end": death_time, "vis_start": 0.0, "vis_end": 0.40},
		{"time_start": death_time, "time_end": reboot_end, "vis_start": 0.40, "vis_end": 0.80},
		{"time_start": reboot_end, "time_end": _total_duration, "vis_start": 0.80, "vis_end": 1.0},
	]


func _time_to_x(time: float, width: float) -> float:
	## Map a time value to an x pixel position using non-linear breakpoints.
	var usable: float = width - TIMELINE_MARGIN_LEFT - TIMELINE_MARGIN_RIGHT
	for bp in _time_breakpoints:
		var ts: float = float(bp["time_start"])
		var te: float = float(bp["time_end"])
		var vs: float = float(bp["vis_start"])
		var ve: float = float(bp["vis_end"])
		if time <= te or bp == _time_breakpoints.back():
			var t: float = 0.0
			if te > ts:
				t = clampf((time - ts) / (te - ts), 0.0, 1.0)
			return TIMELINE_MARGIN_LEFT + (vs + t * (ve - vs)) * usable
	return TIMELINE_MARGIN_LEFT


func _x_to_time(x: float, width: float) -> float:
	## Inverse of _time_to_x: map pixel x back to time.
	var usable: float = width - TIMELINE_MARGIN_LEFT - TIMELINE_MARGIN_RIGHT
	var vis: float = (x - TIMELINE_MARGIN_LEFT) / usable
	for bp in _time_breakpoints:
		var vs: float = float(bp["vis_start"])
		var ve: float = float(bp["vis_end"])
		if vis <= ve or bp == _time_breakpoints.back():
			var t: float = 0.0
			if ve > vs:
				t = clampf((vis - vs) / (ve - vs), 0.0, 1.0)
			return float(bp["time_start"]) + t * (float(bp["time_end"]) - float(bp["time_start"]))
	return 0.0


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Top bar: event selector + transport controls
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 12)
	main_vbox.add_child(top_bar)

	var event_label := Label.new()
	event_label.text = "Event:"
	top_bar.add_child(event_label)

	_event_dropdown = OptionButton.new()
	_event_dropdown.add_item("POWER LOSS")
	_event_dropdown.add_item("THERMAL VENT")
	_event_dropdown.custom_minimum_size = Vector2(180, 0)
	_event_dropdown.item_selected.connect(_on_event_type_changed)
	top_bar.add_child(_event_dropdown)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_play_btn = Button.new()
	_play_btn.text = "  \u25b6 PLAY  "
	_play_btn.pressed.connect(_on_play)
	top_bar.add_child(_play_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "  \u25a0 STOP  "
	_stop_btn.pressed.connect(_on_stop)
	top_bar.add_child(_stop_btn)

	_time_label = Label.new()
	_time_label.text = "T = 0.00s"
	_time_label.custom_minimum_size = Vector2(100, 0)
	top_bar.add_child(_time_label)

	# Timeline drawing area
	_timeline_control = Control.new()
	_timeline_control.custom_minimum_size = Vector2(0, TIMELINE_HEIGHT)
	_timeline_control.draw.connect(_draw_timeline)
	_timeline_control.gui_input.connect(_on_timeline_input)
	_timeline_control.mouse_filter = Control.MOUSE_FILTER_STOP
	main_vbox.add_child(_timeline_control)

	# Phase label (shows current phase during playback)
	_phase_label = Label.new()
	_phase_label.text = ""
	_phase_label.add_theme_font_size_override("font_size", 18)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_phase_label)

	# Separator
	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Detail panel for selected cue
	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_detail_panel)

	# Event selector row — pick any power loss event (including non-timeline ones)
	var selector_row := HBoxContainer.new()
	selector_row.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(selector_row)

	var sel_label := Label.new()
	sel_label.text = "Sound:"
	sel_label.custom_minimum_size = Vector2(50, 0)
	selector_row.add_child(sel_label)

	_detail_event_selector = OptionButton.new()
	_detail_event_selector.custom_minimum_size = Vector2(300, 0)
	for eid in POWER_LOSS_EVENT_IDS:
		var display: String = str(SfxConfig.EVENT_LABELS.get(eid, eid))
		_detail_event_selector.add_item(display)
		_detail_event_selector.set_item_metadata(_detail_event_selector.item_count - 1, eid)
	_detail_event_selector.item_selected.connect(_on_event_selector_changed)
	selector_row.add_child(_detail_event_selector)

	_detail_title = Label.new()
	_detail_title.text = ""
	_detail_title.add_theme_font_size_override("font_size", 14)
	selector_row.add_child(_detail_title)

	# Preview audio player
	_preview_player = AudioStreamPlayer.new()
	add_child(_preview_player)

	# Typing sound player (for reboot_char_thunk during playback)
	_typing_player = AudioStreamPlayer.new()
	_typing_player.bus = "UI"
	add_child(_typing_player)

	_build_detail_controls()

	# ── Thermal vent panel (hidden by default, shown when Event=THERMAL VENT) ──
	_vent_panel = VBoxContainer.new()
	_vent_panel.add_theme_constant_override("separation", 12)
	_vent_panel.visible = false
	main_vbox.add_child(_vent_panel)
	_build_vent_panel()


func _build_vent_panel() -> void:
	var desc_label := Label.new()
	desc_label.text = "Emergency thermal vent sequence — 4 cue points. Select a cue below to assign a sound."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ThemeManager.apply_text_glow(desc_label, "body")
	_vent_panel.add_child(desc_label)

	var cue_grid := VBoxContainer.new()
	cue_grid.add_theme_constant_override("separation", 6)
	_vent_panel.add_child(cue_grid)

	_vent_cue_btns.clear()
	for i in THERMAL_VENT_EVENT_IDS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		cue_grid.add_child(row)

		# Stage number + color indicator
		var stage_label := Label.new()
		stage_label.text = "%d." % (i + 1)
		stage_label.custom_minimum_size.x = 20
		ThemeManager.apply_text_glow(stage_label, "body")
		row.add_child(stage_label)

		# Cue button — selects this cue for editing in the detail panel
		var btn := Button.new()
		btn.text = THERMAL_VENT_LABELS[i]
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(200, 0)
		var idx: int = i
		btn.pressed.connect(func() -> void: _select_vent_cue(idx))
		row.add_child(btn)
		_vent_cue_btns.append(btn)

		# Description
		var desc := Label.new()
		desc.text = THERMAL_VENT_DESCRIPTIONS[i]
		desc.modulate.a = 0.6
		ThemeManager.apply_text_glow(desc, "body")
		row.add_child(desc)


func _on_event_type_changed(idx: int) -> void:
	if idx == _active_event_type:
		return
	_active_event_type = idx

	# Stop any playback
	_on_stop()

	if idx == 0:
		# Power loss mode
		_timeline_control.visible = true
		_phase_label.visible = true
		_vent_panel.visible = false
		# Rebuild the Sound selector with power loss events
		_rebuild_event_selector(POWER_LOSS_EVENT_IDS)
		if POWER_LOSS_EVENT_IDS.size() > 0:
			_select_event(POWER_LOSS_EVENT_IDS[0])
	else:
		# Thermal vent mode
		_timeline_control.visible = false
		_phase_label.visible = false
		_vent_panel.visible = true
		# Rebuild the Sound selector with thermal vent events
		_rebuild_event_selector(THERMAL_VENT_EVENT_IDS)
		if THERMAL_VENT_EVENT_IDS.size() > 0:
			_select_vent_cue(0)


func _rebuild_event_selector(event_ids: Array) -> void:
	_detail_event_selector.clear()
	for eid in event_ids:
		var display: String = str(SfxConfig.EVENT_LABELS.get(eid, eid))
		_detail_event_selector.add_item(display)
		_detail_event_selector.set_item_metadata(_detail_event_selector.item_count - 1, eid)


func _select_vent_cue(idx: int) -> void:
	for i in _vent_cue_btns.size():
		(_vent_cue_btns[i] as Button).button_pressed = (i == idx)
	if idx >= 0 and idx < THERMAL_VENT_EVENT_IDS.size():
		_select_event(THERMAL_VENT_EVENT_IDS[idx])


func _build_detail_controls() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(row)

	# File dropdown
	var file_label := Label.new()
	file_label.text = "File:"
	file_label.custom_minimum_size = Vector2(35, 0)
	row.add_child(file_label)

	_detail_file_btn = OptionButton.new()
	_detail_file_btn.custom_minimum_size = Vector2(300, 0)
	_populate_file_dropdown(_detail_file_btn)
	_detail_file_btn.item_selected.connect(_on_detail_file_selected)
	row.add_child(_detail_file_btn)

	# Volume
	var vol_lbl := Label.new()
	vol_lbl.text = "Vol:"
	vol_lbl.custom_minimum_size = Vector2(30, 0)
	row.add_child(vol_lbl)

	_detail_vol_slider = HSlider.new()
	_detail_vol_slider.min_value = -40.0
	_detail_vol_slider.max_value = 6.0
	_detail_vol_slider.step = 0.5
	_detail_vol_slider.custom_minimum_size = Vector2(100, 0)
	_detail_vol_slider.value_changed.connect(_on_detail_volume_changed)
	row.add_child(_detail_vol_slider)

	_detail_vol_label = Label.new()
	_detail_vol_label.text = "0.0 dB"
	_detail_vol_label.custom_minimum_size = Vector2(65, 0)
	row.add_child(_detail_vol_label)

	# Clip End
	var clip_lbl := Label.new()
	clip_lbl.text = "Clip:"
	clip_lbl.custom_minimum_size = Vector2(32, 0)
	row.add_child(clip_lbl)

	_detail_clip_slider = HSlider.new()
	_detail_clip_slider.min_value = 0.0
	_detail_clip_slider.max_value = 10.0
	_detail_clip_slider.step = 0.01
	_detail_clip_slider.custom_minimum_size = Vector2(80, 0)
	_detail_clip_slider.editable = false
	_detail_clip_slider.value_changed.connect(_on_detail_clip_changed)
	row.add_child(_detail_clip_slider)

	_detail_clip_label = Label.new()
	_detail_clip_label.text = "0.00s"
	_detail_clip_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(_detail_clip_label)

	# Fade Out
	var fade_lbl := Label.new()
	fade_lbl.text = "Fade:"
	fade_lbl.custom_minimum_size = Vector2(36, 0)
	row.add_child(fade_lbl)

	_detail_fade_slider = HSlider.new()
	_detail_fade_slider.min_value = 0.0
	_detail_fade_slider.max_value = 2.0
	_detail_fade_slider.step = 0.01
	_detail_fade_slider.custom_minimum_size = Vector2(80, 0)
	_detail_fade_slider.editable = false
	_detail_fade_slider.value_changed.connect(_on_detail_fade_changed)
	row.add_child(_detail_fade_slider)

	_detail_fade_label = Label.new()
	_detail_fade_label.text = "0.00s"
	_detail_fade_label.custom_minimum_size = Vector2(50, 0)
	row.add_child(_detail_fade_label)

	# Preview / Stop
	_detail_preview_btn = Button.new()
	_detail_preview_btn.text = "\u25b6"
	_detail_preview_btn.disabled = true
	_detail_preview_btn.pressed.connect(_on_detail_preview)
	row.add_child(_detail_preview_btn)

	_detail_stop_btn = Button.new()
	_detail_stop_btn.text = "\u25a0"
	_detail_stop_btn.pressed.connect(_on_detail_stop)
	row.add_child(_detail_stop_btn)


# ── Timeline drawing ─────────────────────────────────────────────────────────

func _draw_timeline() -> void:
	var w: float = _timeline_control.size.x
	var h: float = _timeline_control.size.y
	if w < 10.0:
		return

	# Background
	_timeline_control.draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.05, 0.08, 1.0))

	# Phase bands
	for p in _phases:
		var x1: float = _time_to_x(float(p["start_time"]), w)
		var x2: float = _time_to_x(float(p["end_time"]), w)
		var col: Color = p["color"] as Color
		_timeline_control.draw_rect(Rect2(x1, PHASE_BAND_Y, x2 - x1, PHASE_BAND_HEIGHT), col)
		# Phase border
		_timeline_control.draw_rect(Rect2(x1, PHASE_BAND_Y, x2 - x1, PHASE_BAND_HEIGHT), Color(col, 0.6), false, 1.0)
		# Phase name
		var font: Font = ThemeManager.get_font("font_body")
		var font_size: int = 11
		if font:
			var text_w: float = font.get_string_size(str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var text_x: float = x1 + (x2 - x1 - text_w) * 0.5
			if text_w < (x2 - x1 - 4):
				_timeline_control.draw_string(font, Vector2(text_x, PHASE_BAND_Y + 14), str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.7))
			# Time range below name
			var time_text: String = "%.1fs-%.1fs" % [float(p["start_time"]), float(p["end_time"])]
			var time_w: float = font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			if time_w < (x2 - x1 - 4):
				var time_x: float = x1 + (x2 - x1 - time_w) * 0.5
				_timeline_control.draw_string(font, Vector2(time_x, PHASE_BAND_Y + 28), time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.4))

	# Typing regions (reboot_char_thunk) - filled bars
	for region in _typing_regions:
		var rx1: float = _time_to_x(float(region["start"]), w)
		var rx2: float = _time_to_x(float(region["end"]), w)
		_timeline_control.draw_rect(Rect2(rx1, TYPING_BAR_Y, rx2 - rx1, TYPING_BAR_HEIGHT), Color(0.3, 0.8, 0.4, 0.25))

	# Static burst region (hatched indicator in blackout)
	if _static_times.size() >= 2:
		var sx1: float = _time_to_x(_static_times[0] - 0.3, w)
		var sx2: float = _time_to_x(_static_times[_static_times.size() - 1] + 0.3, w)
		# Dashed region
		var dash_x: float = sx1
		while dash_x < sx2:
			var dash_end: float = minf(dash_x + 6.0, sx2)
			_timeline_control.draw_line(Vector2(dash_x, TYPING_BAR_Y + TYPING_BAR_HEIGHT + 4), Vector2(dash_end, TYPING_BAR_Y + TYPING_BAR_HEIGHT + 4), Color(0.8, 0.3, 0.3, 0.4), 2.0)
			dash_x += 12.0

	# Cue markers
	var font: Font = ThemeManager.get_font("font_body")
	for i in _cues.size():
		var cue: Dictionary = _cues[i]
		var cx: float = _time_to_x(float(cue["time"]), w)
		var eid: String = str(cue["event_id"])
		var is_selected: bool = eid == _selected_event_id_str

		# Skip reboot_line_beep markers to avoid clutter — they're too numerous
		if eid == "reboot_line_beep":
			continue

		# Marker color
		var marker_col: Color = Color(1.0, 0.9, 0.3, 1.0)
		if is_selected:
			marker_col = Color(0.3, 1.0, 0.5, 1.0)

		# Draw downward triangle
		var tri_top: float = MARKER_Y - MARKER_SIZE
		var tri_bot: float = MARKER_Y + MARKER_SIZE * 0.5
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(cx - MARKER_SIZE * 0.5, tri_top),
			Vector2(cx + MARKER_SIZE * 0.5, tri_top),
			Vector2(cx, tri_bot),
		])
		_timeline_control.draw_colored_polygon(pts, marker_col)

		# Vertical line from marker to phase band
		_timeline_control.draw_line(Vector2(cx, PHASE_BAND_Y + PHASE_BAND_HEIGHT), Vector2(cx, tri_top), Color(marker_col, 0.3), 1.0)

		# Label (abbreviated)
		if font:
			var display: String = _abbreviate_cue(eid)
			var lbl_size: Vector2 = font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1, 9)
			_timeline_control.draw_string(font, Vector2(cx - lbl_size.x * 0.5, LABEL_Y), display, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(marker_col, 0.8))

	# Playback cursor
	if _playback_active or _playback_time > 0.0:
		var cursor_x: float = _time_to_x(_playback_time, w)
		_timeline_control.draw_line(Vector2(cursor_x, 0), Vector2(cursor_x, h), Color(1.0, 1.0, 1.0, 0.9), 2.0)
		# Cursor head
		_timeline_control.draw_circle(Vector2(cursor_x, 8), 4.0, Color(1.0, 1.0, 1.0, 0.9))


func _abbreviate_cue(event_id: String) -> String:
	match event_id:
		"powerdown_drift_start": return "DRIFT"
		"powerdown_engines_dying": return "ENGINE"
		"power_failure": return "FAILURE"
		"powerdown_crt_flicker_start": return "CRT"
		"powerdown_screen_75": return "75%"
		"powerdown_screen_50": return "50%"
		"powerdown_screen_25": return "25%"
		"monitor_shutoff": return "OFF"
		"powerdown_final_death": return "DEATH"
		"powerup_electric_restored": return "COLD"
		"powerup_core_regen": return "CORE"
		"powerup_restored": return "OK"
		"powerup_bars_charging": return "BARS"
		"powerup_screen_on": return "SCRN"
		"powerup_systems_online": return "SYS"
		"monitor_static": return "STATIC"
		_: return event_id.get_file()


# ── Timeline interaction ─────────────────────────────────────────────────────

func _on_timeline_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_timeline_click(mb.position)


func _handle_timeline_click(pos: Vector2) -> void:
	var w: float = _timeline_control.size.x
	# Find nearest cue marker
	var best_eid: String = ""
	var best_dist: float = 20.0  # Max click distance in pixels
	for i in _cues.size():
		var eid: String = str(_cues[i]["event_id"])
		if eid == "reboot_line_beep":
			continue
		var cx: float = _time_to_x(float(_cues[i]["time"]), w)
		var dist: float = absf(pos.x - cx)
		if dist < best_dist:
			best_dist = dist
			best_eid = eid

	# Also check if clicking on a typing region (selects reboot_char_thunk)
	if best_eid == "":
		for region in _typing_regions:
			var rx1: float = _time_to_x(float(region["start"]), w)
			var rx2: float = _time_to_x(float(region["end"]), w)
			if pos.x >= rx1 and pos.x <= rx2 and pos.y >= TYPING_BAR_Y and pos.y <= TYPING_BAR_Y + TYPING_BAR_HEIGHT:
				best_eid = "reboot_char_thunk"
				break

	if best_eid != "":
		_select_event(best_eid)


func _select_event(eid: String) -> void:
	_selected_event_id_str = eid

	# Find matching cue index (for timeline highlight, -1 if non-cue event)
	_selected_cue_idx = -1
	for i in _cues.size():
		if str(_cues[i]["event_id"]) == eid:
			_selected_cue_idx = i
			break

	# Sync the event selector dropdown
	_detail_event_selector.set_block_signals(true)
	for i in _detail_event_selector.item_count:
		if str(_detail_event_selector.get_item_metadata(i)) == eid:
			_detail_event_selector.select(i)
			break
	_detail_event_selector.set_block_signals(false)

	# Build title — show timeline time if this is a cue event
	var label_name: String = str(SfxConfig.EVENT_LABELS.get(eid, eid))
	var display_label: String = str(PowerLossSequence.CUE_DISPLAY_LABELS.get(eid, ""))
	if _selected_cue_idx >= 0:
		var cue_time: float = float(_cues[_selected_cue_idx]["time"])
		if display_label != "":
			_detail_title.text = "%s  (T=%.2fs)" % [display_label, cue_time]
		else:
			_detail_title.text = "(T=%.2fs)" % cue_time
	else:
		if display_label != "":
			_detail_title.text = display_label
		else:
			_detail_title.text = ""

	# Populate controls from config
	var ev: Dictionary = _config.get_event(eid)
	var file_path: String = str(ev.get("file_path", ""))

	# Set file dropdown
	_detail_file_btn.set_block_signals(true)
	_detail_file_btn.select(0)  # (none)
	if file_path != "":
		for i in range(1, _detail_file_btn.item_count):
			if str(_detail_file_btn.get_item_metadata(i)) == file_path:
				_detail_file_btn.select(i)
				break
	_detail_file_btn.set_block_signals(false)

	# Volume
	_detail_vol_slider.set_block_signals(true)
	_detail_vol_slider.value = float(ev.get("volume_db", 0.0))
	_detail_vol_slider.set_block_signals(false)
	_detail_vol_label.text = "%.1f dB" % _detail_vol_slider.value

	# Clip
	var has_file: bool = file_path != ""
	_detail_clip_slider.editable = has_file
	_detail_fade_slider.editable = has_file
	_detail_preview_btn.disabled = not has_file

	if has_file:
		var stream_length: float = _get_stream_length(file_path)
		if stream_length > 0.0:
			_detail_clip_slider.max_value = stream_length

	_detail_clip_slider.set_block_signals(true)
	_detail_clip_slider.value = float(ev.get("clip_end_time", 0.0))
	_detail_clip_slider.set_block_signals(false)
	_detail_clip_label.text = "%.2fs" % _detail_clip_slider.value

	# Fade
	_detail_fade_slider.set_block_signals(true)
	_detail_fade_slider.value = float(ev.get("fade_out_duration", 0.0))
	_detail_fade_slider.set_block_signals(false)
	_detail_fade_label.text = "%.2fs" % _detail_fade_slider.value

	_timeline_control.queue_redraw()


func _on_event_selector_changed(idx: int) -> void:
	var eid: String = str(_detail_event_selector.get_item_metadata(idx))
	_select_event(eid)


# ── Detail panel handlers ────────────────────────────────────────────────────

func _selected_event_id() -> String:
	return _selected_event_id_str


func _on_detail_file_selected(idx: int) -> void:
	var eid: String = _selected_event_id()
	if eid == "":
		return
	var file_path: String = ""
	if idx > 0:
		file_path = str(_detail_file_btn.get_item_metadata(idx))
	var ev: Dictionary = _config.get_event(eid)
	ev["file_path"] = file_path

	var has_file: bool = file_path != ""
	_detail_clip_slider.editable = has_file
	_detail_fade_slider.editable = has_file
	_detail_preview_btn.disabled = not has_file

	if has_file:
		var stream_length: float = _get_stream_length(file_path)
		if stream_length > 0.0:
			_detail_clip_slider.max_value = stream_length
	else:
		_detail_clip_slider.value = 0.0
		_detail_fade_slider.value = 0.0

	_auto_save()


func _on_detail_volume_changed(value: float) -> void:
	var eid: String = _selected_event_id()
	if eid == "":
		return
	var ev: Dictionary = _config.get_event(eid)
	ev["volume_db"] = value
	_detail_vol_label.text = "%.1f dB" % value
	_auto_save()


func _on_detail_clip_changed(value: float) -> void:
	var eid: String = _selected_event_id()
	if eid == "":
		return
	var ev: Dictionary = _config.get_event(eid)
	ev["clip_end_time"] = value
	_detail_clip_label.text = "%.2fs" % value
	_auto_save()


func _on_detail_fade_changed(value: float) -> void:
	var eid: String = _selected_event_id()
	if eid == "":
		return
	var ev: Dictionary = _config.get_event(eid)
	ev["fade_out_duration"] = value
	_detail_fade_label.text = "%.2fs" % value
	_auto_save()


func _on_detail_preview() -> void:
	var eid: String = _selected_event_id()
	if eid == "":
		return
	var ev: Dictionary = _config.get_event(eid)
	var file_path: String = str(ev.get("file_path", ""))
	if file_path == "":
		return
	var stream: AudioStream = load(file_path) as AudioStream
	if stream == null:
		return
	_preview_player.stop()
	_preview_player.stream = stream
	_preview_player.volume_db = float(ev.get("volume_db", 0.0))
	_preview_player.play()


func _on_detail_stop() -> void:
	_preview_player.stop()


# ── Playback engine ──────────────────────────────────────────────────────────

func _on_play() -> void:
	if _playback_active:
		return
	_playback_active = true
	_playback_time = 0.0
	_next_cue_idx = 0
	_next_static_idx = 0
	_typing_active = false
	SfxPlayer.reload()
	if _active_event_type == 0:
		_setup_typing_player()
	_play_btn.disabled = true


func _on_stop() -> void:
	_playback_active = false
	_playback_time = 0.0
	_next_cue_idx = 0
	_next_static_idx = 0
	_play_btn.disabled = false
	_phase_label.text = ""
	_time_label.text = "T = 0.00s"
	_stop_typing_sound()
	_timeline_control.queue_redraw()


func _setup_typing_player() -> void:
	## Load reboot_char_thunk for looping playback during typing regions.
	var ev: Dictionary = _config.get_event("reboot_char_thunk")
	var thunk_path: String = str(ev.get("file_path", ""))
	if thunk_path == "":
		_typing_player.stream = null
		return
	var stream: AudioStream = load(thunk_path) as AudioStream
	if stream == null:
		_typing_player.stream = null
		return
	if stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	_typing_player.stream = stream
	_typing_player.volume_db = float(ev.get("volume_db", 0.0))


func _start_typing_sound() -> void:
	if not _typing_active and _typing_player.stream:
		_typing_active = true
		_typing_player.play()


func _stop_typing_sound() -> void:
	if _typing_active:
		_typing_active = false
		_typing_player.stop()


func _process(delta: float) -> void:
	if not _playback_active:
		return

	_playback_time += delta

	if _active_event_type == 1:
		_process_vent_playback()
		return

	# ── Power loss playback ──
	# Fire cues
	while _next_cue_idx < _cues.size():
		var cue: Dictionary = _cues[_next_cue_idx]
		if float(cue["time"]) > _playback_time:
			break
		SfxPlayer.play_ui(str(cue["event_id"]))
		_next_cue_idx += 1

	# Fire static bursts
	while _next_static_idx < _static_times.size():
		if _static_times[_next_static_idx] > _playback_time:
			break
		SfxPlayer.play_ui("monitor_static")
		_next_static_idx += 1

	# Typing sound — check if we're in a typing region
	var in_typing: bool = false
	for region in _typing_regions:
		if _playback_time >= float(region["start"]) and _playback_time < float(region["end"]):
			in_typing = true
			break
	if in_typing and not _typing_active:
		_start_typing_sound()
	elif not in_typing and _typing_active:
		_stop_typing_sound()

	# Update phase label
	var phase_name: String = ""
	for p in _phases:
		if _playback_time >= float(p["start_time"]) and _playback_time < float(p["end_time"]):
			phase_name = str(p["name"])
			break

	# Find most recent display label
	var display_text: String = ""
	for i in range(_next_cue_idx - 1, -1, -1):
		var dl: String = str(_cues[i].get("display_label", ""))
		if dl != "":
			display_text = dl
			break

	if phase_name != "" and display_text != "":
		_phase_label.text = "%s  \u2014  %s" % [phase_name, display_text]
	elif phase_name != "":
		_phase_label.text = phase_name
	else:
		_phase_label.text = ""

	_time_label.text = "T = %.2fs" % _playback_time
	_timeline_control.queue_redraw()

	# End of sequence
	if _playback_time >= _total_duration:
		_on_stop()


func _process_vent_playback() -> void:
	## Thermal vent playback — matches 4s purge duration + 1s recovery
	const VENT_CUE_TIMES: Array[float] = [0.0, 2.0, 4.0, 5.0]
	const VENT_TOTAL: float = 6.0
	while _next_cue_idx < THERMAL_VENT_EVENT_IDS.size():
		if VENT_CUE_TIMES[_next_cue_idx] > _playback_time:
			break
		SfxPlayer.play_ui(THERMAL_VENT_EVENT_IDS[_next_cue_idx])
		# Highlight the active cue button
		for i in _vent_cue_btns.size():
			(_vent_cue_btns[i] as Button).button_pressed = (i == _next_cue_idx)
		_select_event(THERMAL_VENT_EVENT_IDS[_next_cue_idx])
		_next_cue_idx += 1

	_time_label.text = "T = %.2fs" % _playback_time

	if _playback_time >= VENT_TOTAL:
		_on_stop()


# ── File scanning (mirrors sfx_editor pattern) ──────────────────────────────

func _scan_sfx_files() -> Array[String]:
	var all_files: Array[String] = []
	var root_path: String = "res://assets/audio/sfx/"
	var dir := DirAccess.open(root_path)
	if dir == null:
		return all_files
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_scan_sfx_folder(root_path + entry + "/", all_files)
		elif not dir.current_is_dir():
			var lower: String = entry.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				all_files.append(root_path + entry)
		entry = dir.get_next()
	dir.list_dir_end()
	all_files.sort()
	return all_files


func _scan_sfx_folder(path: String, results: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var lower: String = fname.to_lower()
			if lower.ends_with(".wav") or lower.ends_with(".ogg"):
				results.append(path + fname)
		fname = dir.get_next()
	dir.list_dir_end()


func _populate_file_dropdown(btn: OptionButton) -> void:
	btn.clear()
	btn.add_item("(none)")
	for f in _sfx_files:
		var display: String = f.replace("res://assets/audio/sfx/", "")
		var item_idx: int = btn.item_count
		btn.add_item(display)
		btn.set_item_metadata(item_idx, f)


func _get_stream_length(file_path: String) -> float:
	if file_path == "":
		return 0.0
	var stream: AudioStream = load(file_path) as AudioStream
	if stream == null:
		return 0.0
	return stream.get_length()


func _populate_from_config() -> void:
	# No per-event rows to populate — detail panel populates on cue selection
	pass


func _auto_save() -> void:
	SfxConfigManager.save(_config)
	SfxPlayer.reload()


# ── Theming ──────────────────────────────────────────────────────────────────

func apply_theme() -> void:
	if _play_btn:
		ThemeManager.apply_button_style(_play_btn)
	if _stop_btn:
		ThemeManager.apply_button_style(_stop_btn)
	if _detail_preview_btn:
		ThemeManager.apply_button_style(_detail_preview_btn)
	if _detail_stop_btn:
		ThemeManager.apply_button_style(_detail_stop_btn)
	if _detail_event_selector:
		ThemeManager.apply_button_style(_detail_event_selector)
	if _detail_file_btn:
		ThemeManager.apply_button_style(_detail_file_btn)
	if _time_label:
		ThemeManager.apply_text_glow(_time_label, "body")
	if _phase_label:
		ThemeManager.apply_text_glow(_phase_label, "header")
	if _detail_title:
		ThemeManager.apply_text_glow(_detail_title, "header")
	if _detail_vol_label:
		ThemeManager.apply_text_glow(_detail_vol_label, "body")
	if _detail_clip_label:
		ThemeManager.apply_text_glow(_detail_clip_label, "body")
	if _detail_fade_label:
		ThemeManager.apply_text_glow(_detail_fade_label, "body")
	if _event_dropdown:
		ThemeManager.apply_button_style(_event_dropdown)
	for btn in _vent_cue_btns:
		if is_instance_valid(btn):
			ThemeManager.apply_button_style(btn as Button)
	_timeline_control.queue_redraw()


func stop_playback() -> void:
	## Called externally when tab switches away.
	if _playback_active:
		_on_stop()
	_preview_player.stop()
