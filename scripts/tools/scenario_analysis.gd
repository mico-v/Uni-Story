class_name ScenarioAnalysis extends RefCounted

## Builds a stable, execution-free intermediate representation for NovaScript.
##
## This source inventory is shared by dialogue statistics today and is shaped
## so flow visualization can consume the same nodes, edges, events, blocks,
## and dialogue entries later. Eager blocks are translated for reference but
## never executed.

const NovaParserScript := preload("res://scripts/core/nova_parser.gd")
const NovaCompatScript := preload("res://scripts/core/nova_script_compat.gd")

const DEFAULT_SCENARIO_DIR := "res://resources/scenarios/"
const NORMALIZATION_VERSION := "visible_v1"

var _files: Array[Dictionary] = []
var _blocks: Array[Dictionary] = []
var _nodes: Array[Dictionary] = []
var _entries: Array[Dictionary] = []
var _silent_entries: Array[Dictionary] = []
var _edges: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _context_labels: Array[Dictionary] = []
var _errors: Array[Dictionary] = []
var _node_index_by_id: Dictionary = {}
var _entry_ordinals_by_path: Dictionary = {}


func analyze_paths(inputs: Array = [], options: Dictionary = {}) -> Dictionary:
	_reset()
	var paths := _collect_paths(inputs)
	if paths.is_empty():
		_errors.append({
			"path": _stable_path(str(inputs.front())) if not inputs.is_empty() else DEFAULT_SCENARIO_DIR,
			"message": "no .txt scenario files found",
		})
	else:
		for path in paths:
			_analyze_file(path)
	_index_context_labels(_collect_context_paths(paths, options))

	_nodes.sort_custom(_node_less)
	_entries.sort_custom(_entry_less)
	_silent_entries.sort_custom(_entry_less)
	_edges.sort_custom(_edge_less)
	_events.sort_custom(_event_less)
	_context_labels.sort_custom(_context_label_less)
	_files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("path", "")) < str(b.get("path", "")))

	# Entry indices are only a convenience during construction. Rebuild stable
	# per-node entry references after the public arrays have been sorted.
	for node in _nodes:
		node["entry_indices"] = []
	for entry_index in range(_entries.size()):
		var node_id := str(_entries[entry_index].get("node", ""))
		for node in _nodes:
			if str(node.get("id", "")) == node_id:
				var indices: Array = node.get("entry_indices", [])
				indices.append(entry_index)
				break

	var eager_blocks := 0
	var lazy_blocks := 0
	for block in _blocks:
		if str(block.get("type", "")) == "eager":
			eager_blocks += 1
		elif str(block.get("type", "")) == "lazy":
			lazy_blocks += 1
	var spoken := 0
	for entry in _entries:
		if bool(entry.get("has_speaker", false)):
			spoken += 1

	return {
		"schema_version": 2,
		"normalization": NORMALIZATION_VERSION,
		"ok": _errors.is_empty(),
		"errors": _errors.duplicate(true),
		"summary": {
			"files": _files.size(),
			"blocks": _blocks.size(),
			"eager_blocks": eager_blocks,
			"lazy_blocks": lazy_blocks,
			"nodes": _nodes.size(),
			"local_nodes": _nodes.filter(func(node: Dictionary) -> bool: return bool(node.get("local", false))).size(),
			"dialogues": _entries.size(),
			"silent_entries": _silent_entries.size(),
			"runtime_entries": _entries.size() + _silent_entries.size(),
			"spoken": spoken,
			"narration": _entries.size() - spoken,
			"edges": _edges.size(),
		},
		"files": _files.duplicate(true),
		"blocks": _blocks.duplicate(true),
		"nodes": _nodes.duplicate(true),
		"entries": _entries.duplicate(true),
		"silent_entries": _silent_entries.duplicate(true),
		"edges": _edges.duplicate(true),
		"events": _events.duplicate(true),
		"context_labels": _context_labels.duplicate(true),
	}


static func strip_paired_rich_tags(value: Variant) -> String:
	var text := str(value)
	if text.is_empty():
		return text
	var regex := RegEx.new()
	if regex.compile("(?s)<([^=>]*)(=[^>]*)?>(.*?)</\\1>") != OK:
		return text
	while true:
		var stripped := regex.sub(text, "$3", true)
		if stripped == text:
			return text
		text = stripped
	return text


static func remove_todo_annotations(value: Variant) -> String:
	var text := str(value)
	if text.is_empty():
		return text
	var regex := RegEx.new()
	if regex.compile("\\r?\\n?（TODO：([^：]*：)?(([^（）]*（[^）]*）)*[^）]*)）") != OK:
		return text
	return regex.sub(text, "", true)


static func normalize_text(value: Variant) -> String:
	var text := remove_todo_annotations(strip_paired_rich_tags(value))
	var spaces := RegEx.new()
	if spaces.compile(" +") == OK:
		text = spaces.sub(text, " ", true)
	return text.strip_edges()


func _reset() -> void:
	_files.clear()
	_blocks.clear()
	_nodes.clear()
	_entries.clear()
	_silent_entries.clear()
	_edges.clear()
	_events.clear()
	_context_labels.clear()
	_errors.clear()
	_node_index_by_id.clear()
	_entry_ordinals_by_path.clear()


