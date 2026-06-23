class_name SlotRow extends HBoxContainer

## Reusable save/load slot row: label button + optional delete button.

signal pressed()
signal delete_requested()

@onready var main_btn: Button = $MainButton
@onready var delete_btn: Button = $DeleteButton

func setup(label: String, has_save: bool, save_mode: bool) -> void:
	main_btn.text = label
	main_btn.disabled = not save_mode and not has_save
	delete_btn.visible = has_save

func _ready() -> void:
	main_btn.pressed.connect(func() -> void: pressed.emit())
	delete_btn.pressed.connect(func() -> void: delete_requested.emit())
