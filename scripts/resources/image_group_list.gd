@tool
class_name ImageGroupList
extends Resource

## Master list of all image groups for the gallery.
##
## This is the top-level resource that the Image Gallery editor
## and runtime gallery UI load.

## All image groups
@export var groups: Array[ImageGroup] = []

## Default sort order (0 = as listed, 1 = by name, 2 = by order field)
@export var sort_mode: int = 0


func _init() -> void:
	resource_name = "ImageGroupList"


func total_entries() -> int:
	var total := 0
	for group in groups:
		if group:
			total += group.entry_count()
	return total


func total_unlocked() -> int:
	var total := 0
	for group in groups:
		if group:
			total += group.unlocked_count()
	return total


func get_group(idx: int) -> ImageGroup:
	if idx >= 0 and idx < groups.size():
		return groups[idx]
	return null


func find_entry(display_name: String) -> ImageEntry:
	for group in groups:
		if group:
			for entry in group.entries:
				if entry and entry.display_name == display_name:
					return entry
	return null
