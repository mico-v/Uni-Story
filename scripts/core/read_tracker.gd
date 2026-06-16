class_name ReadTracker extends RefCounted

## Persistent tracker for dialogue entries the player has already read.
## Keys are "node_name:index" strings stored in user://read_tracker.json.
## Used by Skip mode to stop fast-forwarding when reaching unread text.

var _ctx: Node
var _read_entries: Dictionary = {}

const SAVE_PATH := "user://read_tracker.json"


func _init(ctx: Node) -> void:
	_ctx = ctx
	_load()


## Mark a specific entry as read.
func mark_read(node_name: StringName, index: int) -> void:
	var key = str(node_name) + ":" + str(index)
	_read_entries[key] = true


## Check whether a specific entry has been read.
func is_read(node_name: StringName, index: int) -> bool:
	var key = str(node_name) + ":" + str(index)
	return _read_entries.has(key)


## Persist current read entries to disk.
func save_to_disk() -> void:
	var json := JSON.stringify(_read_entries, "  ")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
	else:
		push_warning("ReadTracker: failed to write %s" % SAVE_PATH)


## Load read entries from disk.
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_read_entries = parsed


## Clear all read entries.
func clear() -> void:
	_read_entries.clear()


## Return a snapshot for save system integration.
func snapshot() -> Dictionary:
	return _read_entries.duplicate()


## Restore from a snapshot.
func restore(data: Dictionary) -> void:
	_read_entries = data.duplicate()
