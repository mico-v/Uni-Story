class_name ScriptLoader extends RefCounted

## Builds the FlowChartGraph from scenario files.
##
## Two-pass-per-file walk over the tokenized blocks:
##   - eager block (`@<|`): compiled & run immediately. Its label/jump_to/branch/
##     is_* calls mutate the graph via the methods at the bottom of this file.
##   - text + lazy block: accumulated into DialogueEntry objects on the current
##     node. Lazy source is stored (not run) — it runs later, during play.

var graph: FlowChartGraph

var _ctx: Node
var _runtime: GDRuntime
var _current_node: FlowChartNode = null
var _pending_lazy: String = ""  # lazy block waiting to attach to the next text
var load_ok: bool = true
var _block_attrs: Dictionary = {}


func _init(ctx: Node) -> void:
	_ctx = ctx
	graph = FlowChartGraph.new()


func load_all(file_paths: Array) -> void:
	graph.clear()
	load_ok = true
	_runtime = _ctx.runtime
	for path in file_paths:
		if not FileAccess.file_exists(path):
			push_warning("ScriptLoader: missing scenario %s" % path)
			load_ok = false
			continue
		_current_node = null
		_pending_lazy = ""
		_block_attrs = {}
		_parse_file(FileAccess.get_file_as_string(path))
	var errors := graph.sanity_check()
	if not errors.is_empty():
		for e in errors:
			push_error(str(e))
		load_ok = false


func _parse_file(source: String) -> void:
	var blocks := NovaParser.tokenize(source)
	for block in blocks:
		match block["type"]:
			"eager":
				_block_attrs = block.get("attrs", {})
				_flush_pending_lazy_as_silent()
				_runtime.run_block(block["content"])
				_block_attrs = {}
			"lazy":
				_block_attrs = {}
				# A lazy block attaches to the dialogue text that follows it.
				# If one is already pending (back-to-back lazy blocks), flush the
				# previous as a silent entry first.
				_flush_pending_lazy_as_silent()
				_pending_lazy = block["content"]
			"text":
				_append_text(block["content"])
	# Flush any trailing lazy block at end of file (no following text).
	_flush_pending_lazy_as_silent()


func _append_text(line: String) -> void:
	if _current_node == null:
		push_warning("ScriptLoader: dialogue text before any label(): '%s'" % line)
		return
	var entry := DialogueEntry.new()
	entry.lazy_source = _pending_lazy
	_pending_lazy = ""
	var parsed := _split_speaker(line)
	entry.speaker = parsed[0]
	entry.text = parsed[1]
	_current_node.add_entry(entry)


## A lazy block with no following text becomes a silent entry (presentation
## only) so it still executes in sequence.
func _flush_pending_lazy_as_silent() -> void:
	if _pending_lazy.strip_edges().is_empty():
		return
	if _current_node == null:
		_pending_lazy = ""
		return
	var entry := DialogueEntry.new()
	entry.lazy_source = _pending_lazy
	entry.is_silent = true
	_current_node.add_entry(entry)
	_pending_lazy = ""


func _split_speaker(line: String) -> Array:
	var marker := line.find("：：")
	var sep_len := 2
	if marker == -1:
		marker = line.find("：")
		sep_len = "：".length()
	if marker == -1:
		marker = line.find(":")
		sep_len = 1
	if marker > 0:
		var speaker := line.substr(0, marker).strip_edges()
		var content := line.substr(marker + sep_len).strip_edges()
		if not speaker.is_empty() and not content.is_empty():
			return [speaker, content]
	return ["", line]


# === API called from eager blocks (via BaseBlock) ============================

func label(name: String, display_name = null) -> void:
	var sn := StringName(name)
	if graph.has_node_named(sn):
		_current_node = graph.get_node_named(sn)
	else:
		var node := FlowChartNode.new()
		node.name = sn
		node.display_name = str(display_name) if display_name != null else name
		graph.add_node(node)
		_current_node = node


func jump_to(dest: String) -> void:
	if _current_node:
		_current_node.jump_target = StringName(dest)


func branch(branches: Array) -> void:
	if _current_node == null:
		return
	var opts: Array = []
	for b in branches:
		if b is Dictionary:
			var src = b.get("mode", _block_attrs.get("mode", FlowChartNode.BranchMode.NORMAL))
			var cond := str(b.get("cond", _block_attrs.get("cond", ""))).strip_edges()
			var image := str(b.get("image", _block_attrs.get("image", ""))).strip_edges()
			opts.append({
				"dest": StringName(b.get("dest", "")),
				"text": str(b.get("text", "")),
				"mode": _parse_branch_mode(src),
				"cond": cond,
				"image": image,
			})
	_current_node.branches = opts


func _parse_branch_mode(value: Variant) -> int:
	var s := str(value).to_lower()
	match s:
		"jump":
			return FlowChartNode.BranchMode.JUMP
		"show":
			return FlowChartNode.BranchMode.SHOW
		"enable":
			return FlowChartNode.BranchMode.ENABLE
		_:
			if value is int:
				if int(value) >= FlowChartNode.BranchMode.NORMAL and int(value) <= FlowChartNode.BranchMode.ENABLE:
					return int(value)
			return FlowChartNode.BranchMode.NORMAL


func is_chapter() -> void:
	if _current_node:
		_current_node.type = FlowChartNode.Type.CHAPTER

func is_start() -> void:
	if _current_node:
		_current_node.is_start = true
		_current_node.is_unlocked_start = true

func is_unlocked_start() -> void:
	if _current_node:
		_current_node.is_unlocked_start = true

func is_debug() -> void:
	if _current_node:
		_current_node.is_debug = true

func is_end(end_name = null) -> void:
	if _current_node:
		_current_node.type = FlowChartNode.Type.END
		if end_name != null:
			_current_node.end_name = str(end_name)
