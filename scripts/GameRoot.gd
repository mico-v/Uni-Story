extends Node

const SCENARIO_FILES := [
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/test_animation.txt",
]
const RESOURCE_ROOT := "res://resources/"

var _nodes: Dictionary = {}
var _start_nodes: Array = []
var _unlocked_nodes: Array = []
var _current_node: StringName = ""
var _current_event_index := 0
var _current_node_data: Dictionary = {}
var _is_waiting_choice := false

@onready var _title_label: Label = $Hud/Panel/Title
@onready var _status_label: Label = $Hud/Panel/Status
@onready var _speaker_label: Label = $Hud/Panel/Speaker
@onready var _story_label: RichTextLabel = $Hud/Panel/Story
@onready var _chapter_list: VBoxContainer = $Hud/Panel/ChapterList
@onready var _choice_list: VBoxContainer = $Hud/Panel/Choices
@onready var _start_btn: Button = $Hud/Panel/Controls/StartButton
@onready var _next_btn: Button = $Hud/Panel/Controls/NextButton
@onready var _restart_btn: Button = $Hud/Panel/Controls/RestartButton
@onready var _quit_btn: Button = $Hud/Panel/Controls/QuitButton
@onready var _bg: TextureRect = $Hud/Panel/Background
@onready var _fg: TextureRect = $Hud/Panel/Foreground

func _ready() -> void:
	_parse_scenarios()
	_refresh_chapter_buttons()
	_show_title_state()

	_start_btn.pressed.connect(_on_start_pressed)
	_next_btn.pressed.connect(_on_next_pressed)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

func _parse_scenarios() -> void:
	_nodes.clear()
	_start_nodes.clear()
	_unlocked_nodes.clear()

	for file_path in SCENARIO_FILES:
		if not FileAccess.file_exists(file_path):
			continue
		_parse_scenario_file(file_path)

	for node_name in _nodes.keys():
		var node_data: Dictionary = _nodes[node_name]
		if node_data.get("is_unlocked_start", false):
			_unlocked_nodes.append(node_name)
		if node_data.get("is_start", false):
			_start_nodes.append(node_name)

	if _start_nodes.is_empty():
		_start_nodes = _unlocked_nodes.duplicate()

func _parse_scenario_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var lines := text.split("\n")
	var current_node: StringName = ""
	var pending_commands: Array = []
	var pending_text: Array = []

	var i := 0
	while i < lines.size():
		var raw_line := lines[i]
		if _is_command_start(raw_line):
			_flush_event(current_node, pending_commands, pending_text)
			pending_commands.clear()
			pending_text.clear()

			var pair := _read_command_block(lines, i)
			var body := pair[0] as String
			i = pair[1]
			if body.is_empty():
				i += 1
				continue

			var commands := _split_commands(body)
			for cmd in commands:
				var cmd_name := _command_name(cmd)
				if cmd_name == "label":
					var args := _parse_args(cmd)
					if not args.is_empty():
						current_node = StringName(args[0])
						if not _nodes.has(current_node):
							_nodes[current_node] = {
								"display": args.size() > 1 ? args[1] : str(current_node),
								"events": [],
								"is_start": false,
								"is_unlocked_start": false,
								"is_end": false,
							}
					continue
				if cmd_name == "is_start" and current_node != "":
					_nodes[current_node]["is_start"] = true
					_nodes[current_node]["is_unlocked_start"] = true
					continue
				if cmd_name == "is_unlocked_start" and current_node != "":
					_nodes[current_node]["is_unlocked_start"] = true
					continue
				if cmd_name == "is_end" and current_node != "":
					_nodes[current_node]["is_end"] = true
					continue
				if cmd_name == "set_box" or cmd_name == "is_chapter":
					continue

			pending_commands = commands
			i += 1
			continue

		# normal text line
		if not raw_line.strip_edges().is_empty():
			pending_text.append(raw_line)
		i += 1

	_flush_event(current_node, pending_commands, pending_text)

func _is_command_start(line: String) -> bool:
	var t := line.strip_edges()
	return t.begins_with("@<|") or t == "<|"

