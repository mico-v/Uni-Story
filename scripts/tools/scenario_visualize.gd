extends SceneTree

## Godot bridge for execution-free scenario flow/branch visualization.
##
## Usage:
##   godot --headless --no-header --path . --script res://scripts/tools/scenario_visualize.gd -- [options] [files/directories]

const ANALYSIS_PATH := "res://scripts/tools/scenario_analysis.gd"
const VISUALIZATION_PATH := "res://scripts/tools/scenario_visualization.gd"


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
	var visualization_script := load(VISUALIZATION_PATH) as Script
	if analysis_script == null or visualization_script == null or not analysis_script.can_instantiate() or not visualization_script.can_instantiate():
		printerr("cannot load scenario visualization tools")
		quit(2)
		return

	var analysis_options := {
		"context_paths": parsed.get("context_paths", []),
		"auto_context": not bool(parsed.get("no_context", false)),
	}
	var analysis: Dictionary = analysis_script.new().analyze_paths(parsed.get("paths", []), analysis_options)
	if not bool(analysis.get("ok", false)):
		for error in analysis.get("errors", []):
			if error is Dictionary:
				printerr("%s:%d:%d: %s" % [error.get("path", ""), int(error.get("line", 0)), int(error.get("column", 1)), error.get("message", "analysis failed")])
		quit(2)
		return

	var builder = visualization_script.new()
	var report: Dictionary = builder.build(analysis, parsed.get("graph_options", {}))
	if not bool(report.get("ok", false)):
		for diagnostic in report.get("diagnostics", []):
			if diagnostic is Dictionary and str((diagnostic as Dictionary).get("severity", "")) == "error":
				var location: Dictionary = (diagnostic as Dictionary).get("location", {})
				printerr("%s:%d:%d: %s [%s] %s" % [
					location.get("path", ""), int(location.get("line", 0)), int(location.get("column", 1)),
					diagnostic.get("severity", "error"), diagnostic.get("code", "visualization.failed"), diagnostic.get("message", "visualization failed"),
				])
		quit(2)
		return

	var format := str(parsed.get("format", "text"))
	var rendered := ""
	match format:
		"json":
			rendered = JSON.stringify(report, "\t") + "\n"
		"dot":
			rendered = builder.render_dot(report)
		"mermaid":
			rendered = builder.render_mermaid(report)
		_:
			rendered = builder.render_text(report)
	var error := _write_output(rendered, str(parsed.get("output", "-")))
	if error != OK:
		printerr("cannot write scenario visualization: %s" % error_string(error))
		quit(2)
		return
	quit(0)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var paths: Array[String] = []
	var context_paths: Array[String] = []
	var format := "text"
	var output := "-"
	var graph_options := {
		"view": "flow",
		"root_policy": "auto",
		"roots": [],
		"reachable_only": false,
		"exclude_debug": false,
		"node_globs": [],
		"edge_kinds": [],
		"phases": [],
		"boundary": "include",
		"context_mode": "auto",
		"cluster": "file",
		"label": "both",
		"max_label_chars": 80,
	}
	var no_context := false
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
				if i >= args.size() or str(args[i]).to_lower() not in ["text", "json", "dot", "mermaid"]:
					return {"ok": false, "error": "--format requires text, json, dot, or mermaid"}
				format = str(args[i]).to_lower()
			"--output":
				i += 1
				if i >= args.size() or str(args[i]).is_empty():
					return {"ok": false, "error": "--output requires - or a file path"}
				output = str(args[i])
			"--view":
				var parsed := _take_enum(args, i, "--view", ["flow", "branches"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				graph_options["view"] = str(parsed.value)
			"--root-policy":
				var parsed := _take_enum(args, i, "--root-policy", ["auto", "start", "unlocked", "debug", "sources", "all"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				graph_options["root_policy"] = str(parsed.value)
			"--root":
				i += 1
				if i >= args.size() or str(args[i]).strip_edges().is_empty():
					return {"ok": false, "error": "--root requires a node selector"}
				(graph_options.roots as Array).append(str(args[i]))
			"--reachable-only":
				graph_options["reachable_only"] = true
			"--exclude-debug":
				graph_options["exclude_debug"] = true
			"--node":
				i += 1
				if i >= args.size() or str(args[i]).strip_edges().is_empty():
					return {"ok": false, "error": "--node requires a glob"}
				(graph_options.node_globs as Array).append(str(args[i]))
			"--edge-kind":
				var parsed := _take_enum(args, i, "--edge-kind", ["jump_to", "jump_if", "branch"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				(graph_options.edge_kinds as Array).append(str(parsed.value))
			"--phase":
				var parsed := _take_enum(args, i, "--phase", ["eager", "lazy"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				(graph_options.phases as Array).append(str(parsed.value))
			"--boundary":
				var parsed := _take_enum(args, i, "--boundary", ["include", "drop"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				graph_options["boundary"] = str(parsed.value)
			"--context":
				i += 1
				if i >= args.size() or str(args[i]).strip_edges().is_empty():
					return {"ok": false, "error": "--context requires a file or directory"}
				context_paths.append(str(args[i]))
			"--no-context":
				no_context = true
				graph_options["context_mode"] = "off"
			"--cluster":
				var parsed := _take_enum(args, i, "--cluster", ["none", "file"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				graph_options["cluster"] = str(parsed.value)
			"--label":
				var parsed := _take_enum(args, i, "--label", ["id", "display", "both"])
				if not bool(parsed.get("ok", false)):
					return parsed
				i = int(parsed.index)
				graph_options["label"] = str(parsed.value)
			"--max-label-chars":
				i += 1
				if i >= args.size() or not str(args[i]).is_valid_int() or int(args[i]) < 0:
					return {"ok": false, "error": "--max-label-chars requires a non-negative integer"}
				graph_options["max_label_chars"] = int(args[i])
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
	if not context_paths.is_empty() and not no_context:
		graph_options["context_mode"] = "explicit+auto"
	elif not context_paths.is_empty():
		graph_options["context_mode"] = "explicit"
	return {
		"ok": true,
		"help": false,
		"paths": paths,
		"context_paths": context_paths,
		"no_context": no_context,
		"format": format,
		"output": output,
		"graph_options": graph_options,
	}


func _take_enum(args: PackedStringArray, index: int, option: String, allowed: Array[String]) -> Dictionary:
	var next := index + 1
	if next >= args.size():
		return {"ok": false, "error": "%s requires one of: %s" % [option, ", ".join(PackedStringArray(allowed))]}
	var value := str(args[next]).to_lower()
	if value not in allowed:
		return {"ok": false, "error": "%s requires one of: %s" % [option, ", ".join(PackedStringArray(allowed))]}
	return {"ok": true, "index": next, "value": value}


func _write_output(rendered: String, output: String) -> Error:
	if output == "-":
		print(rendered.trim_suffix("\n"))
		return OK
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(rendered)
	file.flush()
	return OK


func _print_usage() -> void:
	print("Scenario flow/branch visualization (execution-free static analysis)")
	print("Usage: godot --headless --no-header --path . --script res://scripts/tools/scenario_visualize.gd -- [options] [files/directories]")
	print("Options:")
	print("  --path PATH                       Add a scenario file or directory")
	print("  --format text|json|dot|mermaid    Select output format")
	print("  --output -|PATH                   Write output to stdout or a file")
	print("  --view flow|branches              Select the graph view")
	print("  --root-policy POLICY              auto/start/unlocked/debug/sources/all")
	print("  --root NODE                       Add an explicit root (repeatable)")
	print("  --reachable-only                  Keep only nodes reachable from roots")
	print("  --exclude-debug                   Exclude debug-only nodes")
	print("  --node GLOB                       Filter resolved node IDs")
	print("  --edge-kind KIND                  Filter jump_to/jump_if/branch")
	print("  --phase eager|lazy                Filter source phase")
	print("  --boundary include|drop           Keep or drop boundary stubs")
	print("  --context PATH                    Add label-only graph context")
	print("  --no-context                      Disable automatic default context")
	print("  --cluster none|file               DOT cluster policy")
	print("  --label id|display|both           Rendered node label policy")
	print("  --max-label-chars N               Truncate rendered labels (0 disables)")
	print("  -h, --help                        Show this help")
