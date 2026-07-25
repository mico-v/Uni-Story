@tool
extends Control

## Resource dashboard panel for scenario resource validation.
##
## Displays:
##   - Summary: referenced, found, missing, virtual resource counts
##   - Missing resource list with scenario location references
##   - One-click Scenario lint runner
##   - Color-coded health indicators


var plugin: EditorPlugin

# UI elements
var _summary_grid: GridContainer
var _missing_list: Tree
var _lint_output: TextEdit
var _run_scan_btn: Button
var _run_lint_btn: Button
var _status_label: Label
var _scan_data: Dictionary = {}
var _lint_data: Dictionary = {}


func _ready() -> void:
	custom_minimum_size = Vector2(0, 350)

	var main := HSplitContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.split_offset = 400
	add_child(main)

	# Left panel: summary + missing list
	var left := VBoxContainer.new()
	main.add_child(left)

	# Toolbar
	var toolbar := HBoxContainer.new()
	left.add_child(toolbar)

	_run_scan_btn = Button.new()
	_run_scan_btn.text = "🔍 Scan Resources"
	_run_scan_btn.tooltip_text = "Run scenario resource scan to refresh the dashboard"
	_run_scan_btn.pressed.connect(_run_resource_scan)
	toolbar.add_child(_run_scan_btn)

	_run_lint_btn = Button.new()
	_run_lint_btn.text = "📋 Run Lint"
	_run_lint_btn.tooltip_text = "Run scenario lint and display results"
	_run_lint_btn.pressed.connect(_run_scenario_lint)
	toolbar.add_child(_run_lint_btn)

	# Summary section
	var summary_label := Label.new()
	summary_label.text = "Resource Summary"
	summary_label.add_theme_font_size_override("font_size", 14)
	left.add_child(summary_label)

	_summary_grid = GridContainer.new()
	_summary_grid.columns = 2
	_summary_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_summary_grid)

	_clear_summary()

	# Missing resources list
	var missing_label := Label.new()
	missing_label.text = "Missing Resources (click to navigate)"
	missing_label.add_theme_font_size_override("font_size", 14)
	left.add_child(missing_label)

	_missing_list = Tree.new()
	_missing_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_missing_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_missing_list.columns = 3
	_missing_list.set_column_title(0, "Resource")
	_missing_list.set_column_title(1, "Type")
	_missing_list.set_column_title(2, "Location")
	_missing_list.set_column_expand(0, true)
	_missing_list.set_column_expand(1, false)
	_missing_list.set_column_expand(2, false)
	_missing_list.set_column_custom_minimum_width(1, 80)
	_missing_list.set_column_custom_minimum_width(2, 200)
	_missing_list.item_activated.connect(_on_missing_item_activated)
	left.add_child(_missing_list)

	# Right panel: lint output
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)

	var lint_label := Label.new()
	lint_label.text = "Scenario Lint Output"
	lint_label.add_theme_font_size_override("font_size", 14)
	right.add_child(lint_label)

	_lint_output = TextEdit.new()
	_lint_output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lint_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lint_output.editable = false
	_lint_output.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	right.add_child(_lint_output)

	# Status
	_status_label = Label.new()
	_status_label.text = "Ready. Click 'Scan Resources' or 'Run Lint' to begin."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status_label)

	# Auto-scan on ready
	_run_resource_scan.call_deferred()


func _clear_summary() -> void:
	for child in _summary_grid.get_children():
		child.queue_free()

	var defaults := {
		"Referenced": ("0", Color.WHITE),
		"Found": ("0", Color.WHITE),
		"Missing": ("0", Color.RED),
		"Virtual": ("0", Color(0.5, 0.5, 1.0)),
		"Errors": ("0", Color.RED),
		"Warnings": ("0", Color.YELLOW),
	}
	for key in defaults:
		var entry := defaults[key]
		_add_summary_row(key, entry[0], entry[1])


func _add_summary_row(label: String, value: String, color: Color) -> void:
	var kl := Label.new()
	kl.text = label + ":"
	kl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_summary_grid.add_child(kl)

	var vl := Label.new()
	vl.text = value
	vl.add_theme_color_override("font_color", color)
	_summary_grid.add_child(vl)


