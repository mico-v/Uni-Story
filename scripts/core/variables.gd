class_name Variables extends RefCounted

## Script-visible persistent state. Presentation scripts read/write named values
## via set_var/get_var; these survive across nodes within a playthrough and are
## serializable, so a future save system can snapshot them alongside GameState.
##
## Conditional flow uses these: a branch option may carry a `cond` (only offered
## when true) and an `eval` (run when chosen); jump_if(cond, dest) jumps only when
## the condition holds.

var _store: Dictionary = {}

signal changed(name: String, value: Variant)


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


## Snapshot / restore for save-load.
func to_dict() -> Dictionary:
	return _store.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_store = data.duplicate(true)
