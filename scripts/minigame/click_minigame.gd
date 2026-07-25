class_name ClickMinigame extends Control

## ClickMinigame — a click-to-score minigame that integrates with
## Uni-Story's InterruptManager protocol.
##
## Player clicks on moving targets to accumulate score.
## Story reads result via v_minigame_score variable.

signal finished()

var _ctx: Node
var _interrupt_id: int = -1

# Config
var _target_count: int = 5
var _move_speed: float = 200.0
var _score: int = 0
var _targets_hit: int = 0

# Node references
var _score_label: Label
var _progress_label: Label
var _game_area: Control
var _target_scene: PackedScene
var _active_targets: Array[Control] = []
var _timer: Timer


func _ready() -> void:
	_bind_nodes()
	gui_input.connect(_on_gui)
	_start_game()


func _bind_nodes() -> void:
	var panel := get_node_or_null("Panel/VBox")
	if panel:
		_score_label = panel.get_node_or_null("Header/ScoreLabel") as Label
		_progress_label = panel.get_node_or_null("Header/ProgressLabel") as Label
	_game_area = get_node_or_null("GameArea") as Control
	_timer = get_node_or_null("SpawnTimer") as Timer


func _start_game() -> void:
	_score = 0
	_targets_hit = 0
	_update_ui()
	if _timer:
		_timer.timeout.connect(_spawn_target)
		_timer.start()


func setup_prefab(ctx: Node) -> void:
	_ctx = ctx
	if _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("begin_interrupt"):
		_interrupt_id = _ctx.interrupt_manager.begin_interrupt()


func teardown_prefab(_ctx_node: Node) -> void:
	if _interrupt_id >= 0 and _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("end_interrupt"):
		_ctx.interrupt_manager.end_interrupt(_interrupt_id)
		_interrupt_id = -1
	for target in _active_targets:
		if is_instance_valid(target):
			target.queue_free()
	_active_targets.clear()


func _spawn_target() -> void:
	if _targets_hit >= _target_count:
		return

	var target := ColorRect.new()
	target.size = Vector2(64, 64)
	target.color = Color(randf_range(0.2, 1.0), randf_range(0.3, 0.9), randf_range(0.4, 1.0), 0.9)

	if _game_area:
		var area_size := _game_area.size
		target.position = Vector2(randf_range(0, area_size.x - 64), randf_range(0, area_size.y - 64))
	else:
		target.position = Vector2(randf_range(100, 700), randf_range(100, 400))

	target.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			_on_target_clicked(target)
			accept_event()
	)

	if _game_area:
		_game_area.add_child(target)
	_active_targets.append(target)


func _on_target_clicked(target: Control) -> void:
	if not is_instance_valid(target):
		return
	_score += 100
	_targets_hit += 1
	_active_targets.erase(target)
	target.queue_free()
	_update_ui()

	if _targets_hit >= _target_count:
		_finish_game()


func _update_ui() -> void:
	if _score_label:
		_score_label.text = "Score: %d" % _score
	if _progress_label:
		_progress_label.text = "Targets: %d / %d" % [_targets_hit, _target_count]


func _finish_game() -> void:
	if _ctx and _ctx.variables:
		_ctx.variables.set_var("v_minigame_score", _score)

	if _timer:
		_timer.stop()

	for target in _active_targets:
		if is_instance_valid(target):
			target.queue_free()
	_active_targets.clear()

	if _score_label:
		_score_label.text = "Score: %d — Complete!" % _score

	var finish_timer := get_tree().create_timer(1.5)
	finish_timer.timeout.connect(_finish)


func _finish() -> void:
	finished.emit()
	if _ctx and _ctx.prefab_loader and _ctx.prefab_loader.has_method("destroy_prefab"):
		_ctx.prefab_loader.destroy_prefab("ClickMinigame")


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
