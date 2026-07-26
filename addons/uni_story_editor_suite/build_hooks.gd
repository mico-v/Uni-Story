@tool
class_name BuildHooks
extends RefCounted

## Static utility class providing build/pre-export hooks for Uni-Story.
##
## Usage from build scripts or the BuildPanel:
##   BuildHooks.run_lint()
##   BuildHooks.run_tests()
##   BuildHooks.pre_export_quality_gate()
##   BuildHooks.validate_export_presets()


## Known export preset names that must exist
const REQUIRED_PRESETS := ["Windows", "Linux", "Android"]


## Run scenario lint and return (exit_code, output_lines)
static func run_lint() -> Dictionary:
	var output: Array = []
	var code := OS.execute("python3", ["scripts/tools/scenario_lint.py"], output, true)
	return {"exit_code": code, "output": output}


## Run headless test suite and return (exit_code, output_lines)
static func run_tests() -> Dictionary:
	var output: Array = []
	var code := OS.execute("python3", ["scripts/tests/run_headless_suite.py"], output, true)
	return {"exit_code": code, "output": output}


## Pre-export quality gate: lint + tests must pass
## Returns true if all checks pass, false otherwise
static func pre_export_quality_gate() -> bool:
	print("[BuildHooks] === Pre-export Quality Gate ===")

	var lint_result := run_lint()
	print("[BuildHooks] Lint: exit_code=%d" % lint_result["exit_code"])
	if lint_result["exit_code"] != 0:
		print("[BuildHooks] Lint FAILED — aborting export")
		return false

	var test_result := run_tests()
	print("[BuildHooks] Tests: exit_code=%d" % test_result["exit_code"])
	if test_result["exit_code"] != 0:
		print("[BuildHooks] Tests FAILED — aborting export")
		return false

	print("[BuildHooks] Quality gate PASSED")
	return true


## Validate that required export presets exist
## Returns Dictionary with preset name → true/false
static func validate_export_presets() -> Dictionary:
	var result := {}
	for preset_name in REQUIRED_PRESETS:
		var found := false
		for i in range(EditorExport.get_export_preset_count()):
			var preset := EditorExport.get_export_preset(i)
			if preset and preset.get_name() == preset_name:
				found = true
				break
		result[preset_name] = found
	return result
