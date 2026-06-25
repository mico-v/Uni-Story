class_name SaveLoadPanelController extends RefCounted

## Encapsulates save/load panel UI logic extracted from GameViewController.

signal back_requested()
signal slot_pressed(slot: int, save_mode: bool)

const SlotRowScene: PackedScene = preload("res://scene/ui/slot_row.tscn")

var _ctx: Node
var _save_panel: Panel
var _save_panel_title: Label
var _save_slots: VBoxContainer
var _save_close_btn: Button
var _save_mode := true


func bind_nodes(panel: Panel, title: Label, slots: VBoxContainer, close_btn: Button) -> void:
	_save_panel = panel
	_save_panel_title = title
	_save_slots = slots
	_save_close_btn = close_btn
	if _save_close_btn:
		_save_close_btn.pressed.connect(func() -> void:
			if _save_panel:
				_save_panel.visible = false
			back_requested.emit()
		)


func setup(ctx: Node) -> void:
	_ctx = ctx


func open(save_mode: bool) -> void:
	_save_mode = save_mode
	if _save_panel_title:
		_save_panel_title.text = _t("ingame.save.button", "存档") if save_mode else _t("ingame.load.button", "读档")
	_refresh()
	if _save_panel:
		_save_panel.visible = true


func close() -> void:
	if _save_panel:
		_save_panel.visible = false


func panel_is_visible() -> bool:
	return _save_panel != null and _save_panel.visible


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	if _save_slots == null or _ctx == null or _ctx.save_system == null:
		return
	_clear_children(_save_slots)
	for slot in _ctx.save_system.slot_count:
		_build_slot_row(slot, _save_mode)


func _build_slot_row(slot: int, save_mode: bool) -> void:
	var has: bool = _ctx.save_system.has_save(slot)
	var label := _t("ui.save.slot_format", "存档位 %d：%s") % [slot + 1, _ctx.save_system.slot_label(slot)]
	var row := SlotRowScene.instantiate()
	var main_btn: Button = row.get_node("MainButton")
	var del_btn: Button = row.get_node("DeleteButton")
	main_btn.text = label
	main_btn.custom_minimum_size = Vector2(300, 40)
	main_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not save_mode and not has:
		main_btn.disabled = true
	main_btn.pressed.connect(func() -> void: slot_pressed.emit(slot, save_mode))
	del_btn.visible = has
	if has:
		del_btn.pressed.connect(func() -> void:
			if _ctx.save_system:
				_ctx.save_system.delete_slot(slot)
			_refresh()
		)
	_save_slots.add_child(row)


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)
