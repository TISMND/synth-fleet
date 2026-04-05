class_name EnemySharedRenderer
extends Node
## Manages shared SubViewports for enemy ship rendering.
## Instead of each enemy running its own ShipRenderer._draw() every frame,
## one ShipRenderer per unique appearance (visual_id + render_mode + color)
## renders into a shared SubViewport. All enemies with that appearance
## display the shared ViewportTexture via Sprite2D — animations stay live,
## but _draw() calls scale with unique types, not instance count.
##
## Viewports are paused (UPDATE_DISABLED) when no enemies of that type are
## alive, so idle types cost zero GPU time.
##
## Boss viewports (512x512 with complex procedural _draw) are updated every
## BOSS_RENDER_INTERVAL frames instead of every frame. The animations
## (spinning greebles, pulsing lights) are smooth enough at ~20fps while
## gameplay, collision, and input stay at full framerate.

# Key = "visual_id|render_mode|color_hex" -> { "viewport": SubViewport, "renderer": ShipRenderer, "ref_count": int, "boss": bool }
var _entries: Dictionary = {}

# Boss viewports render once every N frames instead of every frame.
var boss_render_interval: int = 3
var _frame_count: int = 0
var _active_boss_keys: Array[String] = []


func set_boss_render_interval(interval: int) -> void:
	boss_render_interval = maxi(interval, 1)


# Flash shader applied per-instance on Sprite2D (not on shared viewport)
const FLASH_SHADER_CODE := "shader_type canvas_item;
uniform float flash_mix : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col.rgb = mix(col.rgb, vec3(1.0), flash_mix);
	COLOR = col;
}"

var _flash_shader: Shader = null

# Large enemies get bigger viewports for visual fidelity
const LARGE_ENEMY_VISUALS: Array[String] = ["leviathan", "jellyfish", "marauder", "ironclad", "wraith", "monolith", "nexus", "pylon", "aegis", "helix", "conduit", "dreadnought", "mantaray", "nautilus", "behemoth", "mycelia"]
const XLARGE_ENEMY_VISUALS: Array[String] = ["colossus"]
const BOSS_ENEMY_VISUALS: Array[String] = ["archon_core", "archon_wing_l", "archon_wing_r", "archon_turret"]
const BAKE_SIZE_SMALL: int = 128
const BAKE_SIZE_LARGE: int = 256
const BAKE_SIZE_XLARGE: int = 512
const BAKE_SIZE_BOSS: int = 512


func _ready() -> void:
	_flash_shader = Shader.new()
	_flash_shader.code = FLASH_SHADER_CODE


func _process(_delta: float) -> void:
	if _active_boss_keys.size() == 0:
		return
	_frame_count += 1
	if _frame_count % boss_render_interval != 0:
		return
	for key in _active_boss_keys:
		if _entries.has(key):
			var entry: Dictionary = _entries[key]
			var vp: SubViewport = entry["viewport"]
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Call during level load to pre-create viewports for all enemy types in the level.
## appearances = Array of { "visual_id": String, "render_mode": String, "color": Color }
func register_appearances(appearances: Array, parent_node: Node) -> void:
	for entry in appearances:
		var entry_dict: Dictionary = entry as Dictionary
		var vid: String = str(entry_dict.get("visual_id", "sentinel"))
		var rmode_str: String = str(entry_dict.get("render_mode", "neon"))
		var color: Color = entry_dict.get("color", Color.CYAN) as Color
		var key: String = _make_key(vid, rmode_str, color)
		if _entries.has(key):
			continue
		var neon_params: Dictionary = {
			"hdr": float(entry_dict.get("neon_hdr", 1.0)),
			"white": float(entry_dict.get("neon_white", 0.0)),
			"width": float(entry_dict.get("neon_width", 1.0)),
		}
		_create_bake_viewport(key, vid, rmode_str, color, parent_node, neon_params)


## Get the ViewportTexture for a given enemy appearance. Returns null if not registered.
func get_texture(visual_id: String, render_mode_str: String, color: Color) -> ViewportTexture:
	var key: String = _make_key(visual_id, render_mode_str, color)
	if not _entries.has(key):
		return null
	var entry: Dictionary = _entries[key]
	var vp: SubViewport = entry["viewport"]
	return vp.get_texture()


