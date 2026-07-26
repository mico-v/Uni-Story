@tool
class_name ImageGroup
extends Resource

## Resource grouping related CG/image entries together.
##
## Typical groups: chapter-based CGs, character illustrations, concept art.
## Used by the Image Gallery UI to organize entries into tabs/sections.

## Display name for this group (e.g. "Chapter 1 CGs")
@export var group_name: String = ""

## Thumbnail for the group tab
@export var thumbnail: Texture2D

## Entries in this group
@export var entries: Array[ImageEntry] = []

## Sort order among groups
@export var sort_order: int = 0


func _init() -> void:
	resource_name = "ImageGroup"


func entry_count() -> int:
	return entries.size()


func get_entry(idx: int) -> ImageEntry:
	if idx >= 0 and idx < entries.size():
		return entries[idx]
	return null


func unlocked_count() -> int:
	var count := 0
	for entry in entries:
		if entry and entry.unlocked_by_default:
			count += 1
	return count


func is_valid() -> bool:
	return not group_name.is_empty()
