class_name CheckpointManager extends RefCounted

## Coordinates story checkpoints, reached-data tracking, and bookmark restore.
##
## Checkpoint data is intentionally plain Dictionary/Array data so it can be
## stored as JSON and migrated across save versions.

const EngineLogScript := preload("res://scripts/core/engine_log.gd")

const CHECKPOINT_VERSION := 1
const BOOKMARK_VERSION := 1

var _ctx: Node
var _node_records: Array[Dictionary] = []
var _reached_dialogues: Dictionary = {}
var _reached_endings: Dictionary = {}
var _position_checkpoints: Dictionary = {}
var _last_checkpoint: Dictionary = {}


func _init(ctx: Node) -> void:
	_ctx = ctx


func mark_dialogue_reached(node_name: StringName, entry_index: int, display_name: String = "") -> void:
	if entry_index < 0:
		return
	var node_key := str(node_name)
	var key := _dialogue_key(node_name, entry_index)
	_reached_dialogues[key] = true
	_record_node(node_key, entry_index, display_name)
	var checkpoint := _create_checkpoint(false)
	_position_checkpoints[key] = checkpoint
	_last_checkpoint = checkpoint


func mark_end_reached(end_name: String) -> void:
	var name := end_name.strip_edges()
	if name.is_empty():
		return
	_reached_endings[name] = true
	_last_checkpoint = _create_checkpoint(false)


func is_dialogue_reached(node_name: StringName, entry_index: int) -> bool:
	return _reached_dialogues.has(_dialogue_key(node_name, entry_index))


func is_reached_any_history(node_name: StringName, entry_index: int = 0) -> bool:
	var node_key := str(node_name)
	for key in _reached_dialogues.keys():
		var parsed := _parse_dialogue_key(str(key))
		if parsed.is_empty():
			continue
		if str(parsed.get("node", "")) != node_key:
			continue
		if int(parsed.get("index", -1)) >= entry_index:
			return true
	return false


func is_end_reached(end_name: String) -> bool:
	return _reached_endings.has(end_name)


func latest_checkpoint() -> Dictionary:
	if _last_checkpoint.is_empty():
		return create_checkpoint()
	return _last_checkpoint.duplicate(true)


func create_checkpoint() -> Dictionary:
	return _create_checkpoint(true)


func _create_checkpoint(include_position_checkpoints: bool) -> Dictionary:
	var state := _snapshot_game_state()
	var restorable_data := _snapshot_restorables()
	var checkpoint := {
		"version": CHECKPOINT_VERSION,
		"created_at_unix": Time.get_unix_time_from_system(),
		"state": state,
		"restorables": restorable_data,
		"node_records": _node_records.duplicate(true),
		"reached": {
			"dialogues": _reached_dialogues.duplicate(true),
			"endings": _reached_endings.duplicate(true),
		},
		"checkpoint_restraint": _checkpoint_restraint(),
		"script_hash": {
			"entry": _current_entry_hash(),
			"node": _current_node_hash(),
		},
	}
	if include_position_checkpoints:
		checkpoint["position_checkpoints"] = _position_checkpoints.duplicate(true)
	return checkpoint


func create_bookmark(slot: int = -1) -> Dictionary:
	var checkpoint := create_checkpoint()
	var state: Dictionary = checkpoint.get("state", {}) if checkpoint.get("state", {}) is Dictionary else {}
	var node_name := str(state.get("node", ""))
	var index := int(state.get("index", -1))
	var global_save_id := "%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_msec()]
	var metadata := {
		"version": BOOKMARK_VERSION,
		"slot": slot,
		"created_at_unix": Time.get_unix_time_from_system(),
		"chapter": node_name,
		"display_name": _display_name_for(node_name),
		"entry_index": index,
		"screenshot_path": "",
		"global_save_id": global_save_id,
	}
	return {
		"bookmark": metadata,
		"checkpoint": checkpoint,
	}


func restore_bookmark(data: Dictionary) -> bool:
	var checkpoint = data.get("checkpoint", data)
	if not (checkpoint is Dictionary):
		EngineLogScript.error(EngineLogScript.Category.RESTORE, "CheckpointManager", "bookmark missing checkpoint data")
		return false
	return restore_checkpoint(checkpoint)


