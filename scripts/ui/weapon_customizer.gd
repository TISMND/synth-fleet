extends Control
## Weapon customizer / sequencer screen.
## Three panels: turret preview (left), controls (right), timeline (bottom).

const SLOT_SCENE := preload("res://scenes/ui/sequencer_slot.tscn")

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

var mount_name: String = "forward"
var brush_color: String = "cyan"
var brush_pitch: float = 1.0
var brush_direction: float = 0.0

var _pattern: WeaponPattern
var _slot_nodes: Array = []
var _preview_weapon: WeaponBase = null
var _cursor_slot: int = -1

@onready var timeline_container: HBoxContainer = $VBox/BottomPanel/TimelineScroll/Timeline
@onready var color_grid: GridContainer = $VBox/TopPanels/RightPanel/VBox/ColorGrid
@onready var pitch_grid: GridContainer = $VBox/TopPanels/RightPanel/VBox/PitchGrid
@onready var direction_spin: SpinBox = $VBox/TopPanels/RightPanel/VBox/DirectionRow/DirectionSpin
@onready var done_button: Button = $VBox/TopPanels/RightPanel/VBox/DoneButton
@onready var preview_viewport: SubViewport = $VBox/TopPanels/LeftPanel/SubViewportContainer/PreviewViewport
@onready var preview_weapon_node: Node2D = $VBox/TopPanels/LeftPanel/SubViewportContainer/PreviewViewport/PreviewShip/PreviewMount/PreviewWeapon
@onready var color_label: Label = $VBox/TopPanels/RightPanel/VBox/BrushLabel
@onready var pitch_label: Label = $VBox/TopPanels/RightPanel/VBox/PitchValueLabel


func _ready() -> void:
	_load_pattern()
	_build_timeline()
	_build_color_buttons()
	_build_pitch_buttons()
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


func _build_timeline() -> void:
	for i in WeaponPattern.SLOTS:
		var slot_node := SLOT_SCENE.instantiate()
		slot_node.slot_index = i
		timeline_container.add_child(slot_node)
		slot_node.set_note(_pattern.slots[i])
		slot_node.slot_clicked.connect(_on_slot_clicked)
		_slot_nodes.append(slot_node)


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


func _build_pitch_buttons() -> void:
	for p in PITCHES:
		var btn := Button.new()
		btn.text = p["name"]
		btn.custom_minimum_size = Vector2(50, 28)
		btn.pressed.connect(_select_pitch.bind(p["value"], p["name"]))
		pitch_grid.add_child(btn)


func _select_color(c: String) -> void:
	brush_color = c
	_update_brush_label()


func _select_pitch(val: float, _name: String) -> void:
	brush_pitch = val
	_update_brush_label()


func _update_brush_label() -> void:
	if color_label:
		color_label.text = "Brush: " + brush_color.capitalize()
	if pitch_label:
		# Find pitch name
		for p in PITCHES:
			if absf(p["value"] - brush_pitch) < 0.01:
				pitch_label.text = "Pitch: " + p["name"]
				break


func _on_slot_clicked(index: int) -> void:
	if _pattern.is_slot_empty(index):
		_pattern.set_note(index, brush_color, brush_pitch, brush_direction)
	else:
		_pattern.clear_note(index)
	_slot_nodes[index].set_note(_pattern.slots[index])
	# Update preview weapon
	if _preview_weapon:
		_preview_weapon.pattern = _pattern


var _eighth_counter: int = 0

func _on_beat_for_cursor(_beat_index: int) -> void:
	# Advance cursor two slots per beat (eighth notes)
	_highlight_cursor(_eighth_counter)
	_eighth_counter = (_eighth_counter + 1) % WeaponPattern.SLOTS
	# Schedule second eighth highlight
	var half := BeatClock.get_beat_duration() / 2.0
	get_tree().create_timer(half, false).timeout.connect(
		func() -> void:
			_highlight_cursor(_eighth_counter)
			_eighth_counter = (_eighth_counter + 1) % WeaponPattern.SLOTS
	)


func _highlight_cursor(slot: int) -> void:
	if _cursor_slot >= 0 and _cursor_slot < _slot_nodes.size():
		_slot_nodes[_cursor_slot].set_cursor_active(false)
	_cursor_slot = slot
	if _cursor_slot >= 0 and _cursor_slot < _slot_nodes.size():
		_slot_nodes[_cursor_slot].set_cursor_active(true)


func _on_done() -> void:
	# Save pattern
	var slot_array: Array = []
	for i in WeaponPattern.SLOTS:
		slot_array.append(_pattern.slots[i].duplicate())
	GameState.weapon_patterns[mount_name] = slot_array
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
