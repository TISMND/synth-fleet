class_name EffectProfile
extends Resource
## Type-safe container for weapon visual effect profiles.

@export var motion: Dictionary = { "type": "none", "params": {} }
@export var muzzle: Dictionary = { "type": "none", "params": {} }
@export var shape: Dictionary = { "type": "rect", "params": {} }
@export var trail: Dictionary = { "type": "none", "params": {} }
@export var impact: Dictionary = { "type": "none", "params": {} }


static func from_dict(data: Dictionary) -> EffectProfile:
	var ep := EffectProfile.new()
	ep.motion = data.get("motion", { "type": "none", "params": {} })
	ep.muzzle = data.get("muzzle", { "type": "none", "params": {} })
	ep.shape = data.get("shape", { "type": "rect", "params": {} })
	ep.trail = data.get("trail", { "type": "none", "params": {} })
	ep.impact = data.get("impact", { "type": "none", "params": {} })
	return ep


func to_dict() -> Dictionary:
	return {
		"motion": motion,
		"muzzle": muzzle,
		"shape": shape,
		"trail": trail,
		"impact": impact,
	}