func restore_checkpoint(checkpoint: Dictionary) -> bool:
	var state = checkpoint.get("state", {})
	if not (state is Dictionary):
		EngineLogScript.error(EngineLogScript.Category.RESTORE, "CheckpointManager", "checkpoint missing game state")
		return false

	var ok := _restore_game_state(checkpoint)
	if not ok:
		return false

	_restore_secondary_state(checkpoint)
	_restore_reached(checkpoint.get("reached", {}))
	_restore_node_records(checkpoint.get("node_records", []))
	if checkpoint.has("position_checkpoints"):
		_restore_position_checkpoints(checkpoint.get("position_checkpoints", {}))
	_last_checkpoint = checkpoint.duplicate(true)
	return true


func restore_to_position(node_name: String, entry_index: int) -> bool:
	if not is_dialogue_reached(StringName(node_name), entry_index):
		EngineLogScript.warn(EngineLogScript.Category.RESTORE, "CheckpointManager", "position has not been reached: %s:%d" % [node_name, entry_index])
		return false
	var checkpoint = _nearest_position_checkpoint(node_name, entry_index)
	if not (checkpoint is Dictionary) or checkpoint.is_empty():
		checkpoint = latest_checkpoint()
	var ok := restore_checkpoint(checkpoint)
	if not ok:
		return false
	if _ctx.game_state == null:
		return false
	if _ctx.game_state.current_node != null and str(_ctx.game_state.current_node.name) == node_name and _ctx.game_state.current_index == entry_index:
		return true
	if _ctx.game_state.has_method("replay_to_position"):
		var replayed: bool = bool(_ctx.game_state.call("replay_to_position", node_name, entry_index))
		if replayed:
			return true
	return _ctx.game_state.jump_to_position(node_name, entry_index)


func _nearest_position_checkpoint(node_name: String, entry_index: int) -> Dictionary:
	var exact_key := _dialogue_key(StringName(node_name), entry_index)
	var exact = _position_checkpoints.get(exact_key, {})
	if exact is Dictionary and not exact.is_empty():
		return exact.duplicate(true)
	var best_index := -1
	var best_checkpoint: Dictionary = {}
	for key in _position_checkpoints.keys():
		var parsed := _parse_dialogue_key(str(key))
		if parsed.is_empty():
			continue
		if str(parsed.get("node", "")) != node_name:
			continue
		var idx := int(parsed.get("index", -1))
		if idx <= entry_index and idx > best_index:
			var candidate = _position_checkpoints[key]
			if candidate is Dictionary:
				best_index = idx
				best_checkpoint = candidate.duplicate(true)
	return best_checkpoint


func snapshot() -> Dictionary:
	return {
		"node_records": _node_records.duplicate(true),
		"reached": {
			"dialogues": _reached_dialogues.duplicate(true),
			"endings": _reached_endings.duplicate(true),
		},
		"position_checkpoints": _position_checkpoints.duplicate(true),
	}


func restore(data: Dictionary) -> void:
	_restore_reached(data.get("reached", {}))
	_restore_node_records(data.get("node_records", []))
	_restore_position_checkpoints(data.get("position_checkpoints", {}))


func _snapshot_game_state() -> Dictionary:
	if _ctx.game_state == null:
		return {}
	return _ctx.game_state.snapshot()


func _snapshot_restorables() -> Dictionary:
	if _ctx.restorables == null:
		return {}
	return _ctx.restorables.snapshot_all(true)


func _restore_game_state(checkpoint: Dictionary) -> bool:
	if _ctx.game_state == null:
		return false
	var restorable_data = checkpoint.get("restorables", {})
	if restorable_data is Dictionary and restorable_data.has("game_state"):
		return _ctx.game_state.restore(restorable_data["game_state"])
	return _ctx.game_state.restore(checkpoint.get("state", {}))


