class_name SaveSystem extends RefCounted

## Slot-based save/load. Each slot is its own JSON file under user://saves/ —
## following the developer's note to split saves across files rather than keeping
## a hand-rolled linked list. A save stores only the model snapshot (node, index,
## variables); presentation is rebuilt by GameState.restore via replay.

const EngineLogScript := preload("res://scripts/core/engine_log.gd")

const DEFAULT_SAVE_DIR := "user://saves/"
const DEFAULT_SLOT_COUNT := 6
const DEFAULT_AUTO_SAVE_SLOT := 99
const SAVE_VERSION := 1

var _ctx: Node
var save_dir := DEFAULT_SAVE_DIR
var slot_count := DEFAULT_SLOT_COUNT
var auto_save_slot := DEFAULT_AUTO_SAVE_SLOT
var auto_save_enabled := true


func _init(ctx: Node) -> void:
	_ctx = ctx
	_ensure_save_dir()


func configure(dir: String, slots: int, auto_slot: int, auto_enabled: bool) -> void:
	save_dir = dir if not dir.strip_edges().is_empty() else DEFAULT_SAVE_DIR
	slot_count = max(1, slots)
	auto_save_slot = auto_slot
	auto_save_enabled = auto_enabled
	_ensure_save_dir()


func _slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func save(slot: int) -> bool:
	if _ctx.game_state.current_node == null:
		EngineLogScript.warn(EngineLogScript.Category.SAVE, "SaveSystem", "nothing to save (not in a chapter)")
		return false
	var data := {
		"version": SAVE_VERSION,
		"chapter": String(_ctx.game_state.current_node.name),
		"state": _ctx.game_state.snapshot(),
		"restorables": _snapshot_restorables(),
	}
	var f := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if f == null:
		EngineLogScript.error(EngineLogScript.Category.SAVE, "SaveSystem", "cannot write slot %d" % slot)
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
		EngineLogScript.error(EngineLogScript.Category.SAVE, "SaveSystem", "corrupt save in slot %d" % slot)
		return false
	var ver: int = int(parsed.get("version", 0))
	if ver != SAVE_VERSION:
		EngineLogScript.error(EngineLogScript.Category.SAVE, "SaveSystem", "save version mismatch in slot %d (expected %d, got %d)" % [slot, SAVE_VERSION, ver])
		return false
	var ok := _restore_game_state(parsed)
	if ok:
		_restore_secondary_state(parsed)
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
	if not auto_save_enabled:
		return false
	return save(auto_save_slot)


func has_auto_save() -> bool:
	return has_save(auto_save_slot)


func load_auto_save() -> bool:
	return load_slot(auto_save_slot)


func _ensure_save_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))


func _snapshot_restorables() -> Dictionary:
	if _ctx.restorables:
		return _ctx.restorables.snapshot_all(true)
	return {}


func _restore_game_state(parsed: Dictionary) -> bool:
	var restorable_data = parsed.get("restorables", {})
	if restorable_data is Dictionary and restorable_data.has("game_state"):
		return _ctx.game_state.restore(restorable_data["game_state"])
	return _ctx.game_state.restore(parsed["state"])


func _restore_secondary_state(parsed: Dictionary) -> void:
	var restorable_data = parsed.get("restorables", {})
	if restorable_data is Dictionary:
		for name in restorable_data:
			if str(name) == "game_state":
				continue
			var target = _ctx.restorables.get_target(str(name)) if _ctx.restorables else null
			if target != null and is_instance_valid(target):
				target.call("restore", restorable_data[name])
		return

	# Backward compatibility for saves created before the restorable registry.
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
