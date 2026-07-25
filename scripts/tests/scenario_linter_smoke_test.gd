extends SceneTree

## Headless smoke test for ScenarioLinter diagnostics, ordering, and CLI exits.

const ScenarioLinterScript := preload("res://scripts/tools/scenario_linter.gd")
const FIXTURE_DIR := "user://tests/scenario_linter_smoke"
const VALID_PATH := FIXTURE_DIR + "/valid.txt"
const BROKEN_PATH := FIXTURE_DIR + "/broken_flow.txt"
const UNTERMINATED_PATH := FIXTURE_DIR + "/unterminated.txt"
const NO_START_PATH := FIXTURE_DIR + "/no_start.txt"
const WARNING_PATH := FIXTURE_DIR + "/warning_only.txt"
const CONTENT_PATH := FIXTURE_DIR + "/content_rules.txt"
const COMPILE_PATH := FIXTURE_DIR + "/compile_error.txt"
const RESOURCE_PATH := FIXTURE_DIR + "/missing_resource.txt"
const CONDITION_PATH := FIXTURE_DIR + "/condition_error.txt"
const BEFORE_LABEL_PATH := FIXTURE_DIR + "/before_label_order.txt"
const MULTI_LABEL_PATH := FIXTURE_DIR + "/multi_label_order.txt"
const COMMENT_PATH := FIXTURE_DIR + "/comment_and_string_masking.txt"
const BRANCH_ATTR_PATH := FIXTURE_DIR + "/branch_attrs.txt"
const AUTO_VOICE_PATH := FIXTURE_DIR + "/unknown_auto_voice.txt"
const FLOW_SCOPE_PATH := FIXTURE_DIR + "/flow_scope.txt"
const LOCATION_PATH := FIXTURE_DIR + "/leading_blank_location.txt"
const INLINE_LOCATION_PATH := FIXTURE_DIR + "/inline_location.txt"

