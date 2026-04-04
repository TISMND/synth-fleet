class_name SynthwaveBgSetup
## Shared setup for the synthwave background used across menu screens.
## Creates three layers: planet SubViewport, HDR stars, transparent grid overlay.
## All layers load saved settings from user://settings/synthwave_bg.json.

const SW_SETTINGS_PATH: String = "user://settings/synthwave_bg.json"

const _SHARED_PARAMS: Array[String] = [
	"horizon", "planet_x", "atmo_color",
]

const _STAR_SHARED_PARAMS: Array[String] = [
	"horizon", "planet_x", "planet_radius",
]

const _PLANET_PARAMS: Array[String] = [
	"planet_x", "planet_radius", "planet_color_top", "planet_color_bot", "planet_hdr",
	"slice_enabled", "slice_start", "slice_band_h", "slice_gap_base", "slice_gap_grow",
	"ring_inner", "ring_outer", "ring_tilt", "ring_angle", "ring_color", "ring_hdr", "ring_hdr_back",
	"ring_band_width", "ring_gap_base", "ring_gap_grow", "ring_glow_size",
	"planet_tilted", "atmo_glow", "atmo_color",
	"sky_top", "sky_mid", "sky_low", "horizon",
	"accent_color", "nebula_intensity", "nebula_scale", "nebula_drift",
	"warp_streak_intensity", "warp_streak_speed", "warp_streak_count",
	"warp_inner_radius", "warp_fade_width", "warp_max_length", "warp_streak_width",
]

const _STAR_PARAMS: Array[String] = [
	"star_density", "star_size", "star_hdr", "star_twinkle", "star_color", "star_core_white",
	"horizon", "planet_x", "planet_radius",
]


## Adds the synthwave background layers to a Control node.
## `bg_node` is the existing Background node (ColorRect or TextureRect) that
## will be replaced with the grid shader layer. Pass the parent Control.
## Inserts layers at index 0 so they're behind all other children.
static func setup(parent: Control) -> void:
	# Remove existing Background node if present
	var old_bg: Node = parent.get_node_or_null("Background")
	if old_bg:
		old_bg.queue_free()

	# ── Planet layer: SubViewport with ACES tonemapping ──
	var vp := SubViewport.new()
	vp.size = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/viewport_width")),
		int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	vp.transparent_bg = false
	vp.use_hdr_2d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = false
	world_env.environment = env
	vp.add_child(world_env)

	var planet_rect := ColorRect.new()
	planet_rect.color = Color.WHITE
	planet_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var planet_shader: Shader = load("res://assets/shaders/synthwave_planet.gdshader")
	if planet_shader:
		var planet_mat := ShaderMaterial.new()
		planet_mat.shader = planet_shader
		planet_rect.material = planet_mat
	vp.add_child(planet_rect)
	parent.add_child(vp)
	parent.move_child(vp, 0)

	# Show SubViewport via TextureRect
	var tex_rect := TextureRect.new()
	tex_rect.texture = vp.get_texture()
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	parent.add_child(tex_rect)
	parent.move_child(tex_rect, 1)

	# ── Star layer: root viewport HDR ──
	var star_rect := ColorRect.new()
	star_rect.color = Color.WHITE
	star_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var star_shader: Shader = load("res://assets/shaders/synthwave_stars.gdshader")
	if star_shader:
		var star_mat := ShaderMaterial.new()
		star_mat.shader = star_shader
		star_rect.material = star_mat
	parent.add_child(star_rect)
	parent.move_child(star_rect, 2)

	# ── Grid layer: root viewport bloom ──
	var grid_rect := ColorRect.new()
	grid_rect.name = "Background"
	grid_rect.color = Color.WHITE
	grid_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grid_shader: Shader = load("res://assets/shaders/synthwave_bg.gdshader")
	if grid_shader:
		var grid_mat := ShaderMaterial.new()
		grid_mat.shader = grid_shader
		grid_rect.material = grid_mat
	parent.add_child(grid_rect)
	parent.move_child(grid_rect, 3)

	# ── Load saved settings ──
	if not FileAccess.file_exists(SW_SETTINGS_PATH):
		return
	var f: FileAccess = FileAccess.open(SW_SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK or not (json.data is Dictionary):
		f.close()
		return
	var data: Dictionary = json.data as Dictionary
	var p_mat: ShaderMaterial = planet_rect.material as ShaderMaterial
	var g_mat: ShaderMaterial = grid_rect.material as ShaderMaterial
	var s_mat: ShaderMaterial = star_rect.material as ShaderMaterial
	for key in data:
		var val: Variant = data[key]
		if val is Dictionary:
			var d: Dictionary = val as Dictionary
			if d.has("r"):
				val = Color(float(d["r"]), float(d["g"]), float(d["b"]))
		var effective_key: String = key
		if key == "star_brightness":
			effective_key = "star_hdr"
		if key == "star_glow_size":
			continue
		if p_mat and effective_key in _PLANET_PARAMS:
			p_mat.set_shader_parameter(effective_key, val)
		if s_mat and effective_key in _STAR_PARAMS:
			s_mat.set_shader_parameter(effective_key, val)
		if g_mat and (effective_key not in _PLANET_PARAMS or effective_key in _SHARED_PARAMS):
			if effective_key not in _STAR_PARAMS or effective_key in _STAR_SHARED_PARAMS:
				g_mat.set_shader_parameter(effective_key, val)
	f.close()
