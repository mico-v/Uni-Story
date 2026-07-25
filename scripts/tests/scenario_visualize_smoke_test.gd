extends SceneTree

## Headless smoke coverage for execution-free scenario flow visualization.

const ScenarioAnalysisScript := preload("res://scripts/tools/scenario_analysis.gd")
const ScenarioVisualizationScript := preload("res://scripts/tools/scenario_visualization.gd")

const FIXTURE_DIR := "user://tests/scenario_visualize_smoke"
const PRIMARY_PATH := FIXTURE_DIR + "/z_primary.txt"
const SECONDARY_PATH := FIXTURE_DIR + "/a_secondary.txt"
const CONTEXT_PATH := FIXTURE_DIR + "/context_catalog.txt"
const PYTHON_OUTPUT_PATH := FIXTURE_DIR + "/python-output.dot"
const PYTHON_CWD_PATH := FIXTURE_DIR + "/arbitrary-cwd"
const EAGER_SENTINEL := "EAGER_EXECUTION_SENTINEL"

const PRIMARY_SOURCE := (
	"@<|\n"
	+ "label(\"viz_root\", \"根节点 Ω\")\n"
	+ "is_start()\n"
	+ "is_save_point()\n"
	+ "push_error(\"EAGER_EXECUTION_SENTINEL\")\n"
	+ "# jump_to(\"comment_missing\")\n"
	+ "-- branch { { dest = \"lua_missing\" } }\n"
	+ "var pseudo = \"label('string_fake') jump_to('string_missing')\"\n"
	+ "|>\n"
	+ "<|\n"
	+ "jump_to(\"l_after\")\n"
	+ "|>\n"
	+ "Lazy carrier.\n"
	+ "@[mode=show; cond='v_default'; image='default_choice']@<|\n"
	+ "branch {\n"
	+ "    { dest = \"l_choice\", text = '选项 \"一\" \\\\ path' },\n"
	+ "    { dest = \"l_choice\", text = \"并行二\", mode = \"enable\", cond = \"check_pair(1, nested(2, 3))\", image = \"explicit_choice\" },\n"
	+ "    { dest = dynamic_dest, text = \"动态\", mode = \"jump\", cond = \"\" },\n"
	+ "    { dest = \"external_node\", text = \"上下文\" },\n"
	+ "    { dest = \"missing_node\", text = \"缺失\" },\n"
	+ "    { dest = \"l_local\", text = \"本地\" },\n"
	+ "}\n"
	+ "jump_if(check_pair(1, nested(2, 3)), \"l_after\")\n"
	+ "jump_to(\"l_choice\")\n"
	+ "|>\n"
	+ "@<|\n"
	+ "label(\"l_choice\", \"选择节点\")\n"
	+ "jump_to(\"l_end\")\n"
	+ "label(\"l_after\", \"后续节点\")\n"
	+ "jump_to(\"external_node\")\n"
	+ "label(\"l_local\", \"主文件局部\")\n"
	+ "jump_to(\"l_end\")\n"
	+ "|>\n"
	+ "@<|\n"
	+ "label(\"l_end\", \"终点\")\n"
	+ "is_end(\"ending-Ω\")\n"
	+ "|>\n"
	+ "@<|\n"
	+ "label(\"viz_debug_isolated\", \"调试孤点\")\n"
	+ "is_debug()\n"
	+ "|>\n"
)

const SECONDARY_SOURCE := (
	"@<|\n"
	+ "label(\"secondary_root\", \"Secondary root\")\n"
	+ "is_unlocked_start()\n"
	+ "jump_to(\"l_local\")\n"
	+ "label(\"l_local\", \"Secondary local\")\n"
	+ "is_end(\"secondary-ending\")\n"
	+ "|>\n"
)

const CONTEXT_SOURCE := (
	"@<|\n"
	+ "label(\"external_node\", \"上下文外部\")\n"
	+ "label(\"context_unused\", \"Unused context\")\n"
	+ "|>\n"
)

