class_name SaveLoadController extends Control

## Standalone save/load view with GALGAME sidebar layout.
## Displays slot list in the main content area, supports switching
## between save and load modes via sidebar buttons.

signal back_requested()
signal load_completed()

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

@onready var title_label: Label = $HBox/Sidebar/VBox/Title
@onready var btn_save_tab: Button = $HBox/Sidebar/VBox/BtnSaveTab
@onready var btn_load_tab: Button = $HBox/Sidebar/VBox/BtnLoadTab
@onready var btn_back: Button = $HBox/Sidebar/VBox/BtnBack
@onready var mode_label: Label = $HBox/Content/VBox/ModeLabel
@onready var slot_list: VBoxContainer = $HBox/Content/VBox/Scroll/SlotList

var _ctx: Node  # NovaController
var _is_save_mode := false


func setup(ctx: Node) -> void:
	_ctx = ctx


func _ready() -> void:
	btn_save_tab.pressed.connect(func() -> void:
		_is_save_mode = true
		_refresh()
	)
	btn_load_tab.pressed.connect(func() -> void:
		_is_save_mode = false
		_refresh()
	)
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if mode_label:
		mode_label.add_theme_font_size_override("font_size", 20)
		mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_in_mode(save_mode: bool) -> void:
	_is_save_mode = save_mode
	_refresh()


func _refresh() -> void:
	_clear_slots()
	if _ctx == null or _ctx.save_system == null:
		return
	if mode_label:
		if _is_save_mode:
			mode_label.text = _t("ingame.save.button", "存档")
		else:
			mode_label.text = _t("ingame.load.button", "读档")
	for slot in _ctx.save_system.slot_count:
		var label_text := _t("ui.save.slot_format", "存档位 %d：%s") % [slot + 1, _ctx.save_system.slot_label(slot)]
		var b := _make_button(label_text)
		b.custom_minimum_size = Vector2(0, 52)
		if not _is_save_mode and not _ctx.save_system.has_save(slot):
			b.disabled = true
		b.pressed.connect(_on_slot_pressed.bind(slot))
		slot_list.add_child(b)


func _on_slot_pressed(slot: int) -> void:
	if _ctx == null or _ctx.save_system == null:
		return
	if _is_save_mode:
		_ctx.save_system.save(slot)
		_refresh()
	else:
		if _ctx.save_system.load_slot(slot):
			load_completed.emit()


func _clear_slots() -> void:
	if slot_list == null:
		return
	for c in slot_list.get_children():
		c.queue_free()


func _make_button(text: String) -> Button:
	var b := ButtonRingScene.instantiate() as Button
	if b == null:
		b = Button.new()
	b.text = text
	return b


func apply_i18n(i18n: I18n) -> void:
	if i18n == null:
		return
	if title_label:
		title_label.text = i18n.t("bookmark.save.button", "存档")
	if btn_save_tab:
		btn_save_tab.text = i18n.t("ingame.save.button", "存档")
	if btn_load_tab:
		btn_load_tab.text = i18n.t("ingame.load.button", "读档")
	if btn_back:
		btn_back.text = i18n.t("title.selectchapter.return", "返回")
	_refresh()


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)
