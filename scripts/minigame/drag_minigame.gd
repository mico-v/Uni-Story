class_name DragMinigame extends Control

## DragMinigame — a drag-and-drop minigame that integrates with
## Uni-Story's InterruptManager protocol.
##
## Player drags items to their correct target zones.
## Story reads result via v_minigame_score and v_minigame_done variables.

signal finished()

var _ctx: Node
var _interrupt_id: int = -1

# Config
var _target_count: int = 3
var _score: int = 0
var _placed: int = 0

# Node references
var _score_label: Label
var _progress_label: Label
var _game_area: Control
var _drag_items: Array[Control] = []
var _drag_targets: Array[Control] = []
var _dragging: Control = null
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_bind_nodes()
	gui_input.connect(_on_gui)
	_setup_items()


func _bind_nodes() -> void:
	var panel := get_node_or_null("Panel/VBox")
	if panel:
		_score_label = panel.get_node_or_null("Header/ScoreLabel") as Label
		_progress_label = panel.get_node_or_null("Header/ProgressLabel") as Label
	_game_area = get_node_or_null("GameArea") as Control


func _setup_items() -> void:
	if not _game_area:
		return

	var colors := [Color.RED, Color.GREEN, Color.BLUE]
	var labels := ["Red", "Green", "Blue"]
	var area_size := _game_area.size

	for i in range(_target_count):
		# Item to drag
		var item := _make_draggable(labels[i], colors[i], area_size, i)
		_game_area.add_child(item)
		_drag_items.append(item)

		# Drop target zone
		var target_zone := ColorRect.new()
		target_zone.name = "Zone_%d" % i
		target_zone.size = Vector2(80, 80)
		target_zone.position = Vector2(area_size.x - 120, 50 + i * 100)
		target_zone.color = Color(colors[i], 0.3)
		target_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var zone_label := Label.new()
		zone_label.text = labels[i]
		zone_label.position = Vector2(area_size.x - 160, 50 + i * 100 + 25)
		zone_label.add_theme_color_override("font_color", colors[i])
		zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		zone_label.size = Vector2(40, 30)
		_game_area.add_child(zone_label)
		_game_area.add_child(target_zone)
		_drag_targets.append(target_zone)


func _make_draggable(label: String, color: Color, area_size: Vector2, index: int) -> Control:
	var item := PanelContainer.new()
	item.name = "DragItem_%s" % label
	item.size = Vector2(80, 80)
	item.position = Vector2(50, 50 + index * 100)

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	item.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color.BLACK)
	item.add_child(lbl)

	item.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = item
				_drag_offset = item.get_global_mouse_position() - item.global_position
				item.mouse_default_cursor_shape = Control.CURSOR_DRAG
			elif not event.pressed:
				if _dragging == item:
					_dragging = null
					item.mouse_default_cursor_shape = Control.CURSOR_ARROW
					_check_drop(item)
	)

	return item


func _process(_delta: float) -> void:
	if _dragging and is_instance_valid(_dragging):
		_dragging.global_position = _dragging.get_global_mouse_position() - _drag_offset


func _check_drop(item: Control) -> void:
	var item_center := item.global_position + item.size / 2
	for i in range(_drag_targets.size()):
		var target := _drag_targets[i]
		if not is_instance_valid(target):
			continue
		var target_center := target.global_position + target.size / 2
		if item_center.distance_to(target_center) < 60:
			_on_placed(item, i, target)
			return


func _on_placed(item: Control, zone_index: int, _target: Control) -> void:
	if item.get_parent() == null:
		return
	_score += 100
	_placed += 1
	item.name = "__placed__"
	_drag_items.erase(item)
	item.queue_free()
	_update_ui()

	if _placed >= _target_count:
		_finish_game()


func _update_ui() -> void:
	if _score_label:
		_score_label.text = "Score: %d" % _score
	if _progress_label:
		_progress_label.text = "Placed: %d / %d" % [_placed, _target_count]


func setup_prefab(ctx: Node) -> void:
	_ctx = ctx
	if _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("begin_interrupt"):
		_interrupt_id = _ctx.interrupt_manager.begin_interrupt()


func teardown_prefab(_ctx_node: Node) -> void:
	if _interrupt_id >= 0 and _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("end_interrupt"):
		_ctx.interrupt_manager.end_interrupt(_interrupt_id)
		_interrupt_id = -1


func _finish_game() -> void:
	if _ctx and _ctx.variables:
		_ctx.variables.set_var("v_minigame_score", _score)
		_ctx.variables.set_var("v_minigame_done", true)

	var finish_timer := get_tree().create_timer(1.0)
	finish_timer.timeout.connect(_finish)


func _finish() -> void:
	finished.emit()
	if _ctx and _ctx.prefab_loader and _ctx.prefab_loader.has_method("destroy_prefab"):
		_ctx.prefab_loader.destroy_prefab("DragMinigame")


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
