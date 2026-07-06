class_name MobileUiSupport extends Node

## MobileUiSupport centralizes touch affordances that Godot desktop mouse flows
## do not cover by default: drag-scrolling through nested controls and
## suppressing accidental clicks after a scroll gesture.

const META_WATCHED := "_uni_story_mobile_watch"
const META_SCROLL_CONFIGURED := "_uni_story_mobile_scroll_configured"
const META_SCROLL_ACTIVE := "_uni_story_mobile_scroll_active"
const META_SCROLL_DRAGGING := "_uni_story_mobile_scroll_dragging"
const META_SCROLL_DISTANCE := "_uni_story_mobile_scroll_distance"
const META_SCROLL_SUPPRESS_TAP_UNTIL := "_uni_story_mobile_scroll_suppress_tap_until"
const META_SCROLL_CHILD_PREFIX := "_uni_story_mobile_scroll_child_"

@export var drag_deadzone: float = 10.0
@export var suppress_tap_ms: int = 180

var _root: Node


func setup(root_node: Node) -> void:
	_root = root_node
	configure_tree(root_node)


func configure_tree(root_node: Node) -> void:
	if root_node == null:
		return
	_watch_node(root_node)
	if root_node is ScrollContainer:
		configure_scroll_container(root_node as ScrollContainer)
	for child in root_node.get_children():
		configure_tree(child)


func configure_scroll_container(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	if not bool(scroll.get_meta(META_SCROLL_CONFIGURED, false)):
		scroll.set_meta(META_SCROLL_CONFIGURED, true)
		scroll.mouse_filter = Control.MOUSE_FILTER_STOP
		scroll.set("follow_focus", true)
		scroll.gui_input.connect(_on_scroll_gui_input.bind(scroll, scroll))
	_configure_scroll_descendants(scroll, scroll)


static func should_suppress_tap(scroll: ScrollContainer) -> bool:
	if scroll == null:
		return false
	if bool(scroll.get_meta(META_SCROLL_DRAGGING, false)):
		return true
	var until := int(scroll.get_meta(META_SCROLL_SUPPRESS_TAP_UNTIL, 0))
	return Time.get_ticks_msec() < until


func _watch_node(node: Node) -> void:
	if node == null or bool(node.get_meta(META_WATCHED, false)):
		return
	node.set_meta(META_WATCHED, true)
	node.child_entered_tree.connect(_on_child_entered_tree)


func _on_child_entered_tree(child: Node) -> void:
	configure_tree(child)
	var parent := child.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			_configure_scroll_descendants(parent as ScrollContainer, child)
			return
		parent = parent.get_parent()


func _configure_scroll_descendants(scroll: ScrollContainer, node: Node) -> void:
	if scroll == null or node == null:
		return
	if node is Control and node != scroll:
		_configure_scroll_child(scroll, node as Control)
	for child in node.get_children():
		_configure_scroll_descendants(scroll, child)


func _configure_scroll_child(scroll: ScrollContainer, control: Control) -> void:
	if control is VScrollBar or control is HScrollBar:
		return
	var meta_key := META_SCROLL_CHILD_PREFIX + str(scroll.get_instance_id())
	if bool(control.get_meta(meta_key, false)):
		return
	control.set_meta(meta_key, true)
	control.gui_input.connect(_on_scroll_gui_input.bind(control, scroll))
	if control is Label or control is RichTextLabel or control is Container:
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			control.mouse_filter = Control.MOUSE_FILTER_PASS


func _on_scroll_gui_input(event: InputEvent, source: Control, scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll):
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_scroll(scroll)
		else:
			_finish_scroll(scroll, source)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag_scroll(scroll, drag.relative, source)
	elif _uses_mobile_mouse_events() and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_scroll(scroll)
		else:
			_finish_scroll(scroll, source)
	elif _uses_mobile_mouse_events() and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_drag_scroll(scroll, motion.relative, source)


func _begin_scroll(scroll: ScrollContainer) -> void:
	scroll.set_meta(META_SCROLL_ACTIVE, true)
	scroll.set_meta(META_SCROLL_DRAGGING, false)
	scroll.set_meta(META_SCROLL_DISTANCE, 0.0)


func _drag_scroll(scroll: ScrollContainer, relative: Vector2, source: Control) -> void:
	if not bool(scroll.get_meta(META_SCROLL_ACTIVE, false)):
		_begin_scroll(scroll)
	var distance := float(scroll.get_meta(META_SCROLL_DISTANCE, 0.0)) + relative.length()
	scroll.set_meta(META_SCROLL_DISTANCE, distance)
	if distance < drag_deadzone:
		return
	scroll.set_meta(META_SCROLL_DRAGGING, true)
	if scroll.get_v_scroll_bar():
		var max_v := int(round(scroll.get_v_scroll_bar().max_value))
		scroll.scroll_vertical = clampi(scroll.scroll_vertical - int(round(relative.y)), 0, max_v)
	if scroll.get_h_scroll_bar():
		var max_h := int(round(scroll.get_h_scroll_bar().max_value))
		scroll.scroll_horizontal = clampi(scroll.scroll_horizontal - int(round(relative.x)), 0, max_h)
	if source:
		source.accept_event()


func _finish_scroll(scroll: ScrollContainer, source: Control) -> void:
	var was_dragging := bool(scroll.get_meta(META_SCROLL_DRAGGING, false))
	scroll.set_meta(META_SCROLL_ACTIVE, false)
	scroll.set_meta(META_SCROLL_DRAGGING, false)
	scroll.set_meta(META_SCROLL_DISTANCE, 0.0)
	if was_dragging:
		scroll.set_meta(META_SCROLL_SUPPRESS_TAP_UNTIL, Time.get_ticks_msec() + suppress_tap_ms)
		if source:
			source.accept_event()


func _uses_mobile_mouse_events() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
