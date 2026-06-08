class_name Backlog extends RefCounted

## Rolling history of dialogue shown to the player, for the review (回顾) screen.
## Fed by GameState.dialogue_changed. Capped so long playthroughs don't grow
## unbounded. (The developer's note renames the old LogController to this.)

const MAX_ENTRIES := 200

var _entries: Array = []  # Array[{speaker, text}]


func record(speaker: String, text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_entries.append({"speaker": speaker, "text": text})
	if _entries.size() > MAX_ENTRIES:
		_entries.pop_front()


func entries() -> Array:
	return _entries


func clear() -> void:
	_entries.clear()
