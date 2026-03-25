extends Control
## Layout Sandbox — a playground for learning Godot's scene editor.
## Left panel: entirely defined in the .tscn file (buttons, labels, layout).
## Right panel: layout shell in .tscn, content populated by code at runtime.
## This demonstrates the hybrid approach.

# These reference nodes defined in the .tscn — no code needed to create them.
# The $ syntax means "get child node by path in the scene tree."
@onready var _status: Label = $MainLayout/Content/LeftPanel/LeftVBox/StatusLabel
@onready var _bar_container: VBoxContainer = $MainLayout/Content/RightPanel/RightVBox/BarContainer
@onready var _left_panel: PanelContainer = $MainLayout/Content/LeftPanel
@onready var _right_panel: PanelContainer = $MainLayout/Content/RightPanel

var _bar_count: int = 0
var _panel_wide: bool = false


func _ready() -> void:
	# Wire up buttons defined in the .tscn — this is ALL the code needs to do.
	# The buttons already exist; code just connects their signals.
	$MainLayout/TopBar/BackButton.pressed.connect(_on_back)
	$MainLayout/Content/LeftPanel/LeftVBox/ColorButton.pressed.connect(_on_randomize_colors)
	$MainLayout/Content/LeftPanel/LeftVBox/SizeButton.pressed.connect(_on_toggle_size)
	$MainLayout/Content/LeftPanel/LeftVBox/AddBarButton.pressed.connect(_on_add_bar)
	$MainLayout/Content/LeftPanel/LeftVBox/ClearButton.pressed.connect(_on_clear_bars)

	# Apply theme to buttons that were defined in .tscn
	for btn in _find_all_buttons(self):
		ThemeManager.apply_button_style(btn)
	ThemeManager.apply_grid_background($Background)
	ThemeManager.apply_text_glow($MainLayout/TopBar/Title, "header")
	ThemeManager.apply_text_glow($MainLayout/Content/LeftPanel/LeftVBox/PanelTitle, "header")
	ThemeManager.apply_text_glow($MainLayout/Content/RightPanel/RightVBox/RightTitle, "header")

	_style_panel(_left_panel)
	_style_panel(_right_panel)

	# Add a few starter bars via code into the .tscn-defined container
	for i in 3:
		_add_bar()


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dev_studio_menu.tscn")


func _on_randomize_colors() -> void:
	# Randomize all bar colors — demonstrates code modifying .tscn-defined layout
	for bar in _bar_container.get_children():
		if bar is ProgressBar:
			var color := Color(randf(), randf(), randf())
			ThemeManager.apply_led_bar(bar, color, bar.value / bar.max_value)
	_status.text = "Status: Colors randomized!"


func _on_toggle_size() -> void:
	_panel_wide = not _panel_wide
	_left_panel.custom_minimum_size.x = 600 if _panel_wide else 400
	_status.text = "Status: Left panel = %dpx wide" % int(_left_panel.custom_minimum_size.x)


func _on_add_bar() -> void:
	_add_bar()
	_status.text = "Status: %d bars" % _bar_count


func _on_clear_bars() -> void:
	for child in _bar_container.get_children():
		child.queue_free()
	_bar_count = 0
	_status.text = "Status: Cleared!"


func _add_bar() -> void:
	_bar_count += 1
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 24)
	bar.max_value = 100.0
	bar.value = randf_range(20.0, 100.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	_bar_container.add_child(bar)

	var colors: Array[Color] = [
		Color(0.0, 0.8, 1.0),   # cyan
		Color(1.0, 0.3, 0.5),   # pink
		Color(0.5, 1.0, 0.3),   # green
		Color(1.0, 0.8, 0.2),   # gold
		Color(0.6, 0.3, 1.0),   # purple
	]
	var color: Color = colors[(_bar_count - 1) % colors.size()]
	ThemeManager.apply_led_bar(bar, color, bar.value / bar.max_value)


func _find_all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node as Button)
	for child in node.get_children():
		result.append_array(_find_all_buttons(child))
	return result


func _style_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.1, 0.8)
	sb.border_color = Color(0.2, 0.2, 0.3, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
