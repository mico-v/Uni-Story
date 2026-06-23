class_name SaveSystem extends RefCounted

## Slot-based save/load. Each slot is its own JSON file under user://saves/ —
## following the developer's note to split saves across files rather than keeping
## a hand-rolled linked list. A save stores only the model snapshot (node, index,
## variables); presentation is rebuilt by GameState.restore via replay.

const SAVE_DIR := "user://saves/"
const SLOT_COUNT := 6
const AUTO_SAVE_SLOT := 99
const SAVE_VERSION := 1

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
		"version": SAVE_VERSION,
		"chapter": String(_ctx.game_state.current_node.name),
		"state": _ctx.game_state.snapshot(),
	}
	if _ctx.read_tracker:
		data["read_tracker"] = _ctx.read_tracker.snapshot()
	if _ctx.vfx:
		var vfx_data = _ctx.vfx.snapshot()
		if not vfx_data.is_empty():
			data["vfx"] = vfx_data
	if _ctx.dialogue_box:
		data["dialogue_box"] = _ctx.dialogue_box.snapshot()
	if _ctx.composer:
		var comp_data = _ctx.composer.snapshot()
		if not comp_data.is_empty():
			data["composer"] = comp_data
	if _ctx.backlog:
		data["backlog"] = _ctx.backlog.snapshot()
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
	var ver: int = int(parsed.get("version", 0))
	if ver != SAVE_VERSION:
		push_error("SaveSystem: save version mismatch in slot %d (expected %d, got %d)" % [slot, SAVE_VERSION, ver])
		return false
	var ok = _ctx.game_state.restore(parsed["state"])
	if ok:
		if _ctx.read_tracker and parsed.has("read_tracker"):
			var rt_data = parsed["read_tracker"]
			if rt_data is Dictionary:
				_ctx.read_tracker.restore(rt_data)
		if _ctx.vfx and parsed.has("vfx"):
			_ctx.vfx.restore(parsed["vfx"])
		if _ctx.dialogue_box and parsed.has("dialogue_box"):
			_ctx.dialogue_box.restore(parsed["dialogue_box"])
		if _ctx.composer and parsed.has("composer"):
			_ctx.composer.restore(parsed["composer"])
		if _ctx.backlog and parsed.has("backlog"):
			var bl_data = parsed["backlog"]
			if bl_data is Array:
				_ctx.backlog.restore(bl_data)
	return ok


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_slot(slot: int) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var err := DirAccess.remove_absolute(path)
	return err == OK


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


## Auto-save helpers — use a dedicated slot (99) separate from manual (0-5) and quick (98).
func auto_save() -> bool:
	return save(AUTO_SAVE_SLOT)


func has_auto_save() -> bool:
	return has_save(AUTO_SAVE_SLOT)


func load_auto_save() -> bool:
	return load_slot(AUTO_SAVE_SLOT)
