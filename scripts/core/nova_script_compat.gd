class_name NovaScriptCompat extends RefCounted

## Compatibility helpers for Nova's Lua-flavored scenario syntax.
##
## This is intentionally a translation layer in front of the GDScript runtime:
## Uni-Story remains GDScript-first while accepting the common NovaScript forms
## used by the upstream sample scenarios.

const LOCAL_LABEL_PREFIX := "l_"


static func namespace_for_path(path: String) -> String:
	return path.get_file().get_basename()


static func resolve_label(label_name: Variant, ns: String) -> String:
	var value := str(label_name)
	if value.begins_with(LOCAL_LABEL_PREFIX):
		return "%s:%s" % [ns, value.substr(LOCAL_LABEL_PREFIX.length())]
	return value


static func translate_block(source: String, ns: String = "") -> String:
	var text := source.replace("\r\n", "\n")
	text = _rewrite_function_conditions(text)
	text = _rewrite_branch_outer(text)
	text = _rewrite_lua_callbacks_inline(text)

	var out: Array[String] = []
	var in_branch := false
	var temp_names: Dictionary = {}
	for raw_line in text.split("\n"):
		var line := _strip_lua_comment(str(raw_line))
		var stripped := line.strip_edges()

		if stripped.is_empty():
			out.append(line)
			continue

		if stripped.begins_with("branch(["):
			in_branch = true

		if in_branch:
			line = _rewrite_branch_line(line, ns)
			out.append(line)
			if stripped.begins_with("])"):
				in_branch = false
			continue

		line = _rewrite_lua_control(line)
		if line.strip_edges() == "":
			continue

		line = _rewrite_lua_method_call(line)
		line = _rewrite_lua_local(line)
		line = _rewrite_lua_tables(line)
		line = _rewrite_callable_args(line)
		if _should_skip_external_assignment(line):
			continue
		line = _rewrite_command_shorthand(line, ns)
		line = _rewrite_runtime_object_args(line)
		line = _rewrite_assignment(line, temp_names)
		if not _is_assignment_output(line):
			line = _translate_expr_variables(line, temp_names)
		line = line.replace("nil", "null")
		line = line.replace("__Nova.prefabLoader", _gd_quote("prefab_loader"))
		line = line.replace("__Nova.uiPrefabLoader", _gd_quote("ui_prefab_loader"))
		line = line.replace("__Nova.variables:ToString()", "str(nova.variables.to_dict())")
		line = line.replace("__Nova.variables.ToString()", "str(nova.variables.to_dict())")
		line = _balance_line_parentheses(_normalize_indent_to_tabs(line))
		out.append(line)

	return "\n".join(out)


static func translate_condition(expr: String) -> String:
	if expr.find("get_nova_variable(") != -1:
		return expr
	return _translate_expr_variables(expr.replace("nil", "null"), {})


static func interpolate_text(text: String, variables: Variables) -> String:
	if variables == null or text.find("{{") == -1:
		return text
	var result := text
	var re := RegEx.new()
	re.compile("\\{\\{([^}]+)\\}\\}")
	var matches := re.search_all(text)
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var key := m.get_string(1).strip_edges()
		var value: Variant = variables.get_any(key, "")
		result = result.substr(0, m.get_start()) + str(value) + result.substr(m.get_end())
	return result


static func _rewrite_function_conditions(text: String) -> String:
	var lines := text.split("\n")
	var out: Array[String] = []
	var i := 0
	while i < lines.size():
		var line := str(lines[i])
		if line.find("cond") != -1 and line.find("function") != -1:
			var cond_pos := line.find("cond")
			var prefix := line.substr(0, cond_pos)
			var expr := ""
			var suffix := ""
			i += 1
			while i < lines.size():
				var raw_body_line := str(lines[i])
				var body_line := raw_body_line.strip_edges()
				if body_line.begins_with("return "):
					expr = body_line.substr("return ".length()).strip_edges()
				if body_line == "end" or body_line.ends_with("end },") or body_line.ends_with("end }"):
					var end_pos := raw_body_line.find("end")
					if end_pos != -1:
						suffix = raw_body_line.substr(end_pos + "end".length())
					break
				i += 1
			out.append("%scond = %s%s" % [prefix, _gd_quote(translate_condition(expr)), suffix])
		else:
			out.append(line)
		i += 1
	return "\n".join(out)


