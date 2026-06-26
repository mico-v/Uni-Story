class_name ViewManager extends RefCounted

## ViewManager — registers named views and switches between them with
## configurable transitions (fade, slide, instant).  Follows the project's
## subsystem pattern: RefCounted + _ctx: Node.

enum Transition { NONE, FADE, SLIDE_LEFT, SLIDE_RIGHT, SLIDE_UP, SLIDE_DOWN }
enum ViewState { TITLE, UI, GAME, IN_TRANSITION, ALERT }

signal state_changed(state: int)

var _ctx: Node
var _views: Dictionary = {}          # String name -> Control
var _transitions: Dictionary = {}    # String name -> Transition enum int
var _current_view: String = ""
var _is_transitioning := false
var _pending_view := ""
var _state: int = ViewState.TITLE
var _alert_depth: int = 0
var _input_blocker: Control = null
var transition_duration := 0.3


func _init(ctx: Node) -> void:
	_ctx = ctx


## Register a view so ViewManager can switch to it later.
## The control is hidden immediately.
func register(view_name: String, control: Control, default_transition: int = Transition.NONE) -> void:
	_views[view_name] = control
	_transitions[view_name] = default_transition
	control.visible = false


## Switch to a named view.  Pass transition_override >= 0 to override the
## registered default; pass -1 to use the default.
func switch_to(view_name: String, transition_override: int = -1) -> void:
	if view_name == _current_view:
		return
	if _is_transitioning:
		_pending_view = view_name
		return
	var new_ctrl: Control = _views.get(view_name) as Control
	if new_ctrl == null:
		push_warning("ViewManager: unknown view '%s'" % view_name)
		return
	var old_ctrl: Control = null
	if _current_view != "":
		old_ctrl = _views.get(_current_view) as Control
	var trans: int = transition_override if transition_override >= 0 else int(_transitions.get(view_name, Transition.NONE))
	_is_transitioning = true
	_set_state(ViewState.IN_TRANSITION)
	_set_transition_blocker_active(true)
	match trans:
		Transition.FADE:
			_do_fade(old_ctrl, new_ctrl)
		Transition.SLIDE_LEFT:
			_do_slide(old_ctrl, new_ctrl, Vector2(-1, 0))
		Transition.SLIDE_RIGHT:
			_do_slide(old_ctrl, new_ctrl, Vector2(1, 0))
		Transition.SLIDE_UP:
			_do_slide(old_ctrl, new_ctrl, Vector2(0, -1))
		Transition.SLIDE_DOWN:
			_do_slide(old_ctrl, new_ctrl, Vector2(0, 1))
		_:
			_do_instant(old_ctrl, new_ctrl)
	_current_view = view_name


## Return the name of the currently visible view.
func current() -> String:
	return _current_view


func state() -> int:
	return _state


func is_transitioning() -> bool:
	return _is_transitioning


func is_input_blocked() -> bool:
	return _is_transitioning or _alert_depth > 0


func has_view(view_name: String) -> bool:
	return _views.has(view_name)


func begin_alert() -> void:
	_alert_depth += 1
	_set_state(ViewState.ALERT)


func end_alert() -> void:
	_alert_depth = maxi(0, _alert_depth - 1)
	if _alert_depth > 0:
		_set_state(ViewState.ALERT)
	elif _is_transitioning:
		_set_state(ViewState.IN_TRANSITION)
	else:
		_set_state(_state_for_view(_current_view))


# ── Transition implementations ────────────────────────────────────────

func _do_instant(old_ctrl: Control, new_ctrl: Control) -> void:
	if old_ctrl:
		old_ctrl.visible = false
	new_ctrl.visible = true
	new_ctrl.modulate.a = 1.0
	_finish_transition()


func _do_fade(old_ctrl: Control, new_ctrl: Control) -> void:
	new_ctrl.visible = true
	new_ctrl.modulate.a = 0.0
	var t := _ctx.get_tree().create_tween()
	t.set_parallel(true)
	t.tween_property(new_ctrl, "modulate:a", 1.0, transition_duration)
	if old_ctrl:
		t.tween_property(old_ctrl, "modulate:a", 0.0, transition_duration)
	t.chain().tween_callback(func() -> void:
		if old_ctrl:
			old_ctrl.visible = false
			old_ctrl.modulate.a = 1.0
		_finish_transition()
	)


func _do_slide(old_ctrl: Control, new_ctrl: Control, direction: Vector2) -> void:
	var vp_size := _ctx.get_viewport().get_visible_rect().size
	var offset := Vector2(direction.x * vp_size.x, direction.y * vp_size.y)
	new_ctrl.visible = true
	new_ctrl.position = offset
	new_ctrl.modulate.a = 1.0
	var t := _ctx.get_tree().create_tween()
	t.set_parallel(true)
	t.tween_property(new_ctrl, "position", Vector2.ZERO, transition_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if old_ctrl:
		t.tween_property(old_ctrl, "position", -offset, transition_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	t.chain().tween_callback(func() -> void:
		if old_ctrl:
			old_ctrl.visible = false
			old_ctrl.position = Vector2.ZERO
		_finish_transition()
	)


func _finish_transition() -> void:
	_is_transitioning = false
	_set_transition_blocker_active(false)
	if _pending_view != "":
		var next: String = _pending_view
		_pending_view = ""
		switch_to(next)
		return
	if _alert_depth > 0:
		_set_state(ViewState.ALERT)
	else:
		_set_state(_state_for_view(_current_view))


func _state_for_view(view_name: String) -> int:
	match view_name:
		"title":
			return ViewState.TITLE
		"game":
			return ViewState.GAME
		_:
			return ViewState.UI


func _set_state(next_state: int) -> void:
	if _state == next_state:
		return
	_state = next_state
	state_changed.emit(_state)


func _set_transition_blocker_active(active: bool) -> void:
	var blocker: Control = _ensure_input_blocker()
	if blocker == null:
		return
	blocker.visible = active
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE


func _ensure_input_blocker() -> Control:
	if _input_blocker != null and is_instance_valid(_input_blocker):
		return _input_blocker
	var parent: Node = _ctx.get_node_or_null("GlobalUI")
	if parent == null:
		parent = _ctx
	var blocker: Control = Control.new()
	blocker.name = "TransitionInputBlocker"
	blocker.visible = false
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blocker.z_index = 2000
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(blocker)
	_input_blocker = blocker
	return _input_blocker


## Force-reset transition state if stuck (e.g. after hot reload kills tweens).
func force_reset() -> void:
	_is_transitioning = false
	_pending_view = ""
	_alert_depth = 0
	_set_transition_blocker_active(false)
	for view_name in _views:
		var ctrl: Control = _views[view_name]
		if ctrl:
			ctrl.visible = (view_name == _current_view)
			ctrl.modulate.a = 1.0
			ctrl.position = Vector2.ZERO
	_set_state(_state_for_view(_current_view))
