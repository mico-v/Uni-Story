class_name ScriptLoader extends RefCounted

## Builds the FlowChartGraph from scenario files.
##
## Two-pass-per-file walk over the tokenized blocks:
##   - eager block (`@<|`): compiled & run immediately. Its label/jump_to/branch/
##     is_* calls mutate the graph via the methods at the bottom of this file.
##   - text + lazy block: accumulated into DialogueEntry objects on the current
##     node. Lazy source is stored (not run) — it runs later, during play.

const EngineLogScript := preload("res://scripts/core/engine_log.gd")
const NovaCompatScript := preload("res://scripts/core/nova_script_compat.gd")

var graph: FlowChartGraph

var _ctx: Node
var _runtime: GDRuntime
var _current_node: FlowChartNode = null
var _pending_lazy_by_stage: Dictionary = {}
var load_ok: bool = true
var _block_attrs: Dictionary = {}
var _current_namespace: String = ""
var _last_display_name: String = ""


func _init(ctx: Node) -> void:
	_ctx = ctx
	graph = FlowChartGraph.new()


func load_all(file_paths: Array) -> void:
	graph.clear()
	load_ok = true
	_runtime = _ctx.runtime
	for path in file_paths:
		if not FileAccess.file_exists(path):
			EngineLogScript.warn(EngineLogScript.Category.PARSE, "ScriptLoader", "missing scenario %s" % path)
			load_ok = false
			continue
		_current_node = null
		_pending_lazy_by_stage = {}
		_block_attrs = {}
		_current_namespace = NovaCompatScript.namespace_for_path(path)
		_last_display_name = ""
		_parse_file(FileAccess.get_file_as_string(path))
	var errors := graph.sanity_check()
	if not errors.is_empty():
		for e in errors:
			EngineLogScript.error(EngineLogScript.Category.PARSE, "ScriptLoader", str(e))
		load_ok = false


func _parse_file(source: String) -> void:
	var blocks := NovaParser.tokenize(source)
	for block in blocks:
		match block["type"]:
			"eager":
				_block_attrs = block.get("attrs", {})
				_flush_pending_lazy_as_silent()
				var eager_source: String = NovaCompatScript.translate_block(block["content"], _current_namespace)
				_runtime.clear_errors()
				_runtime.run_block(eager_source)
				if _runtime.had_error:
					load_ok = false
				_block_attrs = {}
			"lazy":
				_block_attrs = block.get("attrs", {})
				# A lazy block attaches to the dialogue text that follows it.
				# If one is already pending (back-to-back lazy blocks), flush the
				# previous default action as a silent entry first.
				var stage := _stage_from_attrs(_block_attrs)
				if stage == "default" and _pending_lazy_by_stage.has(stage):
					_flush_pending_lazy_as_silent()
				var lazy_source: String = NovaCompatScript.translate_block(block["content"], _current_namespace)
				_pending_lazy_by_stage[stage] = _join_source(_pending_lazy_by_stage.get(stage, ""), lazy_source)
				_block_attrs = {}
			"text":
				_append_text(block["content"])
	# Flush any trailing lazy block at end of file (no following text).
	_flush_pending_lazy_as_silent()


func _append_text(line: String) -> void:
	if _current_node == null:
		EngineLogScript.warn(EngineLogScript.Category.PARSE, "ScriptLoader", "dialogue text before any label(): '%s'" % line)
		return
	var entry := DialogueEntry.new()
	_apply_pending_lazy(entry)
	var parsed := _split_speaker(line)
	entry.speaker = parsed[0]
	entry.text = parsed[1]
	_current_node.add_entry(entry)


## A lazy block with no following text becomes a silent entry (presentation
## only) so it still executes in sequence.
func _flush_pending_lazy_as_silent() -> void:
	if _pending_lazy_by_stage.is_empty():
		return
	if _current_node == null:
		_pending_lazy_by_stage = {}
		return
	var entry := DialogueEntry.new()
	_apply_pending_lazy(entry)
	entry.is_silent = true
	_current_node.add_entry(entry)