func _read_command_block(lines: PackedStringArray, start_index: int) -> Array:
	var raw := lines[start_index].strip_edges()
	var i := start_index
	var body := ""

	if raw.find("|>") != -1:
		var begin := raw.find("<|") + 2
		var end := raw.rfind("|>")
		body = raw.substr(begin, end - begin)
		return [body, i]

	var collect := []
	if raw == "<|":
		i += 1
		while i < lines.size():
			var part := lines[i]
			var end_idx := part.find("|>")
			if end_idx != -1:
				collect.append(part.substr(0, end_idx))
				break
			collect.append(part)
			i += 1
	else:
		# @<| on a non-closed single line
		collect.append(raw.substr(raw.find("<|") + 2))
	body = "\n".join(collect)
	return [body, i]

func _flush_event(node_name: StringName, commands: Array, text_lines: Array) -> void:
	if node_name == "":
		return
	if commands.is_empty() and text_lines.is_empty():
		return

	var node_data: Dictionary = _nodes[node_name]
	var event := {
		"commands": commands.duplicate(),
		"text": "\n".join(text_lines).strip_edges(),
		"type": "dialogue",
	}
	if _contains_branch(commands):
		event["type"] = "branch"
	node_data["events"].append(event)

func _contains_branch(commands: Array) -> bool:
	for cmd in commands:
		if _command_name(cmd) == "branch":
			return true
	return false

func _split_commands(body: String) -> Array:
	var out := []
	var cur := ""
	var depth := 0
	var in_string := false
	var quote := ""
	var i := 0

	while i < body.length():
		var ch := body[i]
		if in_string:
			if ch == "\\" and i + 1 < body.length():
				cur += ch
				cur += body[i + 1]
				i += 1
				continue
			if ch == quote:
				in_string = false
				quote = ""
			cur += ch
			i += 1
			continue
		if ch == '"' or ch == "'":
			in_string = true
			quote = ch
			cur += ch
			i += 1
			continue
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		if (ch == "\n" or ch == ";") and depth == 0:
			if not cur.strip_edges().is_empty():
				out.append(cur.strip_edges())
			cur = ""
			i += 1
			continue
		cur += ch
		i += 1
	if not cur.strip_edges().is_empty():
		out.append(cur.strip_edges())
	return out

func _command_name(cmd: String) -> String:
	var idx := cmd.find("(")
	if idx == -1:
		return cmd.strip_edges()
	return cmd.substr(0, idx).strip_edges()

func _parse_args(cmd: String) -> Array:
	var start := cmd.find("(")
	var end := cmd.rfind(")")
	if start == -1 or end <= start:
		return []
	var inside := cmd.substr(start + 1, end - start - 1)
	return _split_args(inside)

func _split_args(src: String) -> Array:
	var out := []
	var cur := ""
	var depth := 0
	var in_string := false
	var quote := ""
	var i := 0

	while i < src.length():
		var ch := src[i]
		if in_string:
			if ch == "\\" and i + 1 < src.length():
				cur += ch
				cur += src[i + 1]
				i += 1
				i += 1
				continue
			if ch == quote:
				in_string = false
				quote = ""
			cur += ch
			i += 1
			continue
		if ch == '"' or ch == "'":
			in_string = true
			quote = ch
			cur += ch
			i += 1
			continue
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		if ch == "," and depth == 0:
			out.append(_value_to_scalar(cur.strip_edges()))
			cur = ""
			i += 1
			continue
		cur += ch
		i += 1
	if not cur.is_empty():
		out.append(_value_to_scalar(cur.strip_edges()))
	return out

func _parse_array(raw: String) -> Array:
	var content := raw.strip_edges()
	if not content.begins_with("[") or not content.ends_with("]"):
		return []
	content = content.substr(1, content.length() - 2)
	if content.strip_edges().is_empty():
		return []

	var values := []
	var parts := _split_top_level(content, ",")
	for part in parts:
		values.append(_value_to_scalar(part.strip_edges()))
	return values

