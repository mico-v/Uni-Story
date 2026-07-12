extends SceneTree

## Headless smoke coverage for the shared scenario IR, statistics, and CLIs.

const ScenarioAnalysisScript := preload("res://scripts/tools/scenario_analysis.gd")
const ScenarioStatisticsScript := preload("res://scripts/tools/scenario_statistics.gd")

const FIXTURE_DIR := "user://tests/scenario_stat_smoke"
const PRIMARY_PATH := FIXTURE_DIR + "/z_primary.txt"
const SECONDARY_PATH := FIXTURE_DIR + "/a_secondary.txt"
const COMMENT_PATH := FIXTURE_DIR + "/m_comment.txt"
const FLOW_PATH := "user://tests/scenario_stat_flow_order/order.txt"
const LOCATION_PATH := "user://tests/scenario_stat_source_location/location.txt"
const ORPHAN_PATH := "user://tests/scenario_stat_orphan/orphan.txt"
const SILENT_PATH := "user://tests/scenario_stat_silent/silent.txt"
const METADATA_PATH := "user://tests/scenario_stat_metadata/metadata.txt"
const CONTEXT_SELECTED_PATH := "user://tests/scenario_stat_context/selected.txt"
const CONTEXT_A_PATH := "user://tests/scenario_stat_context/a_context.txt"
const CONTEXT_B_PATH := "user://tests/scenario_stat_context/z_context.txt"
const LAZY_NAMESPACE_A_PATH := "user://tests/scenario_stat_lazy_namespace/a_origin.txt"
const LAZY_NAMESPACE_B_PATH := "user://tests/scenario_stat_lazy_namespace/z_extension.txt"

const PRIMARY_SOURCE := "@<|\nlabel(\"stat_fixture_root\", \"Fixture root\")\nis_start()\n|>\n<|\nsay(\"Alias\", \"000001\")\n|>\nAlias//Canonical：：<b><i>Alpha  text</i></b>（TODO：editor：drop（later））\nAlias：：<i>Beta</i>\nNarration   line\n@<|\nlabel 'l_local'\nis_end()\n|>\nAlias：：<b></b>\n"
const SECONDARY_SOURCE := "@<| label(\"l_local\") |>\nZed：：1234\nA\n"
const COMMENT_SOURCE := "@<|\nlabel(\"stat_comment\")\nis_debug()\n# label(\"fake_hash\")\n-- jump_to(\"fake_lua\")\nvar fake = \"label('fake_string')\"\n|>\nComment-safe narration.\n"
const FLOW_SOURCE := "@<|\nlabel(\"stat_order_first\")\nprint(\"label('fake') jump_to('fake')\")\nvar unrelated = { dest = \"fake_branch\" }\nother.label(\"fake_qualified\")\nother.jump_to(\"fake_qualified_jump\")\njump_to(\"stat_order_second\")\njump_if(check_pair(1, 2), \"stat_order_second\")\nbranch([{\n    dest = \"stat_order_second\", text = \"branch\"\n}])\nlabel(\"stat_order_second\")\njump_to(\"stat_order_first\")\n|>\n"
const LOCATION_SOURCE := "@<| label(\"stat_inline\") |>\n@<|\n\n  jump_to(\"stat_after_blanks\")\n|>\n@<|\n  label(\"stat_after_blanks\")\n|>\n"
const ORPHAN_SOURCE := "Orphan narration.\n@<|\nlabel(\"stat_orphan_valid\")\n|>\nValid narration.\n"
const SILENT_SOURCE := "@<|\nlabel(\"stat_silent\")\n|>\n[stage=before_checkpoint]<|\nbefore_one()\n|>\n[stage=after_dialogue]<|\nafter_one()\n|>\n@<|\nprint(\"flush pending staged lazy blocks\")\n|>\n<|\ndefault_one()\n|>\n<|\ndefault_two()\n|>\nVisible narration.\n<|\njump_to(dynamic_silent_target)\n|>\n"
const METADATA_SOURCE := "@<|\nlabel(\"meta_start\")\n|>\n@[mode=show; cond='v_default'; image='default_choice']@<|\nbranch {\n    { \"dest\": \"meta_end\", \"text\": \"Inherited\" },\n    { dest = dynamic_branch, text = \"Dynamic mode = prose\", mode = \"jump\", cond = \"v_dynamic\", image = \"dyn\" },\n}\njump_if(check_pair(1, 2), dynamic_jump)\njump_to dynamic_fallback\n|>\n<|\njump_if(check_pair(1, 2), \"meta_end\")\n|>\nLazy literal.\n<|\njump_to(dynamic_lazy_target)\n|>\nLazy dynamic.\n@<|\nlabel(\"meta_end\")\nis_end \"named-ending\"\nis_end()\n|>\nEnd.\n"
const CONTEXT_SELECTED_SOURCE := "@<|\nlabel(\"context_selected\", \"Selected\")\n|>\nSelected narration.\n"
const CONTEXT_A_SOURCE := "Ignored context text before any label.\n@<|\nlabel(\"context_external\", \"External\")\nlabel(\"context_selected\", \"Duplicate selected\")\n|>\n"
const CONTEXT_B_SOURCE := "@<| label(\"l_catalog\", \"Local catalog\") |>\n"
const LAZY_NAMESPACE_A_SOURCE := "@<| label(\"shared_global\") |>\n"
const LAZY_NAMESPACE_B_SOURCE := "@<| label(\"shared_global\") |>\n<|\njump_to(\"l_target\")\n|>\nContinued narration.\n@<| label(\"l_target\") |>\nTarget narration.\n"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_write_fixture(PRIMARY_PATH, PRIMARY_SOURCE)
	_write_fixture(SECONDARY_PATH, SECONDARY_SOURCE)
	_write_fixture(COMMENT_PATH, COMMENT_SOURCE)
	_write_fixture(FLOW_PATH, FLOW_SOURCE)
	_write_fixture(LOCATION_PATH, LOCATION_SOURCE)
	_write_fixture(ORPHAN_PATH, ORPHAN_SOURCE)
	_write_fixture(SILENT_PATH, SILENT_SOURCE)
	_write_fixture(METADATA_PATH, METADATA_SOURCE)
	_write_fixture(CONTEXT_SELECTED_PATH, CONTEXT_SELECTED_SOURCE)
	_write_fixture(CONTEXT_A_PATH, CONTEXT_A_SOURCE)
	_write_fixture(CONTEXT_B_PATH, CONTEXT_B_SOURCE)
	_write_fixture(LAZY_NAMESPACE_A_PATH, LAZY_NAMESPACE_A_SOURCE)
	_write_fixture(LAZY_NAMESPACE_B_PATH, LAZY_NAMESPACE_B_SOURCE)
	_test_analysis_ir()
	_test_flow_event_order()
	_test_source_locations()
	_test_pre_label_text()
	_test_silent_lazy_semantics()
	_test_ir_v2_flow_metadata()
	_test_context_labels()
	_test_statistics_and_ordering()
	_test_default_corpus_baseline()
	_test_godot_cli()
	_test_python_cli()

	if _failures.is_empty():
		print("ScenarioStatSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ScenarioStatSmokeTest: FAILED")
		quit(1)


