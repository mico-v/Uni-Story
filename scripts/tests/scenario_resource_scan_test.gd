extends SceneTree

## Headless test: scans all scenario files for referenced resources
## (images, audio, prefabs, videos) and reports any that are missing
## from the project filesystem.

const SCENARIO_DIR := "res://resources/scenarios/"
const RESOURCE_ROOT := "res://resources/"
const STANDING_PROFILE_PATH := "res://resources/standing_profile.tres"
const VISUAL_PROFILE_PATH := "res://resources/visual_profile.tres"
const AUTO_VOICE_PROFILE_PATH := "res://resources/auto_voice_profile.tres"
const RESOURCE_EXTENSIONS = [".png", ".jpg", ".jpeg", ".webp", ".ogg", ".mp3", ".wav", ".tscn", ".tres", ".mp4", ".gdshader"]
const VIRTUAL_PREFIXES = ["RenderTargets/"]

var _total_referenced := 0
var _total_missing := 0
var _total_found := 0
var _total_virtual := 0
var _standing_profile: Resource = null
var _visual_profile: Resource = null
var _auto_voice_profile: Resource = null


func _init() -> void:
	_run()


func _run() -> void:
	print("ScenarioResourceScan: scanning scenarios for resource references...")
	print("")
	_standing_profile = load(STANDING_PROFILE_PATH)
	_visual_profile = load(VISUAL_PROFILE_PATH)
	_auto_voice_profile = load(AUTO_VOICE_PROFILE_PATH)

	var files: Array[String] = _list_txt_files(SCENARIO_DIR)
	if files.is_empty():
		print("  No scenario files found in %s" % SCENARIO_DIR)
		_finish(true)
		return

	var scenario_names: Array[String] = []
	for f in files:
		scenario_names.append(f.get_file())
	_ctx("scenarios", scenario_names)

	# Parse all scenarios and scan references.
	for file_path in files:
		_scan_scenario(file_path)
	print("")
	print("ScenarioResourceScan: referenced=%d, found=%d, virtual=%d, missing=%d" % [_total_referenced, _total_found, _total_virtual, _total_missing])
	print("")
	if _total_missing > 0:
		print("ScenarioResourceScan: WARNING — %d missing resource(s) detected." % _total_missing)
	else:
		print("ScenarioResourceScan: OK — all referenced resources exist.")
	_finish(_total_missing == 0)


func _scan_scenario(file_path: String) -> void:
	print("  %s" % file_path.get_file())
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		print("    SKIP: cannot open file")
		return
	var content := f.get_as_text()
	f.close()
	var lines := content.split("\n")
	var in_lazy := false
	for line in lines:
		var stripped := line.strip_edges()
		# Track block boundaries.
		if stripped.begins_with("<|") or stripped.begins_with("[") and stripped.contains("<|"):
			in_lazy = true
			_scan_line(stripped)
			continue
		if stripped.begins_with("|>"):
			in_lazy = false
			continue
		if in_lazy and not stripped.is_empty() and not stripped.begins_with("#") and not stripped.begins_with("//"):
			_scan_line(stripped)


func _scan_line(line: String) -> void:
	_scan_visual_calls(line)
	_scan_audio_calls(line)
	_scan_prefab_and_video_calls(line)

	# Extract string arguments from function calls (both GDScript full paths and Nova short names).
	var regex := RegEx.new()
	regex.compile("[\"']([^\"']*)[\"']")
	for match in regex.search_all(line):
		var path := match.get_string(1)
		if path.begins_with("@") or path.is_empty() or path.begins_with("res://"):
			continue
		# Skip known non-resource strings: numbers, Lua keywords, common values.
		if path.contains(" ") or path.length() > 128:
			continue
		# Only flag strings that look like resource references.
		if path.contains(".") or path.contains("/"):
			_check_resource(str(path))


