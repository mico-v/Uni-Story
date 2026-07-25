extends SceneTree

## minigame_templates_smoke_test.gd — headless smoke test verifying
## the three minigame template scenes (Click, Drag, QTE) can be
## instantiated and have the correct structure (Phase 13.3).

var _ok_count: int = 0
var _fail_count: int = 0
var _errors: Array[String] = []


func _init() -> void:
	run()


func run() -> void:
	print("=== Phase 13: Minigame Templates Smoke Test ===")

	# 13.3a: ClickMinigame
	_test_click_minigame()

	# 13.3b: DragMinigame
	_test_drag_minigame()

	# 13.3c: QTEMinigame
	_test_qte_minigame()

	# 13.3d: All minigame scripts exist
	_test_scripts_exist()

	# Summary
	print("\n=== Results: %d OK / %d FAIL ===" % [_ok_count, _fail_count])
	if _fail_count > 0:
		print("FAILED TESTS:")
		for err in _errors:
			print("  - %s" % err)
		quit(1)
	else:
		print("PASS")
		quit(0)


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


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _test_click_minigame() -> void:
	print("\n-- 13.3a: ClickMinigame --")
	var scene_path := "res://resources/minigame/ClickMinigame.tscn"
	_assert(_file_exists(scene_path), "ClickMinigame.tscn exists")

	if _file_exists(scene_path):
		var scene: PackedScene = load(scene_path)
		_assert(scene != null, "ClickMinigame scene loads without error")

		if scene:
			var instance := scene.instantiate()
			_assert(instance != null, "ClickMinigame instantiates")
			_assert(instance.has_method("setup_prefab"), "has setup_prefab() method")
			_assert(instance.has_method("teardown_prefab"), "has teardown_prefab() method")
			_assert(instance.has_signal("finished"), "has 'finished' signal")
			instance.queue_free()

	# Script
	_assert(_file_exists("res://scripts/minigame/click_minigame.gd"), "click_minigame.gd exists")


func _test_drag_minigame() -> void:
	print("\n-- 13.3b: DragMinigame --")
	var scene_path := "res://resources/minigame/DragMinigame.tscn"
	_assert(_file_exists(scene_path), "DragMinigame.tscn exists")

	if _file_exists(scene_path):
		var scene: PackedScene = load(scene_path)
		_assert(scene != null, "DragMinigame scene loads without error")

		if scene:
			var instance := scene.instantiate()
			_assert(instance != null, "DragMinigame instantiates")
			_assert(instance.has_method("setup_prefab"), "has setup_prefab() method")
			_assert(instance.has_method("teardown_prefab"), "has teardown_prefab() method")
			_assert(instance.has_signal("finished"), "has 'finished' signal")
			instance.queue_free()

	_assert(_file_exists("res://scripts/minigame/drag_minigame.gd"), "drag_minigame.gd exists")


func _test_qte_minigame() -> void:
	print("\n-- 13.3c: QTEMinigame --")
	var scene_path := "res://resources/minigame/QTEMinigame.tscn"
	_assert(_file_exists(scene_path), "QTEMinigame.tscn exists")

	if _file_exists(scene_path):
		var scene: PackedScene = load(scene_path)
		_assert(scene != null, "QTEMinigame scene loads without error")

		if scene:
			var instance := scene.instantiate()
			_assert(instance != null, "QTEMinigame instantiates")
			_assert(instance.has_method("setup_prefab"), "has setup_prefab() method")
			_assert(instance.has_method("teardown_prefab"), "has teardown_prefab() method")
			_assert(instance.has_signal("finished"), "has 'finished' signal")
			instance.queue_free()

	_assert(_file_exists("res://scripts/minigame/qte_minigame.gd"), "qte_minigame.gd exists")


func _test_scripts_exist() -> void:
	print("\n-- 13.3d: All minigame scripts present --")
	var scripts := [
		"res://scripts/minigame/click_minigame.gd",
		"res://scripts/minigame/drag_minigame.gd",
		"res://scripts/minigame/qte_minigame.gd",
		"res://scripts/minigame/example_minigame.gd",
	]
	for s in scripts:
		_assert(_file_exists(s), "Script exists: %s" % s.get_file())