func _test_analysis_ir() -> void:
	var analysis := _analyze([PRIMARY_PATH, SECONDARY_PATH])
	_expect(bool(analysis.get("ok", false)), "fixture analysis should succeed: %s" % JSON.stringify(analysis.get("errors", [])))
	_expect(int(analysis.get("schema_version", 0)) == 2, "shared scenario analysis should expose IR schema version 2")
	_expect((analysis.get("context_labels", []) as Array).is_empty(), "context indexing should stay opt-in for statistics compatibility")
	var summary: Dictionary = analysis.get("summary", {})
	_expect(int(summary.get("files", 0)) == 2, "fixture directory should contain two analyzed files")
	_expect(int(summary.get("nodes", 0)) == 3, "fixture should define three nodes")
	_expect(int(summary.get("dialogues", 0)) == 6, "fixture should define six text entries")

	var entries: Array = analysis.get("entries", [])
	var explicit := _entry_at(entries, PRIMARY_PATH, 8)
	var inherited := _entry_at(entries, PRIMARY_PATH, 9)
	var reset := _entry_at(entries, PRIMARY_PATH, 15)
	_expect(str(explicit.get("display_speaker", "")) == "Alias", "display speaker should omit the canonical suffix")
	_expect(str(explicit.get("canonical_speaker", "")) == "Canonical", "explicit canonical speaker should be retained")
	_expect(str(inherited.get("canonical_speaker", "")) == "Canonical", "canonical speaker should inherit within one node")
	_expect(str(reset.get("canonical_speaker", "")) == "Alias", "canonical aliases should reset at the next label")
	_expect(str(explicit.get("raw_text", "")) == "<b><i>Alpha  text</i></b>（TODO：editor：drop（later））", "IR should retain the raw dialogue body")
	_expect(str(explicit.get("text_without_rich_tags", "")) == "Alpha  text（TODO：editor：drop（later））", "paired nested rich tags should be stripped without removing text")
	_expect(str(explicit.get("normalized_text", "")) == "Alpha text", "normalization should remove TODO annotations and fold ASCII spaces")
	var lazy_blocks: Array = explicit.get("lazy_blocks", [])
	_expect(lazy_blocks.size() == 1, "the first dialogue should retain its preceding lazy block")
	if lazy_blocks.size() == 1:
		_expect(int((lazy_blocks[0] as Dictionary).get("line", 0)) == 5, "preceding lazy block should keep its source line")
		_expect(str((lazy_blocks[0] as Dictionary).get("translated_content", "")).contains("say("), "preceding lazy block should retain translated NovaScript")

	var local_node := _node_named(analysis.get("nodes", []), "z_primary:local")
	_expect(not local_node.is_empty(), "l_local should resolve through the file namespace")
	_expect(str(local_node.get("raw_name", "")) == "l_local", "IR should retain the raw local label")
	_expect(str(local_node.get("display_name", "")) == "Fixture root", "label display name should inherit within a file")
	_expect(str(reset.get("node", "")) == "z_primary:local", "dialogue should retain its resolved local node")
	_expect(not _node_named(analysis.get("nodes", []), "a_secondary:local").is_empty(), "same raw local label in another file should receive a distinct namespace")

	var directory_analysis := _analyze([FIXTURE_DIR])
	_expect(int((directory_analysis.get("summary", {}) as Dictionary).get("files", 0)) == 3, "explicit directories should be collected recursively")

	var comment_analysis := _analyze([COMMENT_PATH])
	_expect(int((comment_analysis.get("summary", {}) as Dictionary).get("nodes", 0)) == 1, "# / -- comments and quoted pseudo-calls must not create nodes")
	_expect(int((comment_analysis.get("summary", {}) as Dictionary).get("edges", 0)) == 0, "comments and quoted pseudo-calls must not create edges")

	var alias_analysis := _analyze([PRIMARY_PATH, ProjectSettings.globalize_path(PRIMARY_PATH)])
	_expect(int((alias_analysis.get("summary", {}) as Dictionary).get("files", 0)) == 1, "user:// and absolute aliases should be deduplicated")
	var invalid_analysis := _analyze([PRIMARY_PATH, FIXTURE_DIR + "/missing.txt"])
	_expect(not bool(invalid_analysis.get("ok", true)), "mixed valid/invalid inputs should report analysis failure")
	_expect(int((invalid_analysis.get("summary", {}) as Dictionary).get("files", 0)) == 1, "valid inputs should still be indexed when another input is invalid")
	var empty_analysis := _analyze([" "])
	_expect(not bool(empty_analysis.get("ok", true)) and int((empty_analysis.get("summary", {}) as Dictionary).get("files", -1)) == 0, "blank analysis paths must not expand to the project root")


