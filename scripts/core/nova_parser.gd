class_name NovaParser extends RefCounted

## Tokenizes a NovaScript file into an ordered list of blocks:
##   { "type": "eager", "content": String }  -- from `@<| ... |>`
##   { "type": "lazy",  "content": String }  -- from `<| ... |>`
##   { "type": "text",  "content": String }  -- a single non-empty dialogue line
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

		var is_eager := stripped.begins_with("@<|")
		var is_lazy := (not is_eager) and stripped.begins_with("<|")

		if is_eager or is_lazy:
			var open_token := "@<|" if is_eager else "<|"
			var res := _read_block(lines, i, open_token)
			var body := (res[0] as String).strip_edges()
			i = res[1] + 1
			if not body.is_empty():
				out.append({"type": "eager" if is_eager else "lazy", "content": body})
			continue

		if not stripped.is_empty():
			out.append({"type": "text", "content": stripped})
		i += 1
	return out


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