const PYTHON_CWD_RUNNER := "import os,runpy,sys; cwd,script,*rest=sys.argv[1:]; os.chdir(cwd); sys.argv=[script,*rest]; runpy.run_path(script,run_name='__main__')"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_write_fixture(PRIMARY_PATH, PRIMARY_SOURCE)
	_write_fixture(SECONDARY_PATH, SECONDARY_SOURCE)
	_write_fixture(CONTEXT_PATH, CONTEXT_SOURCE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PYTHON_CWD_PATH))
	_remove_file(PYTHON_OUTPUT_PATH)

	_test_schema_and_flow_metadata()
	_test_determinism_and_renderers()
	_test_views_filters_and_boundaries()
	_test_default_corpus_baseline()
	_test_godot_cli()
	_test_python_cli()

	if _failures.is_empty():
		print("ScenarioVisualizeSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ScenarioVisualizeSmokeTest: FAILED")
		quit(1)


func _test_schema_and_flow_metadata() -> void:
	var analysis := _analyze([PRIMARY_PATH, SECONDARY_PATH], [CONTEXT_PATH])
	_expect(bool(analysis.get("ok", false)), "visualization fixture should analyze cleanly: %s" % JSON.stringify(analysis.get("errors", [])))
	_expect(int(analysis.get("schema_version", 0)) == 2, "visualization should consume ScenarioAnalysis schema v2")
	var analysis_summary: Dictionary = analysis.get("summary", {})
	_expect(int(analysis_summary.get("files", 0)) == 2, "fixture should contain two selected source files")
	_expect(int(analysis_summary.get("nodes", 0)) == 8, "fixture should define eight source nodes")
	_expect(int(analysis_summary.get("edges", 0)) == 13, "fixture should expose twelve eager and one lazy transition")
	_expect(_node_named(analysis.get("nodes", []), "string_fake").is_empty(), "quoted pseudo-labels must not create nodes")
	_expect(not _analysis_has_raw_target(analysis, "comment_missing") and not _analysis_has_raw_target(analysis, "lua_missing") and not _analysis_has_raw_target(analysis, "string_missing"), "comments and quoted pseudo-calls must not create flow edges")

	var report := _build(analysis)
	var summary: Dictionary = report.get("summary", {})
	_expect(int(report.get("schema_version", 0)) == 1, "visualization graph schema should be version 1")
	_expect(str(report.get("kind", "")) == "scenario_flow", "visualization report kind should be scenario_flow")
	_expect(str(report.get("analysis_mode", "")) == "execution_free_static", "visualization should identify its execution-free analysis mode")
	_expect(int((report.get("source_ir", {}) as Dictionary).get("schema_version", 0)) == 2, "graph report should identify ScenarioAnalysis schema v2")
	_expect(bool(report.get("ok", false)), "fixture graph should build without error diagnostics: %s" % JSON.stringify(report.get("diagnostics", [])))
	_expect(int(summary.get("defined_nodes", 0)) == 8 and int(summary.get("placeholder_nodes", 0)) == 3, "fixture should preserve eight definitions plus external/missing/dynamic placeholders")
	_expect(int(summary.get("edges", 0)) == 13, "all fixture transitions should remain in the default flow view")
	_expect(int(summary.get("branch_edges", 0)) == 6 and int(summary.get("jump_if_edges", 0)) == 1 and int(summary.get("jump_to_edges", 0)) == 6, "fixture edge kinds should remain stable")
	_expect(int(summary.get("external_targets", 0)) == 2 and int(summary.get("missing_targets", 0)) == 1 and int(summary.get("dynamic_targets", 0)) == 1, "target classifications should count edges, not unique placeholders")
	_expect(int(summary.get("reachable_defined", 0)) == 7 and int(summary.get("unreachable_defined", 0)) == 1, "auto roots should reach every node except the isolated debug node")

	var primary_local := _node_named(report.get("nodes", []), "z_primary:local")
	var secondary_local := _node_named(report.get("nodes", []), "a_secondary:local")
	_expect(not primary_local.is_empty() and not secondary_local.is_empty(), "same l_local name in two files should retain separate namespaces")
	_expect("local" in primary_local.get("flags", []) and "local" in secondary_local.get("flags", []), "both resolved local nodes should carry the local flag")

	var root := _node_named(report.get("nodes", []), "viz_root")
	_expect(str(root.get("type", "")) == "chapter", "is_start should classify the root as a chapter")
	_expect("start" in root.get("flags", []) and "save_point" in root.get("flags", []), "root flags should preserve start and save-point metadata")
	var unlocked := _node_named(report.get("nodes", []), "secondary_root")
	_expect("start" in unlocked.get("flags", []) and "unlocked_start" in unlocked.get("flags", []), "unlocked root should preserve both start flags")
	var ending := _node_named(report.get("nodes", []), "z_primary:end")
	_expect(str(ending.get("type", "")) == "end" and str(ending.get("end_name", "")) == "ending-Ω", "named endings should survive analysis and graph building")
	var debug_node := _node_named(report.get("nodes", []), "viz_debug_isolated")
	_expect("debug" in debug_node.get("flags", []) and "isolated" in debug_node.get("classes", []), "debug-only isolated nodes should be classified explicitly")

	var branches := _edges_of_kind(report, "branch")
	_expect(branches.size() == 6, "all six branch options should be preserved")
	var first := _branch_at(branches, 0)
	var second := _branch_at(branches, 1)
	var dynamic := _branch_at(branches, 2)
	_expect(str(first.get("target", "")) == "z_primary:choice", "literal local branch targets should resolve through the selected file namespace")
	var first_data: Dictionary = first.get("branch", {})
	_expect(str(first_data.get("text", "")) == "选项 \"一\" \\ path", "branch text should preserve Unicode, quotes, and a literal backslash")
	_expect(str(first_data.get("mode", "")) == "show" and str(first_data.get("condition_raw", "")) == "v_default" and str(first_data.get("image_raw", "")) == "default_choice", "block attributes should supply inherited branch mode, condition, and image")
	var second_data: Dictionary = second.get("branch", {})
	_expect(str(second.get("target", "")) == "z_primary:choice" and str(second_data.get("mode", "")) == "enable", "parallel options to one target must remain distinct")
	_expect(str(second_data.get("condition_raw", "")) == "check_pair(1, nested(2, 3))" and str(second_data.get("image_raw", "")) == "explicit_choice", "option metadata should override block attributes")
	_expect(int(first_data.get("option_index", -1)) == 0 and int(second_data.get("option_index", -1)) == 1, "parallel branch option order should remain stable")
	var dynamic_data: Dictionary = dynamic.get("branch", {})
	_expect(str(dynamic.get("target_kind", "")) == "dynamic" and str(dynamic.get("target_expression", "")) == "dynamic_dest", "dynamic branch destinations should retain their expression")
	_expect(bool(dynamic_data.get("fallback", false)), "an unconditional jump-mode option should be marked as fallback")
	_expect(_has_target_kind(report, "defined") and _has_target_kind(report, "external") and _has_target_kind(report, "missing") and _has_target_kind(report, "dynamic"), "graph edges should expose all four target kinds")

	var jump_if := _first_edge_of_kind(report, "jump_if")
	_expect(str((jump_if.get("guard", {}) as Dictionary).get("raw", "")) == "check_pair(1, nested(2, 3))", "jump_if should retain nested-comma condition text")
	_expect(_has_edge(report, "z_primary:choice", "z_primary:end", "jump_to"), "first same-block jump should remain owned by l_choice")
	_expect(_has_edge(report, "z_primary:after", "external_node", "jump_to"), "second same-block jump should remain owned by l_after")
	_expect(_has_edge(report, "z_primary:local", "z_primary:end", "jump_to"), "third same-block jump should remain owned by the primary local label")
	_expect(not JSON.stringify(report).contains(EAGER_SENTINEL), "eager push_error text must never execute or leak into the graph report")