## Get the bake viewport size for proper Sprite2D centering.
static func get_bake_size(visual_id: String) -> int:
	if visual_id in BOSS_ENEMY_VISUALS:
		return BAKE_SIZE_BOSS
	if visual_id in XLARGE_ENEMY_VISUALS:
		return BAKE_SIZE_XLARGE
	return BAKE_SIZE_LARGE if visual_id in LARGE_ENEMY_VISUALS else BAKE_SIZE_SMALL


## Called by NpcShip when it enters the tree — wakes up the viewport if needed.
func ref(visual_id: String, render_mode_str: String, color: Color) -> void:
	var key: String = _make_key(visual_id, render_mode_str, color)
	if not _entries.has(key):
		return
	var entry: Dictionary = _entries[key]
	var count: int = int(entry["ref_count"]) + 1
	entry["ref_count"] = count
	if count == 1:
		var renderer: ShipRenderer = entry["renderer"]
		renderer.animate = true
		if entry.get("boss", false):
			# Boss viewports are throttled — managed by _process() via UPDATE_ONCE
			_active_boss_keys.append(key)
			var vp: SubViewport = entry["viewport"]
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		else:
			var vp: SubViewport = entry["viewport"]
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Called by NpcShip when it exits the tree — pauses the viewport when last enemy dies.
func unref(visual_id: String, render_mode_str: String, color: Color) -> void:
	var key: String = _make_key(visual_id, render_mode_str, color)
	if not _entries.has(key):
		return
	var entry: Dictionary = _entries[key]
	var count: int = maxi(int(entry["ref_count"]) - 1, 0)
	entry["ref_count"] = count
	if count == 0:
		var vp: SubViewport = entry["viewport"]
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var renderer: ShipRenderer = entry["renderer"]
		renderer.animate = false
		if entry.get("boss", false):
			_active_boss_keys.erase(key)


## Create a per-instance flash ShaderMaterial (each enemy gets its own so flash is independent).
func create_flash_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _flash_shader
	return mat


func _make_key(visual_id: String, render_mode_str: String, color: Color) -> String:
	return "%s|%s|%s" % [visual_id, render_mode_str, color.to_html()]


func _create_bake_viewport(key: String, visual_id: String, render_mode_str: String, color: Color, parent_node: Node, neon_params: Dictionary = {}) -> void:
	var bake_size: int = get_bake_size(visual_id)

	var vp := SubViewport.new()
	vp.name = "Bake_" + key.replace("|", "_")
	vp.size = Vector2i(bake_size, bake_size)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED  # Start paused
	vp.transparent_bg = true
	vp.use_hdr_2d = true
	# No WorldEnvironment — no ACES tonemapping here, so HDR values
	# pass through to the texture. Bloom picks them up when the Sprite2D
	# renders in the game viewport.

	var renderer := ShipRenderer.new()
	renderer.ship_id = -1
	renderer.enemy_visual_id = visual_id
	renderer.render_mode = NpcShip._render_mode_from_string(render_mode_str)
	renderer.neon_hdr = float(neon_params.get("hdr", 1.0))
	renderer.neon_white = float(neon_params.get("white", 0.0))
	renderer.neon_width = float(neon_params.get("width", 1.0))
	renderer.hull_color = color
	renderer.accent_color = Color(1.0, 0.2, 0.6)
	renderer.position = Vector2(bake_size / 2.0, bake_size / 2.0)
	renderer.animate = false  # Start paused
	vp.add_child(renderer)

	# Add as child of the bake manager (which lives in the game viewport tree)
	parent_node.add_child(vp)
	# Force one render pass so the texture is warm before any enemy spawns.
	# UPDATE_ONCE renders exactly one frame then reverts to UPDATE_DISABLED.
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var is_boss: bool = visual_id in BOSS_ENEMY_VISUALS
	_entries[key] = {"viewport": vp, "renderer": renderer, "ref_count": 0, "boss": is_boss}


## Clean up all bake viewports (call on level exit).
func cleanup() -> void:
	for key in _entries:
		var entry: Dictionary = _entries[key]
		var vp: SubViewport = entry["viewport"]
		if is_instance_valid(vp):
			vp.queue_free()
	_entries.clear()
	_active_boss_keys.clear()