func _test_flow_event_order() -> void:
	var analysis := _analyze([FLOW_PATH])
	var nodes: Array = analysis.get("nodes", [])
	_expect(nodes.size() == 2, "call-shaped strings must not create fake labels")
	var edges: Array = analysis.get("edges", [])
	_expect(edges.size() == 4, "only unqualified calls and branch-scoped destinations should create edges")
	if edges.size() == 4:
		_expect(str((edges[0] as Dictionary).get("source", "")) == "stat_order_first", "first same-block jump should stay attached to the first label")
		_expect(str((edges[0] as Dictionary).get("target", "")) == "stat_order_second", "first same-block jump target should resolve")
		_expect(str((edges[1] as Dictionary).get("kind", "")) == "jump_if" and str((edges[1] as Dictionary).get("target", "")) == "stat_order_second", "jump_if should parse a target after nested condition commas")
		_expect(str((edges[2] as Dictionary).get("kind", "")) == "branch" and str((edges[2] as Dictionary).get("target", "")) == "stat_order_second", "branch destinations should be collected only inside branch scopes")
		_expect(str((edges[3] as Dictionary).get("source", "")) == "stat_order_second", "last same-block jump should stay attached to the second label")
		_expect(str((edges[3] as Dictionary).get("target", "")) == "stat_order_first", "last same-block jump target should resolve")


func _test_source_locations() -> void:
	var analysis := _analyze([LOCATION_PATH])
	_expect(bool(analysis.get("ok", false)), "source-location fixture should analyze cleanly")
	var inline_node := _node_named(analysis.get("nodes", []), "stat_inline")
	var after_node := _node_named(analysis.get("nodes", []), "stat_after_blanks")
	_expect(int(inline_node.get("line", 0)) == 1 and int(inline_node.get("column", 0)) == 5, "inline block events should retain their physical source column")
	_expect(int(after_node.get("line", 0)) == 7 and int(after_node.get("column", 0)) == 3, "leading blank lines and indentation should retain the label source position")
	var edges: Array = analysis.get("edges", [])
	_expect(edges.size() == 1, "source-location fixture should contain one edge")
	if edges.size() == 1:
		var edge: Dictionary = edges[0]
		_expect(int(edge.get("line", 0)) == 4 and int(edge.get("column", 0)) == 3, "leading blank lines and indentation should retain the jump source position")


