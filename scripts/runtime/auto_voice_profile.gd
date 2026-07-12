class_name AutoVoiceProfile extends Resource

## Project-owned automatic voice naming rules.
##
## Runtime code only deals with stable character ids. A profile maps those ids
## and script-facing aliases to the resource directory used by the project.

@export_range(1, 12, 1) var pad_width: int = 6
@export var extension: String = ".ogg"
@export var characters: Dictionary = {}


func resolve_character(speaker: Variant) -> String:
	var raw: String = str(speaker).strip_edges()
	if raw.is_empty():
		return ""
	if characters.has(raw):
		return raw
	var normalized: String = raw.to_lower()
	for key in characters.keys():
		var canonical: String = str(key)
		if canonical.to_lower() == normalized:
			return canonical
		var cfg: Dictionary = _character_config(canonical)
		var aliases = cfg.get("aliases", [])
		if aliases is Array:
			for alias in aliases:
				if str(alias).strip_edges().to_lower() == normalized:
					return canonical
	return ""


func has_character(speaker: Variant) -> bool:
	return not resolve_character(speaker).is_empty()


func voice_directory(speaker: Variant) -> String:
	var canonical: String = resolve_character(speaker)
	if canonical.is_empty():
		return ""
	return str(_character_config(canonical).get("directory", "")).strip_edges().rstrip("/")


func default_prefix(speaker: Variant) -> String:
	var canonical: String = resolve_character(speaker)
	if canonical.is_empty():
		return ""
	return str(_character_config(canonical).get("prefix", ""))


func voice_path(speaker: Variant, index: int, prefix: Variant = null) -> String:
	var directory: String = voice_directory(speaker)
	if directory.is_empty():
		return ""
	var actual_prefix: String = default_prefix(speaker) if prefix == null else str(prefix)
	var filename := actual_prefix + str(index).pad_zeros(maxi(pad_width, 1))
	return directory.path_join(filename + normalized_extension())


func manual_voice_path(speaker: Variant, voice_id: Variant) -> String:
	var raw: String = str(voice_id).strip_edges()
	if raw.is_empty():
		return ""
	if raw.begins_with("res://") or raw.contains("/") or raw.contains("\\"):
		return _with_extension(raw.replace("\\", "/"))
	var directory: String = voice_directory(speaker)
	if directory.is_empty():
		directory = "Voices"
	return directory.path_join(_with_extension(raw))


func normalized_extension() -> String:
	var value: String = extension.strip_edges()
	if value.is_empty():
		return ""
	return value if value.begins_with(".") else "." + value


func _with_extension(path: String) -> String:
	var ext: String = normalized_extension()
	if ext.is_empty() or path.to_lower().ends_with(ext.to_lower()):
		return path
	return path + ext


func _character_config(canonical: String) -> Dictionary:
	var value = characters.get(canonical, {})
	return value if value is Dictionary else {}
