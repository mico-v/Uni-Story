extends SceneTree

## Command-line entry point for ScenarioLinter.
##
## Usage:
##   godot --headless --path . --script res://scripts/tools/scenario_lint.gd -- [options] [files/directories]

const SCENARIO_LINTER_PATH := "res://scripts/tools/scenario_linter.gd"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var parsed := _parse_args(OS.get_cmdline_user_args())
	if not bool(parsed.get("ok", false)):
		printerr(str(parsed.get("error", "invalid arguments")))
		_print_usage()
		quit(2)
		return
	if bool(parsed.get("help", false)):
		_print_usage()
		quit(0)
		return

	var linter_script := load(SCENARIO_LINTER_PATH) as Script
	if linter_script == null:
		printerr("cannot load scenario linter: %s" % SCENARIO_LINTER_PATH)
		quit(2)
		return
	var linter = linter_script.new()
	var report: Dictionary = linter.lint_paths(parsed.get("paths", []), parsed.get("options", {}))
	var format := str(parsed.get("format", "text"))
	var rendered := JSON.stringify(report, "\t") if format == "json" else _format_text_report(report)
	var output_error := _write_report(rendered, str(parsed.get("output", "-")))
	if output_error != OK:
		printerr("cannot write lint report: %s" % error_string(output_error))
		quit(2)
		return

	var summary: Dictionary = report.get("summary", {})
	var errors := int(summary.get("errors", 0))
	var warnings := int(summary.get("warnings", 0))
	var fail_on := str(parsed.get("fail_on", "error"))
	var failed := errors > 0
	if fail_on == "warning":
		failed = failed or warnings > 0
	elif fail_on == "never":
		failed = false
	quit(1 if failed else 0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var paths: Array[String] = []
	var options := {
		"compile_blocks": true,
		"check_resources": true,
		"check_no_op": true,
	}
	var output_format := "text"
	var output := "-"
	var fail_on := "error"
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		match arg:
			"-h", "--help":
				return {"ok": true, "help": true}
			"--json":
				output_format = "json"
			"--warnings-as-errors", "--strict":
				fail_on = "warning"
			"--no-compile":
				options["compile_blocks"] = false
			"--no-resources":
				options["check_resources"] = false
			"--no-no-op":
				options["check_no_op"] = false
			"--format":
				i += 1
				if i >= args.size():
					return {"ok": false, "error": "--format requires text or json"}
				output_format = str(args[i]).to_lower()
				if output_format not in ["text", "json"]:
					return {"ok": false, "error": "unsupported output format '%s'" % output_format}
			"--output":
				i += 1
				if i >= args.size():
					return {"ok": false, "error": "--output requires - or a file path"}
				output = str(args[i])
				if output.is_empty():
					return {"ok": false, "error": "--output requires - or a file path"}
			"--fail-on":
				i += 1
				if i >= args.size():
					return {"ok": false, "error": "--fail-on requires error, warning, or never"}
				fail_on = str(args[i]).to_lower()
				if fail_on not in ["error", "warning", "never"]:
					return {"ok": false, "error": "unsupported --fail-on value '%s'" % fail_on}
			"--path":
				i += 1
				if i >= args.size() or str(args[i]).strip_edges().is_empty():
					return {"ok": false, "error": "--path requires a file or directory"}
				paths.append(str(args[i]))
			_:
				if arg.begins_with("-"):
					return {"ok": false, "error": "unknown option '%s'" % arg}
				if arg.strip_edges().is_empty():
					return {"ok": false, "error": "scenario path cannot be empty"}
				paths.append(arg)
		i += 1
	return {
		"ok": true,
		"help": false,
		"paths": paths,
		"options": options,
		"format": output_format,
		"output": output,
		"fail_on": fail_on,
	}


func _format_text_report(report: Dictionary) -> String:
	var lines := PackedStringArray()
	for issue in report.get("issues", []):
		if not (issue is Dictionary):
			continue
		var path := str(issue.get("path", ""))
		var line := int(issue.get("line", 0))
		var column := int(issue.get("column", 1))
		var severity := str(issue.get("severity", "warning"))
		var code := str(issue.get("code", "lint"))
		var message := str(issue.get("message", ""))
		lines.append("%s:%d:%d: %s [%s] %s" % [path, line, column, severity, code, message])
	var summary: Dictionary = report.get("summary", {})
	lines.append(
		"ScenarioLint: files=%d blocks=%d dialogues=%d labels=%d errors=%d warnings=%d resources=%d/%d virtual=%d missing=%d" % [
			int(summary.get("files", 0)),
			int(summary.get("blocks", 0)),
			int(summary.get("dialogues", 0)),
			int(summary.get("labels", 0)),
			int(summary.get("errors", 0)),
			int(summary.get("warnings", 0)),
			int(summary.get("resource_found", 0)),
			int(summary.get("resource_references", 0)),
			int(summary.get("resource_virtual", 0)),
			int(summary.get("resource_missing", 0)),
		]
	)
	return "\n".join(lines)


func _write_report(rendered: String, output: String) -> Error:
	if output == "-":
		print(rendered)
		return OK
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(rendered)
	file.store_string("\n")
	file.flush()
	return OK


func _print_usage() -> void:
	print("Scenario lint")
	print("Usage: godot --headless --path . --script res://scripts/tools/scenario_lint.gd -- [options] [files/directories]")
	print("Options:")
	print("  --path PATH             Add a scenario file or directory (repeatable)")
	print("  --format text|json      Select output format")
	print("  --json                  Alias for --format json")
	print("  --output -|PATH         Write the report to stdout or a file")
	print("  --fail-on LEVEL         Exit 1 on error, warning, or never")
	print("  --warnings-as-errors    Alias for --fail-on warning")
	print("  --no-compile            Skip translated GDScript compilation")
	print("  --no-resources          Skip resource existence checks")
	print("  --no-no-op              Skip compatibility no-op warnings")
	print("  -h, --help              Show this help")