func _test_pre_label_text() -> void:
	var analysis := _analyze([ORPHAN_PATH])
	_expect(not bool(analysis.get("ok", true)), "dialogue before label() should fail analysis")
	var summary: Dictionary = analysis.get("summary", {})
	_expect(int(summary.get("dialogues", 0)) == 1 and int(summary.get("runtime_entries", 0)) == 1, "pre-label text should not become a runtime entry")
	var entries: Array = analysis.get("entries", [])
	_expect(entries.size() == 1 and int((entries[0] as Dictionary).get("line", 0)) == 5, "only post-label dialogue should remain in the IR")
	_expect(_analysis_error_contains(analysis, "dialogue text appears before any label()"), "pre-label analysis failure should explain the ScriptLoader rule")


func _test_silent_lazy_semantics() -> void:
	var analysis := _analyze([SILENT_PATH])
	_expect(bool(analysis.get("ok", false)), "silent-lazy fixture should analyze cleanly")
	var summary: Dictionary = analysis.get("summary", {})
	_expect(int(summary.get("dialogues", 0)) == 1 and int(summary.get("silent_entries", 0)) == 3 and int(summary.get("runtime_entries", 0)) == 4, "silent-lazy runtime entry counts should mirror ScriptLoader")
	var silent_entries: Array = analysis.get("silent_entries", [])
	_expect(silent_entries.size() == 3, "staged, repeated-default, and trailing lazy blocks should each flush predictably")
	if silent_entries.size() == 3:
		var first_blocks: Array = (silent_entries[0] as Dictionary).get("lazy_blocks", [])
		var second_blocks: Array = (silent_entries[1] as Dictionary).get("lazy_blocks", [])
		var third_blocks: Array = (silent_entries[2] as Dictionary).get("lazy_blocks", [])
		_expect(first_blocks.size() == 2 and str((first_blocks[0] as Dictionary).get("stage", "")) == "before_checkpoint" and str((first_blocks[1] as Dictionary).get("stage", "")) == "after_dialogue", "eager flush should preserve both staged lazy blocks in source order")
		_expect(second_blocks.size() == 1 and int((second_blocks[0] as Dictionary).get("line", 0)) == 13, "a repeated default lazy block should flush the older default as silent")
		_expect(third_blocks.size() == 1 and int((third_blocks[0] as Dictionary).get("line", 0)) == 20, "a trailing lazy block should flush at end of file")
		_expect(str((silent_entries[2] as Dictionary).get("entry_id", "")) == SILENT_PATH + "#entry:000004", "silent and visible runtime entries should share one per-file ordinal")
	var entries: Array = analysis.get("entries", [])
	if entries.size() == 1:
		var attached: Array = (entries[0] as Dictionary).get("lazy_blocks", [])
		_expect(attached.size() == 1 and int((attached[0] as Dictionary).get("line", 0)) == 16, "the newer repeated default should attach to the following dialogue")
		_expect(str((entries[0] as Dictionary).get("entry_id", "")) == SILENT_PATH + "#entry:000003", "visible entries should retain their runtime ordinal across silent flushes")
	var edges: Array = analysis.get("edges", [])
	_expect(edges.size() == 1, "the trailing silent lazy block should expose its dynamic transition")
	if edges.size() == 1 and silent_entries.size() == 3:
		var edge: Dictionary = edges[0]
		_expect(str(edge.get("phase", "")) == "lazy" and str(edge.get("stage", "")) == "default", "silent lazy transitions should retain phase and stage")
		_expect(str(edge.get("entry_id", "")) == str((silent_entries[2] as Dictionary).get("entry_id", "")), "silent lazy transitions should attach to the silent runtime entry")
		_expect(str(edge.get("target_kind", "")) == "dynamic" and str(edge.get("target_expression", "")) == "dynamic_silent_target", "silent lazy dynamic destinations should retain their expression")
	_expect(_runtime_entry_ids_are_valid(analysis), "all silent-lazy runtime entries should have unique stable IDs")


