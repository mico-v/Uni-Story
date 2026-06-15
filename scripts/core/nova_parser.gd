class_name NovaParser extends RefCounted

## Tokenizes a NovaScript file into an ordered list of blocks:
##   { "type": "eager", "content": String }  -- from `@<| ... |>`
##   { "type": "lazy",  "content": String }  -- from `<| ... |>`
##   { "type": "text",  "content": String }  -- a single non-empty dialogue line
##
## Extensions:
## - Adds 1-based `line` on all block items.
## - Adds optional `attrs` on block items: `@[k=v; k2=v2]@<| ... |>` or
##   `@[k=v; k2=v2]<| ... |>`.
## - Block attributes are independent of block content and preserved into
##   ScriptLoader for eager/lazy normalization.
##
## Eager and lazy blocks may span multiple physical lines. Dialogue text is
## emitted one block per non-empty line (each line is its own story beat).

static func tokenize(source: String) -> Array:
	var out: Array = []
	var lines := source.split("\n")
	var i := 0
	while i < lines.size():
		var raw := lines[i]
		var stripped := raw.strip_edges()
		var start_line := i + 1
		var header := _parse_block_open(stripped)

		var block_type: String = header.get("type", "")
		var open_token: String = header.get("open_token", "")
		var attrs: Dictionary = header.get("attrs", {})

		if block_type != "":
			var res := _read_block(lines, i, open_token)
			var body := (res[0] as String).strip_edges()
			i = res[1] + 1
			if not body.is_empty():
				out.append({
					"type": block_type,
					"content": body,
					"attrs": attrs,
					"line": start_line,
				})
			continue

		if not stripped.is_empty():
			out.append({"type": "text", "content": stripped, "attrs": {}, "line": i + 1})
		i += 1
	return out


## Parse one block opening line and extract optional attrs.
static func _parse_block_open(line: String) -> Dictionary:
	var out := {"type": "", "open_token": "", "attrs": {}}
	if line.is_empty():
		return out

	# Keep backward-compatible block headers first.
	if line.begins_with("@<|"):
		out["type"] = "eager"
		out["open_token"] = "@<|"
		return out

	if line.begins_with("<|"):
		out["type"] = "lazy"
		out["open_token"] = "<|"
		return out

	if not line.begins_with("@["):
		return out

	var close_idx := line.find("]")
	if close_idx == -1:
		return out

	var attrs := _parse_attrs(line.substr(2, close_idx - 2))
	var rest := line.substr(close_idx + 1).strip_edges()
	if rest.begins_with("@<|"):
		out["type"] = "eager"
		out["open_token"] = "@<|"
		out["attrs"] = attrs
		return out

	if rest.begins_with("<|"):
		out["type"] = "lazy"
		out["open_token"] = "<|"
		out["attrs"] = attrs
		return out

	return out


## Parse `k=v; k2=v2` block attrs. Bare keys or invalid pairs are ignored.
static func _parse_attrs(spec: String) -> Dictionary:
	var attrs: Dictionary = {}
	var raw_parts := spec.split(";", false)
	for raw in raw_parts:
		var trimmed := str(raw).strip_edges()
		if trimmed.is_empty():
			continue
		var sep := trimmed.find("=")
		if sep == -1:
			continue
		var key := trimmed.substr(0, sep).strip_edges()
		if key.is_empty():
			continue
		var value := trimmed.substr(sep + 1).strip_edges()
		if value.begins_with("\"") and value.ends_with("\"") and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		elif value.begins_with("'") and value.ends_with("'") and value.length() >= 2:
			value = value.substr(1, value.length() - 2)
		attrs[key] = value

	return attrs


## Read a `<|`/`@<|` ... `|>` block possibly spanning multiple lines.
## Returns [body_string, last_line_index].
static func _read_block(lines: PackedStringArray, start: int, open_token: String) -> Array:
	var first := lines[start].strip_edges()
	var open_at := first.find(open_token) + open_token.length()

	# Single-line block.
	var close_at := first.rfind("|>")
	if close_at != -1 and close_at >= open_at:
		return [first.substr(open_at, close_at - open_at), start]

	var collected: Array = []
	var head := first.substr(open_at)
	if not head.strip_edges().is_empty():
		collected.append(head)

	var i := start + 1
	while i < lines.size():
		var part := lines[i]
		var end_idx := part.find("|>")
		if end_idx != -1:
			collected.append(part.substr(0, end_idx))
			return ["\n".join(collected), i]
		collected.append(part)
		i += 1
	# Unterminated block: take what we have.
	return ["\n".join(collected), lines.size() - 1]
