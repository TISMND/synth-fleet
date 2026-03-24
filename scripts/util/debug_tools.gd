class_name DebugTools
## Static debug utilities. Call from anywhere.

## Dump the Control node tree to console. Shows rect, visibility, and parent path.
## Usage: DebugTools.dump_ui_tree(get_tree().root)
## Or press F4 in-game (handled by screens that wire it up).
static func dump_ui_tree(root: Node, indent: int = 0) -> void:
	if not root:
		return
	var prefix: String = "  ".repeat(indent)
	if root is Control:
		var ctrl: Control = root as Control
		var rect: Rect2 = ctrl.get_global_rect()
		var vis: String = "VIS" if ctrl.visible else "HID"
		var min_sz: Vector2 = ctrl.get_combined_minimum_size()
		print("%s[%s] %s  rect=(%d,%d %dx%d)  min=(%dx%d)  %s" % [
			prefix,
			root.get_class(),
			root.name,
			int(rect.position.x), int(rect.position.y),
			int(rect.size.x), int(rect.size.y),
			int(min_sz.x), int(min_sz.y),
			vis,
		])
	else:
		print("%s[%s] %s" % [prefix, root.get_class(), root.name])
	for child in root.get_children():
		dump_ui_tree(child, indent + 1)
