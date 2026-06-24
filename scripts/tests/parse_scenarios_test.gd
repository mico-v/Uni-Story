extends SceneTree

## Headless scenario parser smoke test.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/parse_scenarios_test.gd
##   godot --headless --path . --script res://scripts/tests/parse_scenarios_test.gd -- res://resources/scenarios/main.txt


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
	var variables: Variables
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


func _init() -> void:
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	var files := _scenario_files_from_args()
	if files.is_empty():
		files = _collect_scenario_files("res://resources/scenarios")

	if files.is_empty():
		push_error("ParseScenariosTest: no scenario files found")
		quit(1)
		return

	print("ParseScenariosTest: parsing %d scenario file(s)" % files.size())
	for path in files:
		print("  - %s" % path)

	ctx.script_loader.load_all(files)
	var errors := ctx.script_loader.graph.sanity_check()
	if not errors.is_empty():
		for err in errors:
			push_error(str(err))

	var ok := ctx.script_loader.load_ok and errors.is_empty()
	if ok:
		print("ParseScenariosTest: OK, nodes=%d" % ctx.script_loader.graph.nodes.size())
		quit(0)
	else:
		push_error("ParseScenariosTest: FAILED")
		quit(1)


func _scenario_files_from_args() -> Array[String]:
	var files: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		var path := str(arg).strip_edges()
		if path.ends_with(".txt"):
			files.append(path)
	files.sort()
	return files


func _collect_scenario_files(root_path: String) -> Array[String]:
	var files: Array[String] = []
	_collect_txt_files(root_path, files)
	files.sort()
	return files


func _collect_txt_files(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("ParseScenariosTest: cannot open directory '%s'" % path)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_collect_txt_files(path.path_join(entry), out)
		elif entry.get_extension().to_lower() == "txt":
			out.append(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