func _test_ir_v2_flow_metadata() -> void:
	var analysis := _analyze([METADATA_PATH])
	var repeated := _analyze([METADATA_PATH])
	_expect(bool(analysis.get("ok", false)), "IR v2 metadata fixture should analyze cleanly: %s" % JSON.stringify(analysis.get("errors", [])))
	_expect(int(analysis.get("schema_version", 0)) == 2, "metadata fixture should use analysis schema version 2")
	_expect(_runtime_entry_ids_are_valid(analysis), "every text and silent entry should have a unique non-empty entry_id")
	_expect(_runtime_entry_id_snapshot(analysis) == _runtime_entry_id_snapshot(repeated), "entry IDs should be stable across repeated analysis")

	var entries: Array = analysis.get("entries", [])
	var lazy_literal_entry := _entry_at(entries, METADATA_PATH, 15)
	var lazy_dynamic_entry := _entry_at(entries, METADATA_PATH, 19)
	_expect(str(lazy_literal_entry.get("entry_id", "")) == METADATA_PATH + "#entry:000001", "the first runtime entry should receive ordinal 1")
	_expect(str(lazy_dynamic_entry.get("entry_id", "")) == METADATA_PATH + "#entry:000002", "the second runtime entry should receive ordinal 2")

	var edges: Array = analysis.get("edges", [])
	_expect(edges.size() == 6, "metadata fixture should expose two branches, two eager jumps, and two lazy jumps")
	var edge_fields := [
		"path", "line", "column", "source", "target", "raw_target",
		"target_kind", "target_expression", "kind", "phase", "stage",
		"entry_id", "group_id", "option_index", "text", "mode",
		"condition_raw", "condition_normalized", "image_raw",
	]
	for raw_edge in edges:
		var edge: Dictionary = raw_edge
		for field in edge_fields:
			_expect(edge.has(field), "IR v2 edge contract should include '%s'" % field)

	var inherited_branch := _edge_matching(edges, {"kind": "branch", "option_index": 0})
	var dynamic_branch := _edge_matching(edges, {"kind": "branch", "option_index": 1})
	_expect(str(inherited_branch.get("target_kind", "")) == "literal" and str(inherited_branch.get("target", "")) == "meta_end", "literal branch targets should resolve normally")
	_expect(str(inherited_branch.get("raw_target", "")) == "meta_end" and str(inherited_branch.get("target_expression", "")) == "", "literal branch targets should retain raw labels without a dynamic expression")
	_expect(str(dynamic_branch.get("target_kind", "")) == "dynamic" and str(dynamic_branch.get("target", "")) == "", "dynamic branch targets should not invent a resolved label")
	_expect(str(dynamic_branch.get("raw_target", "")) == "" and str(dynamic_branch.get("target_expression", "")) == "dynamic_branch", "dynamic branch expressions should be retained verbatim")
	_expect(not str(inherited_branch.get("group_id", "")).is_empty() and inherited_branch.get("group_id") == dynamic_branch.get("group_id"), "options from one branch call should share a stable group_id")
	_expect(str(inherited_branch.get("text", "")) == "Inherited" and str(inherited_branch.get("mode", "")) == "show", "the first branch should retain text and inherited mode")
	_expect(str(inherited_branch.get("condition_raw", "")) == "v_default" and str(inherited_branch.get("condition_normalized", "")) == "get_nova_variable(\"v_default\", false)", "inherited branch conditions should retain raw and normalized forms")
	_expect(str(inherited_branch.get("image_raw", "")) == "default_choice", "the first branch should inherit its image attribute")
	_expect(str(dynamic_branch.get("text", "")) == "Dynamic mode = prose" and str(dynamic_branch.get("mode", "")) == "jump", "explicit branch mode should win even when the text contains a mode-shaped string")
	_expect(str(dynamic_branch.get("condition_raw", "")) == "v_dynamic" and str(dynamic_branch.get("condition_normalized", "")) == "get_nova_variable(\"v_dynamic\", false)", "explicit branch conditions should retain raw and normalized forms")
	_expect(str(dynamic_branch.get("image_raw", "")) == "dyn", "explicit branch images should override block attributes")

	var eager_if := _edge_matching(edges, {"kind": "jump_if", "phase": "eager"})
	var eager_fallback := _edge_matching(edges, {"kind": "jump_to", "phase": "eager"})
	_expect(str(eager_if.get("target_kind", "")) == "dynamic" and str(eager_if.get("target_expression", "")) == "dynamic_jump", "eager jump_if should retain a dynamic destination")
	_expect(str(eager_if.get("condition_raw", "")) == "check_pair(1, 2)" and str(eager_if.get("condition_normalized", "")) == "check_pair(1, 2)", "jump_if should retain nested-comma conditions in raw and normalized form")
	_expect(str(eager_fallback.get("target_expression", "")) == "dynamic_fallback", "jump_to shorthand should retain a dynamic destination")
	for eager_edge in [inherited_branch, dynamic_branch, eager_if, eager_fallback]:
		_expect(str(eager_edge.get("phase", "")) == "eager" and str(eager_edge.get("stage", "")) == "" and str(eager_edge.get("entry_id", "")) == "", "eager transitions should not attach to runtime entries")

	var lazy_literal := _edge_matching(edges, {"kind": "jump_if", "phase": "lazy"})
	var lazy_dynamic := _edge_matching(edges, {"kind": "jump_to", "phase": "lazy"})
	_expect(str(lazy_literal.get("target_kind", "")) == "literal" and str(lazy_literal.get("target", "")) == "meta_end" and str(lazy_literal.get("target_expression", "")) == "", "lazy literal targets should resolve normally")
	_expect(str(lazy_literal.get("stage", "")) == "default" and str(lazy_literal.get("entry_id", "")) == str(lazy_literal_entry.get("entry_id", "")), "lazy literal transitions should attach to the following text entry")
	_expect(str(lazy_dynamic.get("target_kind", "")) == "dynamic" and str(lazy_dynamic.get("target", "")) == "" and str(lazy_dynamic.get("target_expression", "")) == "dynamic_lazy_target", "lazy dynamic targets should retain their expression")
	_expect(str(lazy_dynamic.get("stage", "")) == "default" and str(lazy_dynamic.get("entry_id", "")) == str(lazy_dynamic_entry.get("entry_id", "")), "lazy dynamic transitions should attach to the following text entry")

	var end_node := _node_named(analysis.get("nodes", []), "meta_end")
	_expect(str(end_node.get("end_name", "")) == "named-ending", "named is_end shorthand should populate node.end_name and a later is_end() should not clear it")

	var namespace_analysis := _analyze([LAZY_NAMESPACE_A_PATH, LAZY_NAMESPACE_B_PATH])
	var namespace_edges: Array = namespace_analysis.get("edges", [])
	_expect(namespace_edges.size() == 1, "cross-file continuation fixture should expose one lazy transition")
	if namespace_edges.size() == 1:
		_expect(str((namespace_edges[0] as Dictionary).get("target", "")) == "z_extension:target", "lazy local targets should resolve against the block file rather than the first definition's namespace")


