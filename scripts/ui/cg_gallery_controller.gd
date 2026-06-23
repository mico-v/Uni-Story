class_name CgGalleryController extends Control

## CG appreciation gallery view.  Displays a grid of CG thumbnails;
## locked entries show a placeholder.  Clicking an unlocked entry opens
## a full-screen preview overlay.

signal back_requested()

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

@onready var title_label: Label = $HBox/Sidebar/VBox/Title
@onready var btn_back: Button = $HBox/Sidebar/VBox/BtnBack
@onready var grid: GridContainer = $HBox/Content/Scroll/Grid
@onready var empty_label: Label = $HBox/Content/Scroll/Grid/EmptyLabel

# Full-screen preview overlay (created on demand).
var _preview_overlay: ColorRect = null
var _preview_texture: TextureRect = null


func _ready() -> void:
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_create_preview_overlay()


func _create_preview_overlay() -> void:
	var overlay := preload("res://scene/ui/cg_preview_overlay.tscn").instantiate()
	_preview_overlay = overlay
	_preview_overlay.visible = false
	_preview_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_preview_overlay.visible = false
	)
	_preview_texture = overlay.get_node("TextureRect")
	add_child(overlay)


func set_gallery(entries: Array) -> void:
	_clear_grid()
	if entries.is_empty():
		if empty_label:
			empty_label.visible = true
		return
	if empty_label:
		empty_label.visible = false
	for entry in entries:
		if entry == null or not entry is Dictionary:
			continue
		var unlocked := bool(entry.get("unlocked", false))
		var tex_path := str(entry.get("texture_path", ""))
		var display := str(entry.get("name", "???"))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(160, 120)
		if unlocked and not tex_path.is_empty():
			var tex := load(tex_path) as Texture2D
			if tex:
				btn.icon = tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
				btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
				btn.expand_icon = true
			else:
				btn.text = display
			btn.pressed.connect(_show_preview.bind(tex_path))
		else:
			btn.text = "???"
			btn.disabled = true
		grid.add_child(btn)


func _show_preview(tex_path: String) -> void:
	var tex := load(tex_path) as Texture2D
	if tex and _preview_texture:
		_preview_texture.texture = tex
		_preview_overlay.visible = true


func _clear_grid() -> void:
	for c in grid.get_children():
		if c == empty_label:
			continue
		c.queue_free()


func apply_i18n(i18n: I18n) -> void:
	if i18n == null:
		return
	if title_label:
		title_label.text = i18n.t("title.menu.gallery", "图片鉴赏")
	if btn_back:
		btn_back.text = i18n.t("title.selectchapter.return", "返回")
	if empty_label:
		empty_label.text = i18n.t("gallery.no_items", "（暂无鉴赏内容）")
