class_name Backlog extends RefCounted

## Rolling history of dialogue shown to the player, for the review screen.
## Each entry stores speaker, text, position (node + index), and optionally
## a voice path for replay.

signal jump_requested(node_name: String, entry_index: int)

const MAX_ENTRIES := 200

var _entries: Array[Dictionary] = []  # Array[{speaker, text, node, index, voice}]
var _last_voice_path: String = ""


func record(speaker: String, text: String, node_name: String = "", entry_index: int = -1) -> void:
	if text.strip_edges().is_empty():
		return
	var voice := _last_voice_path
	_last_voice_path = ""
	_entries.append({
		"speaker": speaker,
		"text": text,
		"node": node_name,
		"index": entry_index,
		"voice": voice,
	})
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


## Store a voice path that will be attached to the next record() call.
func note_voice(path: String) -> void:
	if not path.is_empty():
		_last_voice_path = path


func entries() -> Array:
	return _entries


func clear() -> void:
	_entries.clear()


func snapshot() -> Array:
	return _entries.duplicate(true)


func restore(data: Array) -> void:
	_entries.clear()
	for entry in data:
		if entry is Dictionary:
			_entries.append(entry)
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