func _test_determinism_and_renderers() -> void:
	var forward := _build(_analyze([PRIMARY_PATH, SECONDARY_PATH], [CONTEXT_PATH]))
	var reverse := _build(_analyze([SECONDARY_PATH, PRIMARY_PATH], [CONTEXT_PATH]))
	_expect(JSON.stringify(forward, "\t") == JSON.stringify(reverse, "\t"), "reversing selected input order must not change graph JSON")

	var visualizer = ScenarioVisualizationScript.new()
	var forward_dot: String = visualizer.render_dot(forward)
	var reverse_dot: String = visualizer.render_dot(reverse)
	_expect(forward_dot == reverse_dot, "reversing selected input order must not change DOT output")
	var text_report: String = visualizer.render_text(forward)
	var mermaid: String = visualizer.render_mermaid(forward)
	_expect(text_report.begins_with("ScenarioVisualize:"), "text renderer should expose the stable ScenarioVisualize prefix")
	_expect(forward_dot.begins_with("digraph scenario_flow"), "DOT renderer should emit a digraph")
	_expect(mermaid.begins_with("flowchart LR"), "Mermaid renderer should emit a flowchart")
	_expect(text_report.contains("选项 \"一\" \\ path"), "text output should preserve Unicode branch labels")
	_expect(forward_dot.contains("选项 \\\"一\\\" \\\\ path"), "DOT output should escape quotes and backslashes")
	_expect(mermaid.contains("选项 &quot;一&quot; \\ path"), "Mermaid output should escape quotes while retaining the literal backslash")
	_expect(not text_report.contains(EAGER_SENTINEL) and not forward_dot.contains(EAGER_SENTINEL) and not mermaid.contains(EAGER_SENTINEL), "renderers must not expose or execute eager sentinel code")
	var compact := _build(_analyze([PRIMARY_PATH], [CONTEXT_PATH]), {
		"roots": ["viz_root"],
		"cluster": "none",
		"label": "id",
		"max_label_chars": 5,
	})
	var compact_dot: String = visualizer.render_dot(compact)
	_expect(not compact_dot.contains("subgraph cluster_"), "cluster=none should render a flat DOT graph")
	_expect(compact_dot.contains("label=\"viz_…\""), "label and max-label-chars options should deterministically truncate rendered IDs")


