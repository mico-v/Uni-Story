extends SceneTree

## Headless SaveSystem smoke test for configurable slots and restorable snapshots.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/save_system_smoke_test.gd

const CheckpointManagerScript := preload("res://scripts/core/checkpoint_manager.gd")


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var variables: Variables
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
	var save_system: SaveSystem
	var restorables: RestorableRegistry
	var checkpoint_manager: RefCounted
	var read_tracker: NoopReadTracker

	func setup() -> void:
		object_manager = ObjectManager.new()
		variables = Variables.new()
		restorables = RestorableRegistry.new()
		checkpoint_manager = CheckpointManagerScript.new(self)
		runtime = GDRuntime.new(self)
		script_loader = ScriptLoader.new(self)
		game_state = GameState.new(self)
		save_system = SaveSystem.new(self)
		read_tracker = NoopReadTracker.new()


class NoopReadTracker:
	extends RefCounted

	func mark_read(_node_name: StringName, _index: int) -> void:
		pass

	func snapshot() -> Dictionary:
		return {}

	func restore(_data: Dictionary) -> void:
		pass


class DummyRestorable:
	extends RefCounted

	var value := "initial"

	func snapshot() -> Dictionary:
		return {"value": value}

	func restore(data: Dictionary) -> void:
		value = str(data.get("value", ""))


const SCENARIO_PATH := "user://tests/save_system_smoke.txt"
const SAVE_DIR := "user://tests/save_system_smoke_saves/"
const SCENARIO_SOURCE := """
@<|
label("save_start", "Save Start")
is_start()
|>
Tester：：保存前
Tester：：保存后
"""

var _failures: Array[String] = []
var _dialogues: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_prepare_files()

	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()
	ctx.save_system.configure(SAVE_DIR, 3, 42, false)
	ctx.restorables.register("game_state", ctx.game_state)
	var dummy := DummyRestorable.new()
	ctx.restorables.register("dummy", dummy)

	ctx.game_state.dialogue_changed.connect(func(speaker: String, text: String) -> void:
		_dialogues.append({"speaker": speaker, "text": text})
	)

	ctx.script_loader.load_all([SCENARIO_PATH])
	_expect(ctx.script_loader.load_ok, "script loader should accept save smoke scenario")
	ctx.game_state.setup(ctx.script_loader.graph)
	ctx.game_state.start_node(&"save_start")
	await _wait_until(func() -> bool: return ctx.game_state.is_waiting_input)
	_expect(ctx.game_state.current_index == 0, "save should start at first dialogue")
	_expect(ctx.checkpoint_manager.is_dialogue_reached(&"save_start", 0), "checkpoint manager should track reached dialogue")
	_expect(ctx.save_system.slot_count == 3, "configured slot count should be applied")
	_expect(not ctx.save_system.auto_save(), "disabled auto-save should not write")

	dummy.value = "saved"
	_expect(ctx.save_system.save(0), "manual save should succeed")
	_expect(ctx.save_system.has_save(0), "slot 0 should exist after save")
	_assert_bookmark_file()

	dummy.value = "changed"
	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 1 and ctx.game_state.is_waiting_input)
	_expect(ctx.game_state.current_index == 1, "story should advance before load")

	_expect(ctx.save_system.load_slot(0), "load slot 0 should succeed")
	await process_frame
	_expect(ctx.game_state.current_node != null and ctx.game_state.current_node.name == &"save_start", "load should restore node")
	_expect(ctx.game_state.current_index == 0, "load should restore dialogue index")
	_expect(dummy.value == "saved", "load should restore secondary restorable snapshot")

	if _failures.is_empty():
		print("SaveSystemSmokeTest: OK, slot_count=%d" % ctx.save_system.slot_count)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("SaveSystemSmokeTest: FAILED")
		quit(1)


func _prepare_files() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var scenario_file := FileAccess.open(SCENARIO_PATH, FileAccess.WRITE)
	if scenario_file:
		scenario_file.store_string(SCENARIO_SOURCE)
		scenario_file.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	var slot_path := SAVE_DIR.path_join("slot_0.json")
	if FileAccess.file_exists(slot_path):
		DirAccess.remove_absolute(slot_path)


func _assert_bookmark_file() -> void:
	var slot_path := SAVE_DIR.path_join("slot_0.json")
	var file := FileAccess.open(slot_path, FileAccess.READ)
	if file == null:
		_failures.append("failed to read saved slot")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	_expect(parsed is Dictionary, "saved slot should be JSON dictionary")
	if not (parsed is Dictionary):
		return
	_expect(int(parsed.get("version", 0)) == SaveSystem.SAVE_VERSION, "saved slot should use latest save version")
	_expect(str(parsed.get("format", "")) == "bookmark", "saved slot should use bookmark format")
	_expect(parsed.has("bookmark"), "saved slot should include bookmark metadata")
	_expect(parsed.has("checkpoint"), "saved slot should include checkpoint data")
	var checkpoint = parsed.get("checkpoint", {})
	if checkpoint is Dictionary:
		var reached = checkpoint.get("reached", {})
		if reached is Dictionary:
			var dialogues = reached.get("dialogues", {})
			_expect(dialogues is Dictionary and dialogues.has("save_start:0"), "checkpoint should persist reached dialogue data")


func _wait_until(predicate: Callable, max_frames: int = 30) -> void:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return
		await process_frame
	_failures.append("timed out waiting for condition")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
