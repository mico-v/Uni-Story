@tool
extends Control

## Bottom panel for building/exporting the project.
##
## Features:
##   - Platform selection (Windows / Linux / Android)
##   - Version number input
##   - Pre-export quality gate (lint + tests)
##   - One-click export button
##   - Status feedback area


var _platform_checkboxes: Dictionary = {}  # platform_name → CheckBox
var _version_input: LineEdit
var _status_area: TextEdit
var _export_button: Button
var _lint_check: CheckBox
var _test_check: CheckBox
var _is_exporting: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 300)

	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main)

	var title := Label.new()
	title.text = "Build & Export"
	title.add_theme_font_size_override("font_size", 16)
	main.add_child(title)

	# Version input
	var version_hbox := HBoxContainer.new()
	main.add_child(version_hbox)
	var version_label := Label.new()
	version_label.text = "Version:"
	version_hbox.add_child(version_label)
	_version_input = LineEdit.new()
	_version_input.placeholder_text = "0.1.0"
	_version_input.text = ProjectSettings.get_setting("application/config/version", "0.1.0")
	_version_input.custom_minimum_size = Vector2(150, 0)
	version_hbox.add_child(_version_input)

	# Platform selection
	var platforms_label := Label.new()
	platforms_label.text = "Export Platforms:"
	main.add_child(platforms_label)

	var platforms_hbox := HBoxContainer.new()
	main.add_child(platforms_hbox)

	var supported_platforms := ["Windows", "Linux", "Android"]
	for platform in supported_platforms:
		var cb := CheckBox.new()
		cb.text = platform
		cb.button_pressed = (platform != "Android")  # Windows and Linux default on
		_platform_checkboxes[platform] = cb
		platforms_hbox.add_child(cb)

	# Quality gate options
	main.add_child(HSeparator.new())

	var gate_label := Label.new()
	gate_label.text = "Quality Gate:"
	main.add_child(gate_label)

	_lint_check = CheckBox.new()
	_lint_check.text = "Run Scenario Lint before export"
	_lint_check.button_pressed = true
	main.add_child(_lint_check)

	_test_check = CheckBox.new()
	_test_check.text = "Run Headless Tests before export"
	_test_check.button_pressed = true
	main.add_child(_test_check)

	# Export button
	_export_button = Button.new()
	_export_button.text = "🚀 Export Selected Platforms"
	_export_button.tooltip_text = "Run quality gate then export to selected platforms"
	_export_button.pressed.connect(_on_export_pressed)
	main.add_child(_export_button)

	# Status output
	var status_label := Label.new()
	status_label.text = "Output:"
	main.add_child(status_label)

	_status_area = TextEdit.new()
	_status_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_area.editable = false
	_status_area.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	main.add_child(_status_area)

	_append_status("Build panel ready. Select platforms and click Export.")
	_append_status("Available export presets: " + _list_available_presets())


func _on_export_pressed() -> void:
	if _is_exporting:
		_append_status("Export already in progress...")
		return

	_is_exporting = true
	_export_button.disabled = true
	_export_button.text = "⏳ Exporting..."

	# Collect selected platforms
	var selected: Array[String] = []
	for platform in _platform_checkboxes:
		if _platform_checkboxes[platform].button_pressed:
			selected.append(platform)

	if selected.is_empty():
		_append_status("ERROR: No platforms selected!")
		_reset_export_button()
		return

	var version := _version_input.text.strip_edges()
	if version.is_empty():
		version = "0.1.0"

	_append_status("=== Starting export: version %s → %s ===" % [version, ", ".join(selected)])

	# Quality gate
	var gate_passed := true
	if _lint_check.button_pressed:
		_append_status("[Gate] Running scenario lint...")
		var lint := BuildHooks.run_lint()
		_append_status("[Gate] Lint exit code: %d" % lint["exit_code"])
		if lint["exit_code"] != 0:
			gate_passed = false
			for line in lint["output"]:
				_append_status("  " + str(line))

	if _test_check.button_pressed:
		_append_status("[Gate] Running headless tests...")
		var tests := BuildHooks.run_tests()
		_append_status("[Gate] Tests exit code: %d" % tests["exit_code"])
		if tests["exit_code"] != 0:
			gate_passed = false

	if not gate_passed:
		_append_status("ERROR: Quality gate failed! Fix issues before export.")
		_reset_export_button()
		return

	_append_status("[Gate] Quality gate PASSED ✓")

	# Export each platform
	for platform in selected:
		_append_status("--- Exporting %s ---" % platform)
		var preset_idx := _find_export_preset(platform)
		if preset_idx < 0:
			_append_status("  ERROR: No export preset found for %s" % platform)
			continue

		_append_status("  Preset index: %d" % preset_idx)
		var result := _do_export(preset_idx, platform, version)
		_append_status("  Result: " + result)

	_append_status("=== Export complete ===")
	_reset_export_button()


func _reset_export_button() -> void:
	_is_exporting = false
	_export_button.disabled = false
	_export_button.text = "🚀 Export Selected Platforms"


func _do_export(preset_idx: int, platform: String, version: String) -> String:
	# For CI integration: write a marker file that CI picks up.
	# Direct in-editor export via EditorExportPlatform is not exposed in
	# Godot 4.6's public API; CI watches for this trigger file instead.
	var trigger_path := "user://export_trigger_%s_%s.txt" % [platform.to_lower(), version]
	var f := FileAccess.open(trigger_path, FileAccess.WRITE)
	if f:
		f.store_string("preset_index=%d\n" % preset_idx)
		f.store_string("platform=%s\n" % platform)
		f.store_string("version=%s\n" % version)
		f.store_string("timestamp=%d\n" % Time.get_unix_time_from_system())
		f.close()
		return "Export trigger written: %s" % trigger_path
	return "Failed to write export trigger"


## Parse export_presets.cfg to list preset names without relying on the
## EditorExport singleton (not exposed in Godot 4.6 public API).
func _read_preset_names() -> Array[String]:
	var names: Array[String] = []
	var cfg := ConfigFile.new()
	var err := cfg.load("res://export_presets.cfg")
	if err != OK:
		return names
	for section in cfg.get_sections():
		if str(section).begins_with("preset."):
			var pname: String = cfg.get_value(str(section), "name", "")
			if not pname.is_empty():
				names.append(pname)
	return names


func _find_export_preset(preset_name: String) -> int:
	var names := _read_preset_names()
	for i in range(names.size()):
		if names[i] == preset_name:
			return i
	return -1


func _list_available_presets() -> String:
	var names := _read_preset_names()
	if names.is_empty():
		return "(none)"
	return ", ".join(names)


func _append_status(msg: String) -> void:
	_status_area.text += msg + "\n"
	# Auto-scroll to bottom
	_status_area.set_caret_line(_status_area.get_line_count())
