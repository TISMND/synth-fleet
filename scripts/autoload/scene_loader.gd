extends Node
## Scene loader with synthwave-styled loading screen overlay.
## API: SceneLoader.load_scene(path) — shows overlay, loads async, transitions.

var _overlay: CanvasLayer = null
var _bg: ColorRect = null
var _bar: ColorRect = null
var _label: Label = null
var _loading: bool = false
var _target_path: String = ""
var _min_display_time: float = 0.3
var _elapsed: float = 0.0
var _progress: Array = []
const BAR_WIDTH: float = 400.0
const BAR_HEIGHT: float = 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	_overlay.visible = false
	add_child(_overlay)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.01, 0.01, 0.02, 1.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(_bg)

	# Loading text
	_label = Label.new()
	_label.text = "LOADING"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.offset_top = -30.0
	_label.offset_bottom = 0.0
	_label.offset_left = -200.0
	_label.offset_right = 200.0
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
	_overlay.add_child(_label)

	# Progress bar background
	var bar_bg := ColorRect.new()
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_bg.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, 540.0 + 10.0)
	bar_bg.color = Color(0.05, 0.05, 0.08, 0.8)
	_overlay.add_child(bar_bg)

	# Progress bar fill
	_bar = ColorRect.new()
	_bar.size = Vector2(0, BAR_HEIGHT)
	_bar.position = Vector2((1920.0 - BAR_WIDTH) * 0.5, 540.0 + 10.0)
	_bar.color = Color(0.3 * 2.2, 0.6 * 2.2, 1.0 * 2.2, 0.9)  # HDR blue
	_overlay.add_child(_bar)


func load_scene(path: String) -> void:
	if _loading:
		return
	_loading = true
	_target_path = path
	_elapsed = 0.0
	_overlay.visible = true
	_bar.size.x = 0.0

	var err: Error = ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_warning("SceneLoader: failed to start loading '%s', falling back to sync" % path)
		_overlay.visible = false
		_loading = false
		get_tree().change_scene_to_file(path)


func _process(delta: float) -> void:
	if not _loading:
		return
	_elapsed += delta

	# Animate loading text dots
	var dots: int = int(fmod(_elapsed * 3.0, 4.0))
	_label.text = "LOADING" + ".".repeat(dots)

	# Poll loading progress
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_target_path, _progress)
	if _progress.size() > 0:
		var pct: float = float(_progress[0])
		_bar.size.x = BAR_WIDTH * pct

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		if _elapsed >= _min_display_time:
			_finish_load()
		# else wait until min display time
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("SceneLoader: failed to load '%s'" % _target_path)
		_overlay.visible = false
		_loading = false


func _finish_load() -> void:
	var scene: PackedScene = ResourceLoader.load_threaded_get(_target_path) as PackedScene
	if scene:
		_bar.size.x = BAR_WIDTH
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(_target_path)
	_overlay.visible = false
	_loading = false
