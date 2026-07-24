extends SceneTree

## Headless performance baseline test.
##
## Measures key engine operation latencies:
##   1. Scenario parse time (all 28 scripts)
##   2. Main scene load + subsystem init time
##   3. Save + checkpoint replay round-trip time
##   4. Jump-back (replay) time
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/performance_baseline_test.gd


const SCENE_PATH := "res://scene/game.tscn"
const HINTS_PATH := "user://tests/perf_hints.cfg"
const SAVE_DIR := "user://tests/perf_saves/"
const SAVE_SLOT := 1

# Acceptable upper bounds (seconds). These are generous baselines that will
# be tightened as the engine matures.
const MAX_PARSE_TIME := 5.0
const MAX_SCENE_LOAD_TIME := 2.0
const MAX_SAVE_TIME := 2.0
const MAX_RESTORE_TIME := 3.0
const MAX_REPLAY_TIME := 3.0


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_prepare_dirs()

	# ── 1. Scenario parse time ──────────────────────────────────────
	var parse_start := Time.get_ticks_msec()
	var graph: Variant = _parse_all_scenarios()
	var parse_ms := Time.get_ticks_msec() - parse_start
	var parse_sec: float = parse_ms / 1000.0
	_expect(graph != null, "scenario graph should be parsed")
	_expect(graph.nodes.size() >= 1, "scenario graph should contain nodes")
	_expect(parse_sec <= MAX_PARSE_TIME, "parse time %.2fs should be <= %.2fs" % [parse_sec, MAX_PARSE_TIME])
	print("  parse_all_scenarios: %.2fs (%d nodes)" % [parse_sec, graph.nodes.size()])

	# ── 2. Main scene load + subsystem init ─────────────────────────
	var scene_start := Time.get_ticks_msec()
	var nova: NovaController = await _load_main_scene()
	var scene_ms := Time.get_ticks_msec() - scene_start
	var scene_sec: float = scene_ms / 1000.0
	_expect(nova != null, "main scene should load")
	_expect(scene_sec <= MAX_SCENE_LOAD_TIME, "scene load time %.2fs should be <= %.2fs" % [scene_sec, MAX_SCENE_LOAD_TIME])
	print("  main_scene_load: %.2fs" % scene_sec)

	if nova == null:
		_finish()
		return

	# ── 3. Game start + first checkpoint + save ─────────────────────
	var save_start := Time.get_ticks_msec()
	var save_ok := await _start_and_save(nova)
	var save_ms := Time.get_ticks_msec() - save_start
	var save_sec: float = save_ms / 1000.0
	_expect(save_ok, "save should succeed")
	_expect(save_sec <= MAX_SAVE_TIME, "save time %.2fs should be <= %.2fs" % [save_sec, MAX_SAVE_TIME])
	print("  start_and_save: %.2fs" % save_sec)

	# ── 4. Restore from save ────────────────────────────────────────
	var restore_start := Time.get_ticks_msec()
	var restore_ok := await _restore_from_save(nova)
	var restore_ms := Time.get_ticks_msec() - restore_start
	var restore_sec: float = restore_ms / 1000.0
	_expect(restore_ok, "restore should succeed")
	_expect(restore_sec <= MAX_RESTORE_TIME, "restore time %.2fs should be <= %.2fs" % [restore_sec, MAX_RESTORE_TIME])
	print("  restore_from_save: %.2fs" % restore_sec)

	# ── 5. Jump-back replay ─────────────────────────────────────────
	var replay_start := Time.get_ticks_msec()
	var replay_ok := await _jump_back_replay(nova)
	var replay_ms := Time.get_ticks_msec() - replay_start
	var replay_sec: float = replay_ms / 1000.0
	_expect(replay_ok, "jump-back replay should succeed")
	_expect(replay_sec <= MAX_REPLAY_TIME, "replay time %.2fs should be <= %.2fs" % [replay_sec, MAX_REPLAY_TIME])
	print("  jump_back_replay: %.2fs" % replay_sec)

	# ── Cleanup ─────────────────────────────────────────────────────
	await _cleanup_scene(nova)

	# ── Summary ─────────────────────────────────────────────────────
	var total_sec: float = parse_sec + scene_sec + save_sec + restore_sec + replay_sec
	print("perf_baseline total: %.2fs" % total_sec)
	_finish()


# ── Helpers ────────────────────────────────────────────────────────────

func _parse_all_scenarios() -> Variant:
	var script_loader_script := load("res://scripts/core/script_loader.gd") as Script
	if script_loader_script == null or not script_loader_script.can_instantiate():
		return null
	var loader = script_loader_script.new()
	if loader.has_method("load_all"):
		loader.load_all("res://resources/scenarios/")
	return loader.get("graph")


func _load_main_scene() -> NovaController:
	var packed := load(SCENE_PATH)
	if not (packed is PackedScene):
		return null
	var scene := (packed as PackedScene).instantiate()
	if scene is NovaController:
		(scene as NovaController).hints_path = HINTS_PATH
	root.add_child(scene)
	await process_frame
	await create_timer(0.5).timeout
	if scene is NovaController:
		return scene
	return null


func _start_and_save(nova: NovaController) -> bool:
	if nova.script_loader == null or not nova.script_loader.load_ok:
		return false
	# Start chapter 1 from the first node
	var start_node := "ch1_start"
	if not nova.script_loader.graph.nodes.has(start_node):
		# Try to find the first node
		var first_key: String = ""
		for key in nova.script_loader.graph.nodes:
			if str(key).begins_with("ch1"):
				first_key = str(key)
				break
		if first_key.is_empty():
			return false
		start_node = first_key

	# Jump to start and run a few frames
	nova.jump_to_node(start_node)
	await process_frame
	await create_timer(0.3).timeout

	if nova.save_system == null:
		return false
	# Reconfigure save dir for test
	if nova.save_system.has_method("configure"):
		nova.save_system.configure(SAVE_DIR, 6, 99, false)
	return nova.save_system.save(SAVE_SLOT)


func _restore_from_save(nova: NovaController) -> bool:
	if nova.save_system == null:
		return false
	if not nova.save_system.has_save(SAVE_SLOT):
		return false
	var ok := nova.save_system.load_slot(SAVE_SLOT)
	await process_frame
	await create_timer(0.3).timeout
	return ok


func _jump_back_replay(nova: NovaController) -> bool:
	if nova.game_state == null or nova.game_state.current_node == null:
		return false
	var current := str(nova.game_state.current_node)
	if current.is_empty():
		return false
	# Re-jump to the same node to test replay
	nova.jump_to_node(current)
	await process_frame
	await create_timer(0.3).timeout
	return nova.game_state.current_node != null


func _cleanup_scene(nova: NovaController) -> void:
	if nova.hot_reload != null:
		nova.hot_reload.stop()
	root.remove_child(nova)
	nova.free()
	await process_frame
	await process_frame


func _prepare_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if FileAccess.file_exists(HINTS_PATH):
		DirAccess.remove_absolute(HINTS_PATH)


func _finish() -> void:
	if _failures.is_empty():
		print("PerformanceBaselineTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("PerformanceBaselineTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