const VALID_SOURCE := "@<|\nlabel(\"lint_valid_start\")\nis_start()\n|>\nA quiet narration line.\n@<|\nis_end()\n|>\n"
const BROKEN_SOURCE := "@<|\nlabel(\"lint_broken_start\")\nis_start()\njump_to(\"missing_destination\")\nlabel(\"lint_broken_start\")\nbox_tint(\"#ffffff\")\n|>\n"
const UNTERMINATED_SOURCE := "@<|\nlabel(\"lint_unterminated_start\")\nis_start()\n"
const NO_START_SOURCE := "@<|\nlabel(\"lint_no_start\")\nis_end()\n|>\n"
const WARNING_SOURCE := "@<|\nlabel(\"lint_warning_start\")\nis_start()\nbox_tint(\"#ffffff\")\nis_end()\n|>\n"
const CONTENT_SOURCE := "@<|\nlabel(\"lint_content_start\")\nis_start()\nanim_hold_end()\nanim_hold_begin()\nanim_hold_begin()\nbranch {\n    { dest = \"lint_content_start\", mode = \"jump\", cond = \"true\" },\n}\n|>\nAlice::Hello!\nTODO: rewrite\nBad\u0001control\n"
const COMPILE_SOURCE := "@<|\nlabel(\"lint_compile_start\")\nis_start()\nvar broken =\n|>\n"
const RESOURCE_SOURCE := "@<|\nlabel(\"lint_resource_start\")\nis_start()\n|>\n<|\nshow(bg, \"lint_definitely_missing_background\")\nset_temp_var(\"lint_key\", \"not/a/resource\")\nvideo_play(\"Videos/lint_explicit_missing.mp4\")\nshow(bg, \"Backgrounds/room\")\nplay(bgm, \"BGM/prelude.ogg\")\nsound(\"Sounds/clap.ogg\")\n|>\nResource check.\n"
const CONDITION_SOURCE := "@<|\nlabel(\"lint_condition_start\")\nis_start()\nbranch {\n    { dest = \"lint_condition_start\", mode = \"jump\", cond = function()\n        return v_bad +\n    end },\n    { dest = \"lint_condition_start\", mode = \"jump\" },\n}\n|>\n"
const BEFORE_LABEL_SOURCE := "@<|\njump_to(\"lint_before_label\")\nis_start()\nanim_hold_end()\nlabel(\"lint_before_label\")\nis_debug()\n|>\n"
const MULTI_LABEL_SOURCE := "@<|\nlabel(\"lint_order_first\")\nis_start()\njump_to(\"lint_order_second\")\nlabel(\"lint_order_second\")\nis_end()\n|>\n"
const COMMENT_SOURCE := "@<|\nlabel(\"lint_comment_start\")\nis_start()\n# jump_to(\"missing_hash_comment\")\n-- label(\"missing_lua_comment\")\nvar hash_text = \"# jump_to('inside_string')\"\nvar lua_text = \"-- label('inside_string')\"\nvar fake_audio = \"play_bgm('missing.ogg')\"\nvar url = \"https://example.com/not-an-asset.png\"\nvar dest = \"not_a_branch_target\"\nvar image = \"not_a_choice_resource\"\n# box_tint()\nis_end()\n|>\n"
const BRANCH_ATTR_SOURCE := "@<|\nlabel(\"lint_branch_attr_start\")\nis_start()\n|>\n@[mode = jump; cond = \"v_ready\"; image = red_pill]@<|\nbranch {\n    {\n        dest = \"lint_branch_attr_start\"\n    },\n    { dest = \"lint_branch_attr_start\", image = \"red_pill\" },\n    { dest = \"lint_branch_attr_start\", image = [\"blue_pill\", [0, 0, 1]] },\n}\n|>\n"
const AUTO_VOICE_SOURCE := "@<|\nlabel(\"lint_auto_voice_start\")\nis_start()\n|>\n<|\nauto_voice_on(\"lint_missing_speaker\")\n|>\nVoice check.\n"
const FLOW_SCOPE_SOURCE := "@<|\nlabel(\"lint_scope_start\")\nis_start()\nhelper.label(\"qualified_fake_label\")\nhelper.jump_to(\"qualified_missing_target\")\nhelper.jump_if(check(a, b), \"qualified_missing_if_target\")\nvar dest = \"not_a_branch_target\"\njump_if(check(v_ready, pair(1, 2)), \"lint_scope_end\")\nbranch(\n            \n    {\n        { dest = \"lint_scope_end\", mode = \"jump\", cond = \"v_ready\" },\n        { dest = \"lint_scope_end\", mode = \"jump\" },\n    }\n)\nlabel(\"lint_scope_end\")\nis_end()\n|>\n"
const LOCATION_SOURCE := "@<|\n\n   \n    label(\"lint_location_start\")\n    is_start()\n    jump_to(\"lint_location_missing\")\n|>\n"
const INLINE_LOCATION_SOURCE := "@<|    label(\"lint_inline_start\"); is_start(); jump_to(\"lint_inline_missing\") |>\n"

const LINT_OPTIONS := {
	"compile_blocks": false,
	"check_resources": false,
	"check_no_op": true,
}

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_write_fixture(VALID_PATH, VALID_SOURCE)
	_write_fixture(BROKEN_PATH, BROKEN_SOURCE)
	_write_fixture(UNTERMINATED_PATH, UNTERMINATED_SOURCE)
	_write_fixture(NO_START_PATH, NO_START_SOURCE)
	_write_fixture(WARNING_PATH, WARNING_SOURCE)
	_write_fixture(CONTENT_PATH, CONTENT_SOURCE)
	_write_fixture(COMPILE_PATH, COMPILE_SOURCE)
	_write_fixture(RESOURCE_PATH, RESOURCE_SOURCE)
	_write_fixture(CONDITION_PATH, CONDITION_SOURCE)
	_write_fixture(BEFORE_LABEL_PATH, BEFORE_LABEL_SOURCE)
	_write_fixture(MULTI_LABEL_PATH, MULTI_LABEL_SOURCE)
	_write_fixture(COMMENT_PATH, COMMENT_SOURCE)
	_write_fixture(BRANCH_ATTR_PATH, BRANCH_ATTR_SOURCE)
	_write_fixture(AUTO_VOICE_PATH, AUTO_VOICE_SOURCE)
	_write_fixture(FLOW_SCOPE_PATH, FLOW_SCOPE_SOURCE)
	_write_fixture(LOCATION_PATH, LOCATION_SOURCE)
	_write_fixture(INLINE_LOCATION_PATH, INLINE_LOCATION_SOURCE)

	_test_valid_fixture()
	_test_core_diagnostics()
	_test_stable_ordering()
	_test_default_corpus_baseline()
	_test_cli_json_and_exit_codes()

	if _failures.is_empty():
		print("ScenarioLinterSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ScenarioLinterSmokeTest: FAILED")
		quit(1)


