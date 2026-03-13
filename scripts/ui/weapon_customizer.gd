extends Control
## Weapon customizer / sequencer screen.
## Three panels: turret preview (left), controls (right), piano-roll grid (bottom).

const PianoCell := preload("res://scripts/ui/piano_cell.gd")

const COLORS := ["cyan", "magenta", "yellow", "green", "orange", "red", "blue", "white"]
const COLOR_MAP := {
	"cyan": Color(0, 1, 1),
	"magenta": Color(1, 0, 1),
	"yellow": Color(1, 1, 0),
	"green": Color(0, 1, 0.5),
	"orange": Color(1, 0.5, 0),
	"red": Color(1, 0.2, 0.2),
	"blue": Color(0.3, 0.3, 1),
	"white": Color(1, 1, 1),
}

const PITCHES := [
	{ "name": "C3", "value": 0.5 },
	{ "name": "D3", "value": 0.56 },
	{ "name": "E3", "value": 0.63 },
	{ "name": "F3", "value": 0.67 },
	{ "name": "G3", "value": 0.75 },
	{ "name": "A3", "value": 0.84 },
	{ "name": "B3", "value": 0.94 },
	{ "name": "C4", "value": 1.0 },
	{ "name": "D4", "value": 1.12 },
	{ "name": "E4", "value": 1.26 },
	{ "name": "F4", "value": 1.33 },
	{ "name": "G4", "value": 1.5 },
	{ "name": "A4", "value": 1.68 },
	{ "name": "B4", "value": 1.89 },
	{ "name": "C5", "value": 2.0 },
]

const BEAT_LABELS := ["1", "&", "2", "&", "3", "&", "4", "&"]

var mount_name: String = "forward"
var brush_color: String = "cyan"
var brush_direction: float = 0.0

var _pattern: WeaponPattern
var _cell_map: Dictionary = {}  # Vector2i(col, pitch_idx) -> PianoCell
var _preview_weapon: WeaponBase = null
var _cursor_slot: int = -1

@onready var timeline_scroll: ScrollContainer = $VBox/BottomPanel/TimelineScroll
@onready var color_grid: GridContainer = $VBox/TopPanels/RightPanel/VBox/ColorGrid
@onready var direction_spin: SpinBox = $VBox/TopPanels/RightPanel/VBox/DirectionRow/DirectionSpin
@onready var done_button: Button = $VBox/TopPanels/RightPanel/VBox/DoneButton
@onready var preview_viewport: SubViewport = $VBox/TopPanels/LeftPanel/SubViewportContainer/PreviewViewport
@onready var preview_weapon_node: Node2D = $VBox/TopPanels/LeftPanel/SubViewportContainer/PreviewViewport/PreviewShip/PreviewMount/PreviewWeapon
@onready var color_label: Label = $VBox/TopPanels/RightPanel/VBox/BrushLabel


func _ready() -> void:
	_load_pattern()
	_build_piano_grid()
	_build_color_buttons()
	_update_brush_label()

	direction_spin.value = brush_direction
	direction_spin.value_changed.connect(func(val: float) -> void: brush_direction = val)
	done_button.pressed.connect(_on_done)

	# Setup preview weapon
	if preview_weapon_node and preview_weapon_node is WeaponBase:
		_preview_weapon = preview_weapon_node as WeaponBase
		_preview_weapon.preview_mode = true
		_preview_weapon.pattern = _pattern

	# Start BeatClock for preview
	BeatClock.start(120.0)
	BeatClock.beat_hit.connect(_on_beat_for_cursor)


func _exit_tree() -> void:
	BeatClock.stop()


func _load_pattern() -> void:
	_pattern = WeaponPattern.new()
	if mount_name in GameState.weapon_patterns:
		var slot_array: Array = GameState.weapon_patterns[mount_name]
		for i in mini(slot_array.size(), WeaponPattern.SLOTS):
			if slot_array[i] is Dictionary and not slot_array[i].is_empty():
				_pattern.slots[i] = slot_array[i].duplicate()


