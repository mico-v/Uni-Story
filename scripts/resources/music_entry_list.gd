@tool
class_name MusicEntryList
extends Resource

## Master list of all music entries for the music gallery / jukebox.
##
## This is the top-level resource that the Music Gallery editor
## and runtime gallery UI load.

## All music entries
@export var entries: Array[MusicEntry] = []

## Default sort mode (0 = as listed, 1 = by name, 2 = by order field)
@export var sort_mode: int = 0


func _init() -> void:
	resource_name = "MusicEntryList"


func total_tracks() -> int:
	return entries.size()


func get_entry(idx: int) -> MusicEntry:
	if idx >= 0 and idx < entries.size():
		return entries[idx]
	return null


func find_entry(display_name: String) -> MusicEntry:
	for entry in entries:
		if entry and entry.display_name == display_name:
			return entry
	return null


func entries_by_category(category: String) -> Array[MusicEntry]:
	var result: Array[MusicEntry] = []
	for entry in entries:
		if entry and entry.category == category:
			result.append(entry)
	return result
