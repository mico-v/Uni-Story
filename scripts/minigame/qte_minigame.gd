class_name QTEMinigame extends Control

## QTEMinigame — a timed key-press reaction minigame that integrates with
## Uni-Story's InterruptManager protocol.
##
## Player must press the correct key within the time limit for each prompt.
## Story reads result via v_minigame_score and v_minigame_done variables.

signal finished()

var _ctx: Node
var _interrupt_id: int = -1

# Config
var _round_count: int = 5
var _time_limit: float = 2.0
var _score: int = 0
var _current_round: int = 0

# State
var _time_left: float = 0.0
var _expected_key: Key = KEY_A
var _is_active: bool = false

# Node references
var _score_label: Label
var _round_label: Label
var _prompt_label: Label
var _key_label: Label
var _timer_bar: ProgressBar
var _feedback_label: Label
var _countdown_timer: Timer

const KEY_DISPLAY: Dictionary = {
	KEY_A: "A", KEY_S: "S", KEY_D: "D", KEY_W: "W",
	KEY_LEFT: "←", KEY_RIGHT: "→", KEY_UP: "↑", KEY_DOWN: "↓",
	KEY_SPACE: "SPACE",
}


func _ready() -> void:
	_bind_nodes()
	set_process_unhandled_key_input(true)
	gui_input.connect(_on_gui)


func _bind_nodes() -> void:
	var panel := get_node_or_null("Panel/VBox")
	if panel:
		_score_label = panel.get_node_or_null("Header/ScoreLabel") as Label
		_round_label = panel.get_node_or_null("Header/RoundLabel") as Label
		_prompt_label = panel.get_node_or_null("PromptLabel") as Label
		_key_label = panel.get_node_or_null("KeyLabel") as Label
		_timer_bar = panel.get_node_or_null("TimerBar") as ProgressBar
		_feedback_label = panel.get_node_or_null("FeedbackLabel") as Label
	_countdown_timer = get_node_or_null("CountdownTimer") as Timer


func setup_prefab(ctx: Node) -> void:
	_ctx = ctx
	if _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("begin_interrupt"):
		_interrupt_id = _ctx.interrupt_manager.begin_interrupt()

	if _countdown_timer:
		_countdown_timer.timeout.connect(_on_tick)
		_countdown_timer.wait_time = 0.05

	_start_round()


func teardown_prefab(_ctx_node: Node) -> void:
	if _interrupt_id >= 0 and _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("end_interrupt"):
		_ctx.interrupt_manager.end_interrupt(_interrupt_id)
		_interrupt_id = -1


func _start_round() -> void:
	if _current_round >= _round_count:
		_finish_game()
		return

	_current_round += 1
	_is_active = true
	_time_left = _time_limit

	var all_keys := [KEY_A, KEY_S, KEY_D, KEY_W, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE]
	_expected_key = all_keys[randi() % all_keys.size()]

	_update_ui()
	if _feedback_label:
		_feedback_label.text = ""
	if _key_label:
		_key_label.text = KEY_DISPLAY.get(_expected_key, "?")

	if _countdown_timer:
		_countdown_timer.start()


func _update_ui() -> void:
	if _score_label:
		_score_label.text = "Score: %d" % _score
	if _round_label:
		_round_label.text = "Round: %d / %d" % [_current_round, _round_count]
	if _timer_bar:
		_timer_bar.max_value = _time_limit
		_timer_bar.value = _time_left
	if _prompt_label:
		_prompt_label.text = "Press the key!"


func _on_tick() -> void:
	if not _is_active:
		return
	_time_left -= 0.05
	_update_ui()

	if _time_left <= 0:
		_is_active = false
		if _feedback_label:
			_feedback_label.text = "Too slow!"
			_feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		var delay := get_tree().create_timer(0.8)
		delay.timeout.connect(_start_round)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event is InputEventKey and event.pressed:
		_handle_key(event.keycode)


func _handle_key(pressed_key: Key) -> void:
	if pressed_key == _expected_key:
		_is_active = false
		_score += 100
		_update_ui()
		if _feedback_label:
			_feedback_label.text = "✓ Great!"
			_feedback_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))
		var delay := get_tree().create_timer(0.5)
		delay.timeout.connect(_start_round)
	else:
		_is_active = false
		_update_ui()
		if _feedback_label:
			_feedback_label.text = "✗ Wrong key!"
			_feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		var delay := get_tree().create_timer(0.8)
		delay.timeout.connect(_start_round)

	accept_event()


func _finish_game() -> void:
	if _ctx and _ctx.variables:
		_ctx.variables.set_var("v_minigame_score", _score)
		_ctx.variables.set_var("v_minigame_done", true)

	if _prompt_label:
		_prompt_label.text = "Complete!"
	if _key_label:
		_key_label.text = ""

	if _countdown_timer:
		_countdown_timer.stop()

	var finish_timer := get_tree().create_timer(1.5)
	finish_timer.timeout.connect(_finish)


func _finish() -> void:
	finished.emit()
	if _ctx and _ctx.prefab_loader and _ctx.prefab_loader.has_method("destroy_prefab"):
		_ctx.prefab_loader.destroy_prefab("QTEMinigame")


func _on_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
