@tool
extends EditorPlugin

## EditorPlugin for visual StandingProfile editing.
##
## Adds:
##  - A bottom panel for live standing-sprite preview
##  - Inspector plugin for StandingProfile resources
##  - Drag-to-reorder layer ordering
##  - Visual offset/scale adjustment handles


const StandingEditPanel = preload("res://addons/standing_editor/standing_edit_panel.gd")
const StandingInspectorPlugin = preload("res://addons/standing_editor/standing_inspector_plugin.gd")

var _bottom_panel: StandingEditPanel
var _inspector_plugin: StandingInspectorPlugin


func _enter_tree() -> void:
	# Inspector plugin for StandingProfile
	_inspector_plugin = StandingInspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)

	# Bottom panel for visual preview
	_bottom_panel = StandingEditPanel.new()
	_bottom_panel.plugin = self
	add_control_to_bottom_panel(_bottom_panel, "Standing Editor")
	_bottom_panel.hide()  # Hidden by default, shown when a StandingProfile is selected


func _exit_tree() -> void:
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null

	if _bottom_panel:
		remove_control_from_bottom_panel(_bottom_panel)
		_bottom_panel.queue_free()
		_bottom_panel = null


func _handles(object: Object) -> bool:
	return object is Resource and object.get_script() != null and _is_standing_profile(object.get_script())


func _edit(object: Object) -> void:
	if _is_standing_profile(object.get_script()) if object is Resource else false:
		_bottom_panel.edit_profile(object)
		make_bottom_panel_item_visible(_bottom_panel)


func _make_visible(visible: bool) -> void:
	if _bottom_panel:
		if visible:
			_bottom_panel.show()
		else:
			_bottom_panel.hide()


func _is_standing_profile(script: Script) -> bool:
	if script == null:
		return false
	return script.resource_path == "res://scripts/runtime/standing_profile.gd"
