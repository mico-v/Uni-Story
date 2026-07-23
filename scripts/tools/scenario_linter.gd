class_name ScenarioLinter extends RefCounted

## Static checks for Nova scenario sources.
##
## The linter deliberately returns plain Dictionary/Array data so the CLI can
## emit either human-readable diagnostics or stable JSON for editor/CI tools.

const NovaParserScript := preload("res://scripts/core/nova_parser.gd")
const NovaCompatScript := preload("res://scripts/core/nova_script_compat.gd")

const DEFAULT_SCENARIO_DIR := "res://resources/scenarios/"
const DEFAULT_RESOURCE_ROOT := "res://resources/"
const DEFAULT_STANDING_PROFILE := "res://resources/standing_profile.tres"
const DEFAULT_VISUAL_PROFILE := "res://resources/visual_profile.tres"
const DEFAULT_AUTO_VOICE_PROFILE := "res://resources/auto_voice_profile.tres"
const RESOURCE_EXTENSIONS := [".png", ".jpg", ".jpeg", ".webp", ".ogg", ".mp3", ".wav", ".tscn", ".tres", ".mp4", ".gdshader"]
const VIRTUAL_PREFIXES := ["RenderTargets/"]
const NO_OP_APIS := [
	"box_tint", "avatar_show", "anim_hold_begin", "anim_hold_end",
	"stop_auto_ff", "stop_ff", "input_on", "input_off",
	"ff_shortcut_on", "ff_shortcut_off", "auto_fade_on", "auto_fade_off",
	"auto_time", "immediate_step", "minigame", "text_delay",
	"text_duration", "text_scroll", "box_anchor", "box_alignment",
	"new_page", "volume",
]
const ANIMATION_NO_OP_APIS := [
	"volume", "wait", "wait_all", "stop", "loop", "box_anchor", "box_tint",
]

var _options: Dictionary = {}
var _issues: Array[Dictionary] = []
var _labels: Dictionary = {}
var _external_labels: Dictionary = {}
var _has_partial_default_context := false
var _references: Array[Dictionary] = []
var _resource_seen: Dictionary = {}
var _entry_nodes: Dictionary = {}
var _first_label: Dictionary = {}
var _first_input_path := ""
var _anim_hold_open: Dictionary = {}
var _canonical_aliases_by_node: Dictionary = {}
var _standing_profile: Resource = null
var _visual_profile: Resource = null
var _auto_voice_profile: Resource = null
var _current_video_path := ""
var _summary: Dictionary = {}
var _compiled_scripts: Array[GDScript] = []


func lint_paths(inputs: Array = [], options: Dictionary = {}) -> Dictionary:
	_reset(options)
	var paths: Array[String] = _collect_paths(inputs)
	_first_input_path = str(paths.front()) if not paths.is_empty() else (str(inputs.front()) if not inputs.is_empty() else DEFAULT_SCENARIO_DIR)
	if paths.is_empty():
		_add_issue("error", "input.no_scenarios", str(inputs.front()) if not inputs.is_empty() else DEFAULT_SCENARIO_DIR, 0, "no .txt scenario files found")
	else:
		_load_profiles()
		for path in paths:
			_lint_file(path)
		_index_external_labels(paths)
		_validate_references()
		_validate_entry_nodes()
		_validate_reachability()
	_sort_issues()
	_count_severities()
	_summary["files"] = paths.size()
	return {
		"schema_version": 1,
		"files": paths.map(func(path: String) -> String: return _diagnostic_path(path)),
		"issues": _issues.duplicate(true),
		"summary": _summary.duplicate(true),
	}


func _reset(options: Dictionary) -> void:
	_options = {
		"compile_blocks": bool(options.get("compile_blocks", true)),
		"check_resources": bool(options.get("check_resources", true)),
		"check_no_op": bool(options.get("check_no_op", true)),
		"resource_root": str(options.get("resource_root", DEFAULT_RESOURCE_ROOT)),
		"standing_profile": str(options.get("standing_profile", DEFAULT_STANDING_PROFILE)),
		"visual_profile": str(options.get("visual_profile", DEFAULT_VISUAL_PROFILE)),
		"auto_voice_profile": str(options.get("auto_voice_profile", DEFAULT_AUTO_VOICE_PROFILE)),
	}
	_issues.clear()
	_labels.clear()
	_external_labels.clear()
	_has_partial_default_context = false
	_references.clear()
	_resource_seen.clear()
	_entry_nodes.clear()
	_first_label.clear()
	_first_input_path = ""
	_anim_hold_open.clear()
	_canonical_aliases_by_node.clear()
	_standing_profile = null
	_visual_profile = null
	_auto_voice_profile = null
	_current_video_path = ""
	_compiled_scripts.clear()
	_summary = {
		"files": 0,
		"blocks": 0,
		"dialogues": 0,
		"labels": 0,
		"references": 0,
		"errors": 0,
		"warnings": 0,
		"resource_references": 0,
		"resource_found": 0,
		"resource_virtual": 0,
		"resource_missing": 0,
	}


func _load_profiles() -> void:
	var auto_voice_path := str(_options.get("auto_voice_profile", DEFAULT_AUTO_VOICE_PROFILE))
	_auto_voice_profile = load(auto_voice_path)
	if _auto_voice_profile == null or not _auto_voice_profile.has_method("resolve_character"):
		_add_issue("error", "config.auto_voice_profile", auto_voice_path, 0, "AutoVoiceProfile could not be loaded or does not provide resolve_character()")
	if not bool(_options.get("check_resources", true)):
		return
	var standing_path := str(_options.get("standing_profile", DEFAULT_STANDING_PROFILE))
	var visual_path := str(_options.get("visual_profile", DEFAULT_VISUAL_PROFILE))
	_standing_profile = load(standing_path)
	_visual_profile = load(visual_path)
	if not _resource_provides_methods(_standing_profile, ["has_character", "character_directory", "resolve_pose_layers"]):
		_add_issue("error", "config.standing_profile", standing_path, 0, "StandingProfile could not be loaded or is missing required methods")
		_standing_profile = null
	if not _resource_provides_methods(_visual_profile, ["resolve_image_alias"]):
		_add_issue("error", "config.visual_profile", visual_path, 0, "VisualProfile could not be loaded or is missing resolve_image_alias()")
		_visual_profile = null


func _resource_provides_methods(resource: Resource, methods: Array[String]) -> bool:
	if resource == null:
		return false
	for method in methods:
		if not resource.has_method(method):
			return false
	return true


func _collect_paths(inputs: Array) -> Array[String]:
	var roots: Array = inputs if not inputs.is_empty() else [DEFAULT_SCENARIO_DIR]
	var found: Dictionary = {}
	for raw in roots:
		var original := str(raw).strip_edges()
		if original.is_empty():
			_add_issue("error", "input.empty_path", original, 0, "scenario input path cannot be empty")
			continue
		var path := _canonical_storage_path(original)
		if FileAccess.file_exists(path):
			if path.to_lower().ends_with(".txt"):
				found[_path_identity(path)] = path
			else:
				_add_issue("error", "input.not_scenario", path, 0, "scenario input file must use the .txt extension")
			continue
		if DirAccess.open(path) == null:
			_add_issue("error", "input.not_found", path, 0, "scenario input path does not exist or is not readable")
			continue
		_collect_directory(path, found)
	var result: Array[String] = []
	for path in found.values():
		result.append(str(path))
	result.sort()
	return result


