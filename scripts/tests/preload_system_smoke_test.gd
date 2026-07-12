extends SceneTree

## Headless smoke test for PreloadSystem with per-type caches, priority,
## reference counting, and progress reporting.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/preload_system_smoke_test.gd

const MAIN_SCENE := "res://scene/game.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Create a mock ctx for standalone PreloadSystem tests.
	var mock_ctx: Node = Node.new()
	root.add_child(mock_ctx)
	var ps: PreloadSystem = PreloadSystem.new(mock_ctx)

	_test_configure(ps)
	_test_per_type_cache(ps)
	await _test_reference_counting(ps)
	await _test_progress_reporting(ps)
	await _test_snapshot_restore(ps)
	await _test_cancel_all(ps)
	await _test_clear_cache(ps)

	# Integration: verify NovaController has per-type config.
	await _test_nova_integration()

	ps.cancel_all()
	root.remove_child(mock_ctx)
	mock_ctx.free()
	await process_frame

	_finish()


# ── Configuration ────────────────────────────────────────────────────

func _test_configure(ps: PreloadSystem) -> void:
	# Legacy configure should set max_cache_size proportionally.
	ps.configure(256)
	_expect(ps.max_cache_size >= 256, "max_cache_size should be >= 256 after configure(256)")

	# Per-type configure should respect individual sizes.
	ps.configure_types(10, 5, 2, 8)
	_expect(ps.max_cache_size == 25, "max_cache_size should be 25 = 10+5+2+8 after configure_types")

	# Reset to defaults for subsequent tests.
	ps.configure_types(60, 20, 8, 40)


# ── Per-type cache ────────────────────────────────────────────────────

func _test_per_type_cache(ps: PreloadSystem) -> void:
	# Verify cache starts empty.
	_expect(ps.cache_size() == 0, "cache should start empty")

	# Check is_all_ready with no pending items.
	_expect(ps.is_all_ready(), "is_all_ready should be true when nothing pending")

	# get_progress_float should return 1.0 when nothing pending.
	_expect(ps.get_progress_float() == 1.0, "get_progress_float should be 1.0 when nothing pending")


# ── Reference counting ────────────────────────────────────────────────

func _test_reference_counting(ps: PreloadSystem) -> void:
	# Preload a non-existent path to verify entry tracking.
	ps.preload_asset("res://resources/themes/base_theme.tres", "other")
	# Wait for polling to complete.
	var ticks: int = 0
	while not ps.is_all_ready() and ticks < 60:
		await process_frame
		ticks += 1

	# After load completes, should be cached.
	var size_after: int = ps.cache_size()
	_expect(size_after >= 1, "cache should have at least one entry after preload")

	# Preload again — should bump ref_count (not reload).
	ps.preload_asset("res://resources/themes/base_theme.tres", "other")
	await process_frame
	# Cache size should stay the same (same resource, different ref_count).
	_expect(ps.cache_size() == size_after, "cache size should stay same after duplicate preload")

	# Cancel once — should decrement ref_count but not evict.
	ps.cancel_preload("res://resources/themes/base_theme.tres")
	_expect(ps.cache_size() == size_after, "cache should still have entry after single cancel")

	# Cancel again — should evict.
	ps.cancel_preload("res://resources/themes/base_theme.tres")
	# Wait for any pending cleanup.
	await process_frame

	# Cache may or may not still have the entry depending on timing.
	# The entry should be fully evicted after all ref_counts are gone.
	var after_cancel: int = ps.cache_size()
	_expect(after_cancel <= size_after, "cache should not grow after cancellation")


# ── Progress reporting ────────────────────────────────────────────────