func _test_views_filters_and_boundaries() -> void:
	var primary_analysis := _analyze([PRIMARY_PATH], [CONTEXT_PATH])
	var branch_view := _build(primary_analysis, {"view": "branches", "roots": ["viz_root"]})
	var branch_summary: Dictionary = branch_view.get("summary", {})
	_expect(int(branch_summary.get("edges", 0)) == 6 and int(branch_summary.get("branch_edges", 0)) == 6, "branch view should retain only branch transitions")
	_expect(int(branch_summary.get("defined_nodes", 0)) == 3 and int(branch_summary.get("placeholder_nodes", 0)) == 3, "branch view should retain its source, defined targets, and boundary placeholders")

	var jump_filter := _build(primary_analysis, {"roots": ["viz_root"], "edge_kinds": ["jump_if"]})
	_expect(int((jump_filter.get("summary", {}) as Dictionary).get("edges", 0)) == 1 and str(_first_edge_of_kind(jump_filter, "jump_if").get("kind", "")) == "jump_if", "edge-kind filtering should isolate jump_if")
	var lazy_filter := _build(primary_analysis, {"roots": ["viz_root"], "phases": ["lazy"]})
	_expect(int((lazy_filter.get("summary", {}) as Dictionary).get("edges", 0)) == 1 and str(_first_edge_with_phase(lazy_filter, "lazy").get("phase", "")) == "lazy", "phase filtering should isolate the lazy transition")

	var boundary_include := _build(primary_analysis, {
		"roots": ["viz_root"],
		"node_globs": ["viz_root"],
		"boundary": "include",
	})
	var include_summary: Dictionary = boundary_include.get("summary", {})
	_expect(int(include_summary.get("defined_nodes", 0)) == 1 and int(include_summary.get("edges", 0)) == 9, "include boundary should keep every outgoing root transition")
	_expect(int(include_summary.get("placeholder_nodes", 0)) == 6 and int(include_summary.get("filtered_targets", 0)) == 6, "include boundary should coalesce filtered targets while counting their edges")
	var boundary_drop := _build(primary_analysis, {
		"roots": ["viz_root"],
		"node_globs": ["viz_root"],
		"boundary": "drop",
	})
	var drop_summary: Dictionary = boundary_drop.get("summary", {})
	_expect(int(drop_summary.get("defined_nodes", 0)) == 1 and int(drop_summary.get("placeholder_nodes", 0)) == 0 and int(drop_summary.get("edges", 0)) == 0, "drop boundary should remove transitions leaving the selected node set")

	var reachable := _build(_analyze([PRIMARY_PATH, SECONDARY_PATH], [CONTEXT_PATH]), {
		"roots": ["viz_root"],
		"reachable_only": true,
	})
	_expect(int((reachable.get("summary", {}) as Dictionary).get("defined_nodes", 0)) == 5, "reachable-only should retain the five defined nodes reachable from viz_root")
	_expect(_node_named(reachable.get("nodes", []), "secondary_root").is_empty() and _node_named(reachable.get("nodes", []), "viz_debug_isolated").is_empty(), "reachable-only should remove unrelated and isolated nodes")
	var without_debug := _build(_analyze([PRIMARY_PATH, SECONDARY_PATH], [CONTEXT_PATH]), {"exclude_debug": true})
	_expect(_node_named(without_debug.get("nodes", []), "viz_debug_isolated").is_empty(), "exclude-debug should remove a non-start debug node")