func _split_top_level(src: String, sep: String) -> Array:
	var out := []
	var cur := ""
	var depth := 0
	var in_string := false
	var quote := ""
	var i := 0

	while i < src.length():
		var ch := src[i]
		if in_string:
			if ch == "\\" and i + 1 < src.length():
				cur += ch
				cur += src[i + 1]
				i += 2
				continue
			if ch == quote:
				in_string = false
				quote = ""
			cur += ch
			i += 1
			continue
		if ch == '"' or ch == "'":
			in_string = true
			quote = ch
			cur += ch
			i += 1
			continue
		if ch == "(" or ch == "[" or ch == "{":
			depth += 1
		elif ch == ")" or ch == "]" or ch == "}":
			depth -= 1
		if ch == sep and depth == 0:
			out.append(cur.strip_edges())
			cur = ""
			i += 1
			continue
		cur += ch
		i += 1
	if not cur.is_empty():
		out.append(cur.strip_edges())
	return out

func _value_to_scalar(raw: String) -> Variant:
	if raw == "":
		return raw
	if raw == "null":
		return null
	if raw.begins_with('"') and raw.ends_with('"'):
		return raw.substr(1, raw.length() - 2)
	if raw.begins_with("'") and raw.ends_with("'"):
		return raw.substr(1, raw.length() - 2)
	if raw.is_valid_float():
		return raw.to_float()
	if raw.is_valid_int():
		return raw.to_int()
	if raw.begins_with("[") and raw.ends_with("]"):
		return _parse_array(raw)
	return raw

func _refresh_chapter_buttons() -> void:
	for c in _chapter_list.get_children():
		c.queue_free()
	for n in _unlocked_nodes:
		var node: Dictionary = _nodes[n]
		var b := Button.new()
		b.text = str(node.get("display", n))
		b.pressed.connect(_on_chapter_selected.bind(n))
		_chapter_list.add_child(b)

func _show_title_state() -> void:
	_title_label.text = "Nova 2 Rewrite"
	_status_label.text = "状态：选择章节开始"
	_speaker_label.text = ""
	_story_label.text = ""
	_choice_list.visible = false
	_clear_choices()
	_bg.visible = false
	_fg.visible = false
	_next_btn.visible = false
	_restart_btn.visible = false
	_start_btn.visible = true
	_start_btn.disabled = _unlocked_nodes.is_empty()
	_chapter_list.visible = true
	_current_node = ""
	_current_event_index = 0
	_current_node_data = {}
	_is_waiting_choice = false

func _on_start_pressed() -> void:
	_show_title_state()

func _on_chapter_selected(node_name: StringName) -> void:
	if not _nodes.has(node_name):
		return
	_current_node = node_name
	_current_node_data = _nodes[node_name]
	_current_event_index = 0
	_is_waiting_choice = false
	_status_label.text = "状态：对话中"
	_start_btn.visible = false
	_chapter_list.visible = false
	_next_btn.visible = true
	_restart_btn.visible = false
	_show_event()

func _on_next_pressed() -> void:
	if _is_waiting_choice:
		return
	_show_event()

func _on_restart_pressed() -> void:
	_show_title_state()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_event() -> void:
	if _current_node == "":
		return
	if _current_event_index >= _current_node_data.events.size():
		_status_label.text = "状态：章节结束"
		_next_btn.visible = false
		restart_show(true)
		return

	var event: Dictionary = _current_node_data.events[_current_event_index]
	_current_event_index += 1

	# execute all commands
	for cmd in event.get("commands", []):
		_execute_command(cmd)

	var text: String = str(event.get("text", ""))
	if not text.is_empty():
		_display_dialogue(text)
		return

	if event.get("type", "") == "branch":
		_spawn_choices(event.get("commands", []))
		return

	if _is_jump_command_event(event):
		return

	if _current_node_data.get("is_end", false) and _current_event_index >= _current_node_data.events.size():
		restart_show(true)

func restart_show(show_end: bool) -> void:
	if show_end:
		_status_label.text = "状态：章节结束"
	_next_btn.visible = false
	_restart_btn.visible = true
	_choice_list.visible = false

func _is_jump_command_event(event: Dictionary) -> bool:
	for cmd in event.get("commands", []):
		if _command_name(cmd) == "jump_to":
			var args := _parse_args(cmd)
			if not args.is_empty() and _nodes.has(args[0]):
				_change_node(args[0])
				return true
	return false

