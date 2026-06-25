class_name Variables extends RefCounted

## Script-visible persistent state. Presentation scripts read/write named values
## via set_var/get_var; these survive across nodes within a playthrough and are
## serializable, so a future save system can snapshot them alongside GameState.
##
## Conditional flow uses these: a branch option may carry a `cond` (only offered
## when true) and an `eval` (run when chosen); jump_if(cond, dest) jumps only when
## the condition holds.

var _store: Dictionary = {}
var _temp_store: Dictionary = {}
var _global_store: Dictionary = {}

const GLOBAL_SAVE_PATH := "user://global_variables.json"

signal changed(name: String, value: Variant)


func _init() -> void:
	_load_global()


func set_var(name: String, value: Variant) -> void:
	_store[name] = value
	changed.emit(name, value)


func get_var(name: String, default: Variant = null) -> Variant:
	return _store.get(name, default)


func has_var(name: String) -> bool:
	return _store.has(name)


func add_var(name: String, delta: Variant) -> void:
	var current = get_var(name, 0)
	if current is int and delta is int:
		set_var(name, int(current) + int(delta))
	else:
		set_var(name, float(current) + float(delta))


func clear() -> void:
	_store.clear()
	_temp_store.clear()


## Snapshot / restore for save-load.
func to_dict() -> Dictionary:
	return _store.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_store = data.duplicate(true)


func set_temp(name: String, value: Variant) -> void:
	_temp_store[name] = value


func get_temp(name: String, default: Variant = null) -> Variant:
	return _temp_store.get(name, default)


func set_global(name: String, value: Variant) -> void:
	_global_store[name] = value
	_save_global()


func get_global(name: String, default: Variant = null) -> Variant:
	return _global_store.get(name, default)


func get_any(name: String, default: Variant = null) -> Variant:
	if name.begins_with("gv_"):
		return get_global(name, default)
	if name.begins_with("v_"):
		return get_var(name, default)
	if _temp_store.has(name):
		return _temp_store[name]
	if _store.has(name):
		return _store[name]
	if _global_store.has(name):
		return _global_store[name]
	return default


func _load_global() -> void:
	if not FileAccess.file_exists(GLOBAL_SAVE_PATH):
		return
	var file := FileAccess.open(GLOBAL_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_global_store = parsed.duplicate(true)


func _save_global() -> void:
	var file := FileAccess.open(GLOBAL_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_global_store, "\t"))
	file.close()