func _run_resource_scan() -> void:
	_status_label.text = "Running resource scan..."

	# Run the Python resource scanner
	var project_root := _get_project_root()
	var result := _run_python_tool(project_root, "python3", [
		project_root + "/scripts/tools/scenario_lint.py",
		"--format", "json",
	])

	if result.exit_code != 0 or result.stdout.is_empty():
		# Fallback: try with explicit path
		result = _run_python_tool(project_root, "python3", [
			project_root + "/scripts/tools/scenario_lint.py",
			"--format", "json",
		])

	if not result.stdout.is_empty():
		_parse_lint_json(result.stdout)
		_status_label.text = "Resource scan complete."
	else:
		_status_label.text = "Resource scan failed. Run from terminal: python3 scripts/tools/scenario_lint.py"


func _run_scenario_lint() -> void:
	_status_label.text = "Running scenario lint..."

	var project_root := _get_project_root()
	var result := _run_python_tool(project_root, "python3", [
		"scripts/tools/scenario_lint.py",
		"--format", "text",
	])

	if not result.stdout.is_empty():
		_lint_output.text = result.stdout
		_status_label.text = "Lint complete. Exit code: %d" % result.exit_code
	elif not result.stderr.is_empty():
		_lint_output.text = result.stderr
		_status_label.text = "Lint failed. Check output for details."
	else:
		_lint_output.text = "No output from scenario lint."
		_status_label.text = "Lint produced no output."


func _parse_lint_json(json_str: String) -> void:
	var parsed = JSON.parse_string(json_str)
	if parsed == null:
		return

	_clear_summary()

	if parsed is Dictionary:
		for key in ["referenced", "found", "missing", "virtual", "errors", "warnings"]:
			var value = parsed.get(key, 0)
			if value is float or value is int:
				var color := Color.WHITE
				if key == "missing" and int(value) > 0:
					color = Color.RED
				elif key == "virtual":
					color = Color(0.5, 0.5, 1.0)
				elif key == "errors" and int(value) > 0:
					color = Color.RED
				elif key == "warnings" and int(value) > 0:
					color = Color.YELLOW
				_add_summary_row(key.capitalize(), str(value), color)

		# Populate missing list
		var missing := parsed.get("missing_resources", [])
		if missing is Array:
			_missing_list.clear()
			var root := _missing_list.create_item()
			_missing_list.hide_root = true
			for item in missing:
				if item is Dictionary:
					var tree_item := _missing_list.create_item(root)
					tree_item.set_text(0, str(item.get("resource", item.get("path", "?"))))
					tree_item.set_text(1, str(item.get("type", "unknown")))
					tree_item.set_text(2, str(item.get("location", "")))
					tree_item.set_meta("resource", item.get("resource", ""))
					tree_item.set_meta("location", item.get("location", ""))
					tree_item.set_meta("scenario_path", item.get("scenario_path", ""))

		# If errors/warnings are list too
		var error_list := parsed.get("error_list", [])
		if error_list is Array and error_list.size() > 0:
			for e in error_list:
				if e is Dictionary:
					var tree_item := _missing_list.create_item()
					tree_item.set_text(0, "🔴 " + str(e.get("message", "")))
					tree_item.set_text(1, str(e.get("rule", "error")))
					tree_item.set_text(2, str(e.get("location", "")))


func _on_missing_item_activated() -> void:
	var selected := _missing_list.get_selected()
	if selected == null:
		return

	var scenario_path: String = selected.get_meta("scenario_path", "")
	var location: String = selected.get_meta("location", "")

	if not scenario_path.is_empty() and plugin:
		var editor := plugin.get_editor_interface()
		# Try to open the scenario file in the script editor
		var full_path := "res://" + scenario_path
		if ResourceLoader.exists(full_path):
			var res := load(full_path)
			if res:
				editor.edit_resource(res)
				return

	# Fallback: try to find the resource path
	var resource_path: String = selected.get_meta("resource", "")
	if not resource_path.is_empty():
		_status_label.text = "Missing resource: %s  |  Location: %s" % [resource_path, location]
	else:
		_status_label.text = "Cannot navigate to location: %s" % location


func _run_python_tool(project_root: String, python_bin: String, args: Array) -> Dictionary:
	var output: Array = []
	var exit_code := -1

	var result = OS.execute(python_bin, args, output, true)
	exit_code = result

	var stdout := ""
	for line in output:
		stdout += line + "\n"

	return {
		"exit_code": exit_code,
		"stdout": stdout.strip_edges(),
		"stderr": "",
	}


func _get_project_root() -> String:
	var path_str := ProjectSettings.globalize_path("res://")
	return path_str