func _apply_pending_lazy(entry: DialogueEntry) -> void:
	entry.lazy_source = str(_pending_lazy_by_stage.get("default", ""))
	entry.before_checkpoint_source = str(_pending_lazy_by_stage.get("before_checkpoint", ""))
	entry.after_dialogue_source = str(_pending_lazy_by_stage.get("after_dialogue", ""))
	_pending_lazy_by_stage = {}


func _stage_from_attrs(attrs: Dictionary) -> String:
	var stage := str(attrs.get("stage", "default")).strip_edges().to_lower()
	match stage:
		"", "default":
			return "default"
		"before_checkpoint":
			return "before_checkpoint"
		"after_dialogue":
			return "after_dialogue"
		_:
			EngineLogScript.warn(EngineLogScript.Category.PARSE, "ScriptLoader", "unknown lazy stage '%s', using default" % stage)
			return "default"


func _join_source(a: Variant, b: String) -> String:
	var left := str(a).strip_edges()
	var right := b.strip_edges()
	if left.is_empty():
		return right
	if right.is_empty():
		return left
	return left + "\n" + right


func _split_speaker(line: String) -> Array:
	var marker := line.find("：：")
	var sep_len := 2
	if marker == -1:
		marker = line.find("::")
		sep_len = 2
	if marker > 0:
		var speaker := line.substr(0, marker).strip_edges()
		var content := line.substr(marker + sep_len).strip_edges()
		if not speaker.is_empty() and not content.is_empty():
			return [speaker, content]
	return ["", line]


# === API called from eager blocks (via BaseBlock) ============================

func label(name: String, display_name = null) -> void:
	var resolved_name := _resolve_label_name(name)
	var resolved_display := ""
	if display_name == null:
		resolved_display = _last_display_name if not _last_display_name.is_empty() else resolved_name
	else:
		resolved_display = str(display_name)
		_last_display_name = resolved_display
	var sn := StringName(resolved_name)
	if graph.has_node_named(sn):
		_current_node = graph.get_node_named(sn)
	else:
		var node := FlowChartNode.new()
		node.name = sn
		node.display_name = resolved_display
		graph.add_node(node)
		_current_node = node


func jump_to(dest: String) -> void:
	if _current_node:
		_current_node.jump_target = StringName(_resolve_label_name(dest))


func branch(branches: Array) -> void:
	if _current_node == null:
		return
	var opts: Array = []
	for b in branches:
		if b is Dictionary:
			var src = b.get("mode", _block_attrs.get("mode", FlowChartNode.BranchMode.NORMAL))
			var cond := NovaCompatScript.translate_condition(str(b.get("cond", _block_attrs.get("cond", ""))).strip_edges())
			var image = b.get("image", _block_attrs.get("image", ""))
			opts.append({
				"dest": StringName(_resolve_label_name(str(b.get("dest", "")))),
				"text": str(b.get("text", "")),
				"mode": _parse_branch_mode(src),
				"cond": cond,
				"image": _normalize_branch_image(image),
			})
	_current_node.branches = opts


func _normalize_branch_image(image: Variant) -> Variant:
	if image is Array:
		return image.duplicate(true)
	return str(image).strip_edges()


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
		_current_node.is_debug = true

func is_start() -> void:
	if _current_node:
		_current_node.type = FlowChartNode.Type.CHAPTER
		_current_node.is_start = true

func is_unlocked_start() -> void:
	if _current_node:
		_current_node.type = FlowChartNode.Type.CHAPTER
		_current_node.is_start = true
		_current_node.is_unlocked_start = true

func is_debug() -> void:
	if _current_node:
		_current_node.is_debug = true

func is_save_point() -> void:
	if _current_node:
		_current_node.is_save_point = true

func is_end(end_name = null) -> void:
	if _current_node:
		_current_node.type = FlowChartNode.Type.END
		if end_name != null:
			_current_node.end_name = str(end_name)


func interpolate_text(text: String) -> String:
	return NovaCompatScript.interpolate_text(text, _ctx.variables)


func _resolve_label_name(name: String) -> String:
	return NovaCompatScript.resolve_label(name, _current_namespace)
