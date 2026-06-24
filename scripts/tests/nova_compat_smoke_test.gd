extends SceneTree

## Headless NovaScript compatibility smoke test.
##
## Uses imported upstream Nova scenarios plus a tiny stage fixture.


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var variables: Variables
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
	var graphics: NoopGraphics
	var dialogue_box: NoopDialogueBox
	var read_tracker: NoopReadTracker

	func setup() -> void:
		object_manager = ObjectManager.new()
		variables = Variables.new()
		graphics = NoopGraphics.new()
		dialogue_box = NoopDialogueBox.new()
		read_tracker = NoopReadTracker.new()
		runtime = GDRuntime.new(self)
		script_loader = ScriptLoader.new(self)
		game_state = GameState.new(self)


class NoopGraphics:
	extends RefCounted

	func show(_obj: Variant, _image_path: String, _coord = null, _color = null) -> void:
		pass

	func hide(_obj: Variant) -> void:
		pass

	func move(_obj: Variant, _coord: Variant, _scale = null, _angle = null) -> void:
		pass

	func tint(_obj: Variant, _color: Variant) -> void:
		pass


class NoopDialogueBox:
	extends RefCounted

	func set_box(_pos_name: Variant = "bottom") -> void:
		pass


class NoopReadTracker:
	extends RefCounted

	func mark_read(_node_name: StringName, _index: int) -> void:
		pass


const STAGE_FIXTURE_PATH := "user://tests/nova_stage_fixture.txt"
const STAGE_FIXTURE := """
@<|
label 'stage_fixture'
is_debug()
is_save_point()
|>
[stage = before_checkpoint]<|
v_stage_before = 'before'
gv_stage_global = 'global'
|>
<|
v_stage_default = 'default'
|>
[stage = after_dialogue]<|
v_stage_after = 'after'
|>
Stage：：{{v_stage_before}}/{{v_stage_default}}
@<| is_end() |>
"""

var _failures: Array[String] = []
var _dialogues: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_write_stage_fixture()
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	ctx.game_state.dialogue_changed.connect(func(speaker: String, text: String) -> void:
		_dialogues.append({"speaker": speaker, "text": text})
	)

	var files := [
		"res://resources/scenarios/test_branch.txt",
		"res://resources/scenarios/test_branch_image.txt",
		"res://resources/scenarios/test_empty_node.txt",
		"res://resources/scenarios/test_variables.txt",
		STAGE_FIXTURE_PATH,
	]
	ctx.script_loader.load_all(files)
	_expect(ctx.script_loader.load_ok, "Nova compatibility fixture scenarios should parse")
	_expect(ctx.script_loader.graph.has_node_named(&"test_branch:a"), "local label l_a should be namespaced per file")
	_expect(ctx.script_loader.graph.has_node_named(&"test_empty_node:a"), "same local label in another file should not collide")
	_expect(ctx.script_loader.graph.has_node_named(&"test_branch_image:red"), "branch image local destination should be namespaced")
	var stage_node = ctx.script_loader.graph.get_node_named(&"stage_fixture")
	_expect(stage_node != null and stage_node.is_save_point, "is_save_point should mark the current node")

	var branch_image_node = ctx.script_loader.graph.get_node_named(&"test_branch_image")
	_expect(branch_image_node != null and branch_image_node.branches.size() >= 1, "branch image node should have options")
	if branch_image_node != null and branch_image_node.branches.size() >= 1:
		var image_info = branch_image_node.branches[0].get("image", null)
		_expect(image_info is Array and image_info.size() == 2, "Nova branch image tuple should become an array")

	ctx.game_state.setup(ctx.script_loader.graph)
	ctx.game_state.start_node(&"test_variables")
	await _wait_until(func() -> bool: return _dialogues.size() >= 1 and ctx.game_state.is_waiting_input)
	await _advance(ctx)
	await _advance(ctx)
	await _advance(ctx)
	_expect(_dialogues.back().get("text", "") == "变量可以显示在文本中：啊啊啊", "v_ variable should interpolate in text, got '%s'" % _dialogues.back().get("text", ""))
	await _advance(ctx)
	_expect(_dialogues.back().get("speaker", "") == "啊啊啊", "v_ variable should interpolate in speaker")
	await _advance(ctx)
	await _advance(ctx)
	_expect(_dialogues.back().get("text", "") == "把它们显示在文本中：123 4.56 啊啊啊", "temporary variables should interpolate, got '%s'" % _dialogues.back().get("text", ""))

	_dialogues.clear()
	ctx.game_state.start_node(&"stage_fixture")
	await _wait_until(func() -> bool: return _dialogues.size() >= 1 and ctx.game_state.is_waiting_input)
	_expect(_dialogues[0].get("text", "") == "before/default", "before_checkpoint and default stages should run before dialogue")
	_expect(ctx.variables.get_var("v_stage_after", "") == "after", "after_dialogue stage should run after dialogue emission")
	_expect(ctx.variables.get_global("gv_stage_global", "") == "global", "gv_ variable should write to global store")

	if _failures.is_empty():
		print("NovaCompatSmokeTest: OK, nodes=%d" % ctx.script_loader.graph.nodes.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("NovaCompatSmokeTest: FAILED")
		quit(1)


func _advance(ctx: TestContext) -> void:
	var before := _dialogues.size()
	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool:
		return _dialogues.size() > before or ctx.game_state.is_waiting_branch or ctx.game_state.is_ended
	)


func _write_stage_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var file := FileAccess.open(STAGE_FIXTURE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(STAGE_FIXTURE)
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
