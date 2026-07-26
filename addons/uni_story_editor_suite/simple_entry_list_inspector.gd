@tool
class_name SimpleEntryListInspector
extends RefCounted

## Generic list editor base class for Gallery-like inspectors.
##
## Provides common functionality for building inspector plugins
## that manage lists of Resource entries:
##   - Add/Remove entry buttons
##   - Move up/down reordering
##   - Entry count display
##
## Subclass this and override `_entry_display_name(entry)` to customize.


## Display label for the list header
var list_label: String = "Entries"

## The array of entries to manage (set this before calling build_ui)
var entries: Array = []

## Callback called when entries change
var on_changed: Callable


func build_ui(inspector: EditorInspectorPlugin, container: Control = null) -> void:
	pass  # Base implementation is abstract; see subclass examples


func _entry_display_name(entry: Resource) -> String:
	if entry == null:
		return "(null)"
	var name_prop := entry.get("display_name")
	if name_prop != null:
		return str(name_prop)
	return entry.resource_name


func add_entry(resource_class: Resource) -> void:
	var new_entry := resource_class.duplicate(true)
	entries.append(new_entry)
	if on_changed.is_valid():
		on_changed.call()


func remove_entry(index: int) -> void:
	if index >= 0 and index < entries.size():
		entries.remove_at(index)
		if on_changed.is_valid():
			on_changed.call()


func move_entry_up(index: int) -> void:
	if index > 0 and index < entries.size():
		var tmp := entries[index]
		entries[index] = entries[index - 1]
		entries[index - 1] = tmp
		if on_changed.is_valid():
			on_changed.call()


func move_entry_down(index: int) -> void:
	if index >= 0 and index < entries.size() - 1:
		var tmp := entries[index]
		entries[index] = entries[index + 1]
		entries[index + 1] = tmp
		if on_changed.is_valid():
			on_changed.call()