func _test_default_corpus_baseline() -> void:
	var analysis := ScenarioAnalysisScript.new().analyze_paths([], {"auto_context": false})
	_expect(bool(analysis.get("ok", false)), "default corpus should analyze cleanly for visualization")
	var report := _build(analysis, {"root_policy": "all", "phases": ["eager"]})
	var summary: Dictionary = report.get("summary", {})
	_expect(int(summary.get("files", 0)) == 28, "default visualization corpus should contain 28 files")
	_expect(int(summary.get("defined_nodes", 0)) == 57, "default visualization corpus should contain 57 defined nodes")
	_expect(int(summary.get("edges", 0)) == 52, "default eager flow graph should contain 52 transitions")
	_expect(int(summary.get("branch_edges", 0)) == 28, "default eager flow graph should contain 28 branch options")
	_expect(int(summary.get("jump_to_edges", 0)) + int(summary.get("jump_if_edges", 0)) == 24, "default eager flow graph should contain 24 jump-like transitions")
	_expect(_count_nodes_with_flag(report, "start") == 9, "default graph should preserve nine start nodes")
	_expect(_count_nodes_with_flag(report, "unlocked_start") == 2, "default graph should preserve two unlocked starts")
	_expect(_count_nodes_with_flag(report, "debug") == 18, "default graph should preserve eighteen debug nodes")
	_expect(_count_nodes_with_flag(report, "local") == 27, "default graph should preserve twenty-seven local nodes")
	_expect(_count_nodes_of_type(report, "normal") == 26 and _count_nodes_of_type(report, "chapter") == 9 and _count_nodes_of_type(report, "end") == 22, "default graph node types should remain 26 normal / 9 chapter / 22 end")


func _test_godot_cli() -> void:
	var common := ["--context", CONTEXT_PATH, "--no-context", PRIMARY_PATH, SECONDARY_PATH]
	for raw_format in ["text", "json", "dot", "mermaid"]:
		var format := str(raw_format)
		var cli_args: Array[String] = ["--format", format]
		cli_args.append_array(common)
		var result := _run_godot_cli(cli_args)
		var output := str(result.get("output", ""))
		_expect(int(result.get("exit_code", -1)) == 0, "Godot visualization CLI %s should exit 0; output=%s" % [format, output])
		_expect(not output.contains(EAGER_SENTINEL), "Godot visualization CLI must not execute eager sentinel code")
		match format:
			"json":
				var report := _parse_full_json_report(output)
				_expect(int(report.get("schema_version", 0)) == 1 and str(report.get("kind", "")) == "scenario_flow", "Godot JSON CLI should emit the graph contract")
			"dot":
				_expect(output.strip_edges().begins_with("digraph"), "Godot DOT CLI should emit a digraph")
			"mermaid":
				_expect(output.strip_edges().begins_with("flowchart"), "Godot Mermaid CLI should emit a flowchart")
			_:
				_expect(output.strip_edges().begins_with("ScenarioVisualize:"), "Godot text CLI should emit the stable prefix")

	var invalid := _run_godot_cli(["--definitely-invalid-option"])
	_expect(int(invalid.get("exit_code", -1)) == 2, "invalid Godot visualization CLI usage should exit 2")
	var invalid_root := _run_godot_cli(["--root", "definitely_missing_root", PRIMARY_PATH])
	_expect(int(invalid_root.get("exit_code", -1)) == 2, "unmatched explicit Godot CLI roots should exit 2")