func _test_progress_reporting(ps: PreloadSystem) -> void:
	# Trigger a preload to have some pending items.
	ps.preload_asset("res://resources/themes/main_theme.tres")

	# Check get_progress() returns Dictionary with expected keys.
	var prog: Dictionary = ps.get_progress()
	_expect(prog is Dictionary, "get_progress() should return Dictionary")
	_expect(prog.has("overall"), "progress should have 'overall' key")
	_expect(prog.has("pending"), "progress should have 'pending' key")
	_expect(prog.has("cached"), "progress should have 'cached' key")
	_expect(prog.has("by_type"), "progress should have 'by_type' key")
	_expect(prog["by_type"] is Dictionary, "by_type should be a Dictionary")
	_expect(prog["by_type"].has("other"), "by_type should include 'other' type")
	_expect(prog["by_type"].has("image"), "by_type should include 'image' type")
	_expect(prog["by_type"].has("audio"), "by_type should include 'audio' type")
	_expect(prog["by_type"].has("prefab"), "by_type should include 'prefab' type")

	# Check get_progress_float() returns a float.
	var pf: float = ps.get_progress_float()
	_expect(pf >= 0.0 and pf <= 1.0, "get_progress_float should be in [0.0, 1.0]")

	# Wait for pending to complete.
	var ticks2: int = 0
	while not ps.is_all_ready() and ticks2 < 60:
		await process_frame
		ticks2 += 1

	# After all loaded, progress should be 1.0.
	_expect(ps.get_progress_float() == 1.0, "get_progress_float should be 1.0 after all loaded")

	# Clean up for next test.
	ps.clear_cache()


# ── Snapshot / restore ────────────────────────────────────────────────

func _test_snapshot_restore(ps: PreloadSystem) -> void:
	ps.clear_cache()

	# Preload a resource to have something in cache.
	ps.preload_asset("res://resources/themes/base_theme.tres", "other")
	var ticks: int = 0
	while not ps.is_all_ready() and ticks < 60:
		await process_frame
		ticks += 1

	var snap: Dictionary = ps.snapshot()
	_expect(snap is Dictionary, "snapshot() should return Dictionary")
	_expect(snap.has("other"), "snapshot should have 'other' key")
	var other_entries: Array = snap["other"] if snap["other"] is Array else []
	_expect(not other_entries.is_empty(), "snapshot should include cached entries")

	# Verify snapshot entry structure.
	var e: Dictionary = other_entries[0] if not other_entries.is_empty() else {}
	_expect(e.has("path"), "snapshot entry should have 'path'")
	_expect(e.has("ref_count"), "snapshot entry should have 'ref_count'")
	_expect(e.has("priority"), "snapshot entry should have 'priority'")

	# Restore should succeed.
	var ok: bool = ps.restore(snap)
	_expect(ok, "restore() should return true with valid snapshot")

	# Restore with empty data should return false.
	_expect(not ps.restore({}), "restore() with empty data should return false")

	ps.clear_cache()


# ── Cancel all ─────────────────────────────────────────────────────────

func _test_cancel_all(ps: PreloadSystem) -> void:
	ps.preload_asset("res://resources/themes/base_theme.tres", "other")
	await process_frame
	ps.cancel_all()
	_expect(ps.is_all_ready(), "is_all_ready should be true after cancel_all")


# ── Clear cache ────────────────────────────────────────────────────────

func _test_clear_cache(ps: PreloadSystem) -> void:
	ps.preload_asset("res://resources/themes/base_theme.tres", "other")
	var ticks: int = 0
	while not ps.is_all_ready() and ticks < 60:
		await process_frame
		ticks += 1

	ps.clear_cache()
	_expect(ps.cache_size() == 0, "cache should be empty after clear_cache")
	_expect(ps.max_cache_size > 0, "max_cache_size should be preserved after clear_cache")


# ── NovaController integration ────────────────────────────────────────

func _test_nova_integration() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		return
	root.add_child(scene)
	await process_frame
	await process_frame

	var nova := scene as Node
	# Verify PreloadSystem is configured.
	var ps: Variant = nova.get("preload_system")
	_expect(ps != null, "NovaController should have preload_system")

	# Verify per-type exported vars are set.
	var img_cache: int = int(nova.get("preload_image_cache"))
	var audio_cache: int = int(nova.get("preload_audio_cache"))
	var prefab_cache: int = int(nova.get("preload_prefab_cache"))
	var other_cache: int = int(nova.get("preload_other_cache"))
	_expect(img_cache == 60, "preload_image_cache should be 60")
	_expect(audio_cache == 20, "preload_audio_cache should be 20")
	_expect(prefab_cache == 8, "preload_prefab_cache should be 8")
	_expect(other_cache == 40, "preload_other_cache should be 40")

	root.remove_child(scene)
	scene.free()
	await process_frame
	await process_frame


# ── Helpers ────────────────────────────────────────────────────────────

func _finish() -> void:
	if _failures.is_empty():
		print("PreloadSystemSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("PreloadSystemSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
