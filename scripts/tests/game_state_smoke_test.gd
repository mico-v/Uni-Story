extends SceneTree

## Headless GameState runtime smoke test.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/game_state_smoke_test.gd


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var variables: Variables
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
	var read_tracker: NoopReadTracker

	func setup() -> void:
		object_manager = ObjectManager.new()
		variables = Variables.new()
		runtime = GDRuntime.new(self)
		script_loader = ScriptLoader.new(self)
		game_state = GameState.new(self)
		read_tracker = NoopReadTracker.new()


class NoopReadTracker:
	extends RefCounted

	func mark_read(_node_name: StringName, _index: int) -> void:
		pass


const SCENARIO_PATH := "user://tests/game_state_smoke.txt"
const SCENARIO_SOURCE := """
@<|
label("smoke_start", "Smoke Start")
is_start()
|>
<|
set_var("score", 0)
add_var("score", 5)
|>
Tester：：第一句

<|
add_var("score", 3)
jump_if(get_var("score") >= 8, "smoke_high")
|>
这句不应该出现
@<| jump_to("smoke_branch") |>

@<| label("smoke_high") |>
Tester：：跳转成功
@<| jump_to("smoke_branch") |>

@<| label("smoke_branch") |>
请选择：
@<| branch([
	{ dest="smoke_good", text="可见选项", mode="show", cond="get_var('score') >= 8" },
	{ dest="smoke_bad", text="不可见选项", mode="show", cond="get_var('score') < 8" },
	{ dest="smoke_disabled", text="禁用选项", mode="enable", cond="false" },
]) |>

@<| label("smoke_good") |>
Tester：：分支选择成功
@<| jump_to("smoke_end") |>

@<| label("smoke_bad") |>
不应进入隐藏分支
@<| jump_to("smoke_end") |>

@<| label("smoke_disabled") |>
不应进入禁用分支
@<| jump_to("smoke_end") |>

@<| label("smoke_end") |>
Tester：：结束前一句
@<| is_end("smoke_done") |>
"""

var _failures: Array[String] = []
var _dialogues: Array[Dictionary] = []
var _branch_options: Array = []
var _ended := false
var _ending_name := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	ctx.game_state.dialogue_changed.connect(func(speaker: String, text: String) -> void:
		_dialogues.append({"speaker": speaker, "text": text})
	)
	ctx.game_state.branch_requested.connect(func(options: Array) -> void:
		_branch_options = options.duplicate(true)
	)
	ctx.game_state.game_ended.connect(func() -> void:
		_ended = true
	)
	ctx.game_state.ending_reached.connect(func(name: String) -> void:
		_ending_name = name
	)

	_write_scenario()
	ctx.script_loader.load_all([SCENARIO_PATH])
	_expect(ctx.script_loader.load_ok, "script loader should accept smoke scenario")
	_expect(ctx.script_loader.graph.sanity_check().is_empty(), "flow graph should pass sanity check")
	_expect(ctx.script_loader.graph.start_nodes == [&"smoke_start"], "graph should expose smoke_start as start node")

	ctx.game_state.setup(ctx.script_loader.graph)
	ctx.game_state.start_node(&"smoke_start")
	await _wait_until(func() -> bool: return _dialogues.size() >= 1 and ctx.game_state.is_waiting_input)
	_expect_dialogue(0, "Tester", "第一句")
	_expect(ctx.variables.get_var("score") == 5, "first lazy block should initialize score to 5")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return _dialogues.size() >= 2 and ctx.game_state.is_waiting_input)
	_expect_dialogue(1, "Tester", "跳转成功")
	_expect(ctx.variables.get_var("score") == 8, "jump lazy block should raise score to 8")
	_expect(_find_dialogue_text("这句不应该出现") == -1, "jump_if should skip the fall-through line")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return _dialogues.size() >= 3 and ctx.game_state.is_waiting_input)
	_expect_dialogue(2, "", "请选择：")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.is_waiting_branch and not _branch_options.is_empty())
	_expect(_branch_options.size() == 2, "branch should include one visible option and one disabled option")
	_expect(_has_branch(&"smoke_good", true), "visible branch should be enabled")
	_expect(_has_branch(&"smoke_disabled", false), "enable-mode branch should stay visible but disabled")
	_expect(not _has_branch(&"smoke_bad", true), "show-mode false branch should be hidden")

	ctx.game_state.choose_branch(&"smoke_good")
	await _wait_until(func() -> bool: return _dialogues.size() >= 4 and ctx.game_state.is_waiting_input)
	_expect_dialogue(3, "Tester", "分支选择成功")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return _dialogues.size() >= 5 and ctx.game_state.is_waiting_input)
	_expect_dialogue(4, "Tester", "结束前一句")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return _ended and ctx.game_state.is_ended)
	_expect(_ending_name == "smoke_done", "named ending should be emitted")

	if _failures.is_empty():
		print("GameStateSmokeTest: OK, dialogues=%d, branches=%d" % [_dialogues.size(), _branch_options.size()])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("GameStateSmokeTest: FAILED")
		quit(1)


func _write_scenario() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	var file := FileAccess.open(SCENARIO_PATH, FileAccess.WRITE)
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


func _expect_dialogue(index: int, speaker: String, text: String) -> void:
	if index >= _dialogues.size():
		_failures.append("missing dialogue at index %d" % index)
		return
	var line := _dialogues[index]
	_expect(line.get("speaker", "") == speaker, "dialogue %d speaker should be '%s'" % [index, speaker])
	_expect(line.get("text", "") == text, "dialogue %d text should be '%s'" % [index, text])


func _find_dialogue_text(text: String) -> int:
	for i in range(_dialogues.size()):
		if _dialogues[i].get("text", "") == text:
			return i
	return -1


func _has_branch(dest: StringName, enabled: bool) -> bool:
	for option in _branch_options:
		if option is Dictionary and option.get("dest", &"") == dest and bool(option.get("enabled", false)) == enabled:
			return true
	return false