func _test_python_cli() -> void:
	var python := _find_python()
	_expect(not python.is_empty(), "a Python interpreter is required to smoke-test scenario_visualize.py")
	if python.is_empty():
		return
	var script_path := ProjectSettings.globalize_path("res://scripts/tools/scenario_visualize.py")
	var project_path := ProjectSettings.globalize_path("res://")
	var common := [
		"--godot", OS.get_executable_path(),
		"--project", project_path,
		"--context", CONTEXT_PATH,
		"--no-context",
		PRIMARY_PATH,
		SECONDARY_PATH,
	]
	for raw_format in ["text", "json", "dot", "mermaid"]:
		var format := str(raw_format)
		var args: Array[String] = [script_path, "--format", format]
		args.append_array(common)
		var result := _run_process(python, args)
		var output := str(result.get("output", ""))
		_expect(int(result.get("exit_code", -1)) == 0, "public Python visualization CLI %s should exit 0; output=%s" % [format, output])
		_expect(not output.contains(EAGER_SENTINEL), "public Python visualization CLI must not execute eager sentinel code")
		match format:
			"json":
				var report := _parse_full_json_report(output)
				_expect(int(report.get("schema_version", 0)) == 1 and str(report.get("kind", "")) == "scenario_flow", "public Python JSON CLI should preserve the graph contract")
			"dot":
				_expect(output.begins_with("digraph"), "public Python DOT CLI should emit a digraph")
			"mermaid":
				_expect(output.begins_with("flowchart"), "public Python Mermaid CLI should emit a flowchart")
			_:
				_expect(output.begins_with("ScenarioVisualize:"), "public Python text CLI should emit the stable prefix")

	var output_path := ProjectSettings.globalize_path(PYTHON_OUTPUT_PATH)
	var file_args: Array[String] = [script_path, "--format", "dot", "--output", output_path]
	file_args.append_array(common)
	var file_result := _run_process(python, file_args)
	_expect(int(file_result.get("exit_code", -1)) == 0, "public Python CLI should write DOT to an output file")
	_expect(_read_file(PYTHON_OUTPUT_PATH).begins_with("digraph"), "public Python output file should contain DOT rather than subprocess logs")

	var cwd_args := [
		"-c", PYTHON_CWD_RUNNER,
		ProjectSettings.globalize_path(PYTHON_CWD_PATH),
		script_path,
		"--godot", OS.get_executable_path(),
		"--project", project_path,
		"--format", "json",
		"--no-context",
		"resources/scenarios/ch1.txt",
	]
	var cwd_result := _run_process(python, cwd_args)
	var cwd_report := _parse_full_json_report(str(cwd_result.get("output", "")))
	_expect(int(cwd_result.get("exit_code", -1)) == 0 and int(cwd_report.get("schema_version", 0)) == 1, "public Python CLI should resolve project-relative scenario paths from an arbitrary cwd")

	var bad_result := _run_process(python, [
		script_path,
		"--project", project_path,
		"--godot", "definitely_missing_godot_for_visualize_smoke",
		PRIMARY_PATH,
	])
	_expect(int(bad_result.get("exit_code", -1)) == 2, "public Python visualization infrastructure failures should exit 2")


func _analyze(paths: Array, context_paths: Array = []) -> Dictionary:
	return ScenarioAnalysisScript.new().analyze_paths(paths, {
		"context_paths": context_paths,
		"auto_context": false,
	})


func _build(analysis: Dictionary, options: Dictionary = {}) -> Dictionary:
	return ScenarioVisualizationScript.new().build(analysis, options)


func _node_named(nodes: Array, node_id: String) -> Dictionary:
	for raw_node in nodes:
		if raw_node is Dictionary and str((raw_node as Dictionary).get("id", "")) == node_id:
			return raw_node as Dictionary
	return {}


