class_name EffectParticles
extends Node2D
## Fire-and-forget particle cloud. Draws HDR glow particles and queue_free()s when all expire.

var _particles: Array = []
var _color: Color = Color.CYAN


func setup(particles: Array, color: Color) -> void:
	_particles = particles
	_color = color


func _process(delta: float) -> void:
	var alive: bool = false
	for p in _particles:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		if float(p["age"]) < float(p["lifetime"]):
			alive = true
	if not alive:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	for p in _particles:
		var age: float = float(p["age"])
		var lifetime: float = float(p["lifetime"])
		if age >= lifetime:
			continue
		var t: float = clampf(age / lifetime, 0.0, 1.0)
		var alpha: float = (1.0 - t) * 0.8
		var sz: float = float(p["size"]) * (1.0 - t * 0.5)
		var pos: Vector2 = p["pos"]
		var col: Color = p.get("color", _color) as Color
		# HDR glow — bloom picks up values > 1.0
		draw_circle(pos, sz * 2.0, Color(col.r * 1.5, col.g * 1.5, col.b * 1.5, alpha * 0.3))
		draw_circle(pos, sz, Color(col.r * 2.0, col.g * 2.0, col.b * 2.0, alpha))
		draw_circle(pos, sz * 0.4, Color(2.0, 2.0, 2.0, alpha * 0.6))
