class_name RestorableRegistry extends RefCounted

## Duck-typed registry for systems that can participate in checkpoints.
##
## A restorable object must implement:
## - snapshot() -> Variant
## - restore(data: Variant) -> void
##
## Phase 3 will build checkpoint orchestration on top of this registry.

const SNAPSHOT_METHOD := "snapshot"
const RESTORE_METHOD := "restore"

var _entries: Dictionary = {}


static func is_restorable(target: Object) -> bool:
	return target != null and target.has_method(SNAPSHOT_METHOD) and target.has_method(RESTORE_METHOD)


func register(name: String, target: Object) -> bool:
	var key := name.strip_edges()
	if key.is_empty():
		push_warning("RestorableRegistry: empty restorable name")
		return false
	if target == null:
		push_warning("RestorableRegistry: '%s' target is null" % key)
		return false
	if not is_restorable(target):
		push_warning("RestorableRegistry: '%s' must implement snapshot() and restore(data)" % key)
		return false
	_entries[key] = target
	return true


func unregister(name: String) -> void:
	_entries.erase(name)


func has(name: String) -> bool:
	return _entries.has(name)


func get_target(name: String) -> Object:
	return _entries.get(name)


func names() -> Array[String]:
	var out: Array[String] = []
	for name in _entries.keys():
		out.append(str(name))
	out.sort()
	return out


func validate_all() -> Array[String]:
	var errors: Array[String] = []
	for name in _entries:
		var target: Object = _entries[name]
		if not is_instance_valid(target):
			errors.append("RestorableRegistry: '%s' target is no longer valid" % name)
		elif not is_restorable(target):
			errors.append("RestorableRegistry: '%s' no longer implements snapshot()/restore()" % name)
	return errors


func snapshot_all(skip_empty: bool = false) -> Dictionary:
	var data := {}
	for name in _entries:
		var target: Object = _entries[name]
		if not is_instance_valid(target):
			continue
		var value: Variant = target.call(SNAPSHOT_METHOD)
		if skip_empty and _is_empty_snapshot(value):
			continue
		data[name] = value
	return data


func restore_all(data: Dictionary) -> void:
	for name in data:
		if not _entries.has(name):
			push_warning("RestorableRegistry: no registered target for '%s'" % str(name))
			continue
		var target: Object = _entries[name]
		if is_instance_valid(target):
			target.call(RESTORE_METHOD, data[name])


func _is_empty_snapshot(value: Variant) -> bool:
	if value == null:
		return true
	if value is Dictionary:
		return value.is_empty()
	if value is Array:
		return value.is_empty()
	return false
