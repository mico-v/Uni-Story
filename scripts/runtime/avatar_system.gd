class_name AvatarSystem extends RefCounted

## A speaker portrait shown inside the dialogue box. Resolves
## characters/<char>/avatar_<key>.png (or avatar.png). The avatar TextureRect is
## registered in ObjectManager under "avatar"; the controller shifts the dialogue
## text aside while a portrait is visible.

signal avatar_changed(visible: bool)

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx


func _node() -> TextureRect:
	var a = _ctx.object_manager.objects.get("avatar")
	return a if a is TextureRect else null


func set_avatar(char_name: String, key: Variant = "") -> void:
	var node := _node()
	if node == null:
		return
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var file := "avatar"
	if key != null and str(key) != "":
		file = "avatar_" + str(key)
	var path := root + SpriteComposer.CHAR_ROOT + char_name + "/" + file + ".png"
	var tex := _load(path)
	if tex == null:
		clear_avatar()
		return
	node.texture = tex
	node.visible = true
	avatar_changed.emit(true)


func clear_avatar() -> void:
	var node := _node()
	if node:
		node.visible = false
	avatar_changed.emit(false)


func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	push_warning("AvatarSystem: avatar not found '%s'" % path)
	return null
