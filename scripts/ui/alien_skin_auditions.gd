extends MarginContainer
## Alien skin auditions — cycle through neon/alien render modes on enemy ships.
## Renders through bake viewport to match in-game appearance.

var _time: float = 0.0
var _ship_renderer: ShipRenderer = null
var _skin_index: int = 1  # Start on NEON (skip debug)
var _skin_label: Label = null
var _ship_label: Label = null
var _ship_index: int = 0
var _main_vp: SubViewport = null
var _bake_vp: SubViewport = null
var _bake_sprite: Sprite2D = null

# Lifeform-themed ships only
const SHIP_LIST: Array[Array] = [
	["BEHEMOTH", "behemoth"],
	["SPORE", "spore"],
	["MITE", "mite"],
	["POLYP", "polyp"],
	["JELLYFISH", "jellyfish"],
	["LAMPREY", "lamprey"],
	["ANEMONE", "anemone"],
	["MANTARAY", "mantaray"],
	["NAUTILUS", "nautilus"],
	["MYCELIA", "mycelia"],
	["COLOSSUS", "colossus"],
	["IRONCLAD", "ironclad"],
]

# Alien skins for lifeforms
const SKIN_MODES: Array[int] = [
	ShipRenderer.RenderMode.DEBUG_MATERIALS,
	ShipRenderer.RenderMode.NEON,
	ShipRenderer.RenderMode.EMBER,
	ShipRenderer.RenderMode.FROST,
	ShipRenderer.RenderMode.SOLAR,
	ShipRenderer.RenderMode.SPORT,
	ShipRenderer.RenderMode.BIOLUME,
	ShipRenderer.RenderMode.TOXIC,
	ShipRenderer.RenderMode.CORAL,
	ShipRenderer.RenderMode.ABYSSAL,
	ShipRenderer.RenderMode.BLOODMOON,
	ShipRenderer.RenderMode.PHANTOM,
	ShipRenderer.RenderMode.AURORA,
]
const SKIN_NAMES: Array[String] = [
	"DEBUG MATERIALS",
	"NEON",
	"EMBER",
	"FROST",
	"SOLAR",
	"SPORT",
	"BIOLUME",
	"TOXIC",
	"CORAL",
	"ABYSSAL",
	"BLOODMOON",
	"PHANTOM",
	"AURORA",
]


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	_time += delta
	if _ship_renderer:
		_ship_renderer.time = _time


func _input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var ke: InputEventKey = event as InputEventKey
		if ke.keycode == KEY_Q or ke.keycode == KEY_COMMA:
			_cycle_skin(-1)
		elif ke.keycode == KEY_E or ke.keycode == KEY_PERIOD:
			_cycle_skin(1)
		elif ke.keycode == KEY_1:
			_cycle_ship(-1)
		elif ke.keycode == KEY_2:
			_cycle_ship(1)


func _cycle_skin(dir: int) -> void:
	_skin_index = (_skin_index + dir + SKIN_MODES.size()) % SKIN_MODES.size()
	if _ship_renderer:
		_ship_renderer.render_mode = SKIN_MODES[_skin_index]
	if _skin_label:
		_skin_label.text = SKIN_NAMES[_skin_index]


func _cycle_ship(dir: int) -> void:
	_ship_index = (_ship_index + dir + SHIP_LIST.size()) % SHIP_LIST.size()
	if _ship_label:
		_ship_label.text = SHIP_LIST[_ship_index][0] as String
	_rebuild_ship()


func _rebuild_ship() -> void:
	if not _bake_vp:
		return
	if _ship_renderer:
		_ship_renderer.queue_free()

	var vid: String = SHIP_LIST[_ship_index][1] as String
	var bake_size: int = EnemySharedRenderer.get_bake_size(vid)
	_bake_vp.size = Vector2i(bake_size, bake_size)

	# Load saved neon params from ShipData if available
	var neon_hdr: float = 1.0
	var neon_white: float = 0.0
	var neon_width: float = 1.0
	# Find ship by visual_id
	var ships: Array = ShipDataManager.load_all_by_type("enemy")
	for ship in ships:
		var sd: ShipData = ship as ShipData
		if sd and sd.visual_id == vid:
			neon_hdr = sd.neon_hdr
			neon_white = sd.neon_white
			neon_width = sd.neon_width
			break

	_ship_renderer = ShipRenderer.new()
	_ship_renderer.ship_id = -1
	_ship_renderer.enemy_visual_id = vid
	_ship_renderer.render_mode = SKIN_MODES[_skin_index]
	_ship_renderer.neon_hdr = neon_hdr
	_ship_renderer.neon_white = neon_white
	_ship_renderer.neon_width = neon_width
	_ship_renderer.position = Vector2(bake_size / 2.0, bake_size / 2.0)
	_ship_renderer.z_index = 1
	_bake_vp.add_child(_ship_renderer)

	_bake_sprite.texture = _bake_vp.get_texture()


