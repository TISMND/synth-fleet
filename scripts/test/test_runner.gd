extends SceneTree
## Headless test runner — validates data integrity without launching the game.
## Run: godot --headless --script res://scripts/test/test_runner.gd
##
## Grows over time: add checks after each session.

var _pass_count: int = 0
var _fail_count: int = 0
var _warn_count: int = 0


func _init() -> void:
	print("\n========================================")
	print("  SYNTHERION TEST RUNNER")
	print("========================================\n")

	_test_json_integrity()
	_test_cross_references()
	_test_round_trips()
	_test_level_progression()
	_test_scene_loading()

	print("\n========================================")
	if _fail_count == 0:
		print("  ALL PASSED: %d checks, %d warnings" % [_pass_count, _warn_count])
	else:
		print("  FAILURES: %d failed, %d passed, %d warnings" % [_fail_count, _pass_count, _warn_count])
	print("========================================\n")
	quit()


# ── Helpers ─────────────────────────────────────────────────

func _pass(msg: String) -> void:
	_pass_count += 1
	print("  PASS  %s" % msg)

func _fail(msg: String) -> void:
	_fail_count += 1
	print("  FAIL  %s" % msg)

func _warn(msg: String) -> void:
	_warn_count += 1
	print("  WARN  %s" % msg)

func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return null
	return json.data

func _list_json_files(dir_path: String) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return results
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			results.append(fname)
		fname = dir.get_next()
	return results

func _get_ids_in_dir(dir_path: String) -> Array[String]:
	var ids: Array[String] = []
	for fname in _list_json_files(dir_path):
		ids.append(fname.get_basename())
	return ids


# ── Test: JSON file integrity ───────────────────────────────

func _test_json_integrity() -> void:
	print("── JSON Integrity ──")
	var dirs: Dictionary = {
		"weapons": "res://data/weapons/",
		"ships": "res://data/ships/",
		"beam_styles": "res://data/beam_styles/",
		"field_styles": "res://data/field_styles/",
		"field_emitters": "res://data/field_emitters/",
		"flight_paths": "res://data/flight_paths/",
		"formations": "res://data/formations/",
		"key_changes": "res://data/key_changes/",
		"levels": "res://data/levels/",
		"nebula_definitions": "res://data/nebula_definitions/",
		"orbital_generators": "res://data/orbital_generators/",
		"power_cores": "res://data/power_cores/",
		"projectile_styles": "res://data/projectile_styles/",
	}
	for category in dirs:
		var dir_path: String = dirs[category]
		var files: Array[String] = _list_json_files(dir_path)
		if files.is_empty():
			_warn("%s: no JSON files found in %s" % [category, dir_path])
			continue
		var all_ok := true
		for fname in files:
			var data: Variant = _load_json(dir_path + fname)
			if data == null:
				_fail("%s/%s: failed to parse JSON" % [category, fname])
				all_ok = false
			elif not data is Dictionary:
				_fail("%s/%s: root is not a Dictionary" % [category, fname])
				all_ok = false
		if all_ok:
			_pass("%s: %d files parsed OK" % [category, files.size()])

	# Root config files
	for config_file in ["res://data/loop_config.json", "res://data/sfx_config.json", "res://data/vfx_config.json"]:
		var data: Variant = _load_json(config_file)
		if data == null:
			_fail("%s: failed to parse" % config_file)
		else:
			_pass("%s: parsed OK" % config_file)
	print("")


# ── Test: Cross-references ──────────────────────────────────