func _test_valid_fixture() -> void:
	var report := _lint([VALID_PATH])
	var summary: Dictionary = report.get("summary", {})
	_expect(int(summary.get("files", 0)) == 1, "valid fixture should be linted")
	_expect(int(summary.get("errors", -1)) == 0, "valid fixture should have no errors: %s" % JSON.stringify(report.get("issues", [])))
	var alias_report := _lint([VALID_PATH, ProjectSettings.globalize_path(VALID_PATH)])
	_expect(int(alias_report.get("summary", {}).get("files", 0)) == 1, "res/user paths and their absolute aliases should be deduplicated")
	_expect(int(alias_report.get("summary", {}).get("errors", -1)) == 0, "path aliases must not create duplicate labels")
	var missing_path := FIXTURE_DIR + "/does_not_exist.txt"
	var mixed_report := _lint([VALID_PATH, missing_path])
	_expect(int(mixed_report.get("summary", {}).get("files", 0)) == 1, "valid inputs should still be linted when another input is invalid")
	_expect_diagnostic(mixed_report, "input.not_found", "error", missing_path, 0)
	if OS.get_name() == "Windows":
		var case_alias_report := _lint_with_options(["res://Resources/Scenarios/ch1.txt"], {
			"compile_blocks": false,
			"check_resources": false,
			"check_no_op": false,
		})
		_expect(int(case_alias_report.get("summary", {}).get("errors", -1)) == 0, "Windows path-case aliases should still receive the default external label context")
	var partial_default_report := _lint_with_options(["res://resources/scenarios/ch4.txt"], {
		"compile_blocks": false,
		"check_resources": false,
		"check_no_op": false,
	})
	_expect(int(partial_default_report.get("summary", {}).get("errors", -1)) == 0, "a default-corpus subset should use external graph context without requiring its own start node: %s" % JSON.stringify(partial_default_report.get("issues", [])))


