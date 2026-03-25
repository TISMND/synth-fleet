class_name EnemyBakeManager
extends Node
## Manages shared SubViewports for enemy ship rendering.
## Instead of each enemy running its own ShipRenderer._draw() every frame,
## one ShipRenderer per unique appearance (visual_id + render_mode + color)
## renders into a shared SubViewport. All enemies with that appearance
## display the shared ViewportTexture via Sprite2D — animations stay live,
## but _draw() calls scale with unique types, not instance count.

# Key = "visual_id|render_mode|color_hex" -> SubViewport
var _viewports: Dictionary = {}

# Flash shader applied per-instance on Sprite2D (not on shared viewport)
const FLASH_SHADER_CODE := "shader_type canvas_item;
uniform float flash_mix : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	col.rgb = mix(col.rgb, vec3(1.0), flash_mix);
	COLOR = col;
}"

var _flash_shader: Shader = null

const BAKE_SIZE: int = 256  # px — enough for largest enemies (colossus at ~80px radius)


func _ready() -> void:
	_flash_shader = Shader.new()
	_flash_shader.code = FLASH_SHADER_CODE


## Call during level load to pre-create viewports for all enemy types in the level.
## appearances = Array of { "visual_id": String, "render_mode": String, "color": Color }
func register_appearances(appearances: Array, parent_viewport: SubViewport) -> void:
	for entry in appearances:
		var entry_dict: Dictionary = entry as Dictionary
		var vid: String = str(entry_dict.get("visual_id", "sentinel"))
		var rmode_str: String = str(entry_dict.get("render_mode", "neon"))
		var color: Color = entry_dict.get("color", Color.CYAN) as Color
		var key: String = _make_key(vid, rmode_str, color)
		if _viewports.has(key):
			continue
		_create_bake_viewport(key, vid, rmode_str, color, parent_viewport)


## Get the ViewportTexture for a given enemy appearance. Returns null if not registered.
func get_texture(visual_id: String, render_mode_str: String, color: Color) -> ViewportTexture:
	var key: String = _make_key(visual_id, render_mode_str, color)
	if not _viewports.has(key):
		return null
	var vp: SubViewport = _viewports[key]
	return vp.get_texture()


## Create a per-instance flash ShaderMaterial (each enemy gets its own so flash is independent).
func create_flash_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _flash_shader
	return mat


func _make_key(visual_id: String, render_mode_str: String, color: Color) -> String:
	return "%s|%s|%s" % [visual_id, render_mode_str, color.to_html()]


func _create_bake_viewport(key: String, visual_id: String, render_mode_str: String, color: Color, parent_viewport: SubViewport) -> void:
	var vp := SubViewport.new()
	vp.name = "Bake_" + key.replace("|", "_")
	vp.size = Vector2i(BAKE_SIZE, BAKE_SIZE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = true
	vp.use_hdr_2d = true
	# No WorldEnvironment — no ACES tonemapping here, so HDR values
	# pass through to the texture. Bloom picks them up when the Sprite2D
	# renders in the game viewport.

	var renderer := ShipRenderer.new()
	renderer.ship_id = -1
	renderer.enemy_visual_id = visual_id
	renderer.render_mode = ShipRenderer.RenderMode.CHROME if render_mode_str == "chrome" else ShipRenderer.RenderMode.NEON
	renderer.hull_color = color
	renderer.accent_color = Color(1.0, 0.2, 0.6)
	renderer.position = Vector2(BAKE_SIZE / 2.0, BAKE_SIZE / 2.0)
	vp.add_child(renderer)

	# Add as child of the game viewport so it's part of the rendering tree
	parent_viewport.add_child(vp)
	_viewports[key] = vp


## Clean up all bake viewports (call on level exit).
func cleanup() -> void:
	for key in _viewports:
		var vp: SubViewport = _viewports[key]
		if is_instance_valid(vp):
			vp.queue_free()
	_viewports.clear()
