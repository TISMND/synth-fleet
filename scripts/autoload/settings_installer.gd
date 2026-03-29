extends Node
## Installs default save data on first run or when a new build is detected.
## Visual settings (theme, colors, buttons) are baked into ThemeManager code defaults.
## This only handles save_data.json (ship loadout, credits, progress).
##
## Compares the executable's modification time against a stored timestamp.
## If the build is newer, save data is reset to bundled defaults.
## If same build, player progress is preserved.

const TIMESTAMP_PATH := "user://settings/.build_timestamp"
const DEFAULTS_DIR := "res://data/default_settings/"

const ROOT_FILES: Array[String] = [
	"save_data.json",
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://settings")

	var build_time: String = _get_build_timestamp()
	var stored_time: String = _get_stored_timestamp()

	if build_time == stored_time:
		return  # Same build, keep player progress

	# New build (or first run) — install default save data
	for filename in ROOT_FILES:
		var src: String = DEFAULTS_DIR + filename
		var dst: String = "user://" + filename
		_copy_resource_file(src, dst)

	# Save current build timestamp
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.WRITE)
	if file:
		file.store_string(build_time)


func _get_build_timestamp() -> String:
	if OS.has_feature("editor"):
		return ""  # Always overwrite in editor
	var exe_path: String = OS.get_executable_path()
	if exe_path != "" and FileAccess.file_exists(exe_path):
		var mod_time: int = FileAccess.get_modified_time(exe_path)
		return str(mod_time)
	return ""


func _get_stored_timestamp() -> String:
	if not FileAccess.file_exists(TIMESTAMP_PATH):
		return ""
	var file := FileAccess.open(TIMESTAMP_PATH, FileAccess.READ)
	if not file:
		return ""
	return file.get_as_text().strip_edges()


func _copy_resource_file(src: String, dst: String) -> void:
	if not ResourceLoader.exists(src) and not FileAccess.file_exists(src):
		push_warning("SettingsInstaller: bundled default not found: %s" % src)
		return
	var file := FileAccess.open(src, FileAccess.READ)
	if not file:
		push_warning("SettingsInstaller: cannot open bundled default: %s" % src)
		return
	var content: String = file.get_as_text()
	var out := FileAccess.open(dst, FileAccess.WRITE)
	if out:
		out.store_string(content)
