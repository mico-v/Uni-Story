class_name ChapterSelectViewController extends Control

## Chapter selection view aligned with Nova's start node rules.
## Normal start nodes are visible in release; debug start nodes are shown only
## in debug builds unless unlock_debug_nodes is enabled by tests/tools.

signal chapter_selected(node_name: StringName)
signal back_requested()

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

@onready var title_label: Label = $HBox/Sidebar/VBox/Title
@onready var btn_back: Button = $HBox/Sidebar/VBox/BtnBack
@onready var chapter_list: VBoxContainer = $HBox/Content/Scroll/ChapterList
@onready var empty_label: Label = $HBox/Content/Scroll/ChapterList/EmptyLabel

var unlock_all_nodes := false
var unlock_debug_nodes := false

var _ctx: Node
var _i18n: Object


func setup(ctx: Node) -> void:
	_ctx = ctx


func _ready() -> void:
	if btn_back:
		btn_back.pressed.connect(func() -> void: back_requested.emit())
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if chapter_list:
		chapter_list.add_theme_constant_override("separation", 10)


func apply_i18n(i18n: Object) -> void:
	_i18n = i18n
	if title_label:
		title_label.text = _t("title.first.selectchapter", "章节选择")
	if btn_back:
		btn_back.text = _t("title.selectchapter.return", "返回")
	if empty_label:
		empty_label.text = _t("ui.chapter.empty", "（无可用章节）")
	refresh()


func show_or_start_first() -> bool:
	refresh()
	var unlocked := get_unlocked_nodes()
	if unlocked.size() == 1 and not unlock_all_nodes and not unlock_debug_nodes:
		chapter_selected.emit(unlocked[0])
		return true
	return false


func get_unlocked_nodes() -> Array[StringName]:
	var unlocked: Array[StringName] = []
	for node_name in _active_start_nodes():
		if _is_unlocked(node_name):
			unlocked.append(node_name)
	return unlocked


func refresh() -> void:
	if chapter_list == null:
		return
	_clear_list()
	var nodes := _all_selectable_nodes()
	if nodes.is_empty():
		if empty_label:
			empty_label.visible = true
		return
	if empty_label:
		empty_label.visible = false
	var any_visible := false
	var active := _active_start_nodes()
	for node_name in nodes:
		if not active.has(node_name):
			continue
		any_visible = true
		chapter_list.add_child(_make_chapter_button(node_name))
	if empty_label:
		empty_label.visible = not any_visible


func unlock_nodes(normal: bool, debug: bool) -> void:
	unlock_all_nodes = unlock_all_nodes or normal
	unlock_debug_nodes = unlock_debug_nodes or debug
	refresh()


func _all_selectable_nodes() -> Array[StringName]:
	var out: Array[StringName] = []
	var graph := _graph()
	if graph == null:
		return out
	for node in graph.nodes.values():
		if node == null:
			continue
		if bool(node.is_start) or bool(node.is_unlocked_start) or bool(node.is_debug):
			out.append(node.name)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return out


func _active_start_nodes() -> Array[StringName]:
	var out: Array[StringName] = []
	var graph := _graph()
	if graph == null:
		return out
	for node in graph.nodes.values():
		if node == null:
			continue
		if bool(node.is_debug):
			if OS.is_debug_build() or unlock_debug_nodes:
				out.append(node.name)
			continue
		if bool(node.is_start) or bool(node.is_unlocked_start):
			out.append(node.name)
	return out


func _is_unlocked(node_name: StringName) -> bool:
	if unlock_all_nodes:
		return true
	var graph := _graph()
	var node = graph.get_node_named(node_name) if graph else null
	if node == null:
		return false
	if bool(node.is_debug):
		return OS.is_debug_build() or unlock_debug_nodes
	if bool(node.is_unlocked_start):
		return true
	var manager := _checkpoint_manager()
	if manager != null and manager.has_method("is_reached_any_history"):
		return bool(manager.call("is_reached_any_history", node_name, 0))
	return false


func _make_chapter_button(node_name: StringName) -> Button:
	var button := ButtonRingScene.instantiate() as Button
	if button == null:
		button = Button.new()
	button.custom_minimum_size = Vector2(0, 54)
	if _is_unlocked(node_name):
		button.text = _display_name_for(node_name)
		button.pressed.connect(func() -> void: chapter_selected.emit(node_name))
	else:
		button.text = _t("title.selectchapter.locked", "？？？")
		button.disabled = true
	return button


func _display_name_for(node_name: StringName) -> String:
	var graph := _graph()
	var node = graph.get_node_named(node_name) if graph else null
	if node == null:
		return str(node_name)
	var display := str(node.display_name)
	return display if not display.is_empty() else str(node_name)


func _clear_list() -> void:
	for child in chapter_list.get_children():
		if child == empty_label:
			continue
		child.queue_free()


func _graph() -> FlowChartGraph:
	if _ctx == null:
		return null
	var loader = _ctx.get("script_loader")
	if loader == null:
		return null
	return loader.get("graph") as FlowChartGraph


func _checkpoint_manager() -> Object:
	if _ctx == null:
		return null
	return _ctx.get("checkpoint_manager") as Object


func _t(key: String, fallback: String = "") -> String:
	if _i18n != null and _i18n.has_method("t"):
		return str(_i18n.call("t", key, fallback))
	if _ctx != null:
		var ctx_i18n = _ctx.get("i18n")
		if ctx_i18n != null and ctx_i18n.has_method("t"):
			return str(ctx_i18n.call("t", key, fallback))
	return fallback
