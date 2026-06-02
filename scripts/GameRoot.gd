extends Node

const SCENARIO_FILES := [
	"res://resources/scenarios/plan_demo.txt",
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/test_animation.txt",
	"res://resources/scenarios/demo_full.txt",
]
const RESOURCE_ROOT := "res://resources/"

const STORY_ANKOR_LEFT := 0.05
const STORY_ANKOR_RIGHT := 0.95
const SPEAKER_OFFSET_X := 0.05
const BOX_DEFAULT_TOP := 0.78
const BOX_DEFAULT_BOTTOM := 0.95
const BOX_TOP_TOP := 0.08
const BOX_TOP_BOTTOM := 0.38
const BOX_CENTER_TOP := 0.45
const BOX_CENTER_BOTTOM := 0.95
const BOX_FULL_TOP := 0.10
const BOX_FULL_BOTTOM := 0.95
const BOX_SIDE_TOP := 0.78
const BOX_SIDE_BOTTOM := 0.95
const BOX_LEFT_LEFT := 0.02
const BOX_LEFT_RIGHT := 0.45
const BOX_RIGHT_LEFT := 0.55
const BOX_RIGHT_RIGHT := 0.98
const UI_BG_COLOR := Color(0.045, 0.06, 0.1, 0.9)
const UI_ACCENT_COLOR := Color(0.72, 0.88, 1.0, 0.95)
const UI_TEXT_COLOR := Color(0.96, 0.98, 1.0, 1.0)
const BUTTON_MIN_WIDTH := 560.0
const BUTTON_HEIGHT := 56.0

const UI_BUTTON_SKIN_NORMAL := "res://resources/button_ring/button_ring_0.png"
const UI_BUTTON_SKIN_HOVER := "res://resources/button_ring/button_ring_1.png"
const UI_BUTTON_SKIN_PRESSED := "res://resources/button_ring/button_ring_2.png"
const UI_BUTTON_SKIN_FOCUS := "res://resources/button_ring/button_ring_3.png"
const UI_BUTTON_SKIN_DISABLED := "res://resources/button_ring/button_ring_4.png"

var _nodes: Dictionary = {}
var _start_nodes: Array = []
var _unlocked_nodes: Array = []
var _current_node: StringName = ""
var _current_event_index := 0
var _current_node_data: Dictionary = {}
var _is_waiting_choice := false
var _camera_position := Vector2.ZERO
var _camera_scale := 1.0
var _camera_rotation := 0.0
var _display_object_states: Dictionary = {}

@onready var _hud: Control = $Hud
@onready var _title_label: Label = $Hud/Panel/Title
@onready var _status_label: Label = $Hud/Panel/Status
@onready var _speaker_label: Label = $Hud/Panel/Speaker
@onready var _story_label: RichTextLabel = $Hud/Panel/Story
@onready var _chapter_list: VBoxContainer = $Hud/Panel/ChapterList
@onready var _choice_list: VBoxContainer = $Hud/Panel/Choices
@onready var _controls: HBoxContainer = $Hud/Panel/Controls
@onready var _start_btn: Button = $Hud/Panel/Controls/StartButton
@onready var _next_btn: Button = $Hud/Panel/Controls/NextButton
@onready var _restart_btn: Button = $Hud/Panel/Controls/RestartButton
@onready var _quit_btn: Button = $Hud/Panel/Controls/QuitButton
@onready var _bg: TextureRect = $Hud/Panel/Background
@onready var _fg: TextureRect = $Hud/Panel/Foreground


func _ready() -> void:
	_apply_ui_style()
	_parse_scenarios()
	_refresh_chapter_buttons()
	_show_title_state()
	_apply_box_mode("default")

	_style_button(_start_btn)
	_style_button(_next_btn)
	_style_button(_restart_btn)
	_style_button(_quit_btn)
	_start_btn.pressed.connect(_on_start_pressed)
	_next_btn.pressed.connect(_on_next_pressed)
	_restart_btn.pressed.connect(_on_restart_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)