func _test_cross_references() -> void:
	print("── Cross-References ──")

	var weapon_ids: Array[String] = _get_ids_in_dir("res://data/weapons/")
	var ship_ids: Array[String] = _get_ids_in_dir("res://data/ships/")
	var beam_ids: Array[String] = _get_ids_in_dir("res://data/beam_styles/")
	var proj_ids: Array[String] = _get_ids_in_dir("res://data/projectile_styles/")
	var path_ids: Array[String] = _get_ids_in_dir("res://data/flight_paths/")
	var formation_ids: Array[String] = _get_ids_in_dir("res://data/formations/")
	var nebula_ids: Array[String] = _get_ids_in_dir("res://data/nebula_definitions/")
	var field_style_ids: Array[String] = _get_ids_in_dir("res://data/field_styles/")
	var power_core_ids: Array[String] = _get_ids_in_dir("res://data/power_cores/")

	# Weapons → projectile_style_id, beam_style_id
	var weapon_ref_ok := true
	for wid in weapon_ids:
		var data: Variant = _load_json("res://data/weapons/%s.json" % wid)
		if not data is Dictionary:
			continue
		var d: Dictionary = data as Dictionary
		var psid: String = str(d.get("projectile_style_id", ""))
		if psid != "" and not proj_ids.has(psid):
			_fail("weapon '%s' references projectile_style '%s' — not found" % [wid, psid])
			weapon_ref_ok = false
		var bsid: String = str(d.get("beam_style_id", ""))
		if bsid != "" and not beam_ids.has(bsid):
			_fail("weapon '%s' references beam_style '%s' — not found" % [wid, bsid])
			weapon_ref_ok = false
	if weapon_ref_ok:
		_pass("weapons: all projectile_style_id / beam_style_id references valid")

	# Levels → ships, paths, formations, nebulas
	var level_ids: Array[String] = _get_ids_in_dir("res://data/levels/")
	var level_ref_ok := true
	for lid in level_ids:
		var data: Variant = _load_json("res://data/levels/%s.json" % lid)
		if not data is Dictionary:
			continue
		var d: Dictionary = data as Dictionary

		# Check encounters
		var encounters: Array = d.get("encounters", []) as Array
		for enc in encounters:
			var ed: Dictionary = enc as Dictionary
			var sid: String = str(ed.get("ship_id", ""))
			if sid != "" and not ship_ids.has(sid):
				_fail("level '%s' encounter references ship '%s' — not found" % [lid, sid])
				level_ref_ok = false
			var pid: String = str(ed.get("path_id", ""))
			if pid != "" and not path_ids.has(pid):
				_fail("level '%s' encounter references path '%s' — not found" % [lid, pid])
				level_ref_ok = false
			var fid: String = str(ed.get("formation_id", ""))
			if fid != "" and not formation_ids.has(fid):
				_fail("level '%s' encounter references formation '%s' — not found" % [lid, fid])
				level_ref_ok = false

		# Check nebula placements
		var nebulas: Array = d.get("nebula_placements", []) as Array
		for neb in nebulas:
			var nd: Dictionary = neb as Dictionary
			var nid: String = str(nd.get("nebula_id", ""))
			if nid != "" and not nebula_ids.has(nid):
				_fail("level '%s' references nebula '%s' — not found" % [lid, nid])
				level_ref_ok = false

	if level_ref_ok:
		_pass("levels: all ship/path/formation/nebula references valid")

	# Ships → weapon_id (enemy ships)
	var ship_ref_ok := true
	for sid in ship_ids:
		var data: Variant = _load_json("res://data/ships/%s.json" % sid)
		if not data is Dictionary:
			continue
		var d: Dictionary = data as Dictionary
		var wid: String = str(d.get("weapon_id", ""))
		if wid != "" and not weapon_ids.has(wid):
			_fail("ship '%s' references weapon '%s' — not found" % [sid, wid])
			ship_ref_ok = false
	if ship_ref_ok:
		_pass("ships: all weapon_id references valid")

	print("")


# ── Test: Round-trip (from_dict → to_dict) ──────────────────

func _test_round_trips() -> void:
	print("── Round-Trip Tests ──")

	# ProjectileStyle: archetype + archetype_params must survive
	var proj_ok := true
	for pid in _get_ids_in_dir("res://data/projectile_styles/"):
		var data: Variant = _load_json("res://data/projectile_styles/%s.json" % pid)
		if not data is Dictionary:
			continue
		var style: ProjectileStyle = ProjectileStyle.from_dict(data as Dictionary)
		var exported: Dictionary = style.to_dict()
		if not exported.has("archetype"):
			_fail("ProjectileStyle '%s': archetype missing after round-trip" % pid)
			proj_ok = false
		if not exported.has("archetype_params"):
			_fail("ProjectileStyle '%s': archetype_params missing after round-trip" % pid)
			proj_ok = false
		if exported.get("id", "") != pid:
			_fail("ProjectileStyle '%s': id mismatch after round-trip (got '%s')" % [pid, exported.get("id", "")])
			proj_ok = false
	if proj_ok:
		_pass("ProjectileStyle: archetype + archetype_params survive round-trip")

	# PowerCoreData: equip_slot must survive
	var core_ok := true
	for cid in _get_ids_in_dir("res://data/power_cores/"):
		var data: Variant = _load_json("res://data/power_cores/%s.json" % cid)
		if not data is Dictionary:
			continue
		var core: PowerCoreData = PowerCoreData.from_dict(data as Dictionary)
		var exported: Dictionary = core.to_dict()
		if not exported.has("equip_slot"):
			_fail("PowerCoreData '%s': equip_slot missing after round-trip" % cid)
			core_ok = false
	if core_ok:
		_pass("PowerCoreData: equip_slot survives round-trip")

	# WeaponData: key fields survive
	var weapon_ok := true
	for wid in _get_ids_in_dir("res://data/weapons/"):
		var data: Variant = _load_json("res://data/weapons/%s.json" % wid)
		if not data is Dictionary:
			continue
		var weapon: WeaponData = WeaponData.from_dict(data as Dictionary)
		var exported: Dictionary = weapon.to_dict()
		for key in ["id", "fire_triggers", "effect_profile", "projectile_style_id", "aim_mode", "mirror_mode"]:
			if not exported.has(key):
				_fail("WeaponData '%s': missing '%s' after round-trip" % [wid, key])
				weapon_ok = false
	if weapon_ok:
		_pass("WeaponData: key fields survive round-trip")

	# BeamStyle: effect_profile survives
	var beam_ok := true
	for bid in _get_ids_in_dir("res://data/beam_styles/"):
		var data: Variant = _load_json("res://data/beam_styles/%s.json" % bid)
		if not data is Dictionary:
			continue
		var style: BeamStyle = BeamStyle.from_dict(data as Dictionary)
		var exported: Dictionary = style.to_dict()
		if not exported.has("effect_profile"):
			_fail("BeamStyle '%s': effect_profile missing after round-trip" % bid)
			beam_ok = false
	if beam_ok:
		_pass("BeamStyle: effect_profile survives round-trip")

	print("")