static func _rewrite_branch_outer(text: String) -> String:
	var out: Array[String] = []
	var in_branch := false
	for raw_line in text.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if not in_branch and stripped.begins_with("branch {"):
			out.append(line.replace("branch {", "branch(["))
			in_branch = true
			continue
		if in_branch and stripped == "}":
			var indent := _indent_of(line)
			out.append(indent + "])")
			in_branch = false
			continue
		out.append(line)
	return "\n".join(out)


static func _rewrite_branch_line(line: String, ns: String) -> String:
	var out := line
	out = _rewrite_dest_value(out, ns)
	out = _rewrite_cond_value(out)
	out = _rewrite_image_tuple(out)
	return out


static func _rewrite_dest_value(line: String, ns: String) -> String:
	var re := RegEx.new()
	re.compile("(dest\\s*=\\s*)(['\"])([^'\"]+)(['\"])")
	var m := re.search(line)
	if m == null:
		return line
	var resolved := resolve_label(m.get_string(3), ns)
	return line.substr(0, m.get_start()) + m.get_string(1) + _gd_quote(resolved) + line.substr(m.get_end())


static func _rewrite_cond_value(line: String) -> String:
	if line.find("get_nova_variable(") != -1:
		return line
	var double_re := RegEx.new()
	double_re.compile("(cond\\s*=\\s*)\"([^\"]*)\"")
	var m := double_re.search(line)
	if m != null:
		var expr := translate_condition(m.get_string(2))
		return line.substr(0, m.get_start()) + m.get_string(1) + _gd_quote(expr) + line.substr(m.get_end())

	var single_re := RegEx.new()
	single_re.compile("(cond\\s*=\\s*)'([^']*)'")
	m = single_re.search(line)
	if m != null:
		var expr := translate_condition(m.get_string(2))
		return line.substr(0, m.get_start()) + m.get_string(1) + _gd_quote(expr) + line.substr(m.get_end())

	return line


static func _rewrite_image_tuple(line: String) -> String:
	var re := RegEx.new()
	re.compile("image\\s*=\\s*\\{\\s*(['\"][^'\"]+['\"])\\s*,\\s*\\{([^}]*)\\}\\s*\\}")
	var m := re.search(line)
	if m == null:
		return line
	var replacement := "image = [%s, [%s]]" % [m.get_string(1), m.get_string(2)]
	return line.substr(0, m.get_start()) + replacement + line.substr(m.get_end())


static func _rewrite_lua_control(line: String) -> String:
	var stripped := line.strip_edges()
	var indent := _indent_of(line)
	if stripped == "end":
		return ""
	if stripped == "else":
		return indent + "else:"
	if stripped.begins_with("if ") and stripped.ends_with(" then"):
		var expr := stripped.substr(3, stripped.length() - 8).strip_edges()
		return indent + "if " + translate_condition(expr) + ":"
	if stripped.begins_with("elseif ") and stripped.ends_with(" then"):
		var expr := stripped.substr(7, stripped.length() - 12).strip_edges()
		return indent + "elif " + translate_condition(expr) + ":"
	return line


static func _rewrite_lua_callbacks_inline(text: String) -> String:
	var out: Array[String] = []
	var callback_depth := 0
	for raw_line in text.split("\n"):
		var line := str(raw_line)
		var stripped := line.strip_edges()
		if stripped.find("function(") != -1:
			callback_depth += 1
			continue
		if stripped == "end" or stripped.begins_with("end,") or stripped.begins_with("end)") or stripped.begins_with("end }"):
			if callback_depth > 0:
				callback_depth -= 1
			continue
		if stripped.begins_with("return "):
			continue
		if stripped.begins_with("):"):
			continue
		if callback_depth > 0:
			out.append(_dedent_callback_line(line))
		else:
			out.append(line)
	return "\n".join(out)


static func _rewrite_lua_method_call(line: String) -> String:
	var stripped := line.strip_edges()
	var out := line if stripped.begins_with("if ") or stripped.begins_with("elif ") else line.replace("):", ").")
	var re := RegEx.new()
	re.compile("([A-Za-z_]\\w*)\\s*:\\s*([A-Za-z_]\\w*)")
	var matches := re.search_all(out)
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var replacement := "%s.%s" % [m.get_string(1), m.get_string(2)]
		out = out.substr(0, m.get_start()) + replacement + out.substr(m.get_end())
	return out


