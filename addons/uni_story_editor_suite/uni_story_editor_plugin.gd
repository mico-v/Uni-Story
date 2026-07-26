@tool
extends EditorPlugin

## Main editor plugin for the Uni-Story Editor Suite.
##
## Provides a toolbar menu ("NovaMenu") with quick access to:
##   - Clear Save / Clear Config
##   - Run Scenario Lint
##   - Run Scenario Stat
##
## Also registers all EditorSuite child plugins:
##   - BuildPanel
##   - BuildHooks
##   - Image Gallery editors
##   - Music Gallery editors
##   - UI Transition Inspector


const BuildPanelClass = preload("res://addons/uni_story_editor_suite/build_panel.gd")
const ImageGroupInspectorClass = preload("res://addons/uni_story_editor_suite/image_group_inspector.gd")
const ImageGroupListPanelClass = preload("res://addons/uni_story_editor_suite/image_group_list_panel.gd")
const MusicEntryInspectorClass = preload("res://addons/uni_story_editor_suite/music_entry_inspector.gd")
const MusicEntryListPanelClass = preload("res://addons/uni_story_editor_suite/music_entry_list_panel.gd")
const CompositeUIViewTransitionInspectorClass = preload("res://addons/uni_story_editor_suite/composite_ui_view_transition_inspector.gd")

var _build_panel: Control
var _image_group_list_panel: Control
var _music_entry_list_panel: Control
var _transition_inspector: Control
var _inspector_plugins: Array[EditorInspectorPlugin] = []
var _toolbar_button: MenuButton


func _enter_tree() -> void:
	# Inspector plugins
	_add_inspector_plugin(ImageGroupInspectorClass.new())
	_add_inspector_plugin(MusicEntryInspectorClass.new())
	_add_inspector_plugin(CompositeUIViewTransitionInspectorClass.new())

	# Bottom panels
	_build_panel = BuildPanelClass.new()
	add_control_to_bottom_panel(_build_panel, "Build")

	_image_group_list_panel = ImageGroupListPanelClass.new()
	add_control_to_bottom_panel(_image_group_list_panel, "Image Gallery")

	_music_entry_list_panel = MusicEntryListPanelClass.new()
	_music_entry_list_panel.plugin = self
	add_control_to_bottom_panel(_music_entry_list_panel, "Music Gallery")

	# Toolbar: NovaMenu
	_toolbar_button = MenuButton.new()
	_toolbar_button.text = "UniStory"
	_toolbar_button.tooltip_text = "Uni-Story editor tools and shortcuts"
	_toolbar_button.switch_on_hover = true
	var popup := _toolbar_button.get_popup()
	popup.add_item("Clear Save", 100)
	popup.add_item("Clear Config", 101)
	popup.add_separator()
	popup.add_item("Run Scenario Lint", 200)
	popup.add_item("Run Scenario Stat", 201)
	popup.id_pressed.connect(_on_toolbar_action)
	add_control_to_container(CONTAINER_TOOLBAR, _toolbar_button)


func _exit_tree() -> void:
	# Remove inspector plugins
	for plugin in _inspector_plugins:
		remove_inspector_plugin(plugin)
	_inspector_plugins.clear()

	# Remove bottom panels
	if _build_panel:
		remove_control_from_bottom_panel(_build_panel)
		_build_panel.queue_free()
		_build_panel = null

	if _image_group_list_panel:
		remove_control_from_bottom_panel(_image_group_list_panel)
		_image_group_list_panel.queue_free()
		_image_group_list_panel = null

	if _music_entry_list_panel:
		remove_control_from_bottom_panel(_music_entry_list_panel)
		_music_entry_list_panel.queue_free()
		_music_entry_list_panel = null

	# Remove toolbar button
	if _toolbar_button:
		remove_control_from_container(CONTAINER_TOOLBAR, _toolbar_button)
		_toolbar_button.queue_free()
		_toolbar_button = null


func _add_inspector_plugin(plugin: EditorInspectorPlugin) -> void:
	_inspector_plugins.append(plugin)
	add_inspector_plugin(plugin)


func _on_toolbar_action(id: int) -> void:
	match id:
		100:
			_clear_save()
		101:
			_clear_config()
		200:
			_run_lint()
		201:
			_run_stat()


func _clear_save() -> void:
	var dir := DirAccess.open("user://saves/")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[UniStory] Cleared all save files in user://saves/")


func _clear_config() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".cfg"):
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	print("[UniStory] Cleared all .cfg files in user://")


func _run_lint() -> void:
	var output: Array = []
	var code := OS.execute("python3", ["scripts/tools/scenario_lint.py"], output, true)
	if code == 0:
		print("[UniStory] Scenario lint passed.")
	else:
		print("[UniStory] Scenario lint returned code %d" % code)
		for line in output:
			print(line)


func _run_stat() -> void:
	var output: Array = []
	var code := OS.execute("python3", ["scripts/tools/scenario_stat.py"], output, true)
	print("[UniStory] Scenario stat (code %d):" % code)
	for line in output:
		print(line)