func _collect_paths(inputs: Array) -> Array[String]:
	var roots: Array = inputs if not inputs.is_empty() else [DEFAULT_SCENARIO_DIR]
	var found: Dictionary = {}
	for raw_root in roots:
		var original := str(raw_root).strip_edges()
		if original.is_empty():
			_errors.append({"path": original, "message": "scenario input path cannot be empty"})
			continue
		var root := _canonical_storage_path(original)
		if FileAccess.file_exists(root):
			if root.to_lower().ends_with(".txt"):
				found[_path_identity(root)] = root
			else:
				_errors.append({"path": root, "message": "scenario input file must use the .txt extension"})
			continue
		if DirAccess.open(root) == null:
			_errors.append({"path": root, "message": "scenario input path does not exist or is not readable"})
			continue
		_collect_directory(root, found)
	var paths: Array[String] = []
	for path in found.values():
		paths.append(str(path))
	paths.sort()
	return paths


func _collect_directory(path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var child := _canonical_storage_path(path.path_join(name))
			if dir.current_is_dir():
				if not name.begins_with("."):
					_collect_directory(child, found)
			elif name.to_lower().ends_with(".txt"):
				found[_path_identity(child)] = child
		name = dir.get_next()
	dir.list_dir_end()


func _collect_context_paths(selected_paths: Array[String], options: Dictionary) -> Array[String]:
	var selected: Dictionary = {}
	for path in selected_paths:
		selected[_path_identity(path)] = true

	var found: Dictionary = {}
	var context_inputs: Array = []
	var raw_context_paths: Variant = options.get("context_paths", [])
	if raw_context_paths is Array or raw_context_paths is PackedStringArray:
		for raw_path in raw_context_paths:
			context_inputs.append(raw_path)
	elif raw_context_paths != null:
		context_inputs.append(raw_context_paths)
	if not context_inputs.is_empty():
		for path in _collect_paths(context_inputs):
			found[_path_identity(path)] = path

	if bool(options.get("auto_context", false)):
		var needs_default_context := false
		for path in selected_paths:
			if _path_is_within(path, DEFAULT_SCENARIO_DIR):
				needs_default_context = true
				break
		if needs_default_context:
			for path in _collect_paths([DEFAULT_SCENARIO_DIR]):
				found[_path_identity(path)] = path

	for identity in selected.keys():
		found.erase(identity)
	var paths: Array[String] = []
	for path in found.values():
		paths.append(str(path))
	paths.sort()
	return paths


func _index_context_labels(paths: Array[String]) -> void:
	var seen: Dictionary = {}
	for path in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_errors.append({"path": path, "message": "cannot read context scenario: %s" % error_string(FileAccess.get_open_error())})
			continue
		var source := file.get_as_text()
		file.close()
		var physical_lines := source.split("\n")
		var ns := NovaCompatScript.namespace_for_path(path)
		var last_display_name := ""
		for raw_block in NovaParserScript.tokenize(source):
			var block: Dictionary = raw_block
			if str(block.get("type", "")) != "eager":
				continue
			var content := _mask_line_comments(str(block.get("content", "")))
			var base_line := int(block.get("content_line", _block_content_base_line(physical_lines, block)))
			var base_column := int(block.get("content_column", 1))
			var label_regex := _regex("\\blabel\\s*(?:\\(\\s*)?['\"]([^'\"]*)['\"](?:\\s*,\\s*['\"]([^'\"]*)['\"])?")
			for match in label_regex.search_all(content):
				if not _is_unqualified_runtime_identifier(content, match.get_start()):
					continue
				var raw_name := match.get_string(1)
				var resolved := NovaCompatScript.resolve_label(raw_name, ns)
				var has_display := match.get_start(2) >= 0
				var display_name := match.get_string(2) if has_display else (last_display_name if not last_display_name.is_empty() else resolved)
				if has_display:
					last_display_name = display_name
				if _node_index_by_id.has(resolved) or seen.has(resolved):
					continue
				seen[resolved] = true
				_context_labels.append({
					"id": resolved,
					"raw_name": raw_name,
					"display_name": display_name,
					"namespace": ns,
					"local": raw_name.begins_with(NovaCompatScript.LOCAL_LABEL_PREFIX),
					"path": path,
					"line": _line_for_offset(content, base_line, match.get_start()),
					"column": _column_for_offset(content, match.get_start(), base_column),
				})


func _analyze_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append({"path": path, "message": "cannot read scenario: %s" % error_string(FileAccess.get_open_error())})
		return
	var source := file.get_as_text()
	file.close()

	var file_block_start := _blocks.size()
	var file_entry_start := _entries.size()
	var file_silent_start := _silent_entries.size()
	var file_edge_start := _edges.size()
	var physical_lines := source.split("\n")
	var ns := NovaCompatScript.namespace_for_path(path)
	var current_node_index := -1
	var pending_lazy: Array[Dictionary] = []
	var canonical_by_display: Dictionary = {}
	var last_display_name := ""

	for raw_block in NovaParserScript.tokenize(source):
		var block: Dictionary = raw_block
		var block_type := str(block.get("type", ""))
		var content := str(block.get("content", ""))
		var line := int(block.get("line", 1))

		if block_type == "text":
			if current_node_index < 0 or current_node_index >= _nodes.size():
				_errors.append({
					"path": path,
					"line": line,
					"column": 1,
					"message": "dialogue text appears before any label()",
				})
				continue
			var split := _split_speaker(content, canonical_by_display)
			canonical_by_display = split.get("aliases", canonical_by_display)
			var text := str(split.get("text", content))
			var without_rich := strip_paired_rich_tags(text)
			var normalized := normalize_text(text)
			var node_id := str(_nodes[current_node_index].get("id", ""))
			var raw_node := str(_nodes[current_node_index].get("raw_name", ""))
			var entry_id := _allocate_entry_id(path)
			var entry := {
				"entry_id": entry_id,
				"path": path,
				"line": line,
				"node": node_id,
				"raw_node": raw_node,
				"raw_line": content,
				"raw_text": text,
				"text_without_rich_tags": without_rich,
				"normalized_text": normalized,
				"length": normalized.length(),
				"has_speaker": bool(split.get("has_speaker", false)),
				"display_speaker": str(split.get("display_speaker", "")),
				"canonical_speaker": str(split.get("canonical_speaker", "")),
				"dynamic_speaker": str(split.get("display_speaker", "")).contains("{{") or str(split.get("canonical_speaker", "")).contains("{{"),
				"lazy_blocks": pending_lazy.duplicate(true),
			}
			_entries.append(entry)
			_scan_lazy_flow_edges(current_node_index, pending_lazy, entry_id)
			pending_lazy.clear()
			continue

		var translated := NovaCompatScript.translate_block(content, ns)
		var content_line := int(block.get("content_line", _block_content_base_line(physical_lines, block)))
		var content_column := int(block.get("content_column", 1))
		var analysis_block := {
			"path": path,
			"line": line,
			"content_line": content_line,
			"content_column": content_column,
			"type": block_type,
			"attrs": (block.get("attrs", {}) as Dictionary).duplicate(true),
			"content": content,
			"translated_content": translated,
		}
		_blocks.append(analysis_block)

		if block_type == "lazy":
			var stage := _stage_from_attrs(analysis_block.get("attrs", {}))
			var has_pending_default := false
			for pending in pending_lazy:
				if str(pending.get("stage", "default")) == "default":
					has_pending_default = true
					break
			if stage == "default" and has_pending_default:
				# ScriptLoader turns the older set into a silent entry. Dialogue
				# statistics intentionally inventory only source text entries.
				_flush_pending_as_silent(current_node_index, pending_lazy)
			var lazy_record: Dictionary = analysis_block.duplicate(true)
			lazy_record["stage"] = stage
			pending_lazy.append(lazy_record)
			continue

		# Eager execution flushes pending lazy blocks into a silent runtime
		# entry before running. They therefore do not precede later text.
		_flush_pending_as_silent(current_node_index, pending_lazy)
		var scan_content := _mask_line_comments(content)
		var base_line := int(analysis_block.get("content_line", line))
		var base_column := int(analysis_block.get("content_column", 1))
		var block_events := _scan_eager_events(scan_content, base_line, base_column, analysis_block.get("attrs", {}))
		for raw_event in block_events:
			var event: Dictionary = raw_event
			var kind := str(event.get("kind", ""))
			var event_line := int(event.get("line", line))
			if kind == "label":
				var raw_name := str(event.get("raw", ""))
				var resolved := NovaCompatScript.resolve_label(raw_name, ns)
				var explicit_display := bool(event.get("has_display", false))
				var resolved_display := str(event.get("display", "")) if explicit_display else (last_display_name if not last_display_name.is_empty() else resolved)
				if explicit_display:
					last_display_name = resolved_display
				canonical_by_display = {}
				if _node_index_by_id.has(resolved):
					current_node_index = int(_node_index_by_id[resolved])
				else:
					current_node_index = _nodes.size()
					_node_index_by_id[resolved] = current_node_index
					_nodes.append({
						"id": resolved,
						"raw_name": raw_name,
						"display_name": resolved_display,
						"namespace": ns,
						"local": raw_name.begins_with(NovaCompatScript.LOCAL_LABEL_PREFIX),
						"path": path,
						"line": event_line,
						"column": int(event.get("column", 1)),
						"type": "normal",
						"is_start": false,
						"is_unlocked_start": false,
						"is_debug": false,
						"is_save_point": false,
						"end_name": "",
						"entry_indices": [],
					})
				_events.append(_public_event(path, event_line, resolved, event))
				continue

			var current_id := ""
			if current_node_index >= 0 and current_node_index < _nodes.size():
				current_id = str(_nodes[current_node_index].get("id", ""))
			if kind in ["jump_to", "jump_if", "branch"]:
				var target_kind := str(event.get("target_kind", "literal"))
				var raw_target := str(event.get("raw", ""))
				var target := NovaCompatScript.resolve_label(raw_target, ns) if target_kind == "literal" else ""
				var group_id := ""
				if kind == "branch":
					group_id = "%s#branch:%d:%d" % [path, int(event.get("group_line", event_line)), int(event.get("group_column", event.get("column", 1)))]
				var edge := {
					"path": path,
					"line": event_line,
					"column": int(event.get("column", 1)),
					"source": current_id,
					"target": target,
					"raw_target": raw_target,
					"target_kind": target_kind,
					"target_expression": str(event.get("target_expression", "")),
					"kind": kind,
					"phase": "eager",
					"stage": "",
					"entry_id": "",
					"group_id": group_id,
					"option_index": int(event.get("option_index", -1)),
					"text": str(event.get("text", "")),
					"mode": str(event.get("mode", "")),
					"condition_raw": str(event.get("condition_raw", "")),
					"condition_normalized": str(event.get("condition_normalized", "")),
					"image_raw": str(event.get("image_raw", "")),
				}
				_edges.append(edge)
				_events.append(_public_event(path, event_line, current_id, event))
				continue

			if current_node_index < 0 or current_node_index >= _nodes.size():
				_events.append(_public_event(path, event_line, "", event))
				continue
			var node: Dictionary = _nodes[current_node_index]
			match kind:
				"is_chapter":
					node["type"] = "chapter"
				"is_start":
					node["type"] = "chapter"
					node["is_start"] = true
				"is_unlocked_start":
					node["type"] = "chapter"
					node["is_start"] = true
					node["is_unlocked_start"] = true
				"is_debug":
					node["is_debug"] = true
				"is_save_point":
					node["is_save_point"] = true
				"is_end":
					node["type"] = "end"
					if bool(event.get("has_end_name", false)):
						node["end_name"] = str(event.get("end_name", ""))
			_nodes[current_node_index] = node
			_events.append(_public_event(path, event_line, str(node.get("id", "")), event))

	_flush_pending_as_silent(current_node_index, pending_lazy)
	var file_nodes := 0
	for node in _nodes:
		if str(node.get("path", "")) == path:
			file_nodes += 1
	_files.append({
		"path": path,
		"namespace": ns,
		"blocks": _blocks.size() - file_block_start,
		"nodes": file_nodes,
		"dialogues": _entries.size() - file_entry_start,
		"silent_entries": _silent_entries.size() - file_silent_start,
		"edges": _edges.size() - file_edge_start,
	})


func _flush_pending_as_silent(current_node_index: int, pending_lazy: Array[Dictionary]) -> void:
	if pending_lazy.is_empty():
		return
	if current_node_index >= 0 and current_node_index < _nodes.size():
		var node: Dictionary = _nodes[current_node_index]
		var first_block: Dictionary = pending_lazy.front()
		var path := str(first_block.get("path", node.get("path", "")))
		var entry_id := _allocate_entry_id(path)
		_silent_entries.append({
			"entry_id": entry_id,
			"path": path,
			"line": int(first_block.get("line", node.get("line", 1))),
			"node": str(node.get("id", "")),
			"raw_node": str(node.get("raw_name", "")),
			"is_silent": true,
			"lazy_blocks": pending_lazy.duplicate(true),
		})
		_scan_lazy_flow_edges(current_node_index, pending_lazy, entry_id)
	pending_lazy.clear()


func _split_speaker(line: String, aliases: Dictionary) -> Dictionary:
	var updated_aliases := aliases.duplicate(true)
	var marker := line.find("：：")
	if marker == -1:
		marker = line.find("::")
	if marker > 0:
		var raw_speaker := line.substr(0, marker).strip_edges()
		var content := line.substr(marker + 2).strip_edges()
		var display_name := raw_speaker
		var canonical_name := ""
		var hidden_marker := raw_speaker.find("//")
		if hidden_marker >= 0:
			display_name = raw_speaker.substr(0, hidden_marker).strip_edges()
			canonical_name = raw_speaker.substr(hidden_marker + 2).strip_edges()
			if not display_name.is_empty() and not canonical_name.is_empty():
				updated_aliases[display_name] = canonical_name
		elif not display_name.is_empty():
			canonical_name = str(updated_aliases.get(display_name, display_name))
		if not display_name.is_empty() and not content.is_empty():
			if canonical_name.is_empty():
				canonical_name = display_name
			return {
				"has_speaker": true,
				"display_speaker": display_name,
				"canonical_speaker": canonical_name,
				"text": content,
				"aliases": updated_aliases,
			}
	return {
		"has_speaker": false,
		"display_speaker": "",
		"canonical_speaker": "",
		"text": line,
		"aliases": updated_aliases,
	}


func _scan_eager_events(content: String, base_line: int, base_column: int = 1, raw_attrs: Variant = {}) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var label_regex := _regex("\\blabel\\s*(?:\\(\\s*)?['\"]([^'\"]*)['\"](?:\\s*,\\s*['\"]([^'\"]*)['\"])?")
	for match in label_regex.search_all(content):
		if not _is_unqualified_runtime_identifier(content, match.get_start()):
			continue
		found.append({
			"offset": match.get_start(),
			"kind": "label",
			"raw": match.get_string(1),
			"has_display": match.get_start(2) >= 0,
			"display": match.get_string(2),
		})
	for kind in ["is_chapter", "is_start", "is_unlocked_start", "is_debug", "is_save_point"]:
		for match in _regex("\\b%s\\s*\\(" % kind).search_all(content):
			if not _is_unqualified_runtime_identifier(content, match.get_start()):
				continue
			found.append({"offset": match.get_start(), "kind": kind})
	_append_is_end_events(found, content)
	_append_jump_to_events(found, content)
	_append_jump_if_events(found, content)
	_append_branch_events(found, content, raw_attrs)
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_offset := int(a.get("offset", 0))
		var b_offset := int(b.get("offset", 0))
		if a_offset != b_offset:
			return a_offset < b_offset
		return _event_priority(str(a.get("kind", ""))) < _event_priority(str(b.get("kind", "")))
	)
	for event in found:
		event["line"] = _line_for_offset(content, base_line, int(event.get("offset", 0)))
		event["column"] = _column_for_offset(content, int(event.get("offset", 0)), base_column)
		if event.has("group_offset"):
			event["group_line"] = _line_for_offset(content, base_line, int(event.get("group_offset", 0)))
			event["group_column"] = _column_for_offset(content, int(event.get("group_offset", 0)), base_column)
	return found