func _restore_secondary_state(checkpoint: Dictionary) -> void:
	var restorable_data = checkpoint.get("restorables", {})
	if not (restorable_data is Dictionary) or _ctx.restorables == null:
		return
	for name in restorable_data:
		if str(name) == "game_state":
			continue
		var target = _ctx.restorables.get_target(str(name))
		if target != null and is_instance_valid(target):
			target.call("restore", restorable_data[name])


func _record_node(node_name: String, entry_index: int, display_name: String) -> void:
	var record := _find_node_record(node_name)
	if record.is_empty():
		record = {
			"name": node_name,
			"display_name": display_name,
			"parent": _previous_node_name(),
			"begin_dialogue": entry_index,
			"end_dialogue": entry_index,
			"variables_hash": _variables_hash(),
		}
		_node_records.append(record)
		return
	record["end_dialogue"] = max(int(record.get("end_dialogue", entry_index)), entry_index)
	if str(record.get("display_name", "")).is_empty() and not display_name.is_empty():
		record["display_name"] = display_name
	record["variables_hash"] = _variables_hash()


func _find_node_record(node_name: String) -> Dictionary:
	for record in _node_records:
		if str(record.get("name", "")) == node_name:
			return record
	return {}


func _previous_node_name() -> String:
	if _node_records.is_empty():
		return ""
	return str(_node_records.back().get("name", ""))


func _restore_reached(data: Variant) -> void:
	_reached_dialogues.clear()
	_reached_endings.clear()
	if not (data is Dictionary):
		return
	var dialogues = data.get("dialogues", {})
	if dialogues is Dictionary:
		_reached_dialogues = dialogues.duplicate(true)
	var endings = data.get("endings", {})
	if endings is Dictionary:
		_reached_endings = endings.duplicate(true)


func _restore_node_records(data: Variant) -> void:
	_node_records.clear()
	if not (data is Array):
		return
	for record in data:
		if record is Dictionary:
			_node_records.append(record.duplicate(true))


func _restore_position_checkpoints(data: Variant) -> void:
	_position_checkpoints.clear()
	if data is Dictionary:
		_position_checkpoints = data.duplicate(true)


func _checkpoint_restraint() -> Dictionary:
	if _ctx.game_state == null or _ctx.game_state.current_node == null:
		return {}
	return {
		"node_is_save_point": bool(_ctx.game_state.current_node.is_save_point),
	}


func _current_entry_hash() -> String:
	if _ctx.game_state == null or _ctx.game_state.current_node == null:
		return ""
	var index: int = _ctx.game_state.current_index
	if index < 0 or index >= _ctx.game_state.current_node.entries.size():
		return ""
	var entry = _ctx.game_state.current_node.entries[index]
	var source := "%s\n%s\n%s\n%s\n%s" % [entry.speaker, entry.text, entry.before_checkpoint_source, entry.lazy_source, entry.after_dialogue_source]
	return str(hash(source))


func _current_node_hash() -> String:
	if _ctx.game_state == null or _ctx.game_state.current_node == null:
		return ""
	var parts: Array[String] = []
	for entry in _ctx.game_state.current_node.entries:
		parts.append("%s\n%s\n%s\n%s\n%s" % [entry.speaker, entry.text, entry.before_checkpoint_source, entry.lazy_source, entry.after_dialogue_source])
	return str(hash("\n---\n".join(parts)))


func _variables_hash() -> String:
	if _ctx.variables == null:
		return ""
	return str(hash(JSON.stringify(_ctx.variables.to_dict())))


func _display_name_for(node_name: String) -> String:
	if node_name.is_empty() or _ctx.script_loader == null or _ctx.script_loader.graph == null:
		return ""
	var node = _ctx.script_loader.graph.get_node_named(StringName(node_name))
	if node == null:
		return ""
	return node.display_name


func _dialogue_key(node_name: StringName, entry_index: int) -> String:
	return "%s:%d" % [str(node_name), entry_index]


func _parse_dialogue_key(key: String) -> Dictionary:
	var sep := key.rfind(":")
	if sep <= 0 or sep >= key.length() - 1:
		return {}
	return {
		"node": key.substr(0, sep),
		"index": int(key.substr(sep + 1)),
	}
