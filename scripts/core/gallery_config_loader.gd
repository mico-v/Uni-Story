class_name GalleryConfigLoader extends RefCounted

## Parses gallery configuration files (.txt) and returns structured entry arrays.
##
## Config format (INI-like):
##   # comment
##   [cg_name]
##   name = Display Name
##   file = cg/cg1.png
##   unlocked = true
##
## Sections: each [section_id] begins a new entry.
## Keys: name (display name), file (relative path under res://resources/),
##        unlocked (true/false, default true).

const RESOURCE_PREFIX := "res://resources/"


static func load_cg(path: String) -> Array:
	var entries: Array = []
	var sections := _parse_sections(path)
	for sec in sections:
		var file: String = sec.get("file", "").strip_edges()
		if file.is_empty():
			continue
		var entry := {
			"name": sec.get("name", file.get_file().get_basename()),
			"texture_path": RESOURCE_PREFIX + file,
			"unlocked": _to_bool(sec.get("unlocked", "true")),
		}
		entries.append(entry)
	return entries


static func load_music(path: String) -> Array:
	var entries: Array = []
	var sections := _parse_sections(path)
	for sec in sections:
		var file: String = sec.get("file", "").strip_edges()
		if file.is_empty():
			continue
		var base_name: String = file.get_file().get_basename()
		var entry := {
			"name": base_name,
			"display_name": sec.get("name", base_name),
			"path": RESOURCE_PREFIX + file,
			"unlocked": _to_bool(sec.get("unlocked", "true")),
		}
		entries.append(entry)
	return entries


## Parse an INI-style file into an Array of Dictionaries (one per section).
static func _parse_sections(path: String) -> Array:
	var result: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("GalleryConfigLoader: cannot open '%s'" % path)
		return result
	var current: Dictionary = {}
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			if not current.is_empty():
				result.append(current)
			current = {}
			continue
		var eq := line.find("=")
		if eq < 0:
			continue
		var key := line.substr(0, eq).strip_edges()
		var val := line.substr(eq + 1).strip_edges()
		current[key] = val
	if not current.is_empty():
		result.append(current)
	return result


static func _to_bool(s: String) -> bool:
	var lower := s.strip_edges().to_lower()
	return lower == "true" or lower == "yes" or lower == "1"
