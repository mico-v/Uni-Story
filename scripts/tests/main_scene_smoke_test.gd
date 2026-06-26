extends SceneTree

## Headless main scene lifecycle smoke test.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/main_scene_smoke_test.gd


const SCENE_PATH := "res://scene/game.tscn"
const HINTS_PATH := "user://tests/main_scene_hints.cfg"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(SCENE_PATH)
	_expect(packed is PackedScene, "main scene should load as PackedScene")
	if not packed is PackedScene:
		_finish()
		return

	_prepare_files()
	var scene := (packed as PackedScene).instantiate()
	if scene is NovaController:
		(scene as NovaController).hints_path = HINTS_PATH
	root.add_child(scene)
	await process_frame
	await create_timer(0.7).timeout

	_expect(scene is NovaController, "main scene root should use NovaController")
	if scene is NovaController:
		var nova := scene as NovaController
		_expect(nova.script_loader != null and nova.script_loader.load_ok, "NovaController should load scenario graph")
		_expect(nova.script_loader.graph.nodes.size() >= 1, "scenario graph should contain nodes")
		_expect(nova.game_state != null and nova.game_state.current_node == null, "GameState should be initialized but not playing at title")
		_expect(nova.view_manager != null and nova.view_manager.current() == "help", "ViewManager should show first-run help from title")
		_expect(nova.view_manager != null and nova.view_manager.has_method("state"), "ViewManager should expose Phase 5 state")
		_expect(nova.view_manager != null and not nova.view_manager.is_input_blocked(), "ViewManager should unblock input after initial transition")
		var chapter_view := nova.get_node_or_null("ChapterSelectView")
		var help_view := nova.get_node_or_null("HelpView")
		_expect(chapter_view is Control and chapter_view.has_signal("chapter_selected"), "ChapterSelectView should be present")
		_expect(help_view is Control and help_view.has_signal("back_requested"), "HelpView should be present")
		_expect(nova.view_manager != null and nova.view_manager.has_view("chapter_select"), "ViewManager should register chapter select view")
		_expect(nova.view_manager != null and nova.view_manager.has_view("help"), "ViewManager should register help view")
		_expect(nova.settings_coordinator != null, "SettingsCoordinator should be initialized")
		_expect(nova.save_system != null and nova.save_system.slot_count == nova.save_slot_count, "SaveSystem should receive exported slot count")
		_expect(nova.preload_system != null and nova.preload_system.max_cache_size == nova.preload_cache_size, "PreloadSystem should receive exported cache size")
		_expect(nova.gallery_coordinator != null, "GalleryCoordinator should be initialized")
		var game_view := nova.get_node_or_null("GameView") as Control
		_expect(game_view != null, "GameView should be present")
		if game_view:
			var dialogue_layer := game_view.get_node_or_null("Hud/DialogueLayer") as Control
			var control_layer := game_view.get_node_or_null("Hud/ControlLayer") as Control
			var modal_layer := game_view.get_node_or_null("Hud/ModalLayer") as Control
			_expect(dialogue_layer != null, "GameView should expose DialogueLayer")
			_expect(control_layer != null, "GameView should expose ControlLayer")
			_expect(modal_layer != null, "GameView should expose ModalLayer")
			var controls := game_view.get_node_or_null("Hud/ControlLayer/Controls") as Control
			var dbox := game_view.get_node_or_null("Hud/DialogueLayer/DialogueBox") as Control
			_expect(controls != null, "GameView controls should be present")
			if controls:
				_expect(controls.anchor_left == 1.0 and controls.anchor_top == 1.0 and controls.anchor_right == 1.0 and controls.anchor_bottom == 1.0, "GameView controls should anchor to the bottom-right")
				_expect(controls.offset_left < controls.offset_right and controls.offset_right <= 0.0, "GameView controls should stay inside the right edge")
				_expect(controls.offset_top < controls.offset_bottom and controls.offset_bottom <= 0.0, "GameView controls should stay inside the bottom edge")
				var button_order: Array[String] = []
				for child in controls.get_children():
					if child is Button:
						button_order.append(str(child.name))
				_expect(button_order == ["Skip", "Auto", "Backlog", "Save", "Load", "Restart", "Quit"], "GameView controls should follow Skip/Auto/.../Quit order")
			_expect(dbox != null and not dbox.visible, "DialogueBox should be hidden before gameplay")
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


func _prepare_files() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(HINTS_PATH):
		DirAccess.remove_absolute(HINTS_PATH)


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
