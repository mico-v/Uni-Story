class_name ReadTracker extends RefCounted

## Persistent tracker for dialogue entries the player has already read,
## plus gallery unlock tracking (CG and music).
## Keys are "node_name:index" strings stored in user://read_tracker.json.
## Gallery unlocks stored under "cg:" and "music:" prefixed keys.

signal gallery_unlocked(entry_type: String, entry_name: String)

var _ctx: Node
var _read_entries: Dictionary = {}
var _gallery_unlocks: Dictionary = {}  # {"cg:name": true, "music:name": true}

const SAVE_PATH := "user://read_tracker.json"
const GALLERY_KEY := "gallery_unlocks"


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


# ── Gallery unlock tracking ──────────────────────────────────────────

## Mark a CG as unlocked in the gallery.
func mark_cg(name: String) -> void:
	var key := "cg:" + name
	if not _gallery_unlocks.has(key):
		_gallery_unlocks[key] = true
		gallery_unlocked.emit("cg", name)


## Check if a CG is unlocked.
func is_cg_unlocked(name: String) -> bool:
	return _gallery_unlocks.has("cg:" + name)


## Mark a music track as unlocked in the gallery.
func mark_music(name: String) -> void:
	var key := "music:" + name
	if not _gallery_unlocks.has(key):
		_gallery_unlocks[key] = true
		gallery_unlocked.emit("music", name)


## Check if a music track is unlocked.
func is_music_unlocked(name: String) -> bool:
	return _gallery_unlocks.has("music:" + name)


# ── Persistence ──────────────────────────────────────────────────────

## Persist current read entries and gallery unlocks to disk.
func save_to_disk() -> void:
	var data := {
		"read": _read_entries,
		GALLERY_KEY: _gallery_unlocks,
	}
	var json := JSON.stringify(data, "  ")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()
	else:
		push_warning("ReadTracker: failed to write %s" % SAVE_PATH)


## Load read entries and gallery unlocks from disk.
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
		# Backward compatibility: old format was just the read entries dict.
		if parsed.has("read"):
			_read_entries = parsed.get("read", {})
			_gallery_unlocks = parsed.get(GALLERY_KEY, {})
		else:
			_read_entries = parsed
			_gallery_unlocks = {}


## Clear all read entries and gallery unlocks.
func clear() -> void:
	_read_entries.clear()
	_gallery_unlocks.clear()


## Return a snapshot for save system integration.
func snapshot() -> Dictionary:
	return {
		"read": _read_entries.duplicate(),
		GALLERY_KEY: _gallery_unlocks.duplicate(),
	}


## Restore from a snapshot.
func restore(data: Dictionary) -> void:
	if data.has("read"):
		_read_entries = data["read"].duplicate()
		_gallery_unlocks = data.get(GALLERY_KEY, {}).duplicate()
	else:
		# Backward compatibility with old snapshot format.
		_read_entries = data.duplicate()
