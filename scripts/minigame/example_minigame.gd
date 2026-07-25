class_name ExampleMinigame extends Control

## ExampleMinigame — a simple word-input minigame that integrates with
## Uni-Story's InterruptManager protocol.
##
## Lifecycle:
##   1. Story calls minigame(...) → begin_interrupt() → load/instantiate this scene
##   2. Player interacts → result stored in v_minigame_text
##   3. Story calls end_interrupt() → checkpoint created → scene destroyed

signal finished()

var _ctx: Node
var _interrupt_id: int = -1

# ── Node references (bound in _ready) ────────────────────────────────
var _text_input: LineEdit
var _submit_btn: Button
var _feedback_label: Label


func _ready() -> void:
	_bind_nodes()
	gui_input.connect(_on_gui)


func _bind_nodes() -> void:
	var panel := get_node_or_null("Panel/VBox")
	if panel:
		_text_input = panel.get_node_or_null("InputContainer/TextInput") as LineEdit
		_submit_btn = panel.get_node_or_null("InputContainer/SubmitBtn") as Button
		_feedback_label = panel.get_node_or_null("Feedback") as Label

	if _submit_btn:
		_submit_btn.pressed.connect(_on_submit)
	if _text_input:
		_text_input.text_submitted.connect(func(_t: String) -> void: _on_submit())


## Called by PrefabLoader / minigame launcher after instantiation.
## Stores the context reference so the minigame can call back into the engine.
func setup_prefab(ctx: Node) -> void:
	_ctx = ctx
	# Begin the interrupt protocol.
	if _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("begin_interrupt"):
		_interrupt_id = _ctx.interrupt_manager.begin_interrupt()

	if _text_input:
		_text_input.grab_focus()


## Called by PrefabLoader when this minigame is destroyed.
func teardown_prefab(_ctx_node: Node) -> void:
	if _interrupt_id >= 0 and _ctx and _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("end_interrupt"):
		_ctx.interrupt_manager.end_interrupt(_interrupt_id)
		_interrupt_id = -1


func _on_submit() -> void:
	if _text_input == null:
		return
	var text := _text_input.text.strip_edges()
	if text.is_empty():
		if _feedback_label:
			_feedback_label.text = "请输入内容后再确定！"
			_feedback_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
		return

	# Store result in the VN variable system for the story to read.
	if _ctx and _ctx.variables:
		_ctx.variables.set_var("v_minigame_text", text)

	if _feedback_label:
		_feedback_label.text = "✓ 你输入了：" + text
		_feedback_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 1))

	# Disable further input.
	if _text_input:
		_text_input.editable = false
	if _submit_btn:
		_submit_btn.disabled = true

	# Wait a moment so the player can see the feedback, then finish.
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(_finish)


func _finish() -> void:
	finished.emit()
	# Destroy via the prefab loader so it's properly cleaned up.
	if _ctx and _ctx.prefab_loader and _ctx.prefab_loader.has_method("destroy_prefab"):
		_ctx.prefab_loader.destroy_prefab("ExampleMinigame")


func _on_gui(event: InputEvent) -> void:
	# Swallow clicks to prevent advancing the story behind the minigame.
	if event is InputEventMouseButton and event.pressed:
		accept_event()
