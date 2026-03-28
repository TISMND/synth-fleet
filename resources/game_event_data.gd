class_name GameEventData
extends Resource
## Reusable visual + audio event package. Triggered by nebulas, bosses, level events, etc.
## Each event contains one or more effects that fire simultaneously or with delays.

@export var id: String = ""
@export var display_name: String = ""
@export var effects: Array[Dictionary] = []
# Each effect dict has "type" plus type-specific keys:
#   "screen_shake"    — amplitude: float, duration: float
#   "screen_static"   — intensity: float (0-1), duration: float
#   "lightning_flash"  — color: Array[float] (RGBA), intensity: float, count: int, interval: float
#   "screen_dim"      — brightness: float (0-1 target), duration: float, fade_in: float, fade_out: float
#   "sfx"             — sfx_event_id: String, delay: float
#   "hud_flicker"     — intensity: float (0-1), duration: float


static func default_effects() -> Array[Dictionary]:
	return []


static func from_dict(data: Dictionary) -> GameEventData:
	var e := GameEventData.new()
	e.id = str(data.get("id", ""))
	e.display_name = str(data.get("display_name", ""))
	var raw_effects: Array = data.get("effects", []) as Array
	var typed_effects: Array[Dictionary] = []
	for fx in raw_effects:
		var d: Dictionary = fx as Dictionary
		typed_effects.append(d)
	e.effects = typed_effects
	return e


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"effects": effects,
	}