func _test_core_diagnostics() -> void:
	var broken_report := _lint([BROKEN_PATH])
	_expect_diagnostic(broken_report, "flow.missing_target", "error", BROKEN_PATH, 4)
	_expect_diagnostic(broken_report, "flow.duplicate_label", "error", BROKEN_PATH, 5)
	_expect_diagnostic(broken_report, "compat.no_op", "warning", BROKEN_PATH, 6)

	var unterminated_report := _lint([UNTERMINATED_PATH])
	_expect_diagnostic(unterminated_report, "syntax.unterminated_block", "error", UNTERMINATED_PATH, 1)

	var no_start_report := _lint([NO_START_PATH])
	var no_start := _find_diagnostic(no_start_report, "flow.no_start", NO_START_PATH)
	_expect(not no_start.is_empty(), "flow.no_start should identify the fixture path")

	var content_report := _lint([CONTENT_PATH])
	_expect_diagnostic(content_report, "anim_hold.unmatched_end", "warning", CONTENT_PATH, 4)
	_expect_diagnostic(content_report, "anim_hold.reentrant", "warning", CONTENT_PATH, 6)
	_expect_diagnostic(content_report, "anim_hold.unclosed", "warning", CONTENT_PATH, 5)
	_expect_diagnostic(content_report, "flow.jump_branch_no_fallback", "warning", CONTENT_PATH, 7)
	_expect_diagnostic(content_report, "dialogue.missing_quotes", "warning", CONTENT_PATH, 11)
	_expect_diagnostic(content_report, "dialogue.halfwidth_punctuation", "warning", CONTENT_PATH, 11)
	_expect_diagnostic(content_report, "content.todo", "warning", CONTENT_PATH, 12)
	var control_issue := _find_diagnostic(content_report, "content.control_character", CONTENT_PATH)
	_expect(not control_issue.is_empty(), "control characters should produce a diagnostic")
	if not control_issue.is_empty():
		_expect(int(control_issue.get("line", 0)) == 13 and int(control_issue.get("column", 0)) == 4, "control-character diagnostics should preserve a non-default column")

	var resource_report := _lint_with_options([RESOURCE_PATH], {
		"compile_blocks": false,
		"check_resources": true,
		"check_no_op": false,
	})
	_expect_diagnostic(resource_report, "asset.missing", "error", RESOURCE_PATH, 6)
	var found_explicit_video := false
	for raw_issue in resource_report.get("issues", []):
		if raw_issue is Dictionary:
			_expect(str(raw_issue.get("resource", "")) != "not/a/resource", "generic strings containing / must not be treated as resources without a recognized resource context")
			if str(raw_issue.get("resource", "")) == "Videos/lint_explicit_missing.mp4" and int(raw_issue.get("line", 0)) == 8:
				found_explicit_video = true
	_expect(found_explicit_video, "video_play(path) should validate its explicit runtime resource")
	_expect(int(resource_report.get("summary", {}).get("resource_references", -1)) == 5, "recognized resource calls should all be counted")
	_expect(int(resource_report.get("summary", {}).get("resource_found", -1)) == 3, "explicit runtime-relative image/audio paths should resolve without duplicated folders")
	_expect(int(resource_report.get("summary", {}).get("resource_missing", -1)) == 2, "only the intentionally missing image and video should fail resource validation")

	var before_label_report := _lint([BEFORE_LABEL_PATH])
	_expect_diagnostic(before_label_report, "flow.code_before_label", "error", BEFORE_LABEL_PATH, 2)
	_expect_diagnostic(before_label_report, "flow.transition_before_label", "error", BEFORE_LABEL_PATH, 2)
	_expect_diagnostic(before_label_report, "flow.entry_before_label", "error", BEFORE_LABEL_PATH, 3)
	_expect_diagnostic(before_label_report, "anim_hold.before_label", "warning", BEFORE_LABEL_PATH, 4)

	var multi_label_report := _lint([MULTI_LABEL_PATH])
	_expect(_find_diagnostic(multi_label_report, "flow.unreachable", MULTI_LABEL_PATH).is_empty(), "flow events between multiple labels must stay attached to their source node")

	var comment_report := _lint_with_options([COMMENT_PATH], {
		"compile_blocks": false,
		"check_resources": true,
		"check_no_op": true,
	})
	_expect(int(comment_report.get("summary", {}).get("errors", -1)) == 0, "# / -- comments and quoted pseudo-calls must not create lint errors: %s" % JSON.stringify(comment_report.get("issues", [])))
	_expect(_find_diagnostic(comment_report, "compat.no_op", COMMENT_PATH).is_empty(), "no-op names inside comments must be ignored")

	var branch_attr_report := _lint_with_options([BRANCH_ATTR_PATH], {
		"compile_blocks": false,
		"check_resources": true,
		"check_no_op": true,
	})
	_expect_diagnostic(branch_attr_report, "flow.jump_branch_no_fallback", "warning", BRANCH_ATTR_PATH, 6)
	_expect(_find_diagnostic(branch_attr_report, "syntax.unknown_attribute", BRANCH_ATTR_PATH).is_empty(), "mode/cond/image branch attributes are supported runtime attributes")
	_expect(int(branch_attr_report.get("summary", {}).get("resource_missing", -1)) == 0, "branch image attributes should resolve through Choices/")
	var auto_voice_report := _lint_with_options([AUTO_VOICE_PATH], {
		"compile_blocks": false,
		"check_resources": false,
		"check_no_op": false,
	})
	_expect_diagnostic(auto_voice_report, "auto_voice.unknown_speaker", "error", AUTO_VOICE_PATH, 6)

	var flow_scope_report := _lint_with_options([FLOW_SCOPE_PATH], {
		"compile_blocks": false,
		"check_resources": false,
		"check_no_op": false,
	})
	_expect(int(flow_scope_report.get("summary", {}).get("errors", -1)) == 0, "qualified helper calls and nested jump_if commas must not corrupt the flow graph: %s" % JSON.stringify(flow_scope_report.get("issues", [])))
	_expect(int(flow_scope_report.get("summary", {}).get("references", -1)) == 3, "only the unqualified jump_if and two real branch options should create references")
	_expect(_find_diagnostic(flow_scope_report, "flow.dynamic_target", FLOW_SCOPE_PATH).is_empty(), "literal targets with nested condition calls must not be reported as dynamic")
	_expect(_find_diagnostic(flow_scope_report, "flow.jump_branch_no_fallback", FLOW_SCOPE_PATH).is_empty(), "branch containers separated by arbitrary whitespace should retain their unconditional fallback")

	var location_report := _lint([LOCATION_PATH])
	var leading_location := _find_diagnostic(location_report, "flow.missing_target", LOCATION_PATH)
	_expect(not leading_location.is_empty(), "leading-blank fixture should report its missing target")
	if not leading_location.is_empty():
		_expect(int(leading_location.get("line", 0)) == 6 and int(leading_location.get("column", 0)) == 5, "block content metadata should preserve leading blank lines and indentation")
	var inline_location_report := _lint([INLINE_LOCATION_PATH])
	var inline_location := _find_diagnostic(inline_location_report, "flow.missing_target", INLINE_LOCATION_PATH)
	_expect(not inline_location.is_empty(), "inline fixture should report its missing target")
	if not inline_location.is_empty():
		_expect(int(inline_location.get("line", 0)) == 1 and int(inline_location.get("column", 0)) == INLINE_LOCATION_SOURCE.find("jump_to") + 1, "inline block diagnostics should preserve the physical source column")

	var wrong_profile := "res://resources/auto_voice_profile.tres"
	var profile_report := _lint_with_options([VALID_PATH], {
		"compile_blocks": false,
		"check_resources": true,
		"check_no_op": false,
		"standing_profile": wrong_profile,
		"visual_profile": wrong_profile,
	})
	_expect_diagnostic(profile_report, "config.standing_profile", "error", "resources/auto_voice_profile.tres", 0)
	_expect_diagnostic(profile_report, "config.visual_profile", "error", "resources/auto_voice_profile.tres", 0)


