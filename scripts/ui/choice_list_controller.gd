class_name ChoiceListController
extends VBoxContainer

## Lightweight branch-choice dispatcher.

signal choice_chosen(dest: StringName)

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")


func set_choices(options: Array) -> void:
	clear()
	if options.is_empty():
		return

	for option in options:
		if option == null or not (option is Dictionary):
			continue

		var dest := StringName(str(option.get("dest", "")))
		if dest == StringName(""):
			continue

		var button := _make_button(str(option.get("text", "")))
		button.disabled = not bool(option.get("enabled", true))
		button.pressed.connect(_on_choice_pressed.bind(dest))
		add_child(button)


func clear() -> void:
	for c in get_children():
		c.queue_free()


func _make_button(text: String) -> Button:
	var b := ButtonRingScene.instantiate() as Button
	if b == null:
		b = Button.new()
	b.text = text
	return b


func _on_choice_pressed(dest: StringName) -> void:
	clear()
	choice_chosen.emit(dest)
