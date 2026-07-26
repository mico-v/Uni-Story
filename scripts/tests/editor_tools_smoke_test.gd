extends SceneTree

## Smoke test for Phase 17 Editor tools.
##
## Validates that all new Resource types, Inspector plugins,
## Editor Panels, and Standing Editor enhancements are correctly defined.
##
## Run in headless mode: godot --headless --path . --script res://scripts/tests/editor_tools_smoke_test.gd


# ── Test state ──

var _passes := 0
var _fails := 0
var _test_name := ""


func _init() -> void:
	print("=".repeat(60))
	print("Phase 17 Editor Tools Smoke Test")
	print("=".repeat(60))

	# 17.1 + 17.2: Resource types
	_test_resource_types()

	# 17.3: Build hooks
	_test_build_hooks()

	# 17.4: Standing editor enhancement checks
	_test_standing_editor_enhancements()

	# 17.5: Inspector plugins and panels (structural checks)
	_test_inspector_plugins()

	print("")
	print("-".repeat(60))
	print("Results: %d passed, %d failed, %d total" % [_passes, _fails, _passes + _fails])
	print("-".repeat(60))

	if _fails > 0:
		quit(1)
	else:
		quit(0)


func _test(msg: String, condition: bool) -> void:
	_test_name = msg
	if condition:
		_passes += 1
		print("  PASS  %s" % msg)
	else:
		_fails += 1
		printerr("  FAIL  %s" % msg)


