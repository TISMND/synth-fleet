class_name Pickup
extends Area2D
## Runtime currency pickup — spawned on enemy death, collected on player overlap.

var item_data: ItemData = null
var scroll_speed: float = 80.0  # Set from level scroll_speed at spawn time

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
		_renderer.setup(item_data, render_scale)
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
	var credit_val: int = int(item_data.value)
	GameState.add_credits(credit_val)
	# Play appropriate SFX
	if item_data.visual_shape.contains("coin"):
		SfxPlayer.play("pickup_coin")
	else:
		SfxPlayer.play("pickup_shard")
	# Spawn floating value text at pickup position
	_spawn_value_popup(credit_val)
	# Quick scale-to-zero collect animation
	var tw: Tween = create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	# Disable further collection
	collision_layer = 0


func _spawn_value_popup(value: int) -> void:
	var popup := Label.new()
	popup.text = "+" + str(value)
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font: Font = ThemeManager.get_font("font_body")
	if font:
		popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", 16)
	# Color matches the item's glow color
	var col := Color.from_string(item_data.glow_color, Color.WHITE)
	var hdr: float = item_data.hdr_intensity * 0.8
	popup.add_theme_color_override("font_color", Color(col.r * hdr, col.g * hdr, col.b * hdr))
	# Font outline for readability
	popup.add_theme_constant_override("outline_size", 2)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	popup.position = global_position - Vector2(20, 10)
	# Add to same parent so it persists after pickup is freed
	get_parent().add_child(popup)
	# Float upward and fade out
	var tw: Tween = popup.create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y - 40.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.3)
	tw.chain().tween_callback(popup.queue_free)
