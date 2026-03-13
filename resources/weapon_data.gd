class_name WeaponData
extends Resource
## Defines a weapon type — damage, pattern, available colors, cost.

@export var id: String = ""
@export var display_name: String = ""
@export var damage: int = 10
@export var projectile_speed: float = 600.0
@export var subdivision: int = 1  ## 1 = quarter, 2 = eighth, 3 = triplet
@export var available_colors: PackedStringArray = ["cyan"]
@export var power_cost: int = 1
@export var shop_cost: int = 100
@export var mount_type: String = "forward"  ## forward, back, left, right, special
@export var description: String = ""
@export var fire_pattern: String = "single"  ## single, burst, dual, wave, spread, beam, scatter
