extends SceneTree

## Starts the real main scene at Nova ch1 and advances several lines.

const SCENE_PATH := "res://scene/game.tscn"
const STEPS := 24

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH)
	_expect(packed is PackedScene, "main scene should load")
	if not packed is PackedScene:
		_finish()
		return

	var scene := (packed as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.7).timeout

	var nova := scene as NovaController
	_expect(nova != null and nova.script_loader.load_ok, "NovaController should load Nova scenarios")
	if nova == null or not nova.script_loader.load_ok:
		_finish_scene(scene)
		return

	nova.runtime.clear_errors()
	nova.game_state.start_node(&"ch1")
	await _wait_until(func() -> bool: return nova.game_state.is_waiting_input or nova.game_state.is_ended)
	_expect(not nova.runtime.had_error, "starting ch1 should not produce runtime compile errors")

	var advanced := 0
	while advanced < STEPS and not nova.game_state.is_ended:
		if nova.game_state.is_waiting_input:
			nova.runtime.clear_errors()
			await nova.game_state.continue_after_input()
			await _wait_until(func() -> bool: return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended)
			_expect(not nova.runtime.had_error, "ch1 advance %d should not produce runtime compile errors" % advanced)
			advanced += 1
		elif nova.game_state.is_waiting_branch:
			break
		else:
			await process_frame

	_expect(advanced >= 10, "ch1 playback should advance through several lines")
	_finish_scene(scene)


func _finish_scene(scene: Node) -> void:
	if scene is NovaController:
		var nova := scene as NovaController
		if nova.hot_reload:
			nova.hot_reload.stop()
		if nova.audio:
			nova.audio.stop_all()
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
	_failures.append("timed out waiting for playback condition")


func _finish() -> void:
	if _failures.is_empty():
		print("NovaCh1PlaybackSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("NovaCh1PlaybackSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
