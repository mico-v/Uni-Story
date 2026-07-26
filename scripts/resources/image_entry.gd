@tool
class_name ImageEntry
extends Resource

## Single CG/image entry for the image gallery.
##
## Each entry represents one unlockable/viewable image
## with metadata for gallery display.

## Display name shown in the gallery
@export var display_name: String = ""

## Thumbnail texture for the gallery list
@export var thumbnail: Texture2D

## Full-resolution image shown when selected
@export var full_image: Texture2D

## Category/tag for grouping (e.g. "CG", "Illustration")
@export var category: String = "CG"

## Chapter where this image is unlocked
@export var unlock_chapter: String = ""

## Sort order within the gallery (lower = first)
@export var sort_order: int = 0

## Whether this entry is unlocked by default
@export var unlocked_by_default: bool = false


func _init() -> void:
	resource_name = "ImageEntry"


func is_valid() -> bool:
	return not display_name.is_empty() and (thumbnail != null or full_image != null)