func _scan_visual_calls(line: String) -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("\\b(?:show|trans|trans2|trans_fade|trans_left|trans_right|trans_up|trans_down)\\s*\\(\\s*([A-Za-z_][A-Za-z0-9_]*)\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in regex.search_all(line):
		var object_name: String = match.get_string(1).to_lower()
		var image_name: String = match.get_string(2).strip_edges()
		match object_name:
			"bg":
				_check_resource("Backgrounds/" + image_name)
			"fg":
				_check_resource("foregrounds/" + image_name)
			"cg":
				_scan_cg_reference(image_name)
			_:
				_scan_standing_reference(object_name, image_name)


func _scan_cg_reference(image_name: String) -> void:
	var resolved: String = image_name
	if _visual_profile != null and _visual_profile.has_method("resolve_image_alias"):
		resolved = str(_visual_profile.call("resolve_image_alias", "cg", image_name))
	for raw_part in resolved.split("+", false):
		var part: String = str(raw_part).strip_edges()
		if part.is_empty():
			continue
		_check_resource(part if part.contains("/") else "cg/" + part)


func _scan_standing_reference(character_name: String, pose: String) -> void:
	if _standing_profile == null or not _standing_profile.has_method("has_character"):
		return
	if not bool(_standing_profile.call("has_character", character_name)):
		return
	var directory: String = str(_standing_profile.call("character_directory", character_name))
	var layers: Array = _standing_profile.call("resolve_pose_layers", character_name, pose)
	for raw_layer in layers:
		var layer: String = str(raw_layer).strip_edges()
		if not layer.is_empty():
			_check_resource(directory.path_join(layer))


func _scan_audio_calls(line: String) -> void:
	var play_regex: RegEx = RegEx.new()
	play_regex.compile("\\bplay\\s*\\(\\s*(bgm|bgs|voice)\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in play_regex.search_all(line):
		var channel: String = match.get_string(1).to_lower()
		var name: String = match.get_string(2)
		match channel:
			"bgm":
				_check_resource(_with_default_extension("BGM/" + name, ".ogg"))
			"bgs":
				_check_resource(_with_default_extension("Sounds/" + name, ".ogg"))
			"voice":
				_check_resource(name)

	var sound_regex: RegEx = RegEx.new()
	sound_regex.compile("\\bsound\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in sound_regex.search_all(line):
		_check_resource(_with_default_extension("Sounds/" + match.get_string(1), ".ogg"))

	var direct_regex: RegEx = RegEx.new()
	direct_regex.compile("\\b(play_bgm|play_se|play_voice)\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in direct_regex.search_all(line):
		var method: String = match.get_string(1)
		var path: String = match.get_string(2)
		match method:
			"play_bgm":
				_check_resource(_with_default_extension("BGM/" + path, ".ogg"))
			"play_se":
				_check_resource(_with_default_extension("Sounds/" + path, ".ogg"))
			"play_voice":
				_check_resource(path)

	var say_regex: RegEx = RegEx.new()
	say_regex.compile("\\bsay\\s*\\(\\s*(?:[\"']([^\"']+)[\"']|([A-Za-z_][A-Za-z0-9_]*))\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in say_regex.search_all(line):
		var speaker: String = match.get_string(1)
		if speaker.is_empty():
			speaker = match.get_string(2)
		var voice_id: String = match.get_string(3)
		if _auto_voice_profile != null and _auto_voice_profile.has_method("manual_voice_path"):
			_check_resource(str(_auto_voice_profile.call("manual_voice_path", speaker, voice_id)))


func _scan_prefab_and_video_calls(line: String) -> void:
	var prefab_regex: RegEx = RegEx.new()
	prefab_regex.compile("\\b(?:load_prefab|load_ui_prefab|load_persistent_prefab)\\s*\\(\\s*[\"'][^\"']+[\"']\\s*,\\s*[\"']([^\"']+)[\"']")
	for match in prefab_regex.search_all(line):
		var path: String = match.get_string(1)
		_check_resource(_with_default_extension(path, ".tscn"))

	var video_regex: RegEx = RegEx.new()
	video_regex.compile("\\b(?:video|play_video)\\s*\\(\\s*[\"']([^\"']+)[\"']")
	for match in video_regex.search_all(line):
		var path: String = match.get_string(1)
		if not path.contains("/"):
			path = "Videos/" + path
		_check_resource(_with_default_extension(path, ".mp4"))


func _with_default_extension(path: String, extension: String) -> String:
	return path if not path.get_extension().is_empty() else path + extension


func _check_resource(path: String) -> void:
	_total_referenced += 1
	for prefix in VIRTUAL_PREFIXES:
		if path.begins_with(str(prefix)):
			_total_virtual += 1
			return
	var full := path if path.begins_with("res://") else RESOURCE_ROOT + path
	var candidates: Array[String] = [full]
	if full.get_extension().is_empty():
		for extension in RESOURCE_EXTENSIONS:
			candidates.append(full + str(extension))
	for candidate in candidates:
		if ResourceLoader.exists(candidate) or FileAccess.file_exists(candidate):
			_total_found += 1
			return
	_total_missing += 1
	print("    MISSING: %s" % path)


func _list_txt_files(dir: String) -> Array[String]:
	var result: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return result
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if not d.current_is_dir() and name.ends_with(".txt"):
			result.append(dir.path_join(name))
		name = d.get_next()
	d.list_dir_end()
	return result


func _ctx(key: String, value: Variant) -> void:
	pass  # No-op for headless test context.


func _finish(ok: bool) -> void:
	if ok:
		print("ScenarioResourceScan: OK")
	else:
		print("ScenarioResourceScan: FAILED")
	quit(0 if ok else 1)