func _test_stable_ordering() -> void:
	var forward := _lint([UNTERMINATED_PATH, BROKEN_PATH, WARNING_PATH])
	var reverse := _lint([WARNING_PATH, BROKEN_PATH, UNTERMINATED_PATH])
	var forward_issues: Array = forward.get("issues", [])
	var reverse_issues: Array = reverse.get("issues", [])
	_expect(_issues_are_sorted(forward_issues), "diagnostics should use stable path/line/column/code ordering")
	_expect(JSON.stringify(forward_issues) == JSON.stringify(reverse_issues), "diagnostic ordering should not depend on input path order")


func _test_default_corpus_baseline() -> void:
	var report := _lint_with_options([], {
		"compile_blocks": false,
		"check_resources": true,
		"check_no_op": true,
	})
	var summary: Dictionary = report.get("summary", {})
	var expected := {
		"files": 28,
		"blocks": 387,
		"dialogues": 798,
		"labels": 57,
		"errors": 0,
		"warnings": 134,
		"resource_references": 426,
		"resource_found": 424,
		"resource_virtual": 2,
		"resource_missing": 0,
	}
	for key in expected.keys():
		_expect(summary.get(key) == expected[key], "default lint corpus %s should be %s, got %s" % [key, expected[key], summary.get(key)])


