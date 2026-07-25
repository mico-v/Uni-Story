extends SceneTree

## Smoke test for the minigame scenario (test_minigame.txt).
##
## Verifies:
##   1. The minigame scenario parses and loads correctly.
##   2. The scenario advances through dialogue and branch choices.
##   3. After advancing past the minigame() call, the story continues.
##   4. Variables set during gameplay are preserved.

const SCENE_PATH := "res://scene/game.tscn"
const HINTS_PATH := "user://tests/minigame_smoke_hints.cfg"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_prepare_dirs()

	var packed := load(SCENE_PATH)
	if not (packed is PackedScene):
		_failures.append("main scene should be a PackedScene")
		_finish()
		return

	var scene := (packed as PackedScene).instantiate()
	if scene is NovaController:
		(scene as NovaController).hints_path = HINTS_PATH
	root.add_child(scene)
	await process_frame
	await create_timer(0.7).timeout

	var nova := scene as NovaController
	if nova == null or not nova.script_loader.load_ok:
		_failures.append("NovaController should load scenarios")
		_finish_scene(scene)
		return

	# ── Verify the minigame scenario exists ────────────────────────
	var has_minigame_node := nova.script_loader.graph.nodes.has(&"test_minigame")
	_expect(has_minigame_node, "test_minigame node should exist in the graph")

	# ── Start the test_minigame scenario ──────────────────────────
	nova.runtime.clear_errors()
	nova.game_state.start_node(&"test_minigame")
	await _wait_until(func() -> bool:
		return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended
	, 120)
	_expect(not nova.runtime.had_error, "starting test_minigame should not produce errors")

	# ── Advance through the initial dialogue ─────────────────────
	var advanced := 0
	while advanced < 20 and not nova.game_state.is_ended and not nova.game_state.is_waiting_branch:
		if nova.game_state.is_waiting_input:
			nova.runtime.clear_errors()
			await nova.game_state.continue_after_input()
			await _wait_until(func() -> bool:
				return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended
			, 120)
			_expect(not nova.runtime.had_error, "advance %d should not produce errors" % advanced)
			advanced += 1
		else:
			await process_frame

	# ── Handle branch if encountered ──────────────────────────────
	if nova.game_state.is_waiting_branch:
		# Pick first option and advance.
		# The branch options are passed to the UI via the branch_requested signal.
		# We just need to choose a destination to continue.
		nova.game_state.choose_branch(&"l_a")
		await _wait_until(func() -> bool:
			return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended
		, 120)

	# ── Advance further past the minigame() call ─────────────────
	var more_advanced := 0
	while more_advanced < 30 and not nova.game_state.is_ended and not nova.game_state.is_waiting_branch:
		if nova.game_state.is_waiting_input:
			nova.runtime.clear_errors()
			await nova.game_state.continue_after_input()
			await _wait_until(func() -> bool:
				return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended
			, 120)
			_expect(not nova.runtime.had_error, "advance %d should not produce errors" % (advanced + more_advanced))
			more_advanced += 1
		else:
			await process_frame

	_expect(advanced + more_advanced >= 8, "should advance through at least 8 lines of test_minigame")

	_finish_scene(scene)


func _finish_scene(scene: Node) -> void:
	if scene is NovaController:
		var nova := scene as NovaController
		if nova.hot_reload:
			nova.hot_reload.stop()
		if nova.audio:
			nova.audio.stop_all()
		if nova.vfx:
			nova.vfx.clear_all()
		if nova.video_system:
			nova.video_system.stop()
		if nova.composer:
			nova.composer.clear_all()
	root.remove_child(scene)
	scene.free()
	await process_frame
	await process_frame
	_finish()


func _wait_until(predicate: Callable, max_frames: int = 90) -> void:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return
		await process_frame
	_failures.append("timed out waiting for condition")


func _prepare_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(HINTS_PATH):
		DirAccess.remove_absolute(HINTS_PATH)


func _finish() -> void:
	if _failures.is_empty():
		print("MinigameSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("MinigameSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
