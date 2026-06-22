class_name Backlog extends RefCounted

## Rolling history of dialogue shown to the player, for the review screen.
## Each entry stores speaker, text, and the position (node + index) where
## it appeared, enabling jump-back from the review screen.

signal jump_requested(node_name: String, entry_index: int)

const MAX_ENTRIES := 200

var _entries: Array = []  # Array[{speaker, text, node, index}]


func record(speaker: String, text: String, node_name: String = "", entry_index: int = -1) -> void:
	if text.strip_edges().is_empty():
		return
	_entries.append({
		"speaker": speaker,
		"text": text,
		"node": node_name,
		"index": entry_index,
	})
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


func entries() -> Array:
	return _entries


func clear() -> void:
	_entries.clear()


func snapshot() -> Array:
	return _entries.duplicate(true)


func restore(data: Array) -> void:
	_entries = data.duplicate(true)
	if _entries.size() > MAX_ENTRIES:
		_entries = _entries.slice(_entries.size() - MAX_ENTRIES)


## Request a jump-back to the position of a specific backlog entry.
func request_jump(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= _entries.size():
		return
	var entry: Dictionary = _entries[entry_index]
	var node_name := str(entry.get("node", ""))
	var idx: int = int(entry.get("index", -1))
	if node_name != "" and idx >= 0:
		jump_requested.emit(node_name, idx)
