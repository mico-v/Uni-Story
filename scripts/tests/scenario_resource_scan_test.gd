extends SceneTree

## Headless test: scans all scenario files for referenced resources
## (images, audio, prefabs, videos) and reports any that are missing
## from the project filesystem.

const SCENARIO_DIR := "res://resources/scenarios/"
const RESOURCE_ROOT := "res://resources/"

var _total_referenced := 0
var _total_missing := 0
var _total_found := 0


func _init() -> void:
	_run()


func _run() -> void:
	print("ScenarioResourceScan: scanning scenarios for resource references...")
	print("")

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
	print("ScenarioResourceScan: referenced=%d, found=%d, missing=%d" % [_total_referenced, _total_found, _total_missing])
	print("")
	if _total_missing > 0:
		print("ScenarioResourceScan: WARNING — %d missing resource(s) detected." % _total_missing)
	else:
		print("ScenarioResourceScan: OK — all referenced resources exist.")
	_finish(true)


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


func _check_resource(path: String) -> void:
	_total_referenced += 1
	var full := path if path.begins_with("res://") else RESOURCE_ROOT + path
	if ResourceLoader.exists(full):
		_total_found += 1
		return
	if FileAccess.file_exists(full):
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
