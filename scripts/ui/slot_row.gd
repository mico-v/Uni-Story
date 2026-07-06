class_name SlotRow extends HBoxContainer

## Reusable save/load slot row: thumbnail + metadata labels + action button + delete button.

signal pressed()
signal delete_requested()

@onready var thumbnail: TextureRect = $Thumbnail
@onready var chapter_label: Label = $Info/ChapterLabel
@onready var position_label: Label = $Info/PositionLabel
@onready var time_label: Label = $Info/TimeLabel
@onready var main_btn: Button = $MainButton
@onready var delete_btn: Button = $DeleteButton


## Bind slot metadata for rich display.
## `label` is the action button text (e.g. "存档" / "读档").
## `metadata` comes from SaveSystem.slot_metadata() — may be empty for empty slots.
## `has_save` controls whether the delete button is visible.
## `save_mode` controls whether the main button is disabled for empty load slots.
func bind(label: String, metadata: Dictionary, has_save: bool, save_mode: bool) -> void:
	main_btn.text = label
	main_btn.disabled = not save_mode and not has_save
	delete_btn.visible = has_save

	if metadata.is_empty():
		chapter_label.text = "空"
		position_label.text = ""
		time_label.text = ""
		thumbnail.texture = null
		thumbnail.visible = false
		return

	var chapter_name := str(metadata.get("display_name", ""))
	if chapter_name.is_empty():
		chapter_name = str(metadata.get("chapter", "?"))
	chapter_label.text = chapter_name

	var entry_idx := int(metadata.get("entry_index", 0))
	position_label.text = "@%d" % entry_idx

	var created_at := float(metadata.get("created_at_unix", 0.0))
	if created_at > 0.0:
		time_label.text = _format_time(created_at)
	else:
		time_label.text = ""

	# Load thumbnail if available.
	var screenshot_path := str(metadata.get("screenshot_path", ""))
	if not screenshot_path.is_empty():
		_apply_thumbnail(screenshot_path)
	else:
		thumbnail.texture = null
		thumbnail.visible = false


func _ready() -> void:
	main_btn.pressed.connect(func() -> void: pressed.emit())
	delete_btn.pressed.connect(func() -> void: delete_requested.emit())
	# Default font sizes for metadata labels.
	for lbl in [chapter_label, position_label, time_label]:
		if lbl:
			lbl.add_theme_font_size_override("font_size", 14)


func _apply_thumbnail(path: String) -> void:
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		thumbnail.texture = null
		thumbnail.visible = false
		return
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		thumbnail.texture = null
		thumbnail.visible = false
		return
	thumbnail.texture = ImageTexture.create_from_image(img)
	thumbnail.visible = true


func _format_time(unix_time: float) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(int(unix_time))
	if dt.is_empty():
		return ""
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]