func _test_context_labels() -> void:
	var options := {"context_paths": [CONTEXT_A_PATH, CONTEXT_B_PATH, CONTEXT_A_PATH]}
	var analysis := _analyze_with_options([CONTEXT_SELECTED_PATH], options)
	var repeated := _analyze_with_options([CONTEXT_SELECTED_PATH], options)
	_expect(bool(analysis.get("ok", false)), "explicit context paths should be indexed without executing or validating context code")
	var summary: Dictionary = analysis.get("summary", {})
	_expect(int(summary.get("files", 0)) == 1 and int(summary.get("nodes", 0)) == 1 and int(summary.get("dialogues", 0)) == 1, "context labels should stay out of selected files, nodes, and dialogue counts")
	var context_labels: Array = analysis.get("context_labels", [])
	_expect(context_labels.size() == 2, "repeatable context paths should deduplicate files and selected label definitions")
	_expect(JSON.stringify(context_labels) == JSON.stringify(repeated.get("context_labels", [])), "context label catalogs should be stable across repeated analysis")
	var external := _node_named(context_labels, "context_external")
	var local := _node_named(context_labels, "z_context:catalog")
	_expect(not external.is_empty() and str(external.get("path", "")) == CONTEXT_A_PATH and str(external.get("display_name", "")) == "External", "context catalogs should retain stable literal label metadata")
	_expect(not local.is_empty() and bool(local.get("local", false)) and str(local.get("namespace", "")) == "z_context", "context catalogs should resolve local labels in their own namespace")
	_expect(_node_named(context_labels, "context_selected").is_empty(), "selected node definitions must be excluded from context_labels")
	_expect((_analyze([CONTEXT_SELECTED_PATH]).get("context_labels", []) as Array).is_empty(), "auto context should default to false")

	var automatic := _analyze_with_options(["res://resources/scenarios/ch2.txt"], {"auto_context": true})
	var automatic_summary: Dictionary = automatic.get("summary", {})
	var automatic_labels: Array = automatic.get("context_labels", [])
	_expect(bool(automatic.get("ok", false)) and int(automatic_summary.get("files", 0)) == 1 and int(automatic_summary.get("nodes", 0)) == 1, "auto context should not change the selected analysis inventory")
	_expect(not _node_named(automatic_labels, "ch3").is_empty() and not _node_named(automatic_labels, "ch4").is_empty(), "auto context should index remaining default scenario labels")
	_expect(_node_named(automatic_labels, "ch2").is_empty(), "auto context should exclude the selected default scenario definition")


