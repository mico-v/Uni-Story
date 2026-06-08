class_name GameState extends RefCounted

## The model. Walks the flow chart, runs each entry's lazy block, and emits
## signals the view reacts to. Holds no view references, so the same sequence of
## calls always produces the same state (replayable for save/load/skip/jump).

signal dialogue_changed(speaker: String, text: String)
signal branch_requested(options: Array)        # Array[{dest, text}]
signal node_changed(node_name: StringName)
signal game_ended()
signal game_started()

var _ctx: Node
var _graph: FlowChartGraph

var current_node: FlowChartNode = null
var current_index: int = -1
var is_waiting_branch: bool = false
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
	return {
		"node": String(current_node.name) if current_node else "",
		"index": current_index,
		"variables": _ctx.variables.to_dict(),
	}


## Restore a snapshot: set variables, jump to the node, and silently replay the
## lazy blocks of entries [0, index] to rebuild presentation, then show entry.
func restore(data: Dictionary) -> bool:
	var node_name := StringName(data.get("node", ""))
	if not _graph.has_node_named(node_name):
		push_warning("GameState: cannot restore unknown node '%s'" % node_name)
		return false

	_ctx.variables.from_dict(data.get("variables", {}))

	current_node = _graph.get_node_named(node_name)
	is_waiting_branch = false
	is_ended = false
	pending_jump = &""
	node_changed.emit(node_name)

	var target: int = int(data.get("index", 0))
	target = clampi(target, 0, current_node.entries.size() - 1)

	# Replay lazy blocks up to and including the target entry to rebuild state.
	for i in range(0, target + 1):
		current_index = i
		var entry = current_node.entries[i]
		if entry.has_lazy():
			_ctx.runtime.run_block(entry.lazy_source)
		pending_jump = &""  # ignore mid-node jumps during replay

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
	is_ended = false
	node_changed.emit(name)
	game_started.emit()
	advance()


## Move to and present the next dialogue entry. Silent entries (presentation
## only) run their lazy block and immediately fall through to the next.
func advance() -> void:
	if is_ended or is_waiting_branch or current_node == null:
		return

	while true:
		current_index += 1
		if current_index >= current_node.entries.size():
			_on_node_exhausted()
			return

		var entry = current_node.entries[current_index]
		if entry.has_lazy():
			_ctx.runtime.run_block(entry.lazy_source)
			# A lazy block may request a runtime jump (jump_if/jump_to).
			if pending_jump != &"":
				var dest := pending_jump
				pending_jump = &""
				_goto(dest)
				return

		if entry.is_silent:
			continue

		dialogue_changed.emit(entry.speaker, entry.text)
		return


func _on_node_exhausted() -> void:
	if not current_node.branches.is_empty():
		is_waiting_branch = true
		branch_requested.emit(current_node.branches.duplicate(true))
		return

	if current_node.jump_target != &"":
		_goto(current_node.jump_target)
		return

	if current_node.type == FlowChartNode.Type.END:
		is_ended = true
		game_ended.emit()
		return

	# No transition and not explicitly an end: treat as end.
	is_ended = true
	game_ended.emit()


func choose_branch(dest: StringName) -> void:
	if not is_waiting_branch:
		return
	is_waiting_branch = false
	_goto(dest)


func _goto(name: StringName) -> void:
	if not _graph.has_node_named(name):
		push_warning("GameState: jump to unknown node '%s'" % name)
		is_ended = true
		game_ended.emit()
		return
	current_node = _graph.get_node_named(name)
	current_index = -1
	node_changed.emit(name)
	advance()
