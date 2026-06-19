class_name GameState extends RefCounted

## The model. Walks the flow chart, runs each entry's lazy block, and emits
## calls always produces the same state (replayable for save/load/skip/jump).

signal dialogue_changed(speaker: String, text: String)
signal branch_requested(options: Array)        # Array[{dest, text, mode, cond, image, enabled}]
signal node_changed(node_name: StringName)
signal game_ended()
signal game_started()

var _ctx: Node
var _graph: FlowChartGraph

var current_node: FlowChartNode = null
var current_index: int = -1
var is_waiting_branch: bool = false
var is_waiting_input: bool = false
var is_processing: bool = false
var is_ended: bool = false

## Set by a lazy block calling jump_if/jump_to at runtime; consumed after the
## current entry's lazy code runs, redirecting the story immediately.
var pending_jump: StringName = &""


func _init(ctx: Node) -> void:
	_ctx = ctx


func setup(graph: FlowChartGraph) -> void:
	_graph = graph


## Capture the model state for saving. Front/back separation means this plus the
## variables fully describe the playthrough; presentation is rebuilt by replay.
func snapshot() -> Dictionary:
	var system_state := {}
	if _ctx.animation and _ctx.animation.has_method("snapshot"):
		system_state["animation"] = _ctx.animation.snapshot()
	if _ctx.audio and _ctx.audio.has_method("snapshot"):
		system_state["audio"] = _ctx.audio.snapshot()
	if _ctx.prefab_loader and _ctx.prefab_loader.has_method("snapshot"):
		system_state["prefab_loader"] = _ctx.prefab_loader.snapshot()
	if _ctx.camera and _ctx.camera.has_method("snapshot"):
		system_state["camera"] = _ctx.camera.snapshot()
	if _ctx.graphics and _ctx.graphics.has_method("snapshot"):
		system_state["graphics"] = _ctx.graphics.snapshot()
	return {
		"node": String(current_node.name) if current_node else "",
		"index": current_index,
		"variables": _ctx.variables.to_dict(),
		"systems": system_state,
	}


## Restore a snapshot: set variables, jump to the node, and silently replay
## lazy blocks of entries [0, index] to rebuild presentation, then show entry.
func restore(data: Dictionary) -> bool:
	var node_name := StringName(data.get("node", ""))
	if not _graph.has_node_named(node_name):
		push_warning("GameState: cannot restore unknown node '%s'" % node_name)
		return false

	_ctx.variables.from_dict(data.get("variables", {}))

	current_node = _graph.get_node_named(node_name)
	is_waiting_branch = false
	is_waiting_input = false
	is_ended = false
	is_processing = false
	pending_jump = &""
	node_changed.emit(node_name)

	var target: int = int(data.get("index", 0))
	target = clampi(target, 0, current_node.entries.size() - 1)

	# Clean up runtime objects before replay (prefabs will be re-created by lazy blocks).
	if _ctx.prefab_loader:
		_ctx.prefab_loader.destroy_all()

	# Replay lazy blocks up to and including target entry to rebuild state.
	for i in range(0, target + 1):
		current_index = i
		var entry = current_node.entries[i]
		if entry.has_lazy():
			_ctx.runtime.run_block(entry.lazy_source)
		pending_jump = &""  # ignore mid-node jumps during replay

	# Restore subsystem state after replay so playback can continue from a stable model.
	var systems = data.get("systems", {})
	if systems is Dictionary:
		if _ctx.animation and _ctx.animation.has_method("restore"):
			_ctx.animation.restore(systems.get("animation", {}))
		if _ctx.audio and _ctx.audio.has_method("restore"):
			_ctx.audio.restore(systems.get("audio", {}))
		if _ctx.prefab_loader and _ctx.prefab_loader.has_method("restore"):
			_ctx.prefab_loader.restore(systems.get("prefab_loader", {}))
		if _ctx.camera and _ctx.camera.has_method("restore"):
			_ctx.camera.restore(systems.get("camera", {}))
		if _ctx.graphics and _ctx.graphics.has_method("restore"):
			_ctx.graphics.restore(systems.get("graphics", {}))

	var e = current_node.entries[target]
	dialogue_changed.emit(e.speaker, e.text)
	return true


func start_node(name: StringName) -> void:
	if not _graph.has_node_named(name):
		push_warning("GameState: unknown start node '%s'" % name)
		return
	current_node = _graph.get_node_named(name)
	current_index = -1
	is_waiting_branch = false
	is_waiting_input = false
	is_ended = false
	is_processing = false
	node_changed.emit(name)
	game_started.emit()
	is_waiting_input = false
	advance()


## Move to and present the next dialogue entry. Silent entries (presentation
## only) run their lazy block and immediately fall through to the next.
func advance() -> void:
	if is_processing or is_waiting_input or is_ended or is_waiting_branch or current_node == null:
		return
	is_processing = true
	await _continue_after_wait()
	is_processing = false