func _append_is_end_events(events: Array[Dictionary], content: String) -> void:
	for call in _find_runtime_calls(content, "is_end", true):
		var end_name := ""
		var end_name_expression := ""
		var has_end_name := false
		var arguments: Array = call.get("arguments", [])
		if not arguments.is_empty():
			var argument_text := _range_text(content, arguments[0])
			if not argument_text.is_empty() and argument_text not in ["null", "nil"]:
				has_end_name = true
				var literal := _string_value_in_range(content, arguments[0])
				if bool(literal.get("ok", false)):
					end_name = str(literal.get("value", ""))
				else:
					end_name_expression = argument_text
		events.append({
			"offset": int(call.get("offset", 0)),
			"kind": "is_end",
			"has_end_name": has_end_name,
			"end_name": end_name,
			"end_name_expression": end_name_expression,
		})


func _append_jump_to_events(events: Array[Dictionary], content: String) -> void:
	for call in _find_runtime_calls(content, "jump_to", true):
		var arguments: Array = call.get("arguments", [])
		if arguments.is_empty():
			continue
		var target := _target_fields_for_range(content, arguments[0])
		if target.is_empty():
			continue
		target["offset"] = int(call.get("offset", 0))
		target["kind"] = "jump_to"
		events.append(target)


func _append_jump_if_events(events: Array[Dictionary], content: String) -> void:
	for call in _find_runtime_calls(content, "jump_if", false):
		var arguments: Array = call.get("arguments", [])
		if arguments.size() < 2:
			continue
		var target := _target_fields_for_range(content, arguments[1])
		if target.is_empty():
			continue
		var condition_raw := _range_text(content, arguments[0])
		target["offset"] = int(call.get("offset", 0))
		target["kind"] = "jump_if"
		target["condition_raw"] = condition_raw
		target["condition_normalized"] = NovaCompatScript.translate_condition(condition_raw)
		events.append(target)


