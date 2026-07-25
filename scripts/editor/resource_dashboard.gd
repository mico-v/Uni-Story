@tool
extends EditorPlugin

## Editor dashboard for resource validation.
##
## Provides:
##   - Aggregates resource scan results (referenced/found/missing/virtual)
##   - Clickable missing resource list that jumps to scenario location
##   - One-click Scenario lint runner with inline results
##   - Summary statistics panel


const ResourceDashboardPanel := preload("res://scripts/editor/resource_dashboard_panel.gd")

var _panel: ResourceDashboardPanel


func _enter_tree() -> void:
	_panel = ResourceDashboardPanel.new()
	_panel.plugin = self
	add_control_to_bottom_panel(_panel, "Resource Dashboard")


func _exit_tree() -> void:
	if _panel:
		remove_control_from_bottom_panel(_panel)
		_panel.queue_free()
		_panel = null