func _has_prop(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if p["name"] == prop_name:
			return true
	return false


# ── 17.1 + 17.2: Resource Types ──

func _test_resource_types() -> void:
	print("\n── Resource Types ──")

	var ie := ImageEntry.new()
	_test("ImageEntry class exists", ie != null)
	_test("ImageEntry has display_name", ie.get("display_name") != null)
	_test("ImageEntry has thumbnail", _has_prop(ie, "thumbnail"))
	_test("ImageEntry has full_image", _has_prop(ie, "full_image"))
	_test("ImageEntry has category", ie.get("category") != null)
	_test("ImageEntry is_valid returns false for empty", not ie.is_valid())
	ie.display_name = "test"
	_test("ImageEntry is_valid after setting name", not ie.is_valid())  # still needs image

	var ig := ImageGroup.new()
	_test("ImageGroup class exists", ig != null)
	_test("ImageGroup has group_name", ig.get("group_name") != null)
	_test("ImageGroup has entries array", ig.get("entries") != null)
	_test("ImageGroup entry_count zero", ig.entry_count() == 0)
	_test("ImageGroup is_valid returns false for empty", not ig.is_valid())
	ig.group_name = "Test"
	_test("ImageGroup is_valid after setting name", ig.is_valid())

	var igl := ImageGroupList.new()
	_test("ImageGroupList class exists", igl != null)
	_test("ImageGroupList has groups array", igl.get("groups") != null)
	_test("ImageGroupList total_entries zero", igl.total_entries() == 0)
	_test("ImageGroupList.find_entry returns null for missing", igl.find_entry("nonexistent") == null)

	var me := MusicEntry.new()
	_test("MusicEntry class exists", me != null)
	_test("MusicEntry has display_name", me.get("display_name") != null)
	_test("MusicEntry has composer", me.get("composer") != null)
	_test("MusicEntry has audio_stream", _has_prop(me, "audio_stream"))
	_test("MusicEntry has cover_image", _has_prop(me, "cover_image"))
	_test("MusicEntry has loop_start", me.get("loop_start") != null)
	_test("MusicEntry has loop_end", me.get("loop_end") != null)
	_test("MusicEntry is_valid returns false for empty", not me.is_valid())

	var mel := MusicEntryList.new()
	_test("MusicEntryList class exists", mel != null)
	_test("MusicEntryList has entries array", mel.get("entries") != null)
	_test("MusicEntryList total_tracks zero", mel.total_tracks() == 0)
	_test("MusicEntryList.find_entry returns null for missing", mel.find_entry("none") == null)


# ── 17.3: Build Hooks ──

func _test_build_hooks() -> void:
	print("\n── Build Hooks ──")

	var hooks := BuildHooks.new()
	_test("BuildHooks class exists", hooks != null)

	var presets := BuildHooks.validate_export_presets()
	_test("BuildHooks.validate_export_presets returns dict", presets is Dictionary)
	_test("BuildHooks.validate_export_presets has Windows", presets.has("Windows"))
	_test("BuildHooks.validate_export_presets has Linux", presets.has("Linux"))
	_test("BuildHooks.validate_export_presets has Android", presets.has("Android"))

	var lint_result := BuildHooks.run_lint()
	_test("BuildHooks.run_lint returns dict", lint_result is Dictionary)
	_test("BuildHooks.run_lint has exit_code", lint_result.has("exit_code"))
	_test("BuildHooks.run_lint has output", lint_result.has("output"))

	var test_result := BuildHooks.run_tests()
	_test("BuildHooks.run_tests returns dict", test_result is Dictionary)
	_test("BuildHooks.run_tests has exit_code", test_result.has("exit_code"))


# ── 17.4: Standing Editor Enhancement Checks ──

func _test_standing_editor_enhancements() -> void:
	print("\n── Standing Editor Enhancements ──")

	# Check that the enhanced standing_edit_panel.gd exists and has new features
	var panel_path := "res://addons/standing_editor/standing_edit_panel.gd"
	_test("standing_edit_panel.gd exists", ResourceLoader.exists(panel_path))

	var script := load(panel_path)
	_test("standing_edit_panel.gd loads", script != null)

	if script:
		var source: String = (script as GDScript).source_code
		_test("Has _move_layer_up", "_move_layer_up" in source)
		_test("Has _move_layer_down", "_move_layer_down" in source)
		_test("Has _toggle_dual_preview", "_toggle_dual_preview" in source)
		_test("Has _refresh_dual_preview", "_refresh_dual_preview" in source)
		_test("Has _toggle_cycle_poses", "_toggle_cycle_poses" in source)
		_test("Has _on_cycle_tick", "_on_cycle_tick" in source)
		_test("Has _dual_preview_texture_rect", "_dual_preview_texture_rect" in source)
		_test("Has _cycle_poses_timer", "_cycle_poses_timer" in source)

	# Check standing_editor_plugin exists
	var plugin_path := "res://addons/standing_editor/standing_editor_plugin.gd"
	_test("standing_editor_plugin.gd exists", ResourceLoader.exists(plugin_path))

	# Check standing_inspector_plugin exists
	var inspector_path := "res://addons/standing_editor/standing_inspector_plugin.gd"
	_test("standing_inspector_plugin.gd exists", ResourceLoader.exists(inspector_path))


# ── 17.5: Inspector Plugins and Editor Panels ──

func _test_inspector_plugins() -> void:
	print("\n── Inspector Plugins & Editor Panels ──")

	# Build panel
	_test("build_panel.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/build_panel.gd"))
	_test("build_hooks.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/build_hooks.gd"))

	# Image gallery
	_test("image_group_inspector.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/image_group_inspector.gd"))
	_test("image_group_list_panel.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/image_group_list_panel.gd"))

	# Music gallery
	_test("music_entry_inspector.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/music_entry_inspector.gd"))
	_test("music_entry_list_panel.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/music_entry_list_panel.gd"))

	# UI transition
	_test("composite_ui_view_transition_inspector.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/composite_ui_view_transition_inspector.gd"))

	# Simple entry list
	_test("simple_entry_list_inspector.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/simple_entry_list_inspector.gd"))

	# Main editor plugin
	_test("uni_story_editor_plugin.gd exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/uni_story_editor_plugin.gd"))

	# plugin.cfg
	_test("plugin.cfg exists", ResourceLoader.exists("res://addons/uni_story_editor_suite/plugin.cfg"))

	# Resource files exist
	_test("image_entry.gd exists", ResourceLoader.exists("res://scripts/resources/image_entry.gd"))
	_test("image_group.gd exists", ResourceLoader.exists("res://scripts/resources/image_group.gd"))
	_test("image_group_list.gd exists", ResourceLoader.exists("res://scripts/resources/image_group_list.gd"))
	_test("music_entry.gd exists", ResourceLoader.exists("res://scripts/resources/music_entry.gd"))
	_test("music_entry_list.gd exists", ResourceLoader.exists("res://scripts/resources/music_entry_list.gd"))