func _append_branch_events(events: Array[Dictionary], content: String, raw_attrs: Variant) -> void:
	var attrs: Dictionary = raw_attrs if raw_attrs is Dictionary else {}
	for match in _regex("\\bbranch\\b").search_all(content):
		if not _is_unqualified_runtime_identifier(content, match.get_start()):
			continue
		var container_start := _find_branch_container_start(content, match.get_end())
		if container_start < 0:
			continue
		var close_index := _find_matching_delimiter(content, container_start)
		if close_index < 0:
			continue
		var option_ranges := _branch_option_ranges(content, container_start, close_index)
		for option_index in range(option_ranges.size()):
			var option_range: Dictionary = option_ranges[option_index]
			var dest_range := _field_value_range(content, option_range, "dest")
			if dest_range.is_empty():
				continue
			var target := _target_fields_for_range(content, dest_range)
			if target.is_empty():
				continue
			var text_range := _field_value_range(content, option_range, "text")
			var mode_range := _field_value_range(content, option_range, "mode")
			var condition_range := _field_value_range(content, option_range, "cond")
			var image_range := _field_value_range(content, option_range, "image")
			var condition_raw := _value_or_expression(content, condition_range) if not condition_range.is_empty() else str(attrs.get("cond", "")).strip_edges()
			target["offset"] = int(dest_range.get("key_start", dest_range.get("start", match.get_start())))
			target["group_offset"] = match.get_start()
			target["kind"] = "branch"
			target["option_index"] = option_index
			target["text"] = _value_or_expression(content, text_range)
			target["mode"] = _normalize_branch_mode(_value_or_expression(content, mode_range) if not mode_range.is_empty() else str(attrs.get("mode", "normal")))
			target["condition_raw"] = condition_raw
			target["condition_normalized"] = NovaCompatScript.translate_condition(condition_raw) if not condition_raw.is_empty() else ""
			target["image_raw"] = _value_or_expression(content, image_range) if not image_range.is_empty() else str(attrs.get("image", "")).strip_edges()
			events.append(target)


