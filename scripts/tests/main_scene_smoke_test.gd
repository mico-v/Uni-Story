extends SceneTree

## Headless main scene lifecycle smoke test.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/main_scene_smoke_test.gd


const SCENE_PATH := "res://scene/game.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH)
	_expect(packed is PackedScene, "main scene should load as PackedScene")
	if not packed is PackedScene:
		_finish()
		return

	var scene := (packed as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.7).timeout

	_expect(scene is NovaController, "main scene root should use NovaController")
	if scene is NovaController:
		var nova := scene as NovaController
		_expect(nova.script_loader != null and nova.script_loader.load_ok, "NovaController should load scenario graph")
		_expect(nova.script_loader.graph.nodes.size() >= 1, "scenario graph should contain nodes")
		_expect(nova.game_state != null and nova.game_state.current_node == null, "GameState should be initialized but not playing at title")
		_expect(nova.view_manager != null and nova.view_manager.current() == "title", "ViewManager should enter title view")
		_expect(nova.gallery_coordinator != null, "GalleryCoordinator should be initialized")
		if nova.gallery_coordinator:
			var cg_entries: Array = nova.gallery_coordinator.call("cg_entries")
			var music_entries: Array = nova.gallery_coordinator.call("music_entries")
			_expect(cg_entries.size() >= 1, "GalleryCoordinator should load CG entries")
			_expect(music_entries.size() >= 1, "GalleryCoordinator should load music entries")
		if nova.hot_reload:
			nova.hot_reload.stop()

	root.remove_child(scene)
	scene.free()
	await process_frame
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("MainSceneSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("MainSceneSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
