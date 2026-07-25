@tool
extends EditorPlugin

## Editor tool for viewing, parsing, and debugging save files.
##
## Provides:
##   - List all save slots with metadata
##   - View full JSON content with syntax-highlighted folding
##   - Display bookmark metadata (chapter, time, thumbnail)
##   - Display checkpoint state summary
##   - Export save data as formatted JSON
##
## Usage: Enable plugin, then open from bottom panel "Save Viewer".


const SaveViewerPanel := preload("res://scripts/editor/save_viewer_panel.gd")

var _panel: SaveViewerPanel


func _enter_tree() -> void:
	_panel = SaveViewerPanel.new()
	add_control_to_bottom_panel(_panel, "Save Viewer")


func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
