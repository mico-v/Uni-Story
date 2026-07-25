@tool
extends EditorInspectorPlugin

## Inspector plugin that adds a "Preview Pose" button to StandingProfile resources.
## When clicked, it opens the Standing Editor bottom panel with live preview.


const StandingProfileScript = preload("res://scripts/runtime/standing_profile.gd")

var _editor_plugin: EditorPlugin


func _init(editor_plugin: EditorPlugin = null) -> void:
	_editor_plugin = editor_plugin


func _can_handle(object: Object) -> bool:
	if object is Resource:
		var script := object.get_script()
		if script:
			return script.resource_path == "res://scripts/runtime/standing_profile.gd"
	return false


func _parse_begin(object: Object) -> void:
	if not (object is Resource):
		return
	# Add a custom button at the top of the inspector
	var preview_btn := Button.new()
	preview_btn.text = "Open Standing Editor"
	preview_btn.tooltip_text = "Open the visual standing sprite editor for this profile"
	preview_btn.pressed.connect(func():
		if _editor_plugin and is_instance_valid(_editor_plugin):
			_editor_plugin.get_editor_interface().edit_resource(object)
			_editor_plugin._edit(object)
	)

	add_custom_control(preview_btn)
