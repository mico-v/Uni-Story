extends SceneTree

## Godot bridge for scenario dialogue statistics.
##
## Usage:
##   godot --headless --no-header --path . --script res://scripts/tools/scenario_stat.gd -- [options] [files/directories]

const ANALYSIS_PATH := "res://scripts/tools/scenario_analysis.gd"
const STATISTICS_PATH := "res://scripts/tools/scenario_statistics.gd"


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

	var analysis_script := load(ANALYSIS_PATH) as Script
	var statistics_script := load(STATISTICS_PATH) as Script
	if analysis_script == null or statistics_script == null or not analysis_script.can_instantiate() or not statistics_script.can_instantiate():
		printerr("cannot load scenario analysis tools")
		quit(2)
		return
	var analysis: Dictionary = analysis_script.new().analyze_paths(parsed.get("paths", []))
	if not bool(analysis.get("ok", false)):
		for error in analysis.get("errors", []):
			if error is Dictionary:
				printerr("%s: %s" % [error.get("path", ""), error.get("message", "analysis failed")])
		quit(2)
		return
	var report: Dictionary = statistics_script.new().build(analysis, int(parsed.get("top", 10)))
	var rendered := JSON.stringify(report, "\t") if str(parsed.get("format", "text")) == "json" else _format_text_report(report)
	var error := _write_report(rendered, str(parsed.get("output", "-")))
	if error != OK:
		printerr("cannot write scenario statistics: %s" % error_string(error))
		quit(2)
		return
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var paths: Array[String] = []
	var format := "text"
	var output := "-"
	var top := 10
	var i := 0
	while i < args.size():
		var arg := str(args[i])
		match arg:
			"-h", "--help":
				return {"ok": true, "help": true}
			"--json":
				format = "json"
			"--format":
				i += 1
				if i >= args.size():
					return {"ok": false, "error": "--format requires text or json"}
				format = str(args[i]).to_lower()
				if format not in ["text", "json"]:
					return {"ok": false, "error": "unsupported output format '%s'" % format}
			"--output":
				i += 1
				if i >= args.size() or str(args[i]).is_empty():
					return {"ok": false, "error": "--output requires - or a file path"}
				output = str(args[i])
			"--top":
				i += 1
				if i >= args.size() or not str(args[i]).is_valid_int():
					return {"ok": false, "error": "--top requires a non-negative integer"}
				top = int(args[i])
				if top < 0:
					return {"ok": false, "error": "--top requires a non-negative integer"}
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
	return {"ok": true, "help": false, "paths": paths, "format": format, "output": output, "top": top}


func _format_text_report(report: Dictionary) -> String:
	var summary: Dictionary = report.get("summary", {})
	var lines := PackedStringArray()
	lines.append("ScenarioStat: files=%d nodes=%d dialogues=%d spoken=%d narration=%d speakers=%d" % [
		int(summary.get("files", 0)),
		int(summary.get("nodes", 0)),
		int(summary.get("dialogues", 0)),
		int(summary.get("spoken", 0)),
		int(summary.get("narration", 0)),
		int(summary.get("speakers", 0)),
	])
	var node_types: Dictionary = summary.get("node_types", {})
	lines.append("Flow: blocks=%d eager=%d lazy=%d local=%d normal=%d chapter=%d end=%d jumps=%d branches=%d silent=%d" % [
		int(summary.get("blocks", 0)),
		int(summary.get("eager_blocks", 0)),
		int(summary.get("lazy_blocks", 0)),
		int(summary.get("local_nodes", 0)),
		int(node_types.get("normal", 0)),
		int(node_types.get("chapter", 0)),
		int(node_types.get("end", 0)),
		int(summary.get("jumps", 0)),
		int(summary.get("branch_options", 0)),
		int(summary.get("silent_entries", 0)),
	])
	lines.append("Length: total=%d min=%d mean=%.3f p50=%d p90=%d p95=%d max=%d empty=%d" % [
		int(summary.get("total_characters", 0)),
		int(summary.get("min", 0)),
		float(summary.get("mean", 0.0)),
		int(summary.get("p50", 0)),
		int(summary.get("p90", 0)),
		int(summary.get("p95", 0)),
		int(summary.get("max", 0)),
		int(summary.get("empty", 0)),
	])
	var speakers: Array = report.get("by_speaker", [])
	if not speakers.is_empty():
		lines.append("Speakers:")
		for raw_speaker in speakers:
			var speaker: Dictionary = raw_speaker
			lines.append("  %s: dialogues=%d characters=%d mean=%.3f" % [
				speaker.get("canonical_speaker", ""),
				int(speaker.get("dialogues", 0)),
				int(speaker.get("characters", 0)),
				float(speaker.get("mean", 0.0)),
			])
	var longest: Array = report.get("longest", [])
	if not longest.is_empty():
		lines.append("Longest:")
		for raw_entry in longest:
			var entry: Dictionary = raw_entry
			var speaker := str(entry.get("display_speaker", ""))
			var prefix := "%s: " % speaker if not speaker.is_empty() else ""
			lines.append("  %s:%d [%d] %s%s" % [entry.get("path", ""), int(entry.get("line", 0)), int(entry.get("length", 0)), prefix, entry.get("normalized_text", "")])
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
	print("Scenario dialogue statistics (source inventory)")
	print("Usage: godot --headless --no-header --path . --script res://scripts/tools/scenario_stat.gd -- [options] [files/directories]")
	print("Options:")
	print("  --path PATH          Add a scenario file or directory (repeatable)")
	print("  --format text|json   Select output format")
	print("  --json               Alias for --format json")
	print("  --output -|PATH      Write the report to stdout or a file")
	print("  --top N              Include the N longest entries (default: 10)")
	print("  -h, --help           Show this help")