func _build_piano_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 9  # 1 label column + 8 time columns
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 1)
	timeline_scroll.add_child(grid)

	# Row 0: corner spacer + beat labels
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(36, 22)
	grid.add_child(spacer)
	for col in WeaponPattern.SLOTS:
		var lbl := Label.new()
		lbl.text = BEAT_LABELS[col]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(44, 22)
		grid.add_child(lbl)

	# Rows 1-15: pitch labels + cells, C5 (top) -> C3 (bottom)
	for row in range(PITCHES.size()):
		# pitch_index: row 0 = C5 (index 14), row 14 = C3 (index 0)
		var pitch_idx: int = PITCHES.size() - 1 - row
		var pitch_name: String = PITCHES[pitch_idx]["name"]
		var is_c_row: bool = pitch_name.begins_with("C")

		# Pitch label
		var lbl := Label.new()
		lbl.text = pitch_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.custom_minimum_size = Vector2(36, 22)
		if is_c_row:
			lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		else:
			lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		grid.add_child(lbl)

		# 8 cells for this pitch row
		for col in WeaponPattern.SLOTS:
			var cell: ColorRect = PianoCell.new()
			cell.setup(col, pitch_idx, is_c_row)
			cell.cell_clicked.connect(_on_cell_clicked)
			grid.add_child(cell)
			_cell_map[Vector2i(col, pitch_idx)] = cell

	_refresh_all_cells()


func _build_color_buttons() -> void:
	for c in COLORS:
		var btn := Button.new()
		btn.text = c.capitalize()
		btn.custom_minimum_size = Vector2(80, 32)
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_MAP[c].darkened(0.4)
		btn.add_theme_stylebox_override("normal", style)
		var hover := StyleBoxFlat.new()
		hover.bg_color = COLOR_MAP[c].darkened(0.2)
		btn.add_theme_stylebox_override("hover", hover)
		btn.pressed.connect(_select_color.bind(c))
		color_grid.add_child(btn)


func _select_color(c: String) -> void:
	brush_color = c
	_update_brush_label()


func _update_brush_label() -> void:
	if color_label:
		color_label.text = "Brush: " + brush_color.capitalize()


func _on_cell_clicked(column: int, pitch_index: int) -> void:
	var clicked_pitch: float = PITCHES[pitch_index]["value"]
	var current_note: Dictionary = _pattern.slots[column]

	if current_note.is_empty():
		# Empty slot — place note
		_pattern.set_note(column, brush_color, clicked_pitch, brush_direction)
	elif _pitch_matches(current_note.get("pitch", -1.0), clicked_pitch):
		# Same pitch — clear note
		_pattern.clear_note(column)
	else:
		# Different pitch — move note to clicked row with brush color
		_pattern.set_note(column, brush_color, clicked_pitch, brush_direction)

	_refresh_column(column)
	if _preview_weapon:
		_preview_weapon.pattern = _pattern


func _pitch_matches(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _refresh_column(col: int) -> void:
	var note: Dictionary = _pattern.slots[col]
	for pitch_idx in range(PITCHES.size()):
		var cell = _cell_map[Vector2i(col, pitch_idx)]
		if not note.is_empty() and _pitch_matches(note.get("pitch", -1.0), PITCHES[pitch_idx]["value"]):
			cell.set_filled(COLOR_MAP.get(note.get("color", "cyan"), Color(0, 1, 1)))
		else:
			cell.set_empty()


func _refresh_all_cells() -> void:
	for col in WeaponPattern.SLOTS:
		_refresh_column(col)


var _eighth_counter: int = 0

func _on_beat_for_cursor(_beat_index: int) -> void:
	_highlight_cursor(_eighth_counter)
	_eighth_counter = (_eighth_counter + 1) % WeaponPattern.SLOTS
	var half := BeatClock.get_beat_duration() / 2.0
	get_tree().create_timer(half, false).timeout.connect(
		func() -> void:
			_highlight_cursor(_eighth_counter)
			_eighth_counter = (_eighth_counter + 1) % WeaponPattern.SLOTS
	)


func _highlight_cursor(slot: int) -> void:
	# Clear previous column
	if _cursor_slot >= 0:
		for pitch_idx in range(PITCHES.size()):
			var key := Vector2i(_cursor_slot, pitch_idx)
			if key in _cell_map:
				_cell_map[key].set_cursor_highlight(false)
	# Highlight new column
	_cursor_slot = slot
	if _cursor_slot >= 0:
		for pitch_idx in range(PITCHES.size()):
			var key := Vector2i(_cursor_slot, pitch_idx)
			if key in _cell_map:
				_cell_map[key].set_cursor_highlight(true)


func _on_done() -> void:
	var slot_array: Array = []
	for i in WeaponPattern.SLOTS:
		slot_array.append(_pattern.slots[i].duplicate())
	GameState.weapon_patterns[mount_name] = slot_array
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
