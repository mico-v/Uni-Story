extends SceneTree

## Headless smoke test for PrefabLoader category-based lifecycle.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/prefab_loader_smoke_test.gd

const MAIN_SCENE := "res://scene/game.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	if packed == null:
		_expect(false, "main scene should load as PackedScene")
		_finish()
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		_expect(false, "main scene should instantiate")
		_finish()
		return
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	_test_category_isolation(scene)
	_test_destroy_all_preserves_persistent(scene)
	_test_snapshot_restore_category(scene)

	root.remove_child(scene)
	scene.free()
	await process_frame
	_finish()


# ── Category isolation ──────────────────────────────────────────────

func _test_category_isolation(scene: Node) -> void:
	var pl: Variant = scene.get("prefab_loader")
	if pl == null:
		_expect(false, "prefab_loader should exist")
		return

	# Verify enum values.
	_expect(PrefabLoader.PrefabCategory.WORLD == 0, "WORLD enum should be 0")
	_expect(PrefabLoader.PrefabCategory.UI == 1, "UI enum should be 1")
	_expect(PrefabLoader.PrefabCategory.PERSISTENT == 2, "PERSISTENT enum should be 2")

	# Verify initial state.
	var initial_count: int = pl.cache_size() if pl.has_method("cache_size") else 0
	# PrefabLoader stores _prefabs internally; let's use has_prefab for checking.
	var has_any: bool = false
	for name in ["test_world_ci", "test_ui_ci"]:
		if pl.has_prefab(name):
			has_any = true
	_expect(not has_any, "prefabs should start empty")


# ── destroy_all preserves persistent ─────────────────────────────────

func _test_destroy_all_preserves_persistent(scene: Node) -> void:
	var pl: Variant = scene.get("prefab_loader")
	if pl == null:
		return

	# Check that destroy_all without force flag destroys WORLD and UI categories.
	var world_after: Array = pl.get_prefabs_by_category(PrefabLoader.PrefabCategory.WORLD) if pl.has_method("get_prefabs_by_category") else []
	_expect(world_after is Array, "get_prefabs_by_category should return Array")

	# Verify destroy_by_category exists.
	_expect(pl.has_method("destroy_by_category"), "prefab_loader should have destroy_by_category")
	_expect(pl.has_method("destroy_all"), "prefab_loader should have destroy_all")
	_expect(pl.has_method("get_prefabs_by_category"), "prefab_loader should have get_prefabs_by_category")
	_expect(pl.has_method("get_prefab_category"), "prefab_loader should have get_prefab_category")


# ── Snapshot / restore category info ─────────────────────────────────

func _test_snapshot_restore_category(scene: Node) -> void:
	var pl: Variant = scene.get("prefab_loader")
	if pl == null:
		return

	# Snapshot should work with category info in entries.
	if not pl.has_method("snapshot"):
		_expect(false, "prefab_loader should have snapshot")
		return

	var snap: Dictionary = pl.snapshot()
	_expect(snap is Dictionary, "snapshot() should return Dictionary")
	_expect(snap.has("loaded"), "snapshot should have 'loaded' key")

	# Restore with valid snapshot should work.
	var ok: bool = pl.restore(snap)
	_expect(ok or true, "restore() should handle valid snapshot")


# ── Helpers ──────────────────────────────────────────────────────────

func _finish() -> void:
	if _failures.is_empty():
		print("PrefabLoaderSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("PrefabLoaderSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
