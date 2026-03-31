class_name Pickup
extends Area2D
## Runtime currency pickup — spawned on enemy death, collected on player overlap.

var item_data: ItemData = null
var scroll_speed: float = 40.0

var _renderer: ItemRenderer = null
var _lifetime: float = 0.0
const MAX_LIFETIME: float = 15.0
const BLINK_START: float = 12.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	col.shape = shape
	add_child(col)

	if item_data:
		_renderer = ItemRenderer.new()
		var render_scale: float = CurrencyConfigManager.get_scale_for_item(item_data)
		_renderer.setup(item_data, render_scale * 0.45)
		add_child(_renderer)


func _process(delta: float) -> void:
	# Drift downward with the background scroll
	position.y += scroll_speed * delta
	_lifetime += delta

	# Blink before despawn
	if _lifetime > BLINK_START:
		var blink_t: float = (_lifetime - BLINK_START) / (MAX_LIFETIME - BLINK_START)
		var freq: float = lerpf(4.0, 12.0, blink_t)
		visible = sin(_lifetime * freq) > 0.0

	if _lifetime >= MAX_LIFETIME:
		queue_free()

	# Off-screen cleanup
	if position.y > 1280.0:
		queue_free()


func collect() -> void:
	if not item_data:
		queue_free()
		return
	GameState.add_credits(int(item_data.value))
	# Play appropriate SFX
	if item_data.visual_shape.contains("coin"):
		SfxPlayer.play("pickup_coin")
	else:
		SfxPlayer.play("pickup_shard")
	# Quick scale-to-zero collect animation
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	# Disable further collection
	collision_layer = 0
