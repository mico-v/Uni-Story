@tool
class_name MusicEntry
extends Resource

## Single music track entry for the music gallery / jukebox.
##
## Each entry represents one BGM track with metadata for
## the music gallery UI and playback controls.

## Display name shown in the gallery
@export var display_name: String = ""

## Display name for the composer/artist
@export var composer: String = ""

## Audio stream resource (OGG/MP3)
@export var audio_stream: AudioStream

## Cover art / album art
@export var cover_image: Texture2D

## Category (e.g. "BGM", "Theme", "Character")
@export var category: String = "BGM"

## Loop start position in seconds (0 = from beginning)
@export var loop_start: float = 0.0

## Loop end position in seconds (0 = to end of track)
@export var loop_end: float = 0.0

## Chapter where this track is unlocked
@export var unlock_chapter: String = ""

## Sort order in the gallery
@export var sort_order: int = 0

## Whether unlocked by default
@export var unlocked_by_default: bool = false


func _init() -> void:
	resource_name = "MusicEntry"


func is_valid() -> bool:
	return not display_name.is_empty() and audio_stream != null
