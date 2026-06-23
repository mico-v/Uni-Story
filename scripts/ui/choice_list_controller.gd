class_name ChoiceListController
extends VBoxContainer

## Lightweight branch-choice dispatcher. Supports optional image thumbnails
## alongside text buttons. Constrains max height to prevent overflow.

signal choice_chosen(dest: StringName)

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")
const THUMB_SIZE := Vector2(120, 80)
const MAX_VISIBLE_ITEMS := 6
const ITEM_HEIGHT := 48  # approximate button height + spacing


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

		var image_path := str(option.get("image", ""))
		var text := str(option.get("text", ""))
		var enabled := bool(option.get("enabled", true))

		if image_path != "" and ResourceLoader.exists(image_path):
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var thumb := TextureRect.new()
			thumb.custom_minimum_size = THUMB_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			var tex := load(image_path) as Texture2D
			if tex:
				thumb.texture = tex
			row.add_child(thumb)
			var button := _make_button(text)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = not enabled
			button.pressed.connect(_on_choice_pressed.bind(dest))
			row.add_child(button)
			add_child(row)
		else:
			var button := _make_button(text)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.disabled = not enabled
			button.pressed.connect(_on_choice_pressed.bind(dest))
			add_child(button)

	# Constrain max height if too many items.
	var item_count := get_child_count()
	if item_count > MAX_VISIBLE_ITEMS:
		custom_minimum_size.y = MAX_VISIBLE_ITEMS * ITEM_HEIGHT
		clip_contents = true
	else:
		custom_minimum_size.y = 0
		clip_contents = false


func clear() -> void:
	for c in get_children():
		c.queue_free()
	# Reset layout constraints so the container sizes to content after a reset.
	custom_minimum_size.y = 0
	clip_contents = false


func _make_button(text: String) -> Button:
	var b := ButtonRingScene.instantiate() as Button
	if b == null:
		b = Button.new()
	b.text = text
	return b


func _on_choice_pressed(dest: StringName) -> void:
	clear()
	choice_chosen.emit(dest)
