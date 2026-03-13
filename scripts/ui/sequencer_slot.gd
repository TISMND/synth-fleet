extends PanelContainer
## A single slot in the sequencer timeline. Clickable to place/remove notes.

signal slot_clicked(index: int)

@export var slot_index: int = 0

var _note_data: Dictionary = {}
var _is_active: bool = false  # playback cursor highlight

@onready var color_fill: ColorRect = $ColorFill
@onready var pitch_label: Label = $PitchLabel
@onready var beat_label: Label = $BeatLabel
@onready var cursor_overlay: ColorRect = $CursorOverlay

const BEAT_LABELS := ["1", "&", "2", "&", "3", "&", "4", "&"]

# Color name -> actual Color mapping
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

const PITCH_NAMES := {
	0.5: "C3", 0.56: "D3", 0.63: "E3", 0.67: "F3",
	0.75: "G3", 0.84: "A3", 0.94: "B3", 1.0: "C4",
	1.12: "D4", 1.26: "E4", 1.33: "F4", 1.5: "G4",
	1.68: "A4", 1.89: "B4", 2.0: "C5",
}


func _ready() -> void:
	beat_label.text = BEAT_LABELS[slot_index]
	cursor_overlay.visible = false
	update_display()
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_index)


func set_note(data: Dictionary) -> void:
	_note_data = data
	update_display()


func get_note() -> Dictionary:
	return _note_data


func clear() -> void:
	_note_data = {}
	update_display()


func update_display() -> void:
	if _note_data.is_empty():
		color_fill.color = Color(0.15, 0.15, 0.2, 1.0)
		pitch_label.text = ""
	else:
		var c_name: String = _note_data.get("color", "cyan")
		color_fill.color = COLOR_MAP.get(c_name, Color(0, 1, 1))
		var pitch: float = _note_data.get("pitch", 1.0)
		pitch_label.text = _get_pitch_name(pitch)


func set_cursor_active(active: bool) -> void:
	cursor_overlay.visible = active


func _get_pitch_name(pitch: float) -> String:
	# Find closest pitch name
	var closest_name := ""
	var closest_dist := 999.0
	for p in PITCH_NAMES:
		var dist := absf(p - pitch)
		if dist < closest_dist:
			closest_dist = dist
			closest_name = PITCH_NAMES[p]
	return closest_name
