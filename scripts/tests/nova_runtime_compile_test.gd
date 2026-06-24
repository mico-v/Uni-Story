extends SceneTree

## Compiles every runtime block from the default Nova scenario set.
##
## Parser tests only build the flow graph; this catches playback-time GDScript
## compile errors caused by untranslated Lua-style NovaScript.


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var variables: Variables
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
	var dialogue_box: NoopDialogueBox

	func setup() -> void:
		object_manager = ObjectManager.new()
		variables = Variables.new()
		dialogue_box = NoopDialogueBox.new()
		runtime = GDRuntime.new(self)
		script_loader = ScriptLoader.new(self)
		game_state = GameState.new(self)


class NoopDialogueBox:
	extends RefCounted

	func set_box(_pos_name: Variant = "bottom") -> void:
		pass


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	var nova := NovaController.new()
	var files := nova.scenario_files.duplicate()
	nova.free()

	ctx.script_loader.load_all(files)
	_expect(ctx.script_loader.load_ok, "default Nova scenarios should parse")

	for node in ctx.script_loader.graph.nodes.values():
		for i in range(node.entries.size()):
			var entry: DialogueEntry = node.entries[i]
			_compile(ctx, entry.before_checkpoint_source, "%s[%d].before_checkpoint" % [node.name, i])
			_compile(ctx, entry.lazy_source, "%s[%d].default" % [node.name, i])
			_compile(ctx, entry.after_dialogue_source, "%s[%d].after_dialogue" % [node.name, i])
		for b in node.branches:
			if b is Dictionary:
				var cond := str(b.get("cond", "")).strip_edges()
				if not cond.is_empty():
					_compile(ctx, "return %s" % cond, "%s.branch(%s)" % [node.name, b.get("dest", "")])

	if _failures.is_empty():
		print("NovaRuntimeCompileTest: OK, nodes=%d" % ctx.script_loader.graph.nodes.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("NovaRuntimeCompileTest: FAILED")
		quit(1)


func _compile(ctx: TestContext, source: String, label: String) -> void:
	if source.strip_edges().is_empty():
		return
	ctx.runtime.clear_errors()
	var script := ctx.runtime.compile_block(source)
	if script == null or ctx.runtime.had_error:
		_failures.append("compile failed: %s\n%s" % [label, source])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