func _apply_ui_style() -> void:
	var theme := Theme.new()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UI_BG_COLOR
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.75, 0.82, 0.95, 0.45)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 2)
	panel_style.expand_margin_left = 16
	panel_style.expand_margin_right = 16
	panel_style.expand_margin_top = 16
	panel_style.expand_margin_bottom = 16
	theme.set_stylebox("panel", "Panel", panel_style)

	theme.set_color("font_color", "Label", UI_TEXT_COLOR)
	theme.set_color("font_color", "Button", UI_TEXT_COLOR)
	theme.set_color("font_color", "RichTextLabel", UI_TEXT_COLOR)
	theme.set_color("font_shadow_color", "Button", Color(0.0, 0.0, 0.0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_constant("shadow_offset_x", "Button", 1)
	theme.set_constant("shadow_offset_y", "Button", 1)
	theme.set_font_size("font_size", "Label", 24)
	theme.set_font_size("font_size", "Button", 22)
	theme.set_font_size("font_size", "RichTextLabel", 28)
	theme.set_color("default_color", "RichTextLabel", UI_TEXT_COLOR)
	theme.set_constant("line_separation", "RichTextLabel", 10)

	var btn_normal := _create_button_style(UI_BUTTON_SKIN_NORMAL, UI_TEXT_COLOR)
	var btn_hover := _create_button_style(UI_BUTTON_SKIN_HOVER, UI_ACCENT_COLOR)
	var btn_pressed := _create_button_style(UI_BUTTON_SKIN_PRESSED, Color(0.65, 0.75, 1.0, 0.95))
	var btn_focus := _create_button_style(UI_BUTTON_SKIN_FOCUS, UI_ACCENT_COLOR)
	var btn_disabled := _create_button_style(UI_BUTTON_SKIN_DISABLED, Color(0.56, 0.56, 0.62, 0.75))
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn_focus)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.03, 0.05, 0.09, 0.68)
	box_style.border_width_left = 1
	box_style.border_width_top = 1
	box_style.border_width_right = 1
	box_style.border_width_bottom = 1
	box_style.border_color = Color(0.65, 0.78, 0.95, 0.45)
	box_style.corner_radius_top_left = 6
	box_style.corner_radius_top_right = 6
	box_style.corner_radius_bottom_left = 6
	box_style.corner_radius_bottom_right = 6
	box_style.expand_margin_left = 12
	box_style.expand_margin_right = 12
	box_style.expand_margin_top = 10
	box_style.expand_margin_bottom = 10
	_title_label.add_theme_stylebox_override("normal", box_style)
	_status_label.add_theme_stylebox_override("normal", box_style)
	_story_label.add_theme_stylebox_override("normal", box_style)
	_speaker_label.add_theme_stylebox_override("normal", box_style)

	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	_status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))
	_speaker_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.5))

	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_status_label.add_theme_font_size_override("font_size", 20)
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_story_label.add_theme_font_size_override("font_size", 30)
	_chapter_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls.alignment = BoxContainer.ALIGNMENT_CENTER

	_hud.theme = theme


func _create_button_style(path: String, text_color: Color) -> StyleBoxTexture:
	var tex := _load_image_texture(path)
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = 18
	style.texture_margin_top = 10
	style.texture_margin_right = 18
	style.texture_margin_bottom = 10
	style.draw_center = true
	style.modulate_color = text_color
	return style