func _find_branch_container_start(content: String, call_end: int) -> int:
	var opening := _skip_whitespace(content, call_end)
	if opening >= content.length():
		return -1
	var character := content.substr(opening, 1)
	if character in ["{", "["]:
		return opening
	if character != "(":
		return -1
	var close_index := _find_matching_delimiter(content, opening)
	if close_index < 0:
		return -1
	var inner := _skip_whitespace(content, opening + 1)
	if inner < close_index and content.substr(inner, 1) in ["{", "["]:
		return inner
	return -1


func _branch_option_ranges(content: String, container_start: int, container_end: int) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	var stack: Array[String] = [content.substr(container_start, 1)]
	var quote := ""
	var escaped := false
	var option_start := -1
	for cursor in range(container_start + 1, container_end + 1):
		var character := content.substr(cursor, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "'" or character == "\"":
			quote = character
		elif character in ["{", "[", "("]:
			if character == "{" and stack.size() == 1:
				option_start = cursor
			stack.append(character)
		elif character in ["}", "]", ")"] and not stack.is_empty():
			var expected := "{" if character == "}" else ("[" if character == "]" else "(")
			if stack.back() == expected:
				stack.pop_back()
				if option_start >= 0 and stack.size() == 1:
					ranges.append({"start": option_start, "end": cursor + 1})
					option_start = -1
	return ranges


func _field_value_range(content: String, option_range: Dictionary, key: String) -> Dictionary:
	var option_start := int(option_range.get("start", 0))
	var option_end := int(option_range.get("end", option_start))
	var option_text := content.substr(option_start, maxi(option_end - option_start, 0))
	var regex := _regex("(?:['\"]%s['\"]|\\b%s\\b)\\s*(?:=|:)" % [key, key])
	var search_from := 0
	while search_from < option_text.length():
		var match := regex.search(option_text, search_from)
		if match == null:
			break
		search_from = maxi(match.get_end(), match.get_start() + 1)
		var key_start := option_start + match.get_start()
		if not _is_top_level_option_field(content, option_start, key_start):
			continue
		var value_start := _skip_whitespace(content, option_start + match.get_end())
		var value_end := _expression_end(content, value_start, maxi(option_end - 1, value_start))
		var out := _trimmed_range(content, value_start, value_end)
		out["key_start"] = key_start
		return out
	return {}


func _is_top_level_option_field(content: String, option_start: int, field_start: int) -> bool:
	var stack: Array[String] = []
	var quote := ""
	var escaped := false
	var pairs := {"(": ")", "[": "]", "{": "}"}
	for i in range(option_start, field_start):
		var character := content.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "'" or character == "\"":
			quote = character
		elif pairs.has(character):
			stack.append(str(pairs[character]))
		elif not stack.is_empty() and character == stack.back():
			stack.pop_back()
	return quote.is_empty() and stack.size() == 1 and stack.back() == "}"


func _is_unqualified_runtime_identifier(content: String, offset: int) -> bool:
	if _offset_is_in_string(content, offset):
		return false
	var i := offset - 1
	while i >= 0:
		var character := content.substr(i, 1)
		if character == "\n" or character == "\r":
			return true
		if character == " " or character == "\t":
			i -= 1
			continue
		if character == "." or character == ":":
			return false
		if _is_identifier_character(character):
			var word_end := i + 1
			while i >= 0 and _is_identifier_character(content.substr(i, 1)):
				i -= 1
			var previous_word := content.substr(i + 1, word_end - i - 1)
			return previous_word not in ["func", "signal", "class_name"]
		return true
	return true


func _is_dictionary_key_position(content: String, offset: int) -> bool:
	var i := offset - 1
	while i >= 0:
		var character := content.substr(i, 1)
		if character == " " or character == "\t" or character == "\r" or character == "\n":
			i -= 1
			continue
		return character in ["{", "[", "(", ","]
	return true


func _skip_whitespace(content: String, offset: int) -> int:
	var i := clampi(offset, 0, content.length())
	while i < content.length() and content.substr(i, 1) in [" ", "\t", "\r", "\n"]:
		i += 1
	return i


func _find_matching_delimiter(content: String, open_index: int) -> int:
	var pairs := {"(": ")", "[": "]", "{": "}"}
	var opening := content.substr(open_index, 1)
	if not pairs.has(opening):
		return -1
	var stack: Array[String] = [str(pairs[opening])]
	var quote := ""
	var escaped := false
	for i in range(open_index + 1, content.length()):
		var character := content.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "'" or character == "\"":
			quote = character
		elif pairs.has(character):
			stack.append(str(pairs[character]))
		elif not stack.is_empty() and character == stack.back():
			stack.pop_back()
			if stack.is_empty():
				return i
	return -1


func _split_top_level_ranges(content: String, start: int, end: int) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	var stack: Array[String] = []
	var quote := ""
	var escaped := false
	var argument_start := start
	var pairs := {"(": ")", "[": "]", "{": "}"}
	for i in range(start, end):
		var character := content.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "'" or character == "\"":
			quote = character
		elif pairs.has(character):
			stack.append(str(pairs[character]))
		elif not stack.is_empty() and character == stack.back():
			stack.pop_back()
		elif character == "," and stack.is_empty():
			ranges.append(_trimmed_range(content, argument_start, i))
			argument_start = i + 1
	ranges.append(_trimmed_range(content, argument_start, end))
	return ranges


func _trimmed_range(content: String, start: int, end: int) -> Dictionary:
	var trimmed_start := start
	var trimmed_end := end
	while trimmed_start < trimmed_end and content.substr(trimmed_start, 1) in [" ", "\t", "\r", "\n"]:
		trimmed_start += 1
	while trimmed_end > trimmed_start and content.substr(trimmed_end - 1, 1) in [" ", "\t", "\r", "\n"]:
		trimmed_end -= 1
	return {"start": trimmed_start, "end": trimmed_end}


func _string_value_in_range(content: String, raw_range: Dictionary) -> Dictionary:
	var start := int(raw_range.get("start", 0))
	var end := int(raw_range.get("end", 0))
	if start >= end:
		return {"ok": false}
	var quote := content.substr(start, 1)
	if quote != "'" and quote != "\"":
		return {"ok": false}
	var escaped := false
	for i in range(start + 1, end):
		var character := content.substr(i, 1)
		if escaped:
			escaped = false
		elif character == "\\":
			escaped = true
		elif character == quote:
			if i != end - 1:
				return {"ok": false}
			return {"ok": true, "value": content.substr(start + 1, i - start - 1).c_unescape()}
	return {"ok": false}


func _is_identifier_character(character: String) -> bool:
	return character == "_" or (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9")


func _find_runtime_calls(content: String, name: String, allow_shorthand: bool) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	for match in _regex("\\b%s\\b" % name).search_all(content):
		var offset := match.get_start()
		if not _is_unqualified_runtime_identifier(content, offset):
			continue
		var cursor := _skip_inline_whitespace(content, match.get_end())
		if cursor < content.length() and content.substr(cursor, 1) in ["=", ":"]:
			continue
		if cursor < content.length() and content.substr(cursor, 1) == "(":
			var close_index := _find_matching_delimiter(content, cursor)
			if close_index >= 0:
				calls.append({
					"offset": offset,
					"arguments": _split_top_level_ranges(content, cursor + 1, close_index),
				})
			continue
		if not allow_shorthand:
			continue
		var statement_end := _statement_end(content, cursor)
		var argument := _trimmed_range(content, cursor, statement_end)
		if int(argument.get("start", 0)) < int(argument.get("end", 0)):
			calls.append({"offset": offset, "arguments": [argument]})
	return calls


func _target_fields_for_range(content: String, raw_range: Dictionary) -> Dictionary:
	var expression := _range_text(content, raw_range)
	if expression.is_empty():
		return {}
	var literal := _string_value_in_range(content, raw_range)
	if bool(literal.get("ok", false)):
		return {
			"target_kind": "literal",
			"raw": str(literal.get("value", "")),
			"target_expression": "",
		}
	return {
		"target_kind": "dynamic",
		"raw": "",
		"target_expression": expression,
	}


func _range_text(content: String, raw_range: Dictionary) -> String:
	var start := int(raw_range.get("start", 0))
	var end := int(raw_range.get("end", start))
	return content.substr(start, maxi(end - start, 0)).strip_edges()


func _value_or_expression(content: String, raw_range: Dictionary) -> String:
	if raw_range.is_empty():
		return ""
	var literal := _string_value_in_range(content, raw_range)
	return str(literal.get("value", "")) if bool(literal.get("ok", false)) else _range_text(content, raw_range)


func _normalize_branch_mode(value: Variant) -> String:
	var mode := str(value).strip_edges().to_lower()
	match mode:
		"1", "jump":
			return "jump"
		"2", "show":
			return "show"
		"3", "enable":
			return "enable"
		_:
			return "normal"


func _expression_end(content: String, start: int, limit: int) -> int:
	var stack: Array[String] = []
	var quote := ""
	var escaped := false
	var pairs := {"(": ")", "[": "]", "{": "}"}
	for i in range(start, limit):
		var character := content.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "'" or character == "\"":
			quote = character
		elif pairs.has(character):
			stack.append(str(pairs[character]))
		elif not stack.is_empty() and character == stack.back():
			stack.pop_back()
		elif character == "," and stack.is_empty():
			return i
	return limit


func _skip_inline_whitespace(content: String, offset: int) -> int:
	var i := clampi(offset, 0, content.length())
	while i < content.length() and content.substr(i, 1) in [" ", "\t", "\r"]:
		i += 1
	return i


func _statement_end(content: String, offset: int) -> int:
	var newline := content.find("\n", offset)
	var semicolon := content.find(";", offset)
	var end := content.length()
	if newline >= 0:
		end = mini(end, newline)
	if semicolon >= 0:
		end = mini(end, semicolon)
	return end


func _allocate_entry_id(path: String) -> String:
	var ordinal := int(_entry_ordinals_by_path.get(path, 0)) + 1
	_entry_ordinals_by_path[path] = ordinal
	return "%s#entry:%06d" % [path, ordinal]


func _scan_lazy_flow_edges(current_node_index: int, lazy_blocks: Array[Dictionary], entry_id: String) -> void:
	if current_node_index < 0 or current_node_index >= _nodes.size() or lazy_blocks.is_empty():
		return
	var node: Dictionary = _nodes[current_node_index]
	var source := str(node.get("id", ""))
	for block in lazy_blocks:
		var block_path := str(block.get("path", node.get("path", "")))
		var ns := NovaCompatScript.namespace_for_path(block_path)
		var content := _mask_line_comments(str(block.get("content", "")))
		var raw_events: Array[Dictionary] = []
		_append_jump_to_events(raw_events, content)
		_append_jump_if_events(raw_events, content)
		raw_events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("offset", 0)) < int(b.get("offset", 0)))
		var base_line := int(block.get("content_line", block.get("line", 1)))
		var base_column := int(block.get("content_column", 1))
		for event in raw_events:
			var offset := int(event.get("offset", 0))
			var target_kind := str(event.get("target_kind", "literal"))
			var raw_target := str(event.get("raw", ""))
			_edges.append({
				"path": block_path,
				"line": _line_for_offset(content, base_line, offset),
				"column": _column_for_offset(content, offset, base_column),
				"source": source,
				"target": NovaCompatScript.resolve_label(raw_target, ns) if target_kind == "literal" else "",
				"raw_target": raw_target,
				"target_kind": target_kind,
				"target_expression": str(event.get("target_expression", "")),
				"kind": str(event.get("kind", "")),
				"phase": "lazy",
				"stage": str(block.get("stage", "default")),
				"entry_id": entry_id,
				"group_id": "",
				"option_index": -1,
				"text": "",
				"mode": "",
				"condition_raw": str(event.get("condition_raw", "")),
				"condition_normalized": str(event.get("condition_normalized", "")),
				"image_raw": "",
			})


