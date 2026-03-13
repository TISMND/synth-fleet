class_name WeaponPattern
extends Resource
## A looping 1-measure pattern of notes for a weapon.
## 8 slots = eighth-note resolution.

const SLOTS := 8

## Array of 8 Dictionaries. Empty dict = rest.
## Filled: { "color": "cyan", "pitch": 1.0, "direction_deg": 0.0 }
@export var slots: Array[Dictionary] = []
@export var weapon_id: String = "basic_pulse"


func _init() -> void:
	if slots.size() != SLOTS:
		slots.clear()
		for i in SLOTS:
			slots.append({})


func is_slot_empty(i: int) -> bool:
	return slots[i].is_empty()


func set_note(i: int, color: String, pitch: float, direction_deg: float = 0.0) -> void:
	slots[i] = { "color": color, "pitch": pitch, "direction_deg": direction_deg }


func clear_note(i: int) -> void:
	slots[i] = {}


func duplicate_pattern() -> WeaponPattern:
	var p := WeaponPattern.new()
	p.weapon_id = weapon_id
	for i in SLOTS:
		p.slots[i] = slots[i].duplicate()
	return p