func _test_cli_json_and_exit_codes() -> void:
	var broken := _run_cli(["--json", "--no-compile", "--no-resources", BROKEN_PATH])
	_expect(int(broken.get("exit_code", -1)) == 1, "CLI should exit 1 when lint errors exist; output=%s" % broken.get("output", ""))
	var json_report := _extract_json_report(str(broken.get("output", "")))
	_expect(not json_report.is_empty(), "--json should emit a parseable report; output=%s" % broken.get("output", ""))
	if not json_report.is_empty():
		_expect_diagnostic(json_report, "flow.missing_target", "error", BROKEN_PATH, 4)

	var warning := _run_cli(["--no-compile", "--no-resources", WARNING_PATH])
	_expect(int(warning.get("exit_code", -1)) == 0, "warnings should not fail the CLI by default; output=%s" % warning.get("output", ""))
	var strict := _run_cli(["--strict", "--no-compile", "--no-resources", WARNING_PATH])
	_expect(int(strict.get("exit_code", -1)) == 1, "--strict should promote warnings to a failing exit; output=%s" % strict.get("output", ""))

	var invalid := _run_cli(["--definitely-unknown-option"])
	_expect(int(invalid.get("exit_code", -1)) == 2, "invalid CLI usage should exit 2; output=%s" % invalid.get("output", ""))
	var empty_path := _run_cli(["--path", " "])
	_expect(int(empty_path.get("exit_code", -1)) == 2, "empty Godot CLI paths should exit 2; output=%s" % empty_path.get("output", ""))

	# Keep the compiler failure in a child Godot process so SCRIPT ERROR output
	# cannot make the parent aggregate runner treat this smoke test as failed.
	var compile_error := _run_cli(["--json", "--no-resources", COMPILE_PATH])
	_expect(int(compile_error.get("exit_code", -1)) == 1, "compile diagnostics should fail the CLI; output=%s" % compile_error.get("output", ""))
	var compile_report := _extract_json_report(str(compile_error.get("output", "")))
	_expect_diagnostic(compile_report, "syntax.compile", "error", COMPILE_PATH, 1)

	var condition_error := _run_cli(["--json", "--no-resources", CONDITION_PATH])
	_expect(int(condition_error.get("exit_code", -1)) == 1, "invalid branch conditions should fail the CLI; output=%s" % condition_error.get("output", ""))
	var condition_report := _extract_json_report(str(condition_error.get("output", "")))
	_expect_diagnostic(condition_report, "syntax.condition", "error", CONDITION_PATH, 5)
	var branch_attr_compile := _run_cli(["--no-resources", BRANCH_ATTR_PATH])
	_expect(int(branch_attr_compile.get("exit_code", -1)) == 0, "supported branch attrs and inherited conditions should compile; output=%s" % branch_attr_compile.get("output", ""))

	var python_warning := _run_python_cli(["--no-compile", "--no-resources", WARNING_PATH])
	_expect(int(python_warning.get("exit_code", -1)) == 0, "public Python CLI should allow warnings by default; output=%s" % python_warning.get("output", ""))
	var python_error := _run_python_cli(["--format", "json", "--no-compile", "--no-resources", BROKEN_PATH])
	_expect(int(python_error.get("exit_code", -1)) == 1, "public Python CLI should return 1 for lint errors; output=%s" % python_error.get("output", ""))
	var python_report := _extract_json_report(str(python_error.get("output", "")))
	_expect_diagnostic(python_report, "flow.missing_target", "error", BROKEN_PATH, 4)
	var python_invalid := _run_python_cli(["--godot", "definitely-missing-godot-binary"])
	_expect(int(python_invalid.get("exit_code", -1)) == 2, "public Python CLI should return 2 for infrastructure errors; output=%s" % python_invalid.get("output", ""))
	var python_empty := _run_python_cli([" "])
	_expect(int(python_empty.get("exit_code", -1)) == 2, "public Python CLI should reject empty scenario paths; output=%s" % python_empty.get("output", ""))
	var python_partial_default := _run_python_cli(["--no-compile", "--no-resources", "res://resources/scenarios/ch4.txt"])
	_expect(int(python_partial_default.get("exit_code", -1)) == 0, "linting one file from the default corpus should not require that file to declare a project entry node; output=%s" % python_partial_default.get("output", ""))