static func _rewrite_lua_local(line: String) -> String:
	var stripped := line.strip_edges()
	if stripped.begins_with("local "):
		var indent := _indent_of(line)
		return indent + "var " + stripped.substr("local ".length())
	return line


static func _rewrite_lua_tables(line: String) -> String:
	var out := line
	var re := RegEx.new()
	re.compile("\\{([^{}]*)\\}")
	while true:
		var m := re.search(out)
		if m == null:
			break
		var content := m.get_string(1).strip_edges()
		var replacement := _convert_lua_table_content(content)
		out = out.substr(0, m.get_start()) + replacement + out.substr(m.get_end())
	return out.replace("__DICT_OPEN__", "{").replace("__DICT_CLOSE__", "}")


static func _convert_lua_table_content(content: String) -> String:
	if content.find("=") == -1:
		return "[%s]" % content
	var parts := _split_top_level_csv(content)
	var items: Array[String] = []
	for raw_part in parts:
		var part := raw_part.strip_edges()
		if part.is_empty():
			continue
		var eq := part.find("=")
		if eq == -1:
			items.append(part)
			continue
		var key := part.substr(0, eq).strip_edges()
		var value := part.substr(eq + 1).strip_edges()
		items.append("%s: %s" % [_gd_quote(key), value])
	return "__DICT_OPEN__%s__DICT_CLOSE__" % ", ".join(items)


static func _rewrite_callable_args(line: String) -> String:
	var out := line
	for fn in ["show", "hide", "vfx", "video_hide"]:
		out = out.replace("action(%s," % fn, "action(Callable(self, %s)," % _gd_quote(fn))
		out = out.replace("action(%s)" % fn, "action(Callable(self, %s))" % _gd_quote(fn))
	return out


static func _should_skip_external_assignment(line: String) -> bool:
	var stripped := line.strip_edges()
	if stripped.begins_with("__Nova."):
		return true
	if stripped.begins_with("var "):
		return false
	var eq := stripped.find("=")
	if eq != -1 and stripped.find("==") == -1 and stripped.substr(0, eq).find(".") != -1:
		return true
	return false


static func _split_top_level_csv(text: String) -> Array[String]:
	var out: Array[String] = []
	var depth := 0
	var quote := ""
	var start := 0
	for i in range(text.length()):
		var ch := text.substr(i, 1)
		if not quote.is_empty():
			if ch == quote:
				quote = ""
			continue
		if ch == "'" or ch == "\"":
			quote = ch
			continue
		if ch == "[" or ch == "{" or ch == "(":
			depth += 1
		elif ch == "]" or ch == "}" or ch == ")":
			depth = maxi(0, depth - 1)
		elif ch == "," and depth == 0:
			out.append(text.substr(start, i - start))
			start = i + 1
	out.append(text.substr(start))
	return out


static func _rewrite_command_shorthand(line: String, ns: String) -> String:
	var re := RegEx.new()
	re.compile("^(\\s*)(label|jump_to|is_end)\\s+(['\"])([^'\"]+)(['\"])(.*)$")
	var m := re.search(line)
	if m == null:
		return line
	var fn := m.get_string(2)
	var arg := m.get_string(4)
	if fn == "label" or fn == "jump_to":
		arg = resolve_label(arg, ns)
	return "%s%s(%s)%s" % [m.get_string(1), fn, _gd_quote(arg), m.get_string(6)]


static func _rewrite_runtime_object_args(line: String) -> String:
	var out := line
	for fn in [
		"show", "hide", "move", "tint", "vfx", "clear_vfx",
		"trans", "trans2", "trans_fade", "trans_left", "trans_right", "trans_up", "trans_down",
		"fade_out", "fade_in", "volume", "wait_all", "play", "env_tint", "say",
	]:
		var re := RegEx.new()
		re.compile("\\b%s\\(\\s*([A-Za-z_]\\w*)(\\s*[,\\)])" % fn)
		while true:
			var m := re.search(out)
			if m == null or m.get_string(1) == "null":
				break
			out = out.substr(0, m.get_start(1)) + _gd_quote(m.get_string(1)) + out.substr(m.get_end(1))
	return out


