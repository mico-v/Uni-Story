extends SceneTree

## Headless ChapterSelectViewController smoke test.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/chapter_select_smoke_test.gd

const ViewScene := preload("res://scene/view/chapter_select_view.tscn")


class TestContext:
	extends Node

	var script_loader: DummyScriptLoader
	var checkpoint_manager: DummyCheckpointManager
	var i18n: DummyI18n

	func setup() -> void:
		script_loader = DummyScriptLoader.new()
		checkpoint_manager = DummyCheckpointManager.new()
		i18n = DummyI18n.new()


class DummyScriptLoader:
	extends RefCounted

	var graph: FlowChartGraph

	func _init() -> void:
		graph = FlowChartGraph.new()
		_add_node(&"ch1", "Chapter 1", true, true, false)
		_add_node(&"ch2", "Chapter 2", true, false, false)
		_add_node(&"debug", "Debug", false, false, true)
		graph.sanity_check()

	func _add_node(name: StringName, display_name: String, is_start: bool, is_unlocked_start: bool, is_debug: bool) -> void:
		var node := FlowChartNode.new()
		node.name = name
		node.display_name = display_name
		node.is_start = is_start
		node.is_unlocked_start = is_unlocked_start
		node.is_debug = is_debug
		graph.add_node(node)


class DummyI18n:
	extends RefCounted

	func t(_key: String, fallback: String = "") -> String:
		return fallback


class DummyCheckpointManager:
	extends RefCounted

	var reached: Dictionary = {}

	func mark_dialogue_reached(node_name: StringName, entry_index: int, _display_name: String = "") -> void:
		reached["%s:%d" % [str(node_name), entry_index]] = true

	func is_reached_any_history(node_name: StringName, entry_index: int = 0) -> bool:
		var node_key := str(node_name)
		for key in reached.keys():
			var parts := str(key).split(":", false, 1)
			if parts.size() == 2 and parts[0] == node_key and int(parts[1]) >= entry_index:
				return true
		return false


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	var view := ViewScene.instantiate()
	if view == null:
		_failures.append("chapter select scene should instantiate")
		_finish()
		return
	root.add_child(view)
	await process_frame
	_expect(view is Control and view.has_signal("chapter_selected"), "chapter select scene should use controller")
	if view is Control:
		var vc := view as Control
		vc.call("setup", ctx)
		vc.call("apply_i18n", ctx.i18n)
		vc.set("unlock_debug_nodes", false)
		vc.call("refresh")
		var unlocked: Array = vc.call("get_unlocked_nodes")
		_expect(unlocked.has(&"ch1"), "initial unlocked start should be unlocked")
		_expect(not unlocked.has(&"ch2"), "locked start should not unlock before reached history")
		ctx.checkpoint_manager.mark_dialogue_reached(&"ch2", 0, "Chapter 2")
		unlocked = vc.call("get_unlocked_nodes")
		_expect(unlocked.has(&"ch2"), "reached dialogue should unlock chapter")
		vc.set("unlock_debug_nodes", true)
		unlocked = vc.call("get_unlocked_nodes")
		_expect(unlocked.has(&"debug"), "debug chapter should unlock only when debug unlock is enabled")

	root.remove_child(view)
	view.free()
	root.remove_child(ctx)
	ctx.free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("ChapterSelectSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ChapterSelectSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