func _build_ui() -> void:
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 6)
	add_child(main)

	var header := Label.new()
	header.text = "ALIEN SKINS — Q/E skins, 1/2 ship"
	ThemeManager.apply_text_glow(header, "header")
	main.add_child(header)

	# Ship selector + Skin selector row
	var selectors_row := HBoxContainer.new()
	selectors_row.add_theme_constant_override("separation", 30)
	main.add_child(selectors_row)

	# Ship selector
	var ship_row := HBoxContainer.new()
	ship_row.add_theme_constant_override("separation", 12)
	selectors_row.add_child(ship_row)

	var ship_label_prefix := Label.new()
	ship_label_prefix.text = "SHIP:"
	ThemeManager.apply_text_glow(ship_label_prefix, "body")
	ship_row.add_child(ship_label_prefix)

	var prev_ship_btn := Button.new()
	prev_ship_btn.text = "< 1"
	prev_ship_btn.pressed.connect(func() -> void: _cycle_ship(-1))
	ThemeManager.apply_button_style(prev_ship_btn)
	ship_row.add_child(prev_ship_btn)

	_ship_label = Label.new()
	_ship_label.text = SHIP_LIST[_ship_index][0] as String
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ship_label.custom_minimum_size.x = 160
	ThemeManager.apply_text_glow(_ship_label, "header")
	ship_row.add_child(_ship_label)

	var next_ship_btn := Button.new()
	next_ship_btn.text = "2 >"
	next_ship_btn.pressed.connect(func() -> void: _cycle_ship(1))
	ThemeManager.apply_button_style(next_ship_btn)
	ship_row.add_child(next_ship_btn)

	# Skin name + arrows
	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 12)
	selectors_row.add_child(nav_row)

	var prev_btn := Button.new()
	prev_btn.text = "< Q"
	prev_btn.pressed.connect(func() -> void: _cycle_skin(-1))
	ThemeManager.apply_button_style(prev_btn)
	nav_row.add_child(prev_btn)

	_skin_label = Label.new()
	_skin_label.text = SKIN_NAMES[_skin_index]
	_skin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_label.custom_minimum_size.x = 200
	ThemeManager.apply_text_glow(_skin_label, "header")
	nav_row.add_child(_skin_label)

	var next_btn := Button.new()
	next_btn.text = "E >"
	next_btn.pressed.connect(func() -> void: _cycle_skin(1))
	ThemeManager.apply_button_style(next_btn)
	nav_row.add_child(next_btn)

	# Main display viewport (matches game pipeline)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.size = Vector2(1920, 1080)
	vpc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vpc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(vpc)

	_main_vp = SubViewport.new()
	_main_vp.transparent_bg = false
	_main_vp.size = Vector2i(1920, 1080)
	_main_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_main_vp.use_hdr_2d = true
	vpc.add_child(_main_vp)

	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.03, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_vp.add_child(bg)

	var stars := _StarBG.new()
	_main_vp.add_child(stars)

	# Bake viewport (matches EnemySharedRenderer — raw HDR, no tonemapping)
	_bake_vp = SubViewport.new()
	_bake_vp.transparent_bg = true
	_bake_vp.use_hdr_2d = true
	_bake_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_main_vp.add_child(_bake_vp)

	# Bake sprite displays the bake texture in the main viewport
	_bake_sprite = Sprite2D.new()
	_bake_sprite.position = Vector2(960, 540)
	_bake_sprite.z_index = 1
	_main_vp.add_child(_bake_sprite)

	_rebuild_ship()


class _StarBG extends Node2D:
	var _stars: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in range(60):
			_stars.append({
				"pos": Vector2(rng.randf() * 1920.0, rng.randf() * 1080.0),
				"size": rng.randf_range(0.4, 1.4),
				"bright": rng.randf_range(0.15, 0.5),
				"speed": rng.randf_range(0.3, 1.0),
			})

	func _process(delta: float) -> void:
		for s in _stars:
			(s["pos"] as Vector2).y += float(s["speed"]) * 80.0 * delta
			if (s["pos"] as Vector2).y > 1080.0:
				s["pos"] = Vector2(randf() * 1920.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		for s in _stars:
			var b: float = float(s["bright"])
			draw_circle(s["pos"] as Vector2, float(s["size"]),
				Color(b, b, b * 1.2, 0.7))