func _test_statistics_and_ordering() -> void:
	var report := _statistics(_analyze([PRIMARY_PATH, SECONDARY_PATH]), 3)
	var summary: Dictionary = report.get("summary", {})
	_expect(int(report.get("schema_version", 0)) == 1, "statistics JSON schema should be version 1")
	_expect(str(report.get("normalization", "")) == "visible_v1", "statistics should identify the normalization contract")
	_expect(int(summary.get("dialogues", 0)) == 6, "statistics should count all text entries once")
	_expect(int(summary.get("spoken", 0)) == 4 and int(summary.get("narration", 0)) == 2, "speaker/narration split should mirror ScriptLoader")
	_expect(int(summary.get("speakers", 0)) == 3, "statistics should group by canonical speaker")
	_expect(int(summary.get("total_characters", 0)) == 33, "normalized character total should be stable")
	_expect(int(summary.get("min", -1)) == 0 and int(summary.get("max", -1)) == 14, "min/max should include empty normalized dialogue")
	_expect(int(summary.get("median", -1)) == 4 and int(summary.get("p90", -1)) == 14, "percentiles should use nearest-rank")

	var expected_histogram := [
		{"length": 0, "count": 1},
		{"length": 1, "count": 1},
		{"length": 4, "count": 2},
		{"length": 10, "count": 1},
		{"length": 14, "count": 1},
	]
	_expect(JSON.stringify(report.get("length_histogram", [])) == JSON.stringify(expected_histogram), "length histogram should be numeric and sorted")

	var by_file: Array = report.get("by_file", [])
	_expect(by_file.size() == 2 and str((by_file[0] as Dictionary).get("path", "")) == SECONDARY_PATH, "by_file should sort by stable path")
	var by_speaker: Array = report.get("by_speaker", [])
	var speaker_names: Array[String] = []
	for raw_speaker in by_speaker:
		speaker_names.append(str((raw_speaker as Dictionary).get("canonical_speaker", "")))
	_expect(speaker_names == ["Alias", "Canonical", "Zed"], "by_speaker should sort by canonical speaker")

	var longest: Array = report.get("longest", [])
	_expect(longest.size() == 3, "--top should bound longest entries")
	if longest.size() == 3:
		_expect(int((longest[0] as Dictionary).get("length", 0)) == 14, "longest entries should sort by descending length")
		_expect(int((longest[1] as Dictionary).get("length", 0)) == 10, "second longest entry should be stable")
		_expect(str((longest[2] as Dictionary).get("path", "")) == SECONDARY_PATH, "equal-length longest entries should use path/line tie breakers")


func _test_default_corpus_baseline() -> void:
	var report := _statistics(_analyze([]), 0)
	var summary: Dictionary = report.get("summary", {})
	var expected := {
		"files": 28,
		"blocks": 360,
		"eager_blocks": 106,
		"lazy_blocks": 254,
		"nodes": 53,
		"local_nodes": 23,
		"dialogues": 731,
		"silent_entries": 1,
		"runtime_entries": 732,
		"spoken": 111,
		"narration": 620,
		"speakers": 8,
		"display_speakers": 9,
		"dynamic_speaker_entries": 1,
		"total_characters": 15434,
		"empty": 2,
		"min": 0,
		"max": 179,
		"median": 14,
		"p90": 47,
		"p95": 62,
		"starts": 9,
		"unlocked_starts": 2,
		"debug_nodes": 18,
		"jumps": 23,
		"branch_options": 24,
		"transitions": 47,
	}
	for key in expected.keys():
		_expect(summary.get(key) == expected[key], "default corpus %s should be %s, got %s" % [key, expected[key], summary.get(key)])
	_expect(summary.get("node_types", {}) == {"normal": 23, "chapter": 9, "end": 21}, "default corpus node type totals should remain stable")


func _test_godot_cli() -> void:
	var valid := _run_godot_cli(["--format", "json", "--top", "2", PRIMARY_PATH, SECONDARY_PATH])
	_expect(int(valid.get("exit_code", -1)) == 0, "Godot statistics CLI should exit 0; output=%s" % valid.get("output", ""))
	var report := _parse_full_json_report(str(valid.get("output", "")))
	_expect(int(report.get("schema_version", 0)) == 1, "Godot CLI should emit schema-versioned JSON")
	_expect((report.get("longest", []) as Array).size() == 2, "Godot CLI should forward --top")

	var invalid := _run_godot_cli(["--definitely-invalid-option"])
	_expect(int(invalid.get("exit_code", -1)) == 2, "invalid Godot CLI usage should exit 2")
	var empty_path := _run_godot_cli(["--path", " "])
	_expect(int(empty_path.get("exit_code", -1)) == 2, "empty Godot CLI paths should exit 2")