func _lint(paths: Array) -> Dictionary:
	return _lint_with_options(paths, LINT_OPTIONS)


func _lint_with_options(paths: Array, options: Dictionary) -> Dictionary:
	var linter = ScenarioLinterScript.new()
	return linter.lint_paths(paths, options)


func _write_fixture(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write fixture %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(source)
	file.close()


func _expect_diagnostic(report: Dictionary, code: String, severity: String, path: String, line: int) -> void:
	var issue := _find_diagnostic(report, code, path)
	_expect(not issue.is_empty(), "missing diagnostic %s for %s; issues=%s" % [code, path, JSON.stringify(report.get("issues", []))])
	if issue.is_empty():
		return
	_expect(str(issue.get("severity", "")) == severity, "%s should be %s, got %s" % [code, severity, issue.get("severity", "")])
	_expect(int(issue.get("line", 0)) == line, "%s should point to line %d, got %s" % [code, line, issue.get("line", 0)])


func _find_diagnostic(report: Dictionary, code: String, path: String) -> Dictionary:
	for raw_issue in report.get("issues", []):
		if not (raw_issue is Dictionary):
			continue
		var issue: Dictionary = raw_issue
		if str(issue.get("code", "")) == code and str(issue.get("path", "")) == path:
			return issue
	return {}


func _issues_are_sorted(issues: Array) -> bool:
	for i in range(1, issues.size()):
		if not (issues[i - 1] is Dictionary and issues[i] is Dictionary):
			return false
		if _issue_less(issues[i], issues[i - 1]):
			return false
	return true


func _issue_less(a: Dictionary, b: Dictionary) -> bool:
	var a_path := str(a.get("path", ""))
	var b_path := str(b.get("path", ""))
	if a_path != b_path:
		return a_path < b_path
	var a_line := int(a.get("line", 0))
	var b_line := int(b.get("line", 0))
	if a_line != b_line:
		return a_line < b_line
	var a_column := int(a.get("column", 1))
	var b_column := int(b.get("column", 1))
	if a_column != b_column:
		return a_column < b_column
	return str(a.get("code", "")) < str(b.get("code", ""))


func _run_cli(user_args: Array[String]) -> Dictionary:
	var args := PackedStringArray([
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://scripts/tools/scenario_lint.gd",
		"--",
	])
	for arg in user_args:
		args.append(arg)
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), args, output, true)
	return {
		"exit_code": exit_code,
		"output": _join_output(output),
	}


func _run_python_cli(user_args: Array[String]) -> Dictionary:
	var python := OS.get_environment("UNISTORY_PYTHON")
	if python.is_empty():
		python = "python3" if OS.get_name() != "Windows" else "python"
	var args := PackedStringArray([
		ProjectSettings.globalize_path("res://scripts/tools/scenario_lint.py"),
		"--godot",
		OS.get_executable_path(),
	])
	for arg in user_args:
		args.append(arg)
	var output: Array = []
	var exit_code := OS.execute(python, args, output, true)
	return {
		"exit_code": exit_code,
		"output": _join_output(output),
	}


func _join_output(parts: Array) -> String:
	var strings := PackedStringArray()
	for part in parts:
		strings.append(str(part))
	return "\n".join(strings)


func _extract_json_report(output: String) -> Dictionary:
	var start := output.find("{")
	var finish := output.rfind("}")
	if start < 0 or finish < start:
		return {}
	var parsed = JSON.parse_string(output.substr(start, finish - start + 1))
	return parsed if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
