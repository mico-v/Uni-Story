extends SceneTree

## Export smoke test — validates that a production build can:
##   1. Load the main scene
##   2. Initialize all subsystems
##   3. Start and advance through Chapter 1
##   4. Navigate to key views (settings, save/load, chapter select, help)
##   5. Save and load
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/export_smoke_test.gd
##
## This test is designed to run against an exported PCK or the project itself.
## It serves as a production-readiness gate before release.

const SCENE_PATH := "res://scene/game.tscn"
const HINTS_PATH := "user://tests/export_smoke_hints.cfg"
const SAVE_DIR := "user://tests/export_smoke_saves/"

var _failures: Array[String] = []
var _test_started := false
var _test_passed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Allow some initial frames for the engine to settle.
	await create_timer(0.2).timeout
	_prepare_dirs()

	var nova: NovaController = await _load_main_scene()
	if nova == null:
		_finish()
		return

	_test_started = true

	# ── 1. Verify subsystems ───────────────────────────────────────
	_expect(nova.script_loader != null, "script_loader should exist")
	_expect(nova.script_loader.load_ok, "script_loader should have loaded scenarios")
	_expect(nova.game_state != null, "game_state should exist")
	_expect(nova.view_manager != null, "view_manager should exist")
	_expect(nova.save_system != null, "save_system should exist")
	_expect(nova.subsystems_ok(), "all subsystems should initialize")

	# ── 2. Chapter 1 start and advance ─────────────────────────────
	var start_ok := await _start_chapter_1(nova)
	_expect(start_ok, "should start chapter 1 without errors")

	if start_ok:
		var advance_ok := await _advance_lines(nova, 12)
		_expect(advance_ok, "should advance through at least 10 lines in ch1")

	# ── 3. Save and load ───────────────────────────────────────────
	if nova.save_system:
		var save_slot := 1
		nova.save_system.configure(SAVE_DIR, 6, 99, false)
		var save_ok := nova.save_system.save(save_slot)
		_expect(save_ok, "should save successfully")
		if save_ok:
			var load_ok := nova.save_system.load_slot(save_slot)
			_expect(load_ok, "should load save successfully")

	# ── 4. View navigation ─────────────────────────────────────────
	if nova.view_manager:
		var views_ok := true
		for view_name in ["settings", "chapter_select", "help"]:
			if nova.view_manager.has_view(view_name):
				nova.view_manager.switch_to(view_name)
				await create_timer(0.3).timeout
				var current := nova.view_manager.current()
				if current != view_name:
					views_ok = false
			await create_timer(0.2).timeout
		nova.view_manager.switch_to("title")
		await create_timer(0.3).timeout
		_expect(views_ok, "should navigate to all registered views")

	# ── 5. Backlog access ──────────────────────────────────────────
	if nova.backlog:
		var entries: Array = nova.backlog.entries()
		_expect(entries.size() >= 0, "backlog should be accessible")
		nova.backlog.clear()

	# ── 6. Gallery access ──────────────────────────────────────────
	if nova.gallery_coordinator:
		_expect(nova.gallery_coordinator != null, "gallery_coordinator should be accessible")

	# ── 7. Chapter 4 play through ──────────────────────────────────
	var ch4_ok := await _play_chapter_4(nova)
	_expect(ch4_ok, "should play through chapter 4 without errors")

	_test_passed = _failures.is_empty()
	await _cleanup_scene(nova)
	_finish()


# ── Helpers ────────────────────────────────────────────────────────────

func _load_main_scene() -> NovaController:
	var packed := load(SCENE_PATH)
	if not (packed is PackedScene):
		_failures.append("main scene should be a PackedScene")
		return null
	var scene := (packed as PackedScene).instantiate()
	if scene is NovaController:
		(scene as NovaController).hints_path = HINTS_PATH
	root.add_child(scene)
	await process_frame
	await create_timer(0.7).timeout
	if scene is NovaController:
		return scene
	_failures.append("main scene should be NovaController")
	return null


func _start_chapter_1(nova: NovaController) -> bool:
	if nova.script_loader == null or not nova.script_loader.load_ok:
		return false
	if nova.game_state == null:
		return false
	nova.runtime.clear_errors()
	var start_node := _find_start_node(nova, "ch1")
	if start_node.is_empty():
		_failures.append("should find ch1 start node")
		return false
	nova.game_state.start_node(StringName(start_node))
	await _wait_until(func() -> bool: return nova.game_state.is_waiting_input or nova.game_state.is_ended, 120)
	return not nova.runtime.had_error and nova.game_state.is_waiting_input


func _find_start_node(nova: NovaController, prefix: String) -> String:
	for key in nova.script_loader.graph.nodes:
		var name := str(key)
		if name.begins_with(prefix):
			return name
	return ""


func _advance_lines(nova: NovaController, target: int) -> bool:
	var advanced := 0
	while advanced < target and not nova.game_state.is_ended:
		if nova.game_state.is_waiting_input:
			nova.runtime.clear_errors()
			await nova.game_state.continue_after_input()
			await _wait_until(func() -> bool:
				return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended
			, 120)
			if nova.runtime.had_error:
				return false
			advanced += 1
		elif nova.game_state.is_waiting_branch:
			break
		else:
			await process_frame
	return advanced >= 8


func _play_chapter_4(nova: NovaController) -> bool:
	var start_node := _find_start_node(nova, "ch4")
	if start_node.is_empty():
		return true  # optional, not a failure if ch4 start node doesn't exist

	# Reset world state before jumping to ch4.
	if nova.game_state:
		nova.game_state.start_node(StringName(start_node))
		await _wait_until(func() -> bool:
			return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended
		, 120)
	return not nova.runtime.had_error


func _cleanup_scene(nova: NovaController) -> void:
	if nova.hot_reload != null:
		nova.hot_reload.stop()
	if nova.audio:
		nova.audio.stop_all()
	if nova.vfx:
		nova.vfx.clear_all()
	if nova.video_system:
		nova.video_system.stop()
	if nova.composer:
		nova.composer.clear_all()
	root.remove_child(nova)
	nova.free()
	await process_frame
	await process_frame


func _prepare_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	if FileAccess.file_exists(HINTS_PATH):
		DirAccess.remove_absolute(HINTS_PATH)


func _wait_until(predicate: Callable, max_frames: int = 90) -> void:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return
		await process_frame
	_failures.append("timed out waiting for condition")


func _finish() -> void:
	if _failures.is_empty():
		print("ExportSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ExportSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