func _public_event(path: String, line: int, node: String, event: Dictionary) -> Dictionary:
	var out := {
		"path": path,
		"line": line,
		"column": int(event.get("column", 1)),
		"node": node,
		"kind": str(event.get("kind", "")),
		"phase": "eager",
	}
	if event.has("raw"):
		out["raw"] = str(event.get("raw", ""))
	for key in ["target_kind", "target_expression", "condition_raw", "condition_normalized", "option_index", "end_name", "end_name_expression", "has_end_name"]:
		if event.has(key):
			out[key] = event.get(key)
	return out


func _stage_from_attrs(raw_attrs: Variant) -> String:
	if not (raw_attrs is Dictionary):
		return "default"
	var stage := str((raw_attrs as Dictionary).get("stage", "default")).strip_edges().to_lower()
	return stage if stage in ["before_checkpoint", "after_dialogue"] else "default"


func _block_content_base_line(lines: PackedStringArray, block: Dictionary) -> int:
	var start := maxi(int(block.get("line", 1)), 1)
	if start > lines.size():
		return start
	var opening := str(lines[start - 1]).strip_edges()
	var open_at := opening.find("<|")
	if open_at == -1:
		return start
	var tail := opening.substr(open_at + 2)
	var close_at := tail.find("|>")
	if close_at != -1:
		tail = tail.substr(0, close_at)
	return start if not tail.strip_edges().is_empty() else start + 1