func _edges_of_kind(report: Dictionary, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for raw_edge in report.get("edges", []):
		if raw_edge is Dictionary and str((raw_edge as Dictionary).get("kind", "")) == kind:
			out.append(raw_edge as Dictionary)
	return out


func _first_edge_of_kind(report: Dictionary, kind: String) -> Dictionary:
	var edges := _edges_of_kind(report, kind)
	if edges.is_empty():
		return {}
	return edges.front()


func _first_edge_with_phase(report: Dictionary, phase: String) -> Dictionary:
	for raw_edge in report.get("edges", []):
		if raw_edge is Dictionary and str((raw_edge as Dictionary).get("phase", "")) == phase:
			return raw_edge as Dictionary
	return {}


func _branch_at(branches: Array[Dictionary], option_index: int) -> Dictionary:
	for edge in branches:
		var branch: Dictionary = edge.get("branch", {})
		if int(branch.get("option_index", -1)) == option_index:
			return edge
	return {}


func _has_target_kind(report: Dictionary, target_kind: String) -> bool:
	for raw_edge in report.get("edges", []):
		if raw_edge is Dictionary and str((raw_edge as Dictionary).get("target_kind", "")) == target_kind:
			return true
	return false


func _has_edge(report: Dictionary, source: String, target: String, kind: String) -> bool:
	for raw_edge in report.get("edges", []):
		if not (raw_edge is Dictionary):
			continue
		var edge: Dictionary = raw_edge
		if str(edge.get("source", "")) == source and str(edge.get("target", "")) == target and str(edge.get("kind", "")) == kind:
			return true
	return false


func _analysis_has_raw_target(analysis: Dictionary, target: String) -> bool:
	for raw_edge in analysis.get("edges", []):
		if raw_edge is Dictionary and str((raw_edge as Dictionary).get("raw_target", "")) == target:
			return true
	return false


func _count_nodes_with_flag(report: Dictionary, flag: String) -> int:
	var count := 0
	for raw_node in report.get("nodes", []):
		if not (raw_node is Dictionary):
			continue
		var node: Dictionary = raw_node
		if bool(node.get("defined", false)) and flag in node.get("flags", []):
			count += 1
	return count


func _count_nodes_of_type(report: Dictionary, node_type: String) -> int:
	var count := 0
	for raw_node in report.get("nodes", []):
		if not (raw_node is Dictionary):
			continue
		var node: Dictionary = raw_node
		if bool(node.get("defined", false)) and str(node.get("type", "")) == node_type:
			count += 1
	return count


func _write_fixture(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write fixture %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(source)
	file.close()


func _read_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content := file.get_as_text()
	file.close()
	return content


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _run_godot_cli(user_args: Array[String]) -> Dictionary:
	var args := PackedStringArray([
		"--headless",
		"--no-header",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://scripts/tools/scenario_visualize.gd",
		"--",
	])
	for arg in user_args:
		args.append(arg)
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {"exit_code": exit_code, "output": _join_output(output)}


func _find_python() -> String:
	var candidates := [OS.get_environment("UNISTORY_PYTHON"), OS.get_environment("PYTHON"), "python", "python3"]
	for raw_candidate in candidates:
		var candidate := str(raw_candidate).strip_edges()
		if candidate.is_empty():
			continue
		var output: Array = []
		if OS.execute(candidate, PackedStringArray(["--version"]), output, true) == 0:
			return candidate
	return ""


func _run_process(executable: String, raw_args: Array) -> Dictionary:
	var args := PackedStringArray()
	for raw_arg in raw_args:
		args.append(str(raw_arg))
	var output: Array = []
	var exit_code := OS.execute(executable, args, output, true)
	return {"exit_code": exit_code, "output": _join_output(output)}


func _join_output(parts: Array) -> String:
	var strings := PackedStringArray()
	for part in parts:
		strings.append(str(part))
	return "\n".join(strings)


func _parse_full_json_report(output: String) -> Dictionary:
	var parsed = JSON.parse_string(output.strip_edges())
	return parsed if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
