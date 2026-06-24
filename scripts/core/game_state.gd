class_name GameState extends RefCounted

## The model. Walks the flow chart, runs each entry's lazy block, and emits
## calls always produces the same state (replayable for save/load/skip/jump).

signal dialogue_changed(speaker: String, text: String)
signal dialogue_advanced()                 # fired after each dialogue display (for auto-save)
signal branch_requested(options: Array)        # Array[{dest, text, mode, cond, image, enabled}]
signal game_ended()
signal chapter_started()                 # fired for CHAPTER-type nodes (UI auto-advances)
signal ending_reached(ending_name: String)  # fired when a named END node is reached

var _ctx: Node
var _graph: FlowChartGraph

var current_node: FlowChartNode = null
var current_index: int = -1
var current_end_name: String = ""
var is_waiting_branch: bool = false
var is_waiting_input: bool = false
var is_processing: bool = false
var is_ended: bool = false

## Set by a lazy block calling jump_if/jump_to at runtime; consumed after the
## current entry's lazy code runs, redirecting the story immediately.
var pending_jump: StringName = &""

## Cache for _eval_condition results. Keyed by trimmed condition string.
## Cleared on restore() and start_node() since variables may differ.
var _cond_cache: Dictionary = {}
const _COND_CACHE_MAX := 64


func _init(ctx: Node) -> void:
	_ctx = ctx


func setup(graph: FlowChartGraph) -> void:
	_graph = graph
	# Invalidate condition cache whenever a story variable changes.
	if _ctx and _ctx.variables:
		if not _ctx.variables.changed.is_connected(_invalidate_cond_cache):
			_ctx.variables.changed.connect(_invalidate_cond_cache)


## Capture only the model state (node, index, variables).
## Subsystem snapshots are orchestrated by NovaController to maintain layer separation.
func snapshot() -> Dictionary:
	return {
		"node": String(current_node.name) if current_node else "",
		"index": current_index,
		"variables": _ctx.variables.to_dict(),
	}


## Restore a snapshot: set variables, jump to the node, and silently replay
## lazy blocks of entries [0, index] to rebuild presentation, then show entry.
## Note: subsystem restore is orchestrated by NovaController after this call.
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
	current_end_name = ""
	_cond_cache.clear()
	pending_jump = &""

	var target: int = int(data.get("index", 0))
	target = clampi(target, 0, current_node.entries.size() - 1)

	# Replay lazy blocks up to and including target entry to rebuild state.
	for i in range(0, target + 1):
		current_index = i
		var entry = current_node.entries[i]
		if entry.has_before_checkpoint():
			_ctx.runtime.run_block(entry.before_checkpoint_source)
		if entry.has_lazy():
			_ctx.runtime.run_block(entry.lazy_source)
		if entry.has_after_dialogue():
			_ctx.runtime.run_block(entry.after_dialogue_source)
		pending_jump = &""  # ignore mid-node jumps during replay

	var e = current_node.entries[target]
	dialogue_changed.emit(_format_text(e.speaker), _format_text(e.text))
	dialogue_advanced.emit()
	return true


func start_node(name: StringName) -> void:
	if not _graph.has_node_named(name):
		push_warning("GameState: unknown start node '%s'" % name)
		return
	current_node = _graph.get_node_named(name)
	current_index = -1
	current_end_name = ""
	_cond_cache.clear()
	is_waiting_branch = false
	is_waiting_input = false
	is_ended = false
	is_processing = false
	advance()


## Jump to a specific node + entry index (used by backlog jump-back).
## Resets all waiting states and presents the target entry directly.
func jump_to_position(node_name: String, entry_index: int) -> bool:
	if not _graph.has_node_named(StringName(node_name)):
		push_warning("GameState: unknown node for jump '%s'" % node_name)
		return false
	current_node = _graph.get_node_named(StringName(node_name))
	current_index = clampi(entry_index, 0, current_node.entries.size() - 1)
	is_waiting_branch = false
	is_waiting_input = false
	is_ended = false
	is_processing = false
	current_end_name = ""
	pending_jump = &""
	# Present the target entry directly.
	if current_index >= 0 and current_index < current_node.entries.size():
		var e = current_node.entries[current_index]
		dialogue_changed.emit(_format_text(e.speaker), _format_text(e.text))
		is_waiting_input = true
		return true
	return false


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
		if entry.has_before_checkpoint():
			await _ctx.runtime.run_block_async(entry.before_checkpoint_source)
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
		dialogue_changed.emit(_format_text(entry.speaker), _format_text(entry.text))
		if current_node.type == FlowChartNode.Type.CHAPTER:
			chapter_started.emit()
		dialogue_advanced.emit()
		if entry.has_after_dialogue():
			await _ctx.runtime.run_block_async(entry.after_dialogue_source)
		return


func _on_node_exhausted() -> bool:
	is_waiting_input = false
	is_waiting_branch = false
	current_end_name = ""
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
					"text": _format_text(str(b.get("text", ""))),
					"mode": mode,
					"cond": cond,
					"image": b.get("image", ""),
					"enabled": cond_ok,
				}
				opts.append(item)
				continue

			if _is_show_mode(mode):
				if not cond_ok:
					continue
				var item: Dictionary = {
					"dest": dest,
					"text": _format_text(str(b.get("text", ""))),
					"mode": mode,
					"cond": cond,
					"image": b.get("image", ""),
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
		current_end_name = current_node.end_name
		if current_end_name != "":
			ending_reached.emit(current_end_name)
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


func _invalidate_cond_cache(_name: String, _value: Variant) -> void:
	_cond_cache.clear()


func _eval_condition(cond_expr: String) -> bool:
	var c := cond_expr.strip_edges()
	if c.is_empty():
		return true

	# Check result cache first.
	if _cond_cache.has(c):
		return _cond_cache[c]

	var block := "return %s\n" % c
	var script: GDScript = _ctx.runtime.compile_block(block)
	if script == null:
		push_warning("GameState: condition compile failed '%s'" % c)
		return false

	var inst = script.new()
	inst._ctx = _ctx
	var result: Variant = inst.run()
	var bool_result := false
	if result != null:
		bool_result = bool(result)

	# Evict oldest entries if cache is full.
	if _cond_cache.size() >= _COND_CACHE_MAX:
		var keys := _cond_cache.keys()
		@warning_ignore("integer_division")
		for i in range(_COND_CACHE_MAX / 4):
			_cond_cache.erase(keys[i])

	_cond_cache[c] = bool_result
	return bool_result


func _goto(name: StringName) -> bool:
	if not _graph.has_node_named(name):
		push_warning("GameState: jump to unknown node '%s'" % name)
		is_ended = true
		game_ended.emit()
		return false
	current_node = _graph.get_node_named(name)
	current_index = -1
	return true


func _format_text(text: String) -> String:
	if _ctx and _ctx.script_loader and _ctx.script_loader.has_method("interpolate_text"):
		return _ctx.script_loader.interpolate_text(text)
	return text