func _mask_line_comments(content: String) -> String:
	var lines: Array[String] = []
	for raw_line in content.split("\n"):
		var line := str(raw_line)
		var quote := ""
		var escaped := false
		var marker := -1
		var i := 0
		while i < line.length():
			var character := line.substr(i, 1)
			if not quote.is_empty():
				if escaped:
					escaped = false
				elif character == "\\":
					escaped = true
				elif character == quote:
					quote = ""
			elif character == "'" or character == "\"":
				quote = character
			elif character == "#":
				marker = i
				break
			elif character == "-" and i + 1 < line.length() and line.substr(i + 1, 1) == "-":
				marker = i
				break
			i += 1
		lines.append(line if marker < 0 else line.substr(0, marker) + " ".repeat(line.length() - marker))
	return "\n".join(lines)


func _offset_is_in_string(content: String, offset: int) -> bool:
	var quote := ""
	var escaped := false
	for i in range(clampi(offset, 0, content.length())):
		var character := content.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
		elif character == "'" or character == "\"":
			quote = character
	return not quote.is_empty()


func _line_for_offset(content: String, base_line: int, offset: int) -> int:
	return base_line if offset <= 0 else base_line + content.substr(0, offset).count("\n")


func _column_for_offset(content: String, offset: int, base_column: int = 1) -> int:
	if offset <= 0:
		return base_column
	var prefix := content.substr(0, offset)
	var newline := prefix.rfind("\n")
	return base_column + offset if newline < 0 else offset - newline


