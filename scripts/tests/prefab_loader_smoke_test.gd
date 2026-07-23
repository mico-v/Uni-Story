extends SceneTree

## Headless smoke test for PrefabLoader category-based lifecycle.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/prefab_loader_smoke_test.gd

const MAIN_SCENE := "res://scene/game.tscn"
const TEST_PREFAB := "prefabs/test_particles"

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
	var pl: Variant = scene.get("prefab_loader")
	if pl != null:
		pl.destroy_all(true)
	await process_frame

	root.remove_child(scene)
	scene.free()
	await process_frame
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

	var world_node: Node = pl.load_prefab("test_world_ci", TEST_PREFAB, null, null, PrefabLoader.PrefabCategory.WORLD)
	var ui_node: Node = pl.load_prefab("test_ui_ci", TEST_PREFAB, null, null, PrefabLoader.PrefabCategory.UI)
	var persistent_node: Node = pl.load_prefab("test_persistent_ci", TEST_PREFAB, null, null, PrefabLoader.PrefabCategory.PERSISTENT)
	_expect(world_node != null, "WORLD prefab should load")
	_expect(ui_node != null, "UI prefab should load")
	_expect(persistent_node != null, "PERSISTENT prefab should load")
	_expect(pl.get_prefab_category("test_world_ci") == PrefabLoader.PrefabCategory.WORLD, "WORLD category should be retained")
	_expect(pl.get_prefab_category("test_ui_ci") == PrefabLoader.PrefabCategory.UI, "UI category should be retained")
	_expect(pl.get_prefab_category("test_persistent_ci") == PrefabLoader.PrefabCategory.PERSISTENT, "PERSISTENT category should be retained")


# ── destroy_all preserves persistent ─────────────────────────────────

func _test_destroy_all_preserves_persistent(scene: Node) -> void:
	var pl: Variant = scene.get("prefab_loader")
	if pl == null:
		return

	# Verify destroy_by_category exists.
	_expect(pl.has_method("destroy_by_category"), "prefab_loader should have destroy_by_category")
	_expect(pl.has_method("destroy_all"), "prefab_loader should have destroy_all")
	_expect(pl.has_method("get_prefabs_by_category"), "prefab_loader should have get_prefabs_by_category")
	_expect(pl.has_method("get_prefab_category"), "prefab_loader should have get_prefab_category")

	pl.destroy_all()
	_expect(not pl.has_prefab("test_world_ci"), "destroy_all should remove WORLD prefabs")
	_expect(not pl.has_prefab("test_ui_ci"), "destroy_all should remove UI prefabs")
	_expect(pl.has_prefab("test_persistent_ci"), "destroy_all should preserve PERSISTENT prefabs")


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
	var loaded: Dictionary = snap.get("loaded", {})
	_expect(loaded.has("test_persistent_ci"), "snapshot should include the persistent prefab")
	if loaded.has("test_persistent_ci"):
		var entry: Dictionary = loaded["test_persistent_ci"]
		_expect(int(entry.get("category", -1)) == PrefabLoader.PrefabCategory.PERSISTENT, "snapshot should retain prefab category")

	pl.show_prefab("test_persistent_ci")
	var persistent: Node = pl.get_prefab("test_persistent_ci")
	if persistent is CanvasItem:
		(persistent as CanvasItem).visible = false
		snap = pl.snapshot()
		(persistent as CanvasItem).visible = true
		pl.restore(snap)
		_expect(not (persistent as CanvasItem).visible, "restore should reapply saved visibility")
	else:
		pl.restore(snap)
		_expect(persistent != null, "persistent prefab should remain available after restore")


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