func _continue_after_wait() -> void:
	if is_waiting_input or is_waiting_branch or is_ended or current_node == null:
		return
	# Prevent accidental recursion if UI triggers continue from inside signal handlers.

	while true:
		current_index += 1
		if current_index >= current_node.entries.size():
			if not _on_node_exhausted():
				return
			continue

		var entry = current_node.entries[current_index]
		if entry.has_lazy():
			await _ctx.runtime.run_block_async(entry.lazy_source)
			# A lazy block may request a runtime jump (jump_if/jump_to).
			if pending_jump != &"":
				var dest := pending_jump
				pending_jump = &""
				if _goto(dest):
					continue
				return

		if entry.is_silent:
			continue

		is_waiting_input = true
		if _ctx.read_tracker:
			_ctx.read_tracker.mark_read(current_node.name, current_index)
		dialogue_changed.emit(entry.speaker, entry.text)
		return


func _on_node_exhausted() -> bool:
	is_waiting_input = false
	is_waiting_branch = false
	if not current_node.branches.is_empty():
		var opts: Array = []
		for b in current_node.branches:
			if not (b is Dictionary):
				continue

			var dest := StringName(str(b.get("dest", "")))
			if dest == "":
				continue

			var mode := int(b.get("mode", FlowChartNode.BranchMode.NORMAL))
			var cond := str(b.get("cond", "")).strip_edges()
			var cond_ok := _eval_condition(cond)

			if _is_jump_mode(mode):
				if cond_ok:
					return _goto(dest)
				continue

			if _is_enable_mode(mode):
				var item: Dictionary = {
					"dest": dest,
					"text": str(b.get("text", "")),
					"mode": mode,
					"cond": cond,
					"image": str(b.get("image", "")),
					"enabled": cond_ok,
				}
				opts.append(item)
				continue

			if _is_show_mode(mode):
				if not cond_ok:
					continue
				var item: Dictionary = {
					"dest": dest,
					"text": str(b.get("text", "")),
					"mode": mode,
					"cond": cond,
					"image": str(b.get("image", "")),
					"enabled": true,
				}
				opts.append(item)

		if not opts.is_empty():
			is_waiting_branch = true
			branch_requested.emit(opts)
			return false

		# No selectable options -> treat as normal flow end.
		if current_node.jump_target != &"":
			return _goto(current_node.jump_target)
		else:
			is_waiting_input = false
			is_ended = true
			game_ended.emit()
			return false

	if current_node.jump_target != &"":
		is_waiting_input = false
		return _goto(current_node.jump_target)

	if current_node.type == FlowChartNode.Type.END:
		is_waiting_input = false
		is_ended = true
		game_ended.emit()
		return false

	# No transition and not explicitly an end: treat as end.
	is_waiting_input = false
	is_ended = true
	game_ended.emit()
	return false


func choose_branch(dest: StringName) -> void:
	if not is_waiting_branch:
		return
	is_waiting_branch = false
	is_waiting_input = false
	_goto(dest)
	if is_processing:
		return
	advance()


## Called by UI click when current dialogue line is ready to advance.
func continue_after_input() -> void:
	if is_processing:
		return
	is_processing = true
	is_waiting_input = false
	await _continue_after_wait()
	is_processing = false


func _is_jump_mode(mode) -> bool:
	var m := int(mode) if mode is int else FlowChartNode.BranchMode.NORMAL
	return m == FlowChartNode.BranchMode.JUMP


func _is_enable_mode(mode) -> bool:
	var m := int(mode) if mode is int else FlowChartNode.BranchMode.NORMAL
	return m == FlowChartNode.BranchMode.ENABLE


func _is_show_mode(mode) -> bool:
	var m := int(mode) if mode is int else FlowChartNode.BranchMode.NORMAL
	return m == FlowChartNode.BranchMode.SHOW || m == FlowChartNode.BranchMode.NORMAL


func _eval_condition(cond_expr: String) -> bool:
	var c := cond_expr.strip_edges()
	if c.is_empty():
		return true

	var block := "return %s\n" % c
	var script: GDScript = _ctx.runtime.compile_block(block)
	if script == null:
		push_warning("GameState: condition compile failed '%s'" % c)
		return false

	var inst = script.new()
	inst._ctx = _ctx
	var result: Variant = inst.run()
	if result == null:
		return false
	return bool(result)


func _goto(name: StringName) -> bool:
	if not _graph.has_node_named(name):
		push_warning("GameState: jump to unknown node '%s'" % name)
		is_ended = true
		game_ended.emit()
		return false
	current_node = _graph.get_node_named(name)
	current_index = -1
	node_changed.emit(name)
	return true
