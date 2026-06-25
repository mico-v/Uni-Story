extends SceneTree

const SCENE_PATH := "res://scene/game.tscn"

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
	_expect(nova != null and nova.script_loader.load_ok, "NovaController should load scenarios")
	if nova == null or not nova.script_loader.load_ok:
		_finish_scene(scene)
		return

	nova.runtime.clear_errors()
	nova.game_state.start_node(&"ch4")
	await _wait_until(func() -> bool: return nova.game_state.is_waiting_input or nova.game_state.is_ended)
	_expect(not nova.runtime.had_error, "starting ch4 should not produce runtime errors")
	var first_index := nova.game_state.current_index
	await create_timer(3.0).timeout
	_expect(nova.game_state.current_index == first_index, "chapter entry should not auto-advance")

	for _i in range(42):
		if nova.game_state.is_waiting_input:
			nova.runtime.clear_errors()
			await nova.game_state.continue_after_input()
			await _wait_until(func() -> bool: return nova.game_state.is_waiting_input or nova.game_state.is_waiting_branch or nova.game_state.is_ended)
			_expect(not nova.runtime.had_error, "ch4 visual compat advance should not produce runtime errors")
		elif nova.game_state.is_waiting_branch or nova.game_state.is_ended:
			break
		else:
			await process_frame

	_expect(nova.object_manager.objects.has("cg"), "cg display target should be registered")
	_expect(nova.object_manager.objects.has("ergong"), "Nova standing character should be registered")
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
		if nova.game_state:
			nova.game_state.is_ended = true
	root.remove_child(scene)
	scene.free()
	await process_frame
	await process_frame
	_finish()


func _wait_until(predicate: Callable, max_frames: int = 120) -> void:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return
		await process_frame
	_failures.append("timed out waiting for playback condition")


func _finish() -> void:
	if _failures.is_empty():
		print("NovaVisualCompatSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("NovaVisualCompatSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