static func _rewrite_assignment(line: String, temp_names: Dictionary) -> String:
	var re := RegEx.new()
	re.compile("^(\\s*)([A-Za-z_]\\w*)\\s*=\\s*(.+)$")
	var m := re.search(line)
	if m == null:
		return line
	var name := m.get_string(2)
	if line.find("==") != -1 or name == "var":
		return line
	var expr := _translate_expr_variables(m.get_string(3), temp_names).replace("nil", "null")
	if name.begins_with("v_"):
		return "%sset_nova_variable(%s, %s, false)" % [m.get_string(1), _gd_quote(name), expr]
	if name.begins_with("gv_"):
		return "%sset_nova_variable(%s, %s, true)" % [m.get_string(1), _gd_quote(name), expr]
	temp_names[name] = true
	return "%sset_temp_var(%s, %s)" % [m.get_string(1), _gd_quote(name), expr]


static func _is_assignment_output(line: String) -> bool:
	var stripped := line.strip_edges()
	return stripped.begins_with("set_nova_variable(") or stripped.begins_with("set_temp_var(")


static func _translate_expr_variables(expr: String, temp_names: Dictionary) -> String:
	if expr.find("get_nova_variable(") != -1:
		return expr
	var out := expr
	out = _replace_var_tokens(out, "\\bgv_[A-Za-z0-9_]*\\b", true)
	out = _replace_var_tokens(out, "\\bv_[A-Za-z0-9_]*\\b", false)
	for name in temp_names.keys():
		out = _replace_word(out, str(name), "get_temp_var(%s)" % _gd_quote(str(name)))
	return out


static func _replace_var_tokens(text: String, pattern: String, is_global: bool) -> String:
	var re := RegEx.new()
	re.compile(pattern)
	var matches := re.search_all(text)
	var out := text
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		var name := m.get_string(0)
		var global_text := "true" if is_global else "false"
		var replacement := "get_nova_variable(%s, %s)" % [_gd_quote(name), global_text]
		out = out.substr(0, m.get_start()) + replacement + out.substr(m.get_end())
	return out


static func _replace_word(text: String, word: String, replacement: String) -> String:
	var re := RegEx.new()
	re.compile("\\b%s\\b" % word)
	var matches := re.search_all(text)
	var out := text
	for i in range(matches.size() - 1, -1, -1):
		var m := matches[i]
		out = out.substr(0, m.get_start()) + replacement + out.substr(m.get_end())
	return out


static func _strip_lua_comment(line: String) -> String:
	var idx := line.find("--")
	if idx == -1:
		return line
	return line.substr(0, idx)


static func _indent_of(line: String) -> String:
	var i := 0
	while i < line.length():
		var ch := line.substr(i, 1)
		if ch != " " and ch != "\t":
			break
		i += 1
	return line.substr(0, i)


static func _dedent_callback_line(line: String) -> String:
	var out := line
	if out.begins_with("\t"):
		return out.substr(1)
	var removed := 0
	while removed < 8 and out.begins_with(" "):
		out = out.substr(1)
		removed += 1
	return out


static func _normalize_indent_to_tabs(line: String) -> String:
	var spaces := 0
	while spaces < line.length() and line.substr(spaces, 1) == " ":
		spaces += 1
	if spaces == 0:
		return line
	var tabs := ""
	for _i in range(int(spaces / 4)):
		tabs += "\t"
	return tabs + line.substr(spaces)


static func _balance_line_parentheses(line: String) -> String:
	var stripped := line.strip_edges()
	if stripped.ends_with(":") or stripped.is_empty():
		return line
	var open_count := 0
	var close_count := 0
	var quote := ""
	for i in range(line.length()):
		var ch := line.substr(i, 1)
		if not quote.is_empty():
			if ch == quote:
				quote = ""
			continue
		if ch == "'" or ch == "\"":
			quote = ch
			continue
		if ch == "(":
			open_count += 1
		elif ch == ")":
			close_count += 1
	var out := line
	for _i in range(maxi(0, open_count - close_count)):
		out += ")"
	return out


static func _gd_quote(value: String) -> String:
	return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\""