func _regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex


static func _event_priority(kind: String) -> int:
	return 0 if kind == "label" else 1


static func _canonical_storage_path(path: String) -> String:
	var normalized := path.replace("\\", "/").simplify_path()
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	if normalized.to_lower().begins_with(user_root.to_lower() + "/"):
		return "user://" + normalized.substr(user_root.length() + 1).simplify_path()
	var localized := ProjectSettings.localize_path(normalized)
	if localized.begins_with("res://") or localized.begins_with("user://"):
		return localized.simplify_path()
	return normalized


static func _stable_path(path: String) -> String:
	return _canonical_storage_path(path)


static func _path_identity(path: String) -> String:
	return path.to_lower() if OS.get_name() == "Windows" else path


static func _path_is_within(path: String, root: String) -> bool:
	var path_identity := _path_identity(_canonical_storage_path(path)).trim_suffix("/")
	var root_identity := _path_identity(_canonical_storage_path(root)).trim_suffix("/")
	return path_identity == root_identity or path_identity.begins_with(root_identity + "/")


static func _node_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("path", ""))
	var b_path := str(b.get("path", ""))
	if a_path != b_path:
		return a_path < b_path
	var a_line := int(a.get("line", 0))
	var b_line := int(b.get("line", 0))
	if a_line != b_line:
		return a_line < b_line
	return str(a.get("id", "")) < str(b.get("id", ""))


static func _entry_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("path", ""))
	var b_path := str(b.get("path", ""))
	if a_path != b_path:
		return a_path < b_path
	var a_line := int(a.get("line", 0))
	var b_line := int(b.get("line", 0))
	if a_line != b_line:
		return a_line < b_line
	var a_node := str(a.get("node", ""))
	var b_node := str(b.get("node", ""))
	if a_node != b_node:
		return a_node < b_node
	return str(a.get("entry_id", "")) < str(b.get("entry_id", ""))


static func _edge_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("path", ""))
	var b_path := str(b.get("path", ""))
	if a_path != b_path:
		return a_path < b_path
	var a_line := int(a.get("line", 0))
	var b_line := int(b.get("line", 0))
	if a_line != b_line:
		return a_line < b_line
	var a_column := int(a.get("column", 1))
	var b_column := int(b.get("column", 1))
	if a_column != b_column:
		return a_column < b_column
	for field in ["source", "phase", "stage", "entry_id", "group_id"]:
		var a_value := str(a.get(field, ""))
		var b_value := str(b.get(field, ""))
		if a_value != b_value:
			return a_value < b_value
	var a_option_index := int(a.get("option_index", -1))
	var b_option_index := int(b.get("option_index", -1))
	if a_option_index != b_option_index:
		return a_option_index < b_option_index
	for field in ["kind", "target_kind", "target", "raw_target", "target_expression", "condition_raw", "condition_normalized", "text", "mode", "image_raw"]:
		var a_value := str(a.get(field, ""))
		var b_value := str(b.get(field, ""))
		if a_value != b_value:
			return a_value < b_value
	return false


static func _context_label_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("path", ""))
	var b_path := str(b.get("path", ""))
	if a_path != b_path:
		return a_path < b_path
	var a_line := int(a.get("line", 0))
	var b_line := int(b.get("line", 0))
	if a_line != b_line:
		return a_line < b_line
	var a_column := int(a.get("column", 1))
	var b_column := int(b.get("column", 1))
	if a_column != b_column:
		return a_column < b_column
	return str(a.get("id", "")) < str(b.get("id", ""))


static func _event_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("path", ""))
	var b_path := str(b.get("path", ""))
	if a_path != b_path:
		return a_path < b_path
	var a_line := int(a.get("line", 0))
	var b_line := int(b.get("line", 0))
	if a_line != b_line:
		return a_line < b_line
	var a_column := int(a.get("column", 1))
	var b_column := int(b.get("column", 1))
	if a_column != b_column:
		return a_column < b_column
	return str(a.get("kind", "")) < str(b.get("kind", ""))
