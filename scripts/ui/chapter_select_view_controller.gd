class_name ChapterSelectViewController
extends Control

## Lightweight chapter selection view controller.
## Keeps button creation and press dispatch local to the chapter view.

signal chapter_selected(node_name: StringName)
signal back_requested()

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

@onready var title_label: Label = $VBox/Title
@onready var chapter_list: VBoxContainer = $VBox/ChapterList
@onready var back_button: Button = $VBox/Back

var _empty_label := ""


func _ready() -> void:
	back_button.pressed.connect(func() -> void:
		back_requested.emit()
	)


func set_title(text: String) -> void:
	if title_label:
		title_label.text = text


func set_back_text(text: String) -> void:
	if back_button:
		back_button.text = text


func set_empty_label(text: String) -> void:
	_empty_label = text


func clear() -> void:
	for c in chapter_list.get_children():
		c.queue_free()


func set_chapters(entries: Array, empty_text: String = "") -> void:
	if not empty_text.is_empty():
		_empty_label = empty_text

	clear()

	for entry in entries:
		if entry == null:
			continue
		if not entry is Dictionary:
			continue
		var node_name := StringName(str(entry.get("name", "")))
		if node_name == StringName(""):
			continue
		var text := str(entry.get("text", String(node_name)))
		var button := _make_button(text)
		button.pressed.connect(_on_chapter_button_pressed.bind(node_name))
		chapter_list.add_child(button)

	if chapter_list.get_child_count() == 0:
		var lbl := _make_button(_empty_label)
		lbl.disabled = true
		chapter_list.add_child(lbl)


func _on_chapter_button_pressed(node_name: StringName) -> void:
	chapter_selected.emit(node_name)


func _make_button(text: String) -> Button:
	var b := ButtonRingScene.instantiate() as Button
	if b == null:
		b = Button.new()
	b.text = text
	return b
