extends SceneTree

## Headless CheckpointManager smoke test for nearest-checkpoint replay.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/checkpoint_manager_smoke_test.gd

const CheckpointManagerScript = preload("res://scripts/core/checkpoint_manager.gd")


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var variables: Variables
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
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
		read_tracker = NoopReadTracker.new()
		restorables.register("game_state", game_state)


class NoopReadTracker:
	extends RefCounted

	func mark_read(_node_name: StringName, _index: int) -> void:
		pass

	func snapshot() -> Dictionary:
		return {}

	func restore(_data: Dictionary) -> void:
		pass


const SCENARIO_PATH = "user://tests/checkpoint_manager_smoke.txt"
const SCENARIO_SOURCE = """
@<|
label("checkpoint_start", "Checkpoint Start")
is_start()
|>
<|
set_var("checkpoint_phase", "zero")
|>
Tester：：Zero

<|
set_var("checkpoint_phase", "one")
|>
Tester：：One

<|
set_var("checkpoint_phase", "two_lazy")
set_var("target_lazy_count", int(get_var("target_lazy_count", 0)) + 1)
|>
[stage = after_dialogue]<|
set_var("target_after_marker", "two_after")
|>
Tester：：Two
"""

var _failures: Array[String] = []
var _dialogues: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_write_scenario()

	var ctx: TestContext = TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	ctx.game_state.dialogue_changed.connect(func(speaker: String, text: String) -> void:
		_dialogues.append({"speaker": speaker, "text": text})
	)

	ctx.script_loader.load_all([SCENARIO_PATH])
	_expect(ctx.script_loader.load_ok, "script loader should accept checkpoint smoke scenario")
	_expect(ctx.script_loader.graph.sanity_check().is_empty(), "flow graph should pass sanity check")

	ctx.game_state.setup(ctx.script_loader.graph)
	ctx.game_state.start_node(&"checkpoint_start")
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 0 and ctx.game_state.is_waiting_input)
	_expect(ctx.variables.get_var("checkpoint_phase", "") == "zero", "entry 0 lazy should run")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 1 and ctx.game_state.is_waiting_input)
	_expect(ctx.variables.get_var("checkpoint_phase", "") == "one", "entry 1 lazy should run")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 2 and ctx.game_state.is_waiting_input)
	_expect(ctx.variables.get_var("checkpoint_phase", "") == "two_lazy", "entry 2 lazy should run during normal play")
	_expect(ctx.variables.get_var("target_after_marker", "") == "two_after", "entry 2 after_dialogue should run during normal play")
	_expect(ctx.variables.get_var("target_lazy_count", 0) == 1, "entry 2 lazy should run once during normal play")

	var manager_state: Dictionary = ctx.checkpoint_manager.snapshot()
	var position_checkpoints = manager_state.get("position_checkpoints", {})
	if position_checkpoints is Dictionary:
		position_checkpoints.erase("checkpoint_start:2")
		manager_state["position_checkpoints"] = position_checkpoints
	else:
		_failures.append("checkpoint snapshot should include position checkpoints")

	ctx.checkpoint_manager.restore(manager_state)
	ctx.variables.set_var("checkpoint_phase", "dirty")
	ctx.variables.set_var("target_after_marker", "dirty")
	ctx.variables.set_var("target_lazy_count", 99)

	var restored: bool = bool(ctx.checkpoint_manager.restore_to_position("checkpoint_start", 2))
	await process_frame

	_expect(restored, "restore_to_position should succeed for a reached target")
	_expect(ctx.game_state.current_node != null and ctx.game_state.current_node.name == &"checkpoint_start", "restore should keep the target node")
	_expect(ctx.game_state.current_index == 2, "restore should replay to target entry index")
	_expect(ctx.game_state.is_waiting_input, "restore should leave the target dialogue waiting for input")
	_expect(ctx.variables.get_var("checkpoint_phase", "") == "two_lazy", "restore should replay target lazy block from the earlier checkpoint")
	_expect(ctx.variables.get_var("target_after_marker", "") == "two_after", "restore should replay target after_dialogue block")
	_expect(ctx.variables.get_var("target_lazy_count", 0) == 1, "restore should not keep dirty target variables when replaying")
	_expect(_dialogues.size() >= 4 and _dialogues.back().get("text", "") == "Two", "restore should emit the target dialogue")

	if _failures.is_empty():
		print("CheckpointManagerSmokeTest: OK, dialogues=%d" % _dialogues.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("CheckpointManagerSmokeTest: FAILED")
		quit(1)


func _write_scenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var file: FileAccess = FileAccess.open(SCENARIO_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write %s" % SCENARIO_PATH)
		return
	file.store_string(SCENARIO_SOURCE)
	file.close()


func _wait_until(predicate: Callable, max_frames: int = 30) -> void:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return
		await process_frame
	_failures.append("timed out waiting for condition")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