func _load_image_texture(path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


func _style_button(btn: Button) -> void:
	btn.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER



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
			pending_commands.clear()
			for cmd in commands:
				var cmd_name := _command_name(cmd)
				if cmd_name == "label":
					var args := _parse_args(cmd)
					if not args.is_empty():
						current_node = StringName(args[0])
						if not _nodes.has(current_node):
							_nodes[current_node] = {
								"display": args[1] if args.size() > 1 else str(current_node),
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
				pending_commands.append(cmd)
			i += 1
			continue

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
	var first := raw.substr(raw.find("<|") + 2)
	if not first.is_empty():
		collect.append(first)
	i += 1
	while i < lines.size():
		var part := lines[i]
		var end_idx := part.find("|>")
		if end_idx != -1:
			collect.append(part.substr(0, end_idx))
			break
		collect.append(part)
		i += 1
	body = "\n".join(collect)
	return [body, i]


func _flush_event(node_name: StringName, commands: Array, text_lines: Array) -> void:
	if node_name == "":
		return
	if commands.is_empty() and text_lines.is_empty():
		return

	var node_data: Dictionary = _nodes[node_name]
	var text := "\n".join(text_lines).strip_edges()
	if text.is_empty():
		return

	if commands.is_empty():
		for raw_line in text.split("\n"):
			var line := raw_line.strip_edges()
			if line.is_empty():
				continue
			node_data["events"].append({
				"commands": [],
				"text": line,
				"type": "dialogue",
			})
		return

	var event := {
		"commands": commands.duplicate(),
		"text": text,
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
	var normalized := body
	normalized = normalized.replace("\\\r\n", " ")
	normalized = normalized.replace("\\\n", " ")
	normalized = normalized.replace("\\\r", " ")
	var out := []
	var cur := ""
	var depth := 0
	var in_string := false
	var quote := ""
	var i := 0

	while i < normalized.length():
		var ch := normalized[i]
		if in_string:
			if ch == "\\" and i + 1 < normalized.length():
				cur += ch
				cur += normalized[i + 1]
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
	var normalized := raw.strip_edges()
	if normalized == "":
		return normalized
	if normalized == "null":
		return null
	if normalized.to_lower() == "true":
		return true
	if normalized.to_lower() == "false":
		return false
	if normalized.begins_with('"') and normalized.ends_with('"'):
		return normalized.substr(1, normalized.length() - 2)
	if normalized.begins_with("'") and normalized.ends_with("'"):
		return normalized.substr(1, normalized.length() - 2)
	if normalized.begins_with("Vector3(") and normalized.ends_with(")"):
		return _parse_vector3(normalized)
	if normalized.begins_with("Color(") and normalized.ends_with(")"):
		return _parse_color(normalized)
	if normalized.is_valid_float():
		return normalized.to_float()
	if normalized.is_valid_int():
		return normalized.to_int()
	if normalized.begins_with("[") and normalized.ends_with("]"):
		return _parse_array(normalized)
	return normalized


func _parse_vector3(raw: String) -> Vector3:
	var inside := raw.substr("Vector3(".length(), raw.length() - "Vector3(".length() - 1)
	var parts := _split_top_level(inside, ",")
	if parts.size() < 3:
		return Vector3.ZERO
	var x: float = str(parts[0]).to_float()
	var y: float = str(parts[1]).to_float()
	var z: float = str(parts[2]).to_float()
	return Vector3(x, y, z)


func _parse_color(raw: String) -> Color:
	var inside := raw.substr("Color(".length(), raw.length() - "Color(".length() - 1)
	var parts := _split_top_level(inside, ",")
	var r := 1.0
	var g := 1.0
	var b := 1.0
	var a := 1.0
	if parts.size() > 0 and parts[0].strip_edges().is_valid_float():
		r = parts[0].strip_edges().to_float()
	if parts.size() > 1 and parts[1].strip_edges().is_valid_float():
		g = parts[1].strip_edges().to_float()
	if parts.size() > 2 and parts[2].strip_edges().is_valid_float():
		b = parts[2].strip_edges().to_float()
	if parts.size() > 3 and parts[3].strip_edges().is_valid_float():
		a = parts[3].strip_edges().to_float()
	return Color(r, g, b, a)


func _refresh_chapter_buttons() -> void:
	for c in _chapter_list.get_children():
		c.queue_free()
	for n in _unlocked_nodes:
		var node: Dictionary = _nodes[n]
		var b := Button.new()
		b.text = str(node.get("display", n))
		b.pressed.connect(_on_chapter_selected.bind(n))
		_style_button(b)
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
	_display_object_states.clear()
	_camera_position = Vector2.ZERO
	_camera_scale = 1.0
	_camera_rotation = 0.0
	_apply_box_mode("default")
	_capture_initial_display_states()


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
		return

	_show_event()


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
			if not args.is_empty():
				var target := StringName(args[0])
				if _nodes.has(target):
					_change_node(target)
					return true
	return false


func _change_node(target: StringName) -> void:
	if not _nodes.has(target):
		push_warning("Jump target missing: %s" % target)
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
			_style_button(b)
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
	if txt.is_empty():
		return

	var current_speaker := ""
	var lines := []
	for raw_line in txt.split("\n"):
		var t := raw_line.strip_edges()
		if t == "":
			continue

		var marker := t.find("：：")
		if marker == -1:
			marker = t.find(":")
		if marker == -1:
			marker = t.find("：")
		if marker >= 0:
			var parsed_speaker := t.substr(0, marker).strip_edges()
			var line_content := t.substr(marker + 1).strip_edges()
			if parsed_speaker != "" and line_content != "":
				current_speaker = parsed_speaker
				lines.append(line_content)
				continue

		lines.append(t)

	_status_label.text = "状态：对话中"
	_speaker_label.text = current_speaker
	_story_label.text = "\n".join(lines)


func _execute_command(cmd: String) -> void:
	var cmd_name := _command_name(cmd)
	var args := _parse_args(cmd)
	var target_obj: Variant = null

	if cmd_name == "show":
		if args.size() < 2:
			push_warning("show command requires object and asset key")
			return
		target_obj = _resolve_display_object(args[0])
		if target_obj == null:
			push_warning("Unknown display object: %s" % str(args[0]))
			return
		var key := String(args[1])
		var tex_path := RESOURCE_ROOT + key + ".png"
		var tex := _load_image_texture(tex_path)
		if tex == null:
			push_warning("Texture missing: %s" % tex_path)
		else:
			(target_obj as TextureRect).texture = tex
		(target_obj as TextureRect).visible = true
		if args.size() >= 3:
			_apply_transform(target_obj as TextureRect, args[2])
		if args.size() >= 4:
			_set_tint_from_variant(target_obj as TextureRect, args[3])
	elif cmd_name == "hide":
		if args.size() >= 1:
			target_obj = _resolve_display_object(args[0])
			if target_obj:
				(target_obj as TextureRect).visible = false
			else:
				push_warning("Unknown display object: %s" % str(args[0]))
	elif cmd_name == "move":
		if args.size() >= 2:
			var obj_name := str(args[0]).to_lower()
			if obj_name == "cam":
				_apply_camera_transform(args[1])
			else:
				target_obj = _resolve_display_object(args[0])
				if target_obj:
					_apply_transform(target_obj as TextureRect, args[1])
				else:
					push_warning("Unknown display object: %s" % str(args[0]))
	elif cmd_name == "cam":
		if args.size() >= 2:
			_apply_camera_transform(args[1])
	elif cmd_name == "tint":
		if args.size() >= 2:
			target_obj = _resolve_display_object(args[0])
			if target_obj:
				_set_tint_from_variant(target_obj as TextureRect, args[1])
			else:
				push_warning("Unknown display object: %s" % str(args[0]))
	elif cmd_name == "set_box":
		if args.is_empty():
			_set_box_mode("default")
		else:
			_set_box_mode(args[0])
	elif cmd_name == "jump_to":
		pass
	elif cmd_name == "branch":
		pass
	elif cmd_name == "print":
		if not args.is_empty():
			print(args[0])
	else:
		if cmd.begins_with("o.anim."):
			_execute_animation_chain(cmd)
		else:
			push_warning("Unhandled command: %s" % cmd_name)


func _resolve_display_object(raw_obj: Variant) -> TextureRect:
	var key := _normalize_object_key(raw_obj)
	if key == "bg":
		return _bg
	if key == "fg":
		return _fg
	return null


func _normalize_object_key(raw_obj: Variant) -> String:
	var obj_name := str(raw_obj).strip_edges()
	return obj_name.substr(2) if obj_name.begins_with("o.") else obj_name


func _get_display_object_key(obj: TextureRect) -> String:
	if obj == _bg:
		return "bg"
	if obj == _fg:
		return "fg"
	return ""


func _ensure_display_state(key: String) -> void:
	if key == "":
		return
	if _display_object_states.has(key):
		return
	var obj := _resolve_display_object(key)
	if obj == null:
		return
	_display_object_states[key] = {
		"position": obj.position,
		"scale": obj.scale,
		"rotation_degrees": obj.rotation_degrees,
		"modulate": obj.modulate,
	}


func _apply_display_with_camera(key: String) -> void:
	if key == "":
		return
	var obj := _resolve_display_object(key)
	if obj == null:
		return
	_ensure_display_state(key)
	if not _display_object_states.has(key):
		return
	var state: Dictionary = _display_object_states[key]
	var base_pos: Vector2 = state.get("position", Vector2.ZERO)
	var base_scale: Vector2 = state.get("scale", Vector2.ONE)
	var base_rotation: float = float(state.get("rotation_degrees", 0))
	obj.position = base_pos - _camera_position
	obj.scale = base_scale * Vector2(_camera_scale, _camera_scale)
	obj.rotation_degrees = base_rotation + _camera_rotation
	obj.modulate = state.get("modulate", Color.WHITE)


func _apply_camera_to_all_displays() -> void:
	for key in ["bg", "fg"]:
		_ensure_display_state(key)
		_apply_display_with_camera(key)


func _capture_initial_display_states() -> void:
	_display_object_states.clear()
	_ensure_display_state("bg")
	_ensure_display_state("fg")


func _apply_box_mode(mode: Variant) -> void:
	_set_box_mode(mode)


func _set_box_mode(mode: Variant) -> void:
	var box_mode := str(mode).to_lower().strip_edges()
	if box_mode == "" or box_mode == "default":
		_story_label.visible = true
		_speaker_label.visible = true
		_story_label.anchor_left = STORY_ANKOR_LEFT
		_story_label.anchor_right = STORY_ANKOR_RIGHT
		_story_label.anchor_top = BOX_DEFAULT_TOP
		_story_label.anchor_bottom = BOX_DEFAULT_BOTTOM
		_speaker_label.anchor_left = SPEAKER_OFFSET_X
		_speaker_label.anchor_right = 1.0 - SPEAKER_OFFSET_X
		_speaker_label.anchor_top = BOX_DEFAULT_TOP - 0.03
		_speaker_label.anchor_bottom = BOX_DEFAULT_TOP
		return

	match box_mode:
		"top":
			_story_label.visible = true
			_speaker_label.visible = true
			_story_label.anchor_left = STORY_ANKOR_LEFT
			_story_label.anchor_right = STORY_ANKOR_RIGHT
			_story_label.anchor_top = BOX_TOP_TOP
			_story_label.anchor_bottom = BOX_TOP_BOTTOM
			_speaker_label.anchor_left = SPEAKER_OFFSET_X
			_speaker_label.anchor_right = 1.0 - SPEAKER_OFFSET_X
			_speaker_label.anchor_top = BOX_TOP_TOP - 0.04
			_speaker_label.anchor_bottom = BOX_TOP_TOP
		"center":
			_story_label.visible = true
			_speaker_label.visible = true
			_story_label.anchor_left = STORY_ANKOR_LEFT
			_story_label.anchor_right = STORY_ANKOR_RIGHT
			_story_label.anchor_top = BOX_CENTER_TOP
			_story_label.anchor_bottom = BOX_CENTER_BOTTOM
			_speaker_label.anchor_left = SPEAKER_OFFSET_X
			_speaker_label.anchor_right = 1.0 - SPEAKER_OFFSET_X
			_speaker_label.anchor_top = BOX_CENTER_TOP - 0.04
			_speaker_label.anchor_bottom = BOX_CENTER_TOP
		"full":
			_story_label.visible = true
			_speaker_label.visible = true
			_story_label.anchor_left = STORY_ANKOR_LEFT
			_story_label.anchor_right = STORY_ANKOR_RIGHT
			_story_label.anchor_top = BOX_FULL_TOP
			_story_label.anchor_bottom = BOX_FULL_BOTTOM
			_speaker_label.anchor_left = SPEAKER_OFFSET_X
			_speaker_label.anchor_right = 1.0 - SPEAKER_OFFSET_X
			_speaker_label.anchor_top = BOX_FULL_TOP + 0.04
			_speaker_label.anchor_bottom = BOX_FULL_TOP + 0.08
		"left":
			_story_label.visible = true
			_speaker_label.visible = true
			_story_label.anchor_left = BOX_LEFT_LEFT
			_story_label.anchor_right = BOX_LEFT_RIGHT
			_story_label.anchor_top = BOX_SIDE_TOP
			_story_label.anchor_bottom = BOX_SIDE_BOTTOM
			_speaker_label.anchor_left = BOX_LEFT_LEFT
			_speaker_label.anchor_right = BOX_LEFT_RIGHT
			_speaker_label.anchor_top = BOX_SIDE_TOP - 0.04
			_speaker_label.anchor_bottom = BOX_SIDE_TOP
		"right":
			_story_label.visible = true
			_speaker_label.visible = true
			_story_label.anchor_left = BOX_RIGHT_LEFT
			_story_label.anchor_right = BOX_RIGHT_RIGHT
			_story_label.anchor_top = BOX_SIDE_TOP
			_story_label.anchor_bottom = BOX_SIDE_BOTTOM
			_speaker_label.anchor_left = BOX_RIGHT_LEFT
			_speaker_label.anchor_right = BOX_RIGHT_RIGHT
			_speaker_label.anchor_top = BOX_SIDE_TOP - 0.04
			_speaker_label.anchor_bottom = BOX_SIDE_TOP
		"hide":
			_story_label.visible = false
			_speaker_label.visible = false
		_:
			_set_box_mode("default")


func _apply_transform(obj: TextureRect, raw: Variant) -> void:
	if obj == null:
		return
	if not (raw is Array):
		return
	var key := _get_display_object_key(obj)
	if key == "":
		return
	_ensure_display_state(key)
	var values := raw as Array
	var state: Dictionary = _display_object_states[key]
	var position: Vector2 = state.get("position", Vector2.ZERO)
	var scale: Vector2 = state.get("scale", Vector2.ONE)
	var rotation_degrees: float = float(state.get("rotation_degrees", 0.0))
	if values.size() > 0 and _is_number(values[0]):
		position.x = float(values[0])
	if values.size() > 1 and _is_number(values[1]):
		position.y = float(values[1])
	if values.size() > 2 and _is_number(values[2]):
		var s := float(values[2])
		scale = Vector2(s, s)
	if values.size() > 4 and _is_number(values[4]):
		rotation_degrees = float(values[4])
	_display_object_states[key]["position"] = position
	_display_object_states[key]["scale"] = scale
	_display_object_states[key]["rotation_degrees"] = rotation_degrees
	_apply_display_with_camera(key)


func _apply_camera_transform(raw: Variant) -> void:
	if not (raw is Array):
		return
	var values := raw as Array
	if values.size() > 0 and _is_number(values[0]):
		_camera_position.x = float(values[0])
	if values.size() > 1 and _is_number(values[1]):
		_camera_position.y = float(values[1])
	if values.size() > 2 and _is_number(values[2]):
		_camera_scale = float(values[2])
	if values.size() > 4:
		var r: Variant = values[4]
		if r is Array and (r as Array).size() >= 3:
			_camera_rotation = float((r as Array)[2])
		elif _is_number(r):
			_camera_rotation = float(r)
	_apply_camera_to_all_displays()


func _set_tint_from_variant(obj: TextureRect, value: Variant) -> void:
	if obj == null:
		return
	if not (value is Array):
		return
	var key := _get_display_object_key(obj)
	if key == "":
		return
	_ensure_display_state(key)
	var arr := value as Array
	if arr.size() >= 3:
		var a := 1.0
		if arr.size() > 3 and _is_number(arr[3]):
			a = float(arr[3])
		_display_object_states[key]["modulate"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
		_apply_display_with_camera(key)


func _is_number(v: Variant) -> bool:
	return v is float or v is int


func _parse_branch_options(cmd: String) -> Array:
	var options := []
	var body := cmd
	var start := body.find("[")
	var end := body.rfind(")")
	if start == -1 or end <= start:
		return options
	body = body.substr(start + 1, end - start - 1)

	var reg := RegEx.new()
	reg.compile("\\{\\s*dest\\s*=\\s*\"([^\"]+)\"\\s*,\\s*text\\s*=\\s*\"([^\"]+)\"\\s*\\}")
	for hit in reg.search_all(body):
		options.append({
			"dest": StringName(hit.get_string(1)),
			"text": hit.get_string(2),
		})
	return options


func _execute_animation_chain(cmd: String) -> void:
	var rest := cmd.replace("\\", "").strip_edges()
	var current := rest
	while current != "":
		var call_expr := current
		if call_expr.begins_with("."):
			call_expr = "o.anim" + call_expr
		elif not call_expr.begins_with("o.anim."):
			return

		var lp := call_expr.find("(")
		if lp == -1:
			return
		var method_name := call_expr.substr(7, lp - 7).strip_edges()
		var depth := 0
		var i := lp
		var rp := -1

		while i < call_expr.length():
			var ch := call_expr[i]
			if ch == "(":
				depth += 1
			elif ch == ")":
				depth -= 1
				if depth == 0:
					rp = i
					break
			i += 1

		if rp == -1:
			return

		var args := _split_args(call_expr.substr(lp + 1, rp - lp - 1))
		if args.size() >= 3 and (method_name == "PropertyVector3" or method_name == "PropertyColor"):
			var target := _resolve_display_object(args[0])
			if target:
				var property_name := str(args[1])
				var value: Variant = args[2]
				_apply_animation_property(target, property_name, value)

		var tail := call_expr.substr(rp + 1).strip_edges()
		if tail.begins_with("."):
			current = "o.anim" + tail
		else:
			break


func _apply_animation_property(target: TextureRect, property_name: String, value: Variant) -> void:
	if target == null:
		return
	var key := _get_display_object_key(target)
	if key == "":
		return
	_ensure_display_state(key)
	var state: Dictionary = _display_object_states[key]
	var position: Vector2 = state.get("position", Vector2.ZERO)
	var scale: Vector2 = state.get("scale", Vector2.ONE)
	var rotation_degrees: float = float(state.get("rotation_degrees", 0.0))
	if property_name == "position":
		if not (value is Vector3):
			return
		var v := value as Vector3
		position = Vector2(v.x, v.y)
	elif property_name == "scale":
		if not (value is Vector3):
			return
		var v := value as Vector3
		scale = Vector2(v.x, v.y)
	elif property_name == "rotation_degrees":
		if not (value is Vector3):
			return
		rotation_degrees = float((value as Vector3).z)
	elif property_name == "modulate":
		if value is Color:
			_display_object_states[key]["modulate"] = value
		else:
			return
		_apply_display_with_camera(key)
		return
	else:
		return

	_display_object_states[key]["position"] = position
	_display_object_states[key]["scale"] = scale
	_display_object_states[key]["rotation_degrees"] = rotation_degrees
	_apply_display_with_camera(key)
