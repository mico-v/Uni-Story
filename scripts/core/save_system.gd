class_name SaveSystem extends RefCounted

## Slot-based save/load. Each slot is its own JSON file under user://saves/ —
## following the developer's note to split saves across files rather than keeping
## a hand-rolled linked list. A save stores only the model snapshot (node, index,
## variables); presentation is rebuilt by GameState.restore via replay.

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 6

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_%d.json" % slot


func save(slot: int) -> bool:
	if _ctx.game_state.current_node == null:
		push_warning("SaveSystem: nothing to save (not in a chapter)")
		return false
	var data := {
		"version": 1,
		"chapter": String(_ctx.game_state.current_node.name),
		"state": _ctx.game_state.snapshot(),
	}
	if not data.has("version"):
		data["version"] = 1
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write slot %d" % slot)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


func load_slot(slot: int) -> bool:
	if not has_save(slot):
		return false
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary) or not parsed.has("state"):
		push_error("SaveSystem: corrupt save in slot %d" % slot)
		return false
	return _ctx.game_state.restore(parsed["state"])


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


## Short label for a slot (chapter name + entry index), for the save/load UI.
func slot_label(slot: int) -> String:
	if not has_save(slot):
		return "空"
	var f := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if f == null:
		return "空"
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return "损坏"
	var chapter := str(parsed.get("chapter", "?"))
	var idx := int(parsed.get("state", {}).get("index", 0))
	return "%s @%d" % [chapter, idx]