# ── Test: Level progression logic ────────────────────────────

func _test_level_progression() -> void:
	print("── Level Progression ──")

	# GameState can't be instantiated headless (depends on autoloads).
	# Instead, verify the source file contains the expected methods and fields via text scan.
	var path: String = "res://scripts/autoload/game_state.gd"
	if not FileAccess.file_exists(path):
		_fail("game_state.gd not found")
		print("")
		return
	var source: String = FileAccess.open(path, FileAccess.READ).get_as_text()

	# Check completed_levels field
	if "var completed_levels" in source:
		_pass("GameState has completed_levels field")
	else:
		_fail("GameState missing completed_levels field")

	# Check methods exist
	for method in ["func complete_level(", "func get_level_grade(", "func is_level_completed(", "func _grade_rank("]:
		if method in source:
			_pass("GameState has %s)" % method.split("(")[0].strip_edges())
		else:
			_fail("GameState missing %s)" % method.split("(")[0].strip_edges())

	# Check completed_levels is saved and loaded
	if '"completed_levels": completed_levels' in source:
		_pass("completed_levels included in save_game()")
	else:
		_fail("completed_levels NOT included in save_game()")

	if 'completed_levels = data.get("completed_levels"' in source:
		_pass("completed_levels loaded in load_game()")
	else:
		_fail("completed_levels NOT loaded in load_game()")

	# Check grade upgrade logic (only upgrades, never downgrades)
	if "_grade_rank(grade) < _grade_rank(old_grade)" in source:
		_pass("complete_level only upgrades grades (lower rank = better)")
	else:
		_fail("complete_level may not properly prevent grade downgrade")

	print("")


# ── Test: Scene loading ─────────────────────────────────────

func _test_scene_loading() -> void:
	print("── Scene Loading ──")
	var scenes: Array[String] = [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/dev_studio_menu.tscn",
		"res://scenes/ui/component_editor.tscn",
		"res://scenes/ui/environments_screen.tscn",
		"res://scenes/ui/hangar_screen.tscn",
		"res://scenes/ui/mission_prep_menu.tscn",
		"res://scenes/ui/level_select_screen.tscn",
		"res://scenes/ui/level_editor.tscn",
		"res://scenes/ui/options_screen.tscn",
		"res://scenes/ui/play_menu.tscn",
		"res://scenes/ui/sfx_editor.tscn",
		"res://scenes/ui/vfx_editor.tscn",
		"res://scenes/ui/ship_select_screen.tscn",
		"res://scenes/ui/ships_screen.tscn",
		"res://scenes/ui/shop.tscn",
		"res://scenes/ui/style_editor.tscn",
		"res://scenes/ui/hardpoint_edit_screen.tscn",
		"res://scenes/ui/auditions_screen.tscn",
		"res://scenes/ui/encounters_screen.tscn",
		"res://scenes/game/game.tscn",
	]
	for scene_path in scenes:
		if not ResourceLoader.exists(scene_path):
			_fail("scene not found: %s" % scene_path)
			continue
		var packed: PackedScene = load(scene_path) as PackedScene
		if packed == null:
			_fail("scene failed to load: %s" % scene_path)
		else:
			_pass("scene loads: %s" % scene_path.get_file())
	print("")
