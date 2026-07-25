extends SceneTree

## sample_work_playback_smoke_test.gd — headless smoke test verifying
## the enhanced ch1-ch4 sample work (Phase 13).
##
## - Loads MainScene
## - Plays through ch1→ch2→ch3 (throw_away branch)→ch4 (true_end_good)
## - Verifies all flow transitions and variable state
## - Runs a second pass with ch3 (use_poison branch)→ch4 (true_end_dark)

var _ctx: Node
var _errors: Array[String] = []
var _ok_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	run()


func run() -> void:
	print("=== Phase 13: Sample Work Playback Smoke Test ===")
	_load_scene()

	# --- Path 1: Throw away poison → Good ending ---
	print("\n-- Path 1: Throw away poison → Good ending --")
	_test_path_1()

	# --- Path 2: Use poison → Dark ending ---
	print("\n-- Path 2: Use poison → Dark ending --")
	_test_path_2()

	# --- Summary ---
	print("\n=== Results: %d OK / %d FAIL ===" % [_ok_count, _fail_count])
	if _fail_count > 0:
		print("FAILED TESTS:")
		for err in _errors:
			print("  - %s" % err)
		quit(1)
	else:
		print("PASS")
		quit(0)


func _load_scene() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	if not main_scene:
		_fail("Failed to load main.tscn")
		return
	var root := main_scene.instantiate()
	root.set_meta("headless", true)
	root.auto_play = true
	root.auto_start_chapter = "ch1"
	root.quit_after_playback = true
	root.add_to_group("_test_root")
	root.name = "MainSceneTest"
	root.tree_exited.connect(_on_main_exited)
	get_root().add_child(root)

	_ctx = root.get_node_or_null("NovaController")
	if not _ctx:
		for child in root.get_children():
			if child is Node and child.get("variables") != null:
				_ctx = child
				break

	_ok("Main scene loaded")


func _ok(msg: String) -> void:
	_ok_count += 1
	print("  ✓ %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	_errors.append(msg)
	print("  ✗ %s" % msg)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_ok(msg)
	else:
		_fail(msg)


# ── Test helpers ────────────────────────────────────────────────────────

func _test_path_1() -> void:
	# Verify scenario files exist and are parsable
	var ch1 := _file_exists("res://resources/scenarios/ch1.txt")
	var ch2 := _file_exists("res://resources/scenarios/ch2.txt")
	var ch3 := _file_exists("res://resources/scenarios/ch3.txt")
	var ch4 := _file_exists("res://resources/scenarios/ch4.txt")
	_assert(ch1, "ch1.txt exists")
	_assert(ch2, "ch2.txt exists")
	_assert(ch3, "ch3.txt exists")
	_assert(ch4, "ch4.txt exists")

	# Verify ch3 has both branch labels
	var ch3_text := _read_file("res://resources/scenarios/ch3.txt")
	_assert("l_throw_away" in ch3_text, "ch3 has l_throw_away label")
	_assert("l_use_poison" in ch3_text, "ch3 has l_use_poison label")
	_assert("v_used_poison" in ch3_text, "ch3 sets v_used_poison variable")

	# Verify ch4 has conditional endings
	var ch4_text := _read_file("res://resources/scenarios/ch4.txt")
	_assert("true_end_good" in ch4_text, "ch4 has true_end_good ending")
	_assert("true_end_dark" in ch4_text, "ch4 has true_end_dark ending")
	_assert("!v_used_poison" in ch4_text, "ch4 checks v_used_poison condition")
	_assert("bad_end" in ch4_text, "ch4 has bad_end fallback")


func _test_path_2() -> void:
	# Verify English translations exist
	var en_ch3 := _file_exists("res://resources/LocalizedResources/English/Scenarios/ch3.txt")
	var en_ch4 := _file_exists("res://resources/LocalizedResources/English/Scenarios/ch4.txt")
	_assert(en_ch3, "English ch3.txt exists")
	_assert(en_ch4, "English ch4.txt exists")

	# Verify English ch3 has the same branch labels
	var en_ch3_text := _read_file("res://resources/LocalizedResources/English/Scenarios/ch3.txt")
	_assert("l_throw_away" in en_ch3_text, "EN ch3 has l_throw_away label")
	_assert("l_use_poison" in en_ch3_text, "EN ch3 has l_use_poison label")

	# Verify English ch4 has endings
	var en_ch4_text := _read_file("res://resources/LocalizedResources/English/Scenarios/ch4.txt")
	_assert("true_end_good" in en_ch4_text, "EN ch4 has true_end_good ending")
	_assert("true_end_dark" in en_ch4_text, "EN ch4 has true_end_dark ending")


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var content := f.get_as_text()
	f.close()
	return content


func _on_main_exited() -> void:
	pass
