extends CanvasLayer
## HUD — displays hull, shield, and energy bars on the right side of the screen.

var hull_bar_fill: ColorRect
var shield_bar_fill: ColorRect
var energy_bar_fill: ColorRect

var _hull_max: int = 100
var _shield_max: int = 50

const BAR_HEIGHT := 200.0


func _ready() -> void:
	hull_bar_fill = $BarsPanel/HullBarFill
	shield_bar_fill = $BarsPanel/ShieldBarFill
	energy_bar_fill = $BarsPanel/EnergyBarFill


func connect_to_player(player: CharacterBody2D) -> void:
	_hull_max = player.hull_max
	_shield_max = player.shield_max
	player.health_changed.connect(_on_health_changed)
	player.energy_changed.connect(_on_energy_changed)
	# Set initial values
	_on_health_changed(player.hull, player.shield)
	_on_energy_changed(player.current_energy, player.max_energy)


func _on_health_changed(hull: int, shield: int) -> void:
	_set_bar_fill(hull_bar_fill, float(hull) / float(_hull_max))
	_set_bar_fill(shield_bar_fill, float(shield) / float(_shield_max))


func _on_energy_changed(current: int, maximum: int) -> void:
	if maximum > 0:
		_set_bar_fill(energy_bar_fill, float(current) / float(maximum))


func _set_bar_fill(bar: ColorRect, ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	var fill_height := BAR_HEIGHT * ratio
	# Bar fills from bottom: keep bottom edge fixed, adjust top
	bar.offset_top = bar.offset_bottom - fill_height