func _change_node(target: StringName) -> void:
	if not _nodes.has(target):
		print("Jump target missing: ", target)
		return
	_current_node = target
	_current_node_data = _nodes[target]
	_current_event_index = 0
	_show_event()

func _spawn_choices(commands: Array) -> void:
	var options: Array = []
	for cmd in commands:
		if _command_name(cmd) == "branch":
			options = _parse_branch_options(cmd)
			break

	if options.is_empty():
		return
	_choice_list.visible = true
	_next_btn.visible = false
	_is_waiting_choice = true
	_clear_choices()
	for o in options:
		var b := Button.new()
		b.text = str(o["text"])
		b.pressed.connect(_on_choice_selected.bind(o["dest"]))
		_choice_list.add_child(b)

func _on_choice_selected(dest: StringName) -> void:
	_is_waiting_choice = false
	_choice_list.visible = false
	_next_btn.visible = true
	_clear_choices()
	_change_node(dest)

func _clear_choices() -> void:
	for c in _choice_list.get_children():
		c.queue_free()

func _display_dialogue(raw_text: String) -> void:
	var txt := raw_text.strip_edges()
	var speaker := ""
	var content := ""
	for raw_line in txt.split("\n"):
		var t := raw_line.strip_edges()
		if t == "":
			continue
		var marker := t.find("：：")
		if marker >= 0:
			speaker = t.substr(0, marker)
			content = t.substr(marker + 3)
			break
		if content == "":
			content = t
			break
	if content == "":
		content = txt
	_speaker_label.text = speaker
	_story_label.text = content

func _execute_command(cmd: String) -> void:
	var name := _command_name(cmd)
	var args := _parse_args(cmd)

	match name:
		"show":
			if args.size() >= 2:
				var target = String(args[0])
				var key = String(args[1])
				var obj = _get_display_object(target)
				if obj:
					obj.texture = load(RESOURCE_ROOT + key + ".png")
					obj.visible = true
				if args.size() >= 3:
					_apply_transform(obj, args[2])
				if args.size() >= 4:
					_set_tint_from_variant(obj, args[3])
		"hide":
			if not args.is_empty():
				var obj = _get_display_object(String(args[0]))
				if obj:
					obj.visible = false
		"move":
			if not args.is_empty():
				var obj = _get_display_object(String(args[0]))
				if obj and args.size() >= 2:
					_apply_transform(obj, args[1])
		"tint":
			if args.size() >= 2:
				var obj = _get_display_object(String(args[0]))
				if obj:
					_set_tint_from_variant(obj, args[1])
		"jump_to":
			pass
		"branch":
			pass
		"print":
			if not args.is_empty():
				print(args[0])
		_:
			pass

func _get_display_object(name: String) -> TextureRect:
	if name == "bg":
		return _bg
	if name == "fg":
		return _fg
	return null

func _set_tint_from_variant(obj: TextureRect, value: Variant) -> void:
	if not value is Array:
		return
	var arr := value as Array
	if arr.size() >= 3:
		var a := 1.0
		if arr.size() > 3 and arr[3] is float:
			a = arr[3]
		obj.modulate = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)

func _apply_transform(obj: TextureRect, raw: Variant) -> void:
	if not raw is Array:
		return
	var values := raw as Array
	if values.size() > 0 and values[0] is float:
		obj.position.x = values[0]
	if values.size() > 1 and values[1] is float:
		obj.position.y = values[1]
	if values.size() > 2 and values[2] is float:
		obj.scale = Vector2(values[2], values[2])
	if values.size() > 4 and values[4] is float:
		obj.rotation_degrees = values[4]

func _parse_branch_options(cmd: String) -> Array:
	var options := []
	var body := cmd
	var start := body.find("[")
	var end := body.rfind(")")
	if start == -1 or end <= start:
		return options
	body = body.substr(start + 1, end - start - 1)

	var reg := RegEx.new()
	reg.compile("\{\s*dest\s*=\s*\"([^\"]+)\"\s*,\s*text\s*=\s*\"([^\"]+)\"\s*\}")
	for hit in reg.search_all(body):
		options.append({
			"dest": StringName(hit.get_string(1)),
			"text": hit.get_string(2),
		})
	return options