func _test_python_cli() -> void:
	var python := _find_python()
	_expect(not python.is_empty(), "a Python interpreter is required to smoke-test the public CLI")
	if python.is_empty():
		return
	var script_path := ProjectSettings.globalize_path("res://scripts/tools/scenario_stat.py")
	var project_path := ProjectSettings.globalize_path("res://")
	var output: Array = []
	var args := PackedStringArray([
		script_path,
		"--godot", OS.get_executable_path(),
		"--project", project_path,
		"--format", "json",
		"--top", "1",
		PRIMARY_PATH,
		SECONDARY_PATH,
	])
	var exit_code := OS.execute(python, args, output, true)
	var rendered := _join_output(output)
	_expect(exit_code == 0, "public Python CLI should exit 0; output=%s" % rendered)
	var report := _parse_full_json_report(rendered)
	_expect(int(report.get("schema_version", 0)) == 1, "public Python CLI should emit JSON")
	_expect((report.get("longest", []) as Array).size() == 1, "public Python CLI should preserve --top")

	output.clear()
	var bad_exit := OS.execute(python, PackedStringArray([
		script_path,
		"--project", project_path,
		"--godot", "definitely_missing_godot_for_stat_smoke",
		PRIMARY_PATH,
	]), output, true)
	_expect(bad_exit == 2, "public Python CLI infrastructure failures should exit 2")

	output.clear()
	var empty_exit := OS.execute(python, PackedStringArray([
		script_path,
		"--godot", OS.get_executable_path(),
		"--project", project_path,
		" ",
	]), output, true)
	_expect(empty_exit == 2, "public Python CLI should reject empty scenario paths")


func _analyze(paths: Array) -> Dictionary:
	return ScenarioAnalysisScript.new().analyze_paths(paths)


func _analyze_with_options(paths: Array, options: Dictionary) -> Dictionary:
	return ScenarioAnalysisScript.new().analyze_paths(paths, options)


func _statistics(analysis: Dictionary, top: int) -> Dictionary:
	return ScenarioStatisticsScript.new().build(analysis, top)


func _entry_at(entries: Array, path: String, line: int) -> Dictionary:
	for raw_entry in entries:
		var entry: Dictionary = raw_entry
		if str(entry.get("path", "")) == path and int(entry.get("line", 0)) == line:
			return entry
	return {}


func _node_named(nodes: Array, name: String) -> Dictionary:
	for raw_node in nodes:
		var node: Dictionary = raw_node
		if str(node.get("id", "")) == name:
			return node
	return {}


func _edge_matching(edges: Array, criteria: Dictionary) -> Dictionary:
	for raw_edge in edges:
		var edge: Dictionary = raw_edge
		var matches := true
		for key in criteria.keys():
			if edge.get(key) != criteria[key]:
				matches = false
				break
		if matches:
			return edge
	return {}


func _runtime_entry_ids_are_valid(analysis: Dictionary) -> bool:
	var seen: Dictionary = {}
	for collection_name in ["entries", "silent_entries"]:
		for raw_entry in analysis.get(collection_name, []):
			var entry: Dictionary = raw_entry
			var entry_id := str(entry.get("entry_id", ""))
			if entry_id.is_empty() or seen.has(entry_id):
				return false
			seen[entry_id] = true
	return true


func _runtime_entry_id_snapshot(analysis: Dictionary) -> Dictionary:
	var out := {"entries": [], "silent_entries": []}
	for collection_name in out.keys():
		var ids: Array = out[collection_name]
		for raw_entry in analysis.get(collection_name, []):
			ids.append(str((raw_entry as Dictionary).get("entry_id", "")))
	return out


func _analysis_error_contains(analysis: Dictionary, needle: String) -> bool:
	for raw_error in analysis.get("errors", []):
		if raw_error is Dictionary and str((raw_error as Dictionary).get("message", "")).contains(needle):
			return true
	return false


func _write_fixture(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write fixture %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.store_string(source)
	file.close()


func _run_godot_cli(user_args: Array[String]) -> Dictionary:
	var args := PackedStringArray([
		"--headless",
		"--no-header",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		"res://scripts/tools/scenario_stat.gd",
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