func _collect_directory(path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var child := path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect_directory(child, found)
		elif name.to_lower().ends_with(".txt"):
			var canonical_child := _canonical_storage_path(child)
			found[_path_identity(canonical_child)] = canonical_child
		name = dir.get_next()
	dir.list_dir_end()


func _canonical_storage_path(path: String) -> String:
	var normalized := path.replace("\\", "/").simplify_path()
	var user_root := ProjectSettings.globalize_path("user://").replace("\\", "/").trim_suffix("/")
	if normalized.to_lower().begins_with(user_root.to_lower() + "/"):
		return "user://" + normalized.substr(user_root.length() + 1).simplify_path()
	var localized := ProjectSettings.localize_path(normalized)
	if localized.begins_with("res://") or localized.begins_with("user://"):
		return localized.simplify_path()
	return normalized


func _path_identity(path: String) -> String:
	return path.to_lower() if OS.get_name() == "Windows" else path


func _lint_file(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	if source.is_empty() and FileAccess.get_open_error() != OK:
		_add_issue("error", "input.read_failed", path, 0, "cannot read scenario")
		return
	var physical_lines := source.split("\n")
	_scan_source_warnings(path, physical_lines)
	_scan_block_structure(path, physical_lines)
	var blocks: Array = NovaParserScript.tokenize(source)
	var ns: String = NovaCompatScript.namespace_for_path(path)
	var current_label := ""
	_current_video_path = ""
	for block in blocks:
		var block_type := str(block.get("type", ""))
		var line := int(block.get("line", 0))
		if block_type == "text":
			_summary["dialogues"] = int(_summary.get("dialogues", 0)) + 1
			if current_label.is_empty():
				_add_issue("error", "flow.text_before_label", path, line, "dialogue text appears before the first label()")
			_lint_dialogue(path, line, str(block.get("content", "")), current_label)
			continue

		_summary["blocks"] = int(_summary.get("blocks", 0)) + 1
		var content := str(block.get("content", ""))
		var fallback_line := _block_content_base_line(physical_lines, block)
		var base_line := maxi(int(block.get("content_line", fallback_line)), 1)
		var base_column := maxi(int(block.get("content_column", 1)), 1)
		current_label = _scan_flow_metadata(path, ns, block_type, content, base_line, base_column, current_label)
		_scan_dynamic_targets(path, content, base_line, base_column)
		_scan_jump_branch_fallback(path, content, base_line, base_column, block.get("attrs", {}))
		_scan_block_attributes(path, line, block.get("attrs", {}))
		if bool(_options.get("check_no_op", true)):
			_scan_no_op_calls(path, content, base_line, base_column)
			_scan_discarded_assignments(path, content, base_line)
		if bool(_options.get("check_resources", true)):
			_scan_branch_resources(path, content, base_line, block.get("attrs", {}), line)
			_scan_resource_block(path, content, base_line)
		_scan_auto_voice_speakers(path, content, base_line, base_column)
		if bool(_options.get("compile_blocks", true)):
			_compile_block(path, ns, content, line)
			_compile_literal_conditions(path, ns, content, base_line, base_column)
			_compile_attribute_condition(path, block.get("attrs", {}), line)
	_finish_anim_hold_node(current_label)


func _scan_source_warnings(path: String, lines: PackedStringArray) -> void:
	for i in range(lines.size()):
		var line := str(lines[i]).trim_suffix("\r")
		var line_no := i + 1
		if line.contains("TODO"):
			_add_issue("warning", "content.todo", path, line_no, "TODO marker remains in scenario source")
		for j in range(line.length()):
			var codepoint := line.unicode_at(j)
			if _is_disallowed_control(codepoint):
				_add_issue("warning", "content.control_character", path, line_no, "disallowed control character U+%04X" % codepoint, {"column": j + 1})
				break
		var stripped := line.strip_edges()
		if stripped.begins_with("//") and _regex("^//[^:：]+(?:::|：：)").search(stripped) != null:
			_add_issue("error", "dialogue.comment_shaped_speaker", path, line_no, "speaker text beginning with // is parsed as a comment; add a display name before //")


func _is_disallowed_control(codepoint: int) -> bool:
	if codepoint < 32:
		return codepoint not in [9, 10, 13]
	if codepoint >= 0x7F and codepoint <= 0x9F:
		return true
	return (
		(codepoint >= 0x200B and codepoint <= 0x200F)
		or (codepoint >= 0x202A and codepoint <= 0x202E)
		or (codepoint >= 0x2060 and codepoint <= 0x206F)
		or codepoint == 0xFEFF
	)


func _scan_block_structure(path: String, lines: PackedStringArray) -> void:
	var open_line := 0
	var in_block := false
	for i in range(lines.size()):
		var stripped := str(lines[i]).strip_edges()
		var line_no := i + 1
		if in_block:
			var close_at := stripped.find("|>")
			if close_at != -1:
				if not stripped.substr(close_at + 2).strip_edges().is_empty():
					_add_issue("error", "syntax.trailing_after_block", path, line_no, "only whitespace is allowed after |>")
				in_block = false
				open_line = 0
			continue
		if stripped.begins_with("|>"):
			_add_issue("error", "syntax.stray_block_close", path, line_no, "stray |>, no block is open")
			continue
		if stripped.begins_with("@[") or stripped.begins_with("["):
			_scan_attribute_header(path, line_no, stripped)
		var header: Dictionary = NovaParserScript._parse_block_open(stripped)
		if str(header.get("type", "")).is_empty():
			if (stripped.begins_with("@[") or stripped.begins_with("[")) and stripped.contains("<|"):
				_add_issue("error", "syntax.malformed_block_header", path, line_no, "malformed attributed block header")
			elif stripped.contains("<|") and not stripped.begins_with("#") and not stripped.begins_with("//"):
				_add_issue("warning", "syntax.inline_block_open", path, line_no, "block opening token must start the trimmed line")
			continue
		var open_token := str(header.get("open_token", "<|"))
		var open_at := stripped.find(open_token)
		var close_at := stripped.find("|>", open_at + open_token.length())
		if close_at == -1:
			in_block = true
			open_line = line_no
		elif not stripped.substr(close_at + 2).strip_edges().is_empty():
			_add_issue("error", "syntax.trailing_after_block", path, line_no, "only whitespace is allowed after |>")
	if in_block:
		_add_issue("error", "syntax.unterminated_block", path, open_line, "block opened here is missing a closing |>")


func _scan_attribute_header(path: String, line: int, header: String) -> void:
	if not header.contains("<|"):
		return
	var offset := 2 if header.begins_with("@[") else 1
	var close_at := header.find("]", offset)
	if close_at == -1:
		_add_issue("error", "syntax.malformed_block_header", path, line, "attribute list is missing a closing ]")
		return
	var rest := header.substr(close_at + 1).strip_edges()
	if not (rest.begins_with("<|") or rest.begins_with("@<|")):
		_add_issue("error", "syntax.malformed_block_header", path, line, "attribute list must be followed by <| or @<|")
	var seen: Dictionary = {}
	for raw_part in header.substr(offset, close_at - offset).split(";", false):
		var part := str(raw_part).strip_edges()
		if part.is_empty():
			continue
		var equal_at := part.find("=")
		if equal_at <= 0 or equal_at >= part.length() - 1:
			_add_issue("error", "syntax.invalid_attribute", path, line, "block attribute must use key=value: '%s'" % part)
			continue
		var key := part.substr(0, equal_at).strip_edges()
		var value := part.substr(equal_at + 1).strip_edges()
		var key_match := _regex("^[A-Za-z_][A-Za-z0-9_]*$").search(key)
		if key_match == null or value.is_empty():
			_add_issue("error", "syntax.invalid_attribute", path, line, "invalid block attribute '%s'" % part)
			continue
		if seen.has(key):
			_add_issue("error", "syntax.duplicate_attribute", path, line, "duplicate block attribute '%s'" % key)
		seen[key] = true


func _scan_block_attributes(path: String, line: int, raw_attrs: Variant) -> void:
	if not (raw_attrs is Dictionary):
		return
	var attrs: Dictionary = raw_attrs
	for key in attrs.keys():
		if str(key) not in ["stage", "mode", "cond", "image"]:
			_add_issue("warning", "syntax.unknown_attribute", path, line, "unknown block attribute '%s'" % str(key))
	var stage := str(attrs.get("stage", "")).strip_edges().to_lower()
	if not stage.is_empty() and stage not in ["default", "before_checkpoint", "after_dialogue"]:
		_add_issue("error", "syntax.unknown_stage", path, line, "unknown lazy stage '%s'; runtime would fall back to default" % stage)
	var mode := str(attrs.get("mode", "")).strip_edges().to_lower()
	if not mode.is_empty() and mode not in ["normal", "jump", "show", "enable", "0", "1", "2", "3"]:
		_add_issue("error", "flow.invalid_branch_mode", path, line, "unknown branch mode '%s'" % mode)


func _scan_flow_metadata(path: String, ns: String, block_type: String, content: String, base_line: int, base_column: int, current_label: String) -> String:
	var scan_content := _mask_line_comments(content)
	var events: Array[Dictionary] = []
	var label_regex := _regex("\\blabel\\s*(?:\\(\\s*)?['\"]([^'\"]*)['\"]")
	for match in label_regex.search_all(scan_content):
		if _offset_is_in_string(scan_content, match.get_start()) or not _is_unqualified_call(scan_content, match.get_start()):
			continue
		events.append({"offset": match.get_start(), "type": "label", "raw": match.get_string(1)})
	var dynamic_label_regex := _regex("\\blabel\\s*\\(")
	for match in dynamic_label_regex.search_all(scan_content):
		var offset := match.get_start()
		if _offset_is_in_string(scan_content, offset) or not _is_unqualified_call(scan_content, offset):
			continue
		var has_literal_event := false
		for event in events:
			if str(event.get("type", "")) == "label" and int(event.get("offset", -1)) == offset:
				has_literal_event = true
				break
		if not has_literal_event:
			events.append({"offset": offset, "type": "dynamic_label"})
	_append_reference_events(events, scan_content, "jump_to", "\\bjump_to\\s*(?:\\(\\s*)?['\"]([^'\"]*)['\"]")
	_append_jump_if_events(events, scan_content)
	_append_branch_reference_events(events, scan_content)
	var entry_regex := _regex("\\b(is_start|is_unlocked_start|is_debug)\\s*\\(")
	for match in entry_regex.search_all(scan_content):
		if _offset_is_in_string(scan_content, match.get_start()) or not _is_unqualified_call(scan_content, match.get_start()):
			continue
		events.append({"offset": match.get_start(), "type": "entry", "kind": match.get_string(1)})
	var anim_regex := _regex("\\banim_hold_(begin|end)\\s*\\(")
	for match in anim_regex.search_all(scan_content):
		if _offset_is_in_string(scan_content, match.get_start()) or not _is_unqualified_call(scan_content, match.get_start()):
			continue
		events.append({"offset": match.get_start(), "type": "anim_hold", "kind": match.get_string(1)})
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_offset := int(a.get("offset", 0))
		var b_offset := int(b.get("offset", 0))
		if a_offset != b_offset:
			return a_offset < b_offset
		return str(a.get("type", "")) < str(b.get("type", ""))
	)

	if current_label.is_empty():
		var first_label_offset := -1
		for event in events:
			if str(event.get("type", "")) in ["label", "dynamic_label"]:
				first_label_offset = int(event.get("offset", -1))
				break
		var prefix := scan_content if first_label_offset < 0 else scan_content.substr(0, first_label_offset)
		if not prefix.strip_edges().is_empty():
			var code := "flow.code_before_label" if block_type == "eager" else "flow.lazy_before_label"
			var kind := "eager code" if block_type == "eager" else "lazy code"
			var issue_offset := _first_content_offset(prefix)
			_add_issue("error", code, path, _line_for_offset(scan_content, base_line, issue_offset), "%s appears before the first label()" % kind, {"column": _column_for_offset(scan_content, base_column, issue_offset)})

	for event in events:
		var offset := int(event.get("offset", 0))
		var line := _line_for_offset(scan_content, base_line, offset)
		var column := _column_for_offset(scan_content, base_column, offset)
		match str(event.get("type", "")):
			"label":
				var raw := str(event.get("raw", "")).strip_edges()
				if block_type != "eager":
					_add_issue("error", "flow.label_in_lazy", path, line, "label() is only valid in an eager @<| block", {"column": column})
					continue
				if raw.is_empty():
					_add_issue("error", "flow.empty_label", path, line, "label name cannot be empty", {"column": column})
					continue
				var resolved := NovaCompatScript.resolve_label(raw, ns)
				_finish_anim_hold_node(current_label)
				if _labels.has(resolved):
					var previous: Dictionary = _labels[resolved]
					_add_issue("error", "flow.duplicate_label", path, line, "duplicate label '%s'; first defined at %s:%d" % [resolved, _diagnostic_path(str(previous.get("path", ""))), previous.get("line", 0)], {"column": column})
				else:
					_labels[resolved] = {"path": path, "line": line, "column": column, "raw": raw}
					if _first_label.is_empty():
						_first_label = {"path": path, "line": line, "column": column, "name": resolved}
					_summary["labels"] = int(_summary.get("labels", 0)) + 1
				current_label = resolved
			"dynamic_label":
				_add_issue("error", "flow.dynamic_label", path, line, "label() name must be a non-empty string literal", {"column": column})
			"reference":
				var kind := str(event.get("kind", "transition"))
				var raw := str(event.get("raw", "")).strip_edges()
				if current_label.is_empty():
					_add_issue("error", "flow.transition_before_label", path, line, "%s target appears before a label()" % kind, {"column": column})
				if raw.is_empty():
					_add_issue("error", "flow.empty_target", path, line, "%s target cannot be empty" % kind, {"column": column})
					continue
				_references.append({
					"path": path,
					"line": line,
					"column": column,
					"kind": kind,
					"raw": raw,
					"target": NovaCompatScript.resolve_label(raw, ns),
					"source": current_label,
				})
				_summary["references"] = int(_summary.get("references", 0)) + 1
			"entry":
				var kind := str(event.get("kind", "entry"))
				if current_label.is_empty():
					_add_issue("error", "flow.entry_before_label", path, line, "%s() appears before a label()" % kind, {"column": column})
				else:
					_entry_nodes[current_label] = {"path": path, "line": line, "column": column, "kind": kind}
			"anim_hold":
				_process_anim_hold_event(path, line, column, current_label, str(event.get("kind", "")))
	return current_label


func _append_reference_events(events: Array[Dictionary], content: String, kind: String, pattern: String) -> void:
	var regex := _regex(pattern)
	for match in regex.search_all(content):
		if _offset_is_in_string(content, match.get_start()) or not _is_unqualified_call(content, match.get_start()):
			continue
		events.append({
			"offset": match.get_start(),
			"type": "reference",
			"kind": kind,
			"raw": match.get_string(1),
		})


func _append_jump_if_events(events: Array[Dictionary], content: String) -> void:
	for call in _find_function_calls(content, "jump_if"):
		var arguments: Array = call.get("arguments", [])
		if arguments.size() < 2:
			continue
		var literal := _literal_string(str((arguments[1] as Dictionary).get("text", "")))
		if literal.is_empty():
			continue
		events.append({
			"offset": int(call.get("offset", 0)),
			"type": "reference",
			"kind": "jump_if",
			"raw": str(literal.get("value", "")),
		})


func _append_branch_reference_events(events: Array[Dictionary], content: String) -> void:
	var regex := _regex("\\bdest\\s*=\\s*['\"]([^'\"]*)['\"]")
	for group in _extract_branch_groups(content):
		for option in group.get("options", []):
			var option_text := str(option.get("text", ""))
			var option_offset := int(option.get("offset", 0))
			for match in regex.search_all(option_text):
				if _offset_is_in_string(option_text, match.get_start()):
					continue
				events.append({
					"offset": option_offset + match.get_start(),
					"type": "reference",
					"kind": "branch",
					"raw": match.get_string(1),
				})


func _validate_references() -> void:
	for reference in _references:
		var target := str(reference.get("target", ""))
		if not _labels.has(target) and not _external_labels.has(target):
			_add_issue("error", "flow.missing_target", str(reference.get("path", "")), int(reference.get("line", 0)), "%s target '%s' does not resolve to a label" % [reference.get("kind", "transition"), target], {"column": int(reference.get("column", 1))})


func _index_external_labels(selected_paths: Array[String]) -> void:
	var selected: Dictionary = {}
	var needs_default_context := false
	for path in selected_paths:
		selected[_path_identity(path)] = true
		if _path_identity(str(path)).begins_with(_path_identity(DEFAULT_SCENARIO_DIR)):
			needs_default_context = true
	if not needs_default_context:
		return
	var found: Dictionary = {}
	_collect_directory(DEFAULT_SCENARIO_DIR, found)
	var default_paths: Array[String] = []
	for path in found.values():
		default_paths.append(str(path))
	default_paths.sort()
	for path in default_paths:
		if selected.has(_path_identity(path)):
			continue
		_has_partial_default_context = true
		var source := FileAccess.get_file_as_string(path)
		var ns: String = NovaCompatScript.namespace_for_path(path)
		for block in NovaParserScript.tokenize(source):
			if str(block.get("type", "")) != "eager":
				continue
			var content := _mask_line_comments(str(block.get("content", "")))
			var regex := _regex("\\blabel\\s*(?:\\(\\s*)?['\"]([^'\"]+)['\"]")
			for match in regex.search_all(content):
				if _offset_is_in_string(content, match.get_start()) or not _is_unqualified_call(content, match.get_start()):
					continue
				var raw := match.get_string(1).strip_edges()
				if not raw.is_empty():
					_external_labels[NovaCompatScript.resolve_label(raw, ns)] = true


func _scan_dynamic_targets(path: String, content: String, base_line: int, base_column: int) -> void:
	var cleaned := _mask_line_comments(content)
	for call in _find_function_calls(cleaned, "jump_to"):
		var arguments: Array = call.get("arguments", [])
		if arguments.is_empty() or not _literal_string(str((arguments[0] as Dictionary).get("text", ""))).is_empty():
			continue
		var offset := int(call.get("offset", 0))
		_add_issue("warning", "flow.dynamic_target", path, _line_for_offset(cleaned, base_line, offset), "jump_to() target is dynamic and cannot be validated statically", {"column": _column_for_offset(cleaned, base_column, offset)})
	for call in _find_function_calls(cleaned, "jump_if"):
		var arguments: Array = call.get("arguments", [])
		if arguments.size() < 2 or not _literal_string(str((arguments[1] as Dictionary).get("text", ""))).is_empty():
			continue
		var offset := int(call.get("offset", 0))
		_add_issue("warning", "flow.dynamic_target", path, _line_for_offset(cleaned, base_line, offset), "jump_if() target is dynamic and cannot be validated statically", {"column": _column_for_offset(cleaned, base_column, offset)})
	var branch_regex := _regex("\\bdest\\s*=\\s*([A-Za-z_][A-Za-z0-9_]*)")
	for group in _extract_branch_groups(cleaned):
		for option in group.get("options", []):
			var option_text := str(option.get("text", ""))
			var option_offset := int(option.get("offset", 0))
			for match in branch_regex.search_all(option_text):
				if _offset_is_in_string(option_text, match.get_start()):
					continue
				var offset := option_offset + match.get_start()
				_add_issue("warning", "flow.dynamic_target", path, _line_for_offset(cleaned, base_line, offset), "branch destination is dynamic and cannot be validated statically", {"column": _column_for_offset(cleaned, base_column, offset)})


func _validate_entry_nodes() -> void:
	# A selected file or directory below the built-in scenario root is only a
	# partial view of the project graph. External labels are indexed above so
	# transitions can still be checked, but absence of an entry node cannot be
	# proven from that subset alone.
	if _has_partial_default_context:
		return
	if _labels.is_empty():
		_add_issue("error", "flow.no_nodes", _first_input_path, 1, "scenario set does not define any label() nodes")
		return
	if _entry_nodes.is_empty():
		_add_issue("error", "flow.no_start", str(_first_label.get("path", DEFAULT_SCENARIO_DIR)), int(_first_label.get("line", 1)), "scenario set has no is_start(), is_unlocked_start(), or is_debug() entry node")


func _validate_reachability() -> void:
	if _has_partial_default_context:
		return
	if _labels.is_empty() or _entry_nodes.is_empty():
		return
	var edges: Dictionary = {}
	for reference in _references:
		var source := str(reference.get("source", ""))
		var target := str(reference.get("target", ""))
		if source.is_empty() or target.is_empty() or not _labels.has(target):
			continue
		if not edges.has(source):
			edges[source] = []
		var destinations: Array = edges[source]
		if target not in destinations:
			destinations.append(target)
	var visited: Dictionary = {}
	var pending: Array = _entry_nodes.keys()
	while not pending.is_empty():
		var node := str(pending.pop_back())
		if visited.has(node) or not _labels.has(node):
			continue
		visited[node] = true
		for target in edges.get(node, []):
			if not visited.has(str(target)):
				pending.append(str(target))
	for node in _labels.keys():
		if visited.has(str(node)):
			continue
		var declaration: Dictionary = _labels[node]
		_add_issue("warning", "flow.unreachable", str(declaration.get("path", "")), int(declaration.get("line", 1)), "label '%s' is unreachable from any start/debug node" % str(node))


func _lint_dialogue(path: String, line: int, content: String, current_label: String) -> void:
	var marker := content.find("：：")
	if marker == -1:
		marker = content.find("::")
	if marker <= 0:
		if _regex("^[^：:\r\n]+：[“\"]").search(content) != null:
			_add_issue("warning", "dialogue.single_colon_speaker", path, line, "speaker dialogue uses one colon; use the :: or ：： delimiter")
		return
	var raw_speaker := content.substr(0, marker).strip_edges()
	var text := content.substr(marker + 2).strip_edges()
	if text.is_empty():
		_add_issue("warning", "dialogue.empty_text", path, line, "speaker delimiter is followed by empty dialogue text")
	else:
		if not text.begins_with("“") or not text.ends_with("”"):
			_add_issue("warning", "dialogue.missing_quotes", path, line, "speaker dialogue should be wrapped in Chinese quotation marks “…”")
		elif text.length() > 2:
			var inner := text.substr(1, text.length() - 2)
			if inner.contains("“") or inner.contains("”"):
				_add_issue("warning", "dialogue.nested_quotes", path, line, "speaker dialogue contains nested outer-style Chinese quotation marks")
		if _regex("[,.?!;:'\"()]").search(text) != null:
			_add_issue("warning", "dialogue.halfwidth_punctuation", path, line, "speaker dialogue contains half-width punctuation")
	if raw_speaker.contains("//"):
		var split := raw_speaker.find("//")
		var display := raw_speaker.substr(0, split).strip_edges()
		var canonical := raw_speaker.substr(split + 2).strip_edges()
		if display.is_empty() or canonical.is_empty() or canonical.contains("//"):
			_add_issue("error", "dialogue.invalid_canonical_speaker", path, line, "canonical speaker syntax must be display//internal before the dialogue delimiter")
		elif not current_label.is_empty():
			if not _canonical_aliases_by_node.has(current_label):
				_canonical_aliases_by_node[current_label] = {}
			var aliases: Dictionary = _canonical_aliases_by_node[current_label]
			if aliases.has(display) and str(aliases[display]) != canonical:
				_add_issue("error", "dialogue.canonical_conflict", path, line, "speaker '%s' changes canonical name from '%s' to '%s' in the same node" % [display, aliases[display], canonical])
			else:
				aliases[display] = canonical


func _process_anim_hold_event(path: String, line: int, column: int, current_label: String, kind: String) -> void:
	if current_label.is_empty():
		_add_issue("warning", "anim_hold.before_label", path, line, "anim_hold_%s() appears before a label()" % kind, {"column": column})
		return
	if kind == "begin":
		if _anim_hold_open.has(current_label):
			var previous: Dictionary = _anim_hold_open[current_label]
			_add_issue("warning", "anim_hold.reentrant", path, line, "anim_hold_begin() is already active from line %d" % int(previous.get("line", 0)), {"column": column})
		else:
			_anim_hold_open[current_label] = {"path": path, "line": line, "column": column}
	elif not _anim_hold_open.has(current_label):
		_add_issue("warning", "anim_hold.unmatched_end", path, line, "anim_hold_end() has no matching begin in this node", {"column": column})
	else:
		_anim_hold_open.erase(current_label)


func _finish_anim_hold_node(node: String) -> void:
	if node.is_empty() or not _anim_hold_open.has(node):
		return
	var opening: Dictionary = _anim_hold_open[node]
	_add_issue("warning", "anim_hold.unclosed", str(opening.get("path", "")), int(opening.get("line", 1)), "anim_hold_begin() is not closed before node '%s' ends" % node, {"column": int(opening.get("column", 1))})
	_anim_hold_open.erase(node)


func _scan_jump_branch_fallback(path: String, content: String, base_line: int, base_column: int, raw_attrs: Variant) -> void:
	var attrs: Dictionary = raw_attrs if raw_attrs is Dictionary else {}
	var default_mode := str(attrs.get("mode", "normal")).strip_edges().to_lower()
	var default_condition := str(attrs.get("cond", "")).strip_edges()
	for branch_group in _extract_branch_groups(_mask_line_comments(content)):
		var options: Array = branch_group.get("options", [])
		if options.is_empty():
			continue
		var all_conditional_jump := true
		for option in options:
			var option_text := str(option.get("text", ""))
			var mode := _branch_option_mode(option_text, default_mode)
			var condition := _branch_option_condition(option_text, default_condition)
			if mode != "jump" or condition.is_empty():
				all_conditional_jump = false
				break
		if all_conditional_jump:
			var offset := int(branch_group.get("offset", 0))
			_add_issue("warning", "flow.jump_branch_no_fallback", path, _line_for_offset(content, base_line, offset), "jump-mode branch has no unconditional fallback", {"column": _column_for_offset(content, base_column, offset)})


func _extract_branch_groups(content: String) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	var branch_regex := _regex("\\bbranch\\s*(?:\\(|\\{)")
	var search_from := 0
	while search_from < content.length():
		var match := branch_regex.search(content, search_from)
		if match == null:
			break
		if _offset_is_in_string(content, match.get_start()) or not _is_unqualified_call(content, match.get_start()):
			search_from = match.get_end()
			continue
		var outer_start := _find_branch_container_start(content, match.get_start(), match.get_end())
		if outer_start < 0:
			search_from = match.get_end()
			continue
		var outer_open := content.substr(outer_start, 1)
		var stack: Array[String] = [outer_open]
		var quote := ""
		var escaped := false
		var option_start := -1
		var options: Array[Dictionary] = []
		var cursor := outer_start + 1
		while cursor < content.length() and not stack.is_empty():
			var ch := content.substr(cursor, 1)
			if not quote.is_empty():
				if escaped:
					escaped = false
				elif ch == "\\":
					escaped = true
				elif ch == quote:
					quote = ""
				cursor += 1
				continue
			if ch == "'" or ch == "\"":
				quote = ch
				cursor += 1
				continue
			if ch in ["{", "[", "("]:
				if ch == "{" and stack.size() == 1:
					option_start = cursor
				stack.append(ch)
			elif ch in ["}", "]", ")"] and not stack.is_empty():
				var expected := "{" if ch == "}" else ("[" if ch == "]" else "(")
				if stack.back() == expected:
					stack.pop_back()
					if option_start >= 0 and stack.size() == 1:
						options.append({
							"text": content.substr(option_start, cursor - option_start + 1),
							"offset": option_start,
							"line_offset": content.substr(0, option_start).count("\n"),
						})
						option_start = -1
			cursor += 1
		groups.append({
			"offset": match.get_start(),
			"line_offset": content.substr(0, match.get_start()).count("\n"),
			"options": options,
		})
		search_from = maxi(cursor, match.get_end())
	return groups


func _find_branch_container_start(content: String, call_start: int, call_end: int) -> int:
	if call_end <= call_start or call_end > content.length():
		return -1
	var opening := content.substr(call_end - 1, 1)
	if opening == "{":
		return call_end - 1
	if opening != "(":
		return -1
	var close_index := _find_matching_delimiter(content, call_end - 1)
	if close_index < 0:
		return -1
	var cursor := _skip_whitespace(content, call_end)
	if cursor < close_index and content.substr(cursor, 1) in ["{", "["]:
		return cursor
	return -1


func _branch_option_mode(option: String, default_mode: String) -> String:
	var regex := _regex("\\bmode\\s*=\\s*(?:['\"]([^'\"]+)['\"]|([A-Za-z0-9_]+))")
	var match := regex.search(option)
	if match == null or _offset_is_in_string(option, match.get_start()):
		return default_mode
	var value := match.get_string(1)
	if value.is_empty():
		value = match.get_string(2)
	return value.strip_edges().to_lower()


func _branch_option_condition(option: String, default_condition: String) -> String:
	var regex := _regex("\\bcond\\s*=")
	var match := regex.search(option)
	if match == null or _offset_is_in_string(option, match.get_start()):
		return default_condition
	var tail := option.substr(match.get_end()).strip_edges()
	if tail.begins_with("\"\"") or tail.begins_with("''") or tail.begins_with("null") or tail.begins_with("nil"):
		return ""
	return tail


func _compile_block(path: String, ns: String, content: String, line: int) -> void:
	var translated: String = NovaCompatScript.translate_block(content, ns)
	var wrapped := _wrap_statements(translated)
	var script := GDScript.new()
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		_add_issue("error", "syntax.compile", path, line, "NovaScript block failed to compile after translation (Godot error %d)" % err)
	else:
		# Keep dynamically compiled scripts alive until the lint pass finishes.
		# Releasing hundreds of scripts during the same frame can make headless
		# Godot terminate before the report is emitted on Windows.
		_compiled_scripts.append(script)


func _compile_literal_conditions(path: String, _ns: String, content: String, base_line: int, base_column: int) -> void:
	var scan_content := _mask_line_comments(content)
	var regex := _regex("\\bcond\\s*=\\s*['\"]([^'\"]+)['\"]")
	for match in regex.search_all(scan_content):
		if _offset_is_in_string(scan_content, match.get_start()):
			continue
		var condition := NovaCompatScript.translate_condition(match.get_string(1).strip_edges())
		_compile_condition(path, condition, _line_for_offset(scan_content, base_line, match.get_start()), _column_for_offset(scan_content, base_column, match.get_start()))

	var lines := scan_content.split("\n")
	var function_regex := _regex("\\bcond\\s*=\\s*function\\s*\\(")
	var in_condition := false
	var condition_line := base_line
	var condition_source := ""
	for i in range(lines.size()):
		var stripped := _strip_line_comment(str(lines[i])).strip_edges()
		if not in_condition and function_regex.search(stripped) != null:
			in_condition = true
			condition_line = base_line + i
			var inline_return := _regex("\\breturn\\s+(.+?)\\s+end\\b").search(stripped)
			if inline_return != null:
				condition_source = inline_return.get_string(1).strip_edges()
				_compile_condition(path, NovaCompatScript.translate_condition(condition_source), condition_line, base_column if i == 0 else 1)
				in_condition = false
				condition_source = ""
			continue
		if not in_condition:
			continue
		if stripped.begins_with("return "):
			condition_source = stripped.substr("return ".length()).strip_edges()
		if stripped == "end" or stripped.begins_with("end,") or stripped.begins_with("end }"):
			_compile_condition(path, NovaCompatScript.translate_condition(condition_source), condition_line, base_column if condition_line == base_line else 1)
			in_condition = false
			condition_source = ""


func _compile_condition(path: String, condition: String, line: int, column: int = 1) -> void:
	if condition.is_empty():
		_add_issue("error", "syntax.condition", path, line, "branch condition is empty or could not be extracted", {"column": column})
		return
	var script := GDScript.new()
	script.source_code = _wrap_statements("return %s" % condition)
	var err := script.reload()
	if err != OK:
		_add_issue("error", "syntax.condition", path, line, "branch condition failed to compile (Godot error %d)" % err, {"column": column})
	else:
		_compiled_scripts.append(script)


func _compile_attribute_condition(path: String, raw_attrs: Variant, line: int) -> void:
	if not (raw_attrs is Dictionary):
		return
	var condition := str(raw_attrs.get("cond", "")).strip_edges()
	if not condition.is_empty():
		_compile_condition(path, NovaCompatScript.translate_condition(condition), line)


func _wrap_statements(source: String) -> String:
	var body := source.strip_edges()
	if body.is_empty():
		body = "pass"
	var indented := ""
	for line in body.split("\n"):
		indented += "\t" + line + "\n"
	return "extends \"res://scripts/runtime/base_block.gd\"\nfunc __eval():\n%s" % indented


func _scan_no_op_calls(path: String, content: String, base_line: int, base_column: int) -> void:
	var scan_content := _mask_line_comments(content)
	for api in NO_OP_APIS:
		var regex := _regex("\\b%s\\s*\\(" % api)
		for match in regex.search_all(scan_content):
			var start := match.get_start()
			if _offset_is_in_string(scan_content, start) or not _is_unqualified_call(scan_content, start):
				continue
			_add_issue("warning", "compat.no_op", path, _line_for_offset(scan_content, base_line, start), "%s() is currently a compatibility no-op" % api, {"column": _column_for_offset(scan_content, base_column, start)})
	for api in ANIMATION_NO_OP_APIS:
		var regex := _regex("\\b(?:anim|anim_hold)\\s*[:.]\\s*%s\\s*\\(" % api)
		for match in regex.search_all(scan_content):
			if _offset_is_in_string(scan_content, match.get_start()):
				continue
			_add_issue("warning", "compat.animation_no_op", path, _line_for_offset(scan_content, base_line, match.get_start()), "animation compatibility call %s() currently preserves chaining but has no runtime effect" % api, {"column": _column_for_offset(scan_content, base_column, match.get_start())})


func _scan_discarded_assignments(path: String, content: String, base_line: int) -> void:
	var lines := content.split("\n")
	var regex := _regex("^\\s*(?:__Nova\\.)?[A-Za-z_][A-Za-z0-9_]*(?:\\.[A-Za-z_][A-Za-z0-9_]*)+\\s*=(?!=)")
	for i in range(lines.size()):
		var line := _strip_line_comment(str(lines[i]))
		if regex.search(line) != null:
			_add_issue("warning", "compat.discarded_assignment", path, base_line + i, "external property assignment is discarded by the NovaScript compatibility translator")


func _scan_auto_voice_speakers(path: String, content: String, base_line: int, base_column: int) -> void:
	if _auto_voice_profile == null or not _auto_voice_profile.has_method("resolve_character"):
		return
	var scan_content := _mask_line_comments(content)
	var regex := _regex("\\bauto_voice_on\\s*\\(\\s*['\"]([^'\"]+)['\"]")
	for match in regex.search_all(scan_content):
		if _offset_is_in_string(scan_content, match.get_start()) or not _is_unqualified_call(scan_content, match.get_start()):
			continue
		var speaker := match.get_string(1)
		if str(_auto_voice_profile.call("resolve_character", speaker)).is_empty():
			_add_issue("error", "auto_voice.unknown_speaker", path, _line_for_offset(scan_content, base_line, match.get_start()), "auto_voice_on speaker '%s' is not configured in AutoVoiceProfile" % speaker, {"column": _column_for_offset(scan_content, base_column, match.get_start())})


func _scan_resource_block(path: String, content: String, base_line: int) -> void:
	var lines := content.split("\n")
	for i in range(lines.size()):
		_scan_resource_line(path, base_line + i, _strip_line_comment(str(lines[i])))


func _scan_resource_line(path: String, line_no: int, line: String) -> void:
	_scan_visual_calls(path, line_no, line)
	_scan_audio_calls(path, line_no, line)
	_scan_prefab_and_video_calls(path, line_no, line)
	_scan_shader_resource_params(path, line_no, line)
	_scan_direct_resource_calls(path, line_no, line)
	var regex := _regex("[\"']([^\"']*)[\"']")
	for match in regex.search_all(line):
		var value := match.get_string(1)
		if value.begins_with("@") or value.is_empty():
			continue
		if value.length() > 256 or not _looks_like_resource_literal(value):
			continue
		_check_resource(path, line_no, value)


func _scan_visual_calls(path: String, line_no: int, line: String) -> void:
	var regex := _regex("\\b(?:show|trans|trans2|trans_fade|trans_left|trans_right|trans_up|trans_down)\\s*\\(\\s*(?:[\"']?)([A-Za-z_][A-Za-z0-9_]*)(?:[\"']?)\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		var object_name := match.get_string(1).to_lower()
		var image_name := match.get_string(2).strip_edges()
		match object_name:
			"bg":
				_check_resource(path, line_no, image_name if image_name.contains("/") else "Backgrounds/" + image_name)
			"fg":
				_check_resource(path, line_no, image_name if image_name.contains("/") else "foregrounds/" + image_name)
			"cg":
				_scan_cg_reference(path, line_no, image_name)
			_:
				_scan_standing_reference(path, line_no, object_name, image_name)


func _scan_cg_reference(path: String, line_no: int, image_name: String) -> void:
	var resolved := image_name
	if _visual_profile != null and _visual_profile.has_method("resolve_image_alias"):
		resolved = str(_visual_profile.call("resolve_image_alias", "cg", image_name))
	for raw_part in resolved.split("+", false):
		var part := str(raw_part).strip_edges()
		if not part.is_empty():
			_check_resource(path, line_no, part if part.contains("/") else "cg/" + part)


func _scan_standing_reference(path: String, line_no: int, character_name: String, pose: String) -> void:
	if _standing_profile == null or not _standing_profile.has_method("has_character"):
		return
	if not bool(_standing_profile.call("has_character", character_name)):
		return
	var directory := str(_standing_profile.call("character_directory", character_name))
	var layers: Array = _standing_profile.call("resolve_pose_layers", character_name, pose)
	for raw_layer in layers:
		var layer := str(raw_layer).strip_edges()
		if not layer.is_empty():
			_check_resource(path, line_no, directory.path_join(layer))


func _scan_audio_calls(path: String, line_no: int, line: String) -> void:
	var play_regex := _regex("\\bplay\\s*\\(\\s*(bgm|bgs|voice)\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in play_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		var channel := match.get_string(1).to_lower()
		var name := match.get_string(2)
		match channel:
			"bgm":
				_check_resource(path, line_no, _compat_audio_path("BGM", name))
			"bgs":
				_check_resource(path, line_no, _compat_audio_path("Sounds", name))
			"voice":
				_check_resource(path, line_no, name)
	var sound_regex := _regex("\\bsound\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in sound_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		_check_resource(path, line_no, _compat_audio_path("Sounds", match.get_string(1)))
	var direct_regex := _regex("\\b(play_bgm|play_se|play_voice)\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in direct_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		var method := match.get_string(1)
		var resource_path := match.get_string(2)
		match method:
			"play_bgm":
				_check_resource(path, line_no, resource_path)
			"play_se":
				_check_resource(path, line_no, resource_path)
			"play_voice":
				_check_resource(path, line_no, resource_path)
	var say_regex := _regex("\\bsay\\s*\\(\\s*(?:[\"']([^\"']+)[\"']|([A-Za-z_][A-Za-z0-9_]*))\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in say_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		var speaker := match.get_string(1)
		if speaker.is_empty():
			speaker = match.get_string(2)
		if _auto_voice_profile != null and _auto_voice_profile.has_method("manual_voice_path"):
			_check_resource(path, line_no, str(_auto_voice_profile.call("manual_voice_path", speaker, match.get_string(3))))


func _scan_prefab_and_video_calls(path: String, line_no: int, line: String) -> void:
	var prefab_regex := _regex("\\b(?:load_prefab|load_ui_prefab|load_persistent_prefab)\\s*\\(\\s*[\"'][^\"']+[\"']\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in prefab_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		_check_resource(path, line_no, _with_default_extension(match.get_string(1), ".tscn"))
	var video_regex := _regex("\\bvideo\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in video_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		var resource_path := match.get_string(1)
		if not resource_path.contains("/"):
			resource_path = "Videos/" + resource_path
		_current_video_path = _with_default_extension(resource_path, ".mp4")
		_check_resource(path, line_no, _current_video_path)
	var direct_video_regex := _regex("\\b(?:play_video|video_play)\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in direct_video_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		_check_resource(path, line_no, match.get_string(1))
	var prepared_video_regex := _regex("\\bvideo_play\\s*\\(\\s*\\)")
	for match in prepared_video_regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		if _current_video_path.is_empty():
			_check_resource(path, line_no, "Videos/Call.mp4")


func _scan_branch_resources(path: String, content: String, base_line: int, raw_attrs: Variant, block_line: int) -> void:
	var scan_content := _mask_line_comments(content)
	var regex := _regex("(?s)\\bimage\\s*=\\s*(?:\\{|\\[)?\\s*[\"']([^\"']+)[\"']")
	for group in _extract_branch_groups(scan_content):
		for option in group.get("options", []):
			var option_text := str(option.get("text", ""))
			var option_offset := int(option.get("offset", 0))
			for match in regex.search_all(option_text):
				if _offset_is_in_string(option_text, match.get_start()):
					continue
				_check_choice_image(path, _line_for_offset(scan_content, base_line, option_offset + match.get_start()), match.get_string(1))
	if raw_attrs is Dictionary:
		var attr_image := str(raw_attrs.get("image", "")).strip_edges()
		if not attr_image.is_empty():
			var quoted := _regex("[\"']([^\"']+)[\"']").search(attr_image)
			_check_choice_image(path, block_line, quoted.get_string(1) if quoted != null else attr_image)


func _check_choice_image(path: String, line: int, raw_image: String) -> void:
	var image_name := raw_image.strip_edges()
	if not image_name.is_empty():
		_check_resource(path, line, image_name if image_name.contains("/") else "Choices/%s.png" % image_name)


func _scan_shader_resource_params(path: String, line_no: int, line: String) -> void:
	var regex := _regex("\\b(?:_SubTex|_MainTex|_Mask|texture)\\s*=\\s*[\"']([^\"']+)[\"']")
	for match in regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		_check_resource(path, line_no, match.get_string(1))


func _scan_direct_resource_calls(path: String, line_no: int, line: String) -> void:
	var regex := _regex("\\bpreload_asset\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in regex.search_all(line):
		if _offset_is_in_string(line, match.get_start()):
			continue
		_check_resource(path, line_no, match.get_string(1))


func _looks_like_resource_literal(value: String) -> bool:
	# Relative literals are only meaningful in the context of a known runtime
	# API, which is handled by the dedicated scanners above. Treating every
	# string containing '/' or a file extension as an asset creates blocking
	# false positives for labels, URLs, versions, and arbitrary script data.
	return value.begins_with("res://") or value.begins_with("user://")


func _check_resource(source_path: String, line: int, resource_path: String) -> void:
	if resource_path.strip_edges().is_empty():
		return
	var identity := "%s:%d:%s" % [_diagnostic_path(source_path), line, resource_path.replace("\\", "/")]
	if _resource_seen.has(identity):
		return
	_resource_seen[identity] = true
	_summary["resource_references"] = int(_summary.get("resource_references", 0)) + 1
	for prefix in VIRTUAL_PREFIXES:
		if resource_path.begins_with(str(prefix)):
			_summary["resource_virtual"] = int(_summary.get("resource_virtual", 0)) + 1
			return
	var root := str(_options.get("resource_root", DEFAULT_RESOURCE_ROOT))
	var full := resource_path if resource_path.begins_with("res://") or resource_path.begins_with("user://") else root.path_join(resource_path)
	var candidates: Array[String] = [full]
	if full.get_extension().is_empty():
		for extension in RESOURCE_EXTENSIONS:
			candidates.append(full + str(extension))
	for candidate in candidates:
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			_summary["resource_found"] = int(_summary.get("resource_found", 0)) + 1
			return
	_summary["resource_missing"] = int(_summary.get("resource_missing", 0)) + 1
	_add_issue("error", "asset.missing", source_path, line, "referenced resource does not exist: %s" % resource_path, {"resource": resource_path})


func _with_default_extension(path: String, extension: String) -> String:
	return path if not path.get_extension().is_empty() else path + extension


func _compat_audio_path(folder: String, path: String) -> String:
	return path if path.contains("/") or not path.get_extension().is_empty() else "%s/%s.ogg" % [folder, path]


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


func _find_function_calls(content: String, function_name: String) -> Array[Dictionary]:
	var calls: Array[Dictionary] = []
	for match in _regex("\\b%s\\b" % function_name).search_all(content):
		var offset := match.get_start()
		if not _is_unqualified_call(content, offset):
			continue
		var open_index := _skip_whitespace(content, match.get_end())
		if open_index >= content.length() or content.substr(open_index, 1) != "(":
			continue
		var close_index := _find_matching_delimiter(content, open_index)
		if close_index < 0:
			continue
		var arguments: Array[Dictionary] = []
		for raw_range in _split_top_level_ranges(content, open_index + 1, close_index):
			var argument_range: Dictionary = raw_range
			var start := int(argument_range.get("start", open_index + 1))
			var end := int(argument_range.get("end", start))
			arguments.append({
				"start": start,
				"end": end,
				"text": content.substr(start, maxi(end - start, 0)),
			})
		calls.append({
			"offset": offset,
			"open": open_index,
			"close": close_index,
			"arguments": arguments,
		})
	return calls


func _literal_string(value: String) -> Dictionary:
	var text := value.strip_edges()
	if text.length() < 2:
		return {}
	var quote := text.substr(0, 1)
	if quote != "'" and quote != "\"":
		return {}
	var escaped := false
	for i in range(1, text.length()):
		var character := text.substr(i, 1)
		if escaped:
			escaped = false
		elif character == "\\":
			escaped = true
		elif character == quote:
			if i != text.length() - 1:
				return {}
			return {"value": text.substr(1, i - 1).c_unescape()}
	return {}


func _is_unqualified_call(content: String, offset: int) -> bool:
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


func _is_identifier_character(character: String) -> bool:
	return character == "_" or (character >= "a" and character <= "z") or (character >= "A" and character <= "Z") or (character >= "0" and character <= "9")


func _first_content_offset(content: String) -> int:
	for i in range(content.length()):
		if content.substr(i, 1) not in [" ", "\t", "\r", "\n"]:
			return i
	return 0


func _line_for_offset(content: String, base_line: int, offset: int) -> int:
	if offset <= 0:
		return base_line
	return base_line + content.substr(0, offset).count("\n")


func _column_for_offset(content: String, base_column: int, offset: int) -> int:
	if offset <= 0:
		return base_column
	var prefix := content.substr(0, offset)
	var newline := prefix.rfind("\n")
	return base_column + offset if newline < 0 else offset - newline


func _strip_line_comment(line: String) -> String:
	var marker := _line_comment_offset(line)
	return line.substr(0, marker) if marker >= 0 else line


func _strip_comments(content: String) -> String:
	var out: Array[String] = []
	for line in content.split("\n"):
		out.append(_strip_line_comment(str(line)))
	return "\n".join(out)


func _mask_line_comments(content: String) -> String:
	var out: Array[String] = []
	for raw_line in content.split("\n"):
		var line := str(raw_line)
		var marker := _line_comment_offset(line)
		if marker >= 0:
			line = line.substr(0, marker) + " ".repeat(line.length() - marker)
		out.append(line)
	return "\n".join(out)


func _line_comment_offset(line: String) -> int:
	var quote := ""
	var escaped := false
	for i in range(line.length()):
		var ch := line.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == quote:
				quote = ""
			continue
		if ch == "'" or ch == "\"":
			quote = ch
			continue
		if ch == "#":
			return i
		if ch == "-" and i + 1 < line.length() and line.substr(i + 1, 1) == "-":
			return i
	return -1


func _offset_is_in_string(content: String, offset: int) -> bool:
	var quote := ""
	var escaped := false
	for i in range(mini(offset, content.length())):
		var ch := content.substr(i, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif ch == "\\":
				escaped = true
			elif ch == quote:
				quote = ""
			continue
		if ch == "'" or ch == "\"":
			quote = ch
	return not quote.is_empty()


func _first_content_line(content: String, base_line: int) -> int:
	var lines := content.split("\n")
	for i in range(lines.size()):
		if not str(lines[i]).strip_edges().is_empty():
			return base_line + i
	return base_line


func _regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex


func _add_issue(severity: String, code: String, path: String, line: int, message: String, extra: Dictionary = {}) -> void:
	var issue := {
		"severity": severity,
		"code": code,
		"path": _diagnostic_path(path),
		"line": maxi(line, 0),
		"column": int(extra.get("column", 1)),
		"message": message,
	}
	for key in extra.keys():
		issue[key] = extra[key]
	_issues.append(issue)


func _sort_issues() -> void:
	_issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ap := str(a.get("path", ""))
		var bp := str(b.get("path", ""))
		if ap != bp:
			return ap < bp
		var al := int(a.get("line", 0))
		var bl := int(b.get("line", 0))
		if al != bl:
			return al < bl
		var ac := int(a.get("column", 1))
		var bc := int(b.get("column", 1))
		if ac != bc:
			return ac < bc
		var a_code := str(a.get("code", ""))
		var b_code := str(b.get("code", ""))
		if a_code != b_code:
			return a_code < b_code
		var a_severity := str(a.get("severity", ""))
		var b_severity := str(b.get("severity", ""))
		if a_severity != b_severity:
			return a_severity < b_severity
		return str(a.get("message", "")) < str(b.get("message", ""))
	)


func _diagnostic_path(path: String) -> String:
	var normalized := path.replace("\\", "/")
	var localized := ProjectSettings.localize_path(normalized)
	if localized.begins_with("res://"):
		return localized.trim_prefix("res://")
	if normalized.begins_with("res://"):
		return normalized.trim_prefix("res://")
	return normalized


func _count_severities() -> void:
	var errors := 0
	var warnings := 0
	for issue in _issues:
		if str(issue.get("severity", "")) == "error":
			errors += 1
		else:
			warnings += 1
	_summary["errors"] = errors
	_summary["warnings"] = warnings
