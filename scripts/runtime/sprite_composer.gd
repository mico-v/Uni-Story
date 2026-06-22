class_name SpriteComposer extends RefCounted

## Manages named character立绘 built from layered images. A character is a
## CompositeSprite added to the world layer and registered in ObjectManager under
## its name, so move/tint/o.anim and show/hide work on it like any display object.
##
## Layer images resolve under `<resource_root><char_folder>/<layer>_<key>.png`,
## e.g. characters/renna/face_smile.png. The "body" layer takes just the folder
## base name: characters/renna/body.png (or body_<key> if a key is given).

const CHAR_ROOT := "characters/"

var _ctx: Node
var _chars: Dictionary = {}  # name -> CompositeSprite


func _init(ctx: Node) -> void:
	_ctx = ctx


func _world() -> Node2D:
	return _ctx.object_manager.objects.get("world")


func _char_dir(char_name: String) -> String:
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	return root + CHAR_ROOT + char_name + "/"


func _load_layer_texture(char_name: String, layer: String, key: Variant) -> Texture2D:
	var file := layer
	if key != null and str(key) != "":
		file = layer + "_" + str(key)
	var path := _char_dir(char_name) + file + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	push_warning("SpriteComposer: missing layer '%s'" % path)
	return null


func _get_or_create(char_name: String) -> CompositeSprite:
	if _chars.has(char_name):
		return _chars[char_name]
	var cs := CompositeSprite.new()
	cs.name = "Char_" + char_name
	var w := _world()
	if w:
		w.add_child(cs)
		_chars[char_name] = cs
	_ctx.object_manager.bind_object_runtime(char_name, cs)
	return cs


## show_char(name, layers, coord=null, color=null)
## layers: Dictionary like { body="default", face="smile", mouth="closed" }
##         or a String treated as { body=<that key> }.
func show_char(char_name: String, layers: Variant = {}, coord = null, color = null) -> void:
	var cs := _get_or_create(char_name)

	var layer_map: Dictionary = {}
	if layers is Dictionary:
		layer_map = layers
	elif layers is String:
		layer_map = {"body": layers}

	if layer_map.is_empty():
		layer_map = {"body": ""}

	for layer in layer_map:
		var tex := _load_layer_texture(char_name, str(layer), layer_map[layer])
		cs.set_layer(str(layer), tex)

	if coord != null:
		_ctx.graphics.move(cs, coord)
	if color != null:
		_ctx.graphics.tint(cs, color)
	cs.visible = true


## Swap a single layer (e.g. expression / mouth) on an existing character.
func set_layer(char_name: String, layer: String, key: Variant = "") -> void:
	var cs := _get_or_create(char_name)
	var tex := _load_layer_texture(char_name, layer, key)
	cs.set_layer(layer, tex)


func hide_char(char_name: String) -> void:
	if _chars.has(char_name):
		_chars[char_name].visible = false


## Free all character nodes and clear internal references.
## Called during reset_world() to prevent dangling references.
func clear_all() -> void:
	for char_name in _chars:
		var cs: CompositeSprite = _chars[char_name]
		if is_instance_valid(cs):
			cs.clear_layers()
			cs.queue_free()
		if _ctx.object_manager:
			_ctx.object_manager.unbind_object_runtime(char_name)
	_chars.clear()


func snapshot() -> Dictionary:
	var data := {}
	for char_name in _chars:
		var cs: CompositeSprite = _chars[char_name]
		if is_instance_valid(cs) and cs.visible:
			var state := cs.layer_state()
			if not state.is_empty():
				data[char_name] = state
	return data


func restore(data: Dictionary) -> void:
	for char_name in data:
		var layer_map: Dictionary = data[char_name]
		if layer_map.is_empty():
			continue
		var cs := _get_or_create(char_name)
		for layer in layer_map:
			var tex_path: String = str(layer_map[layer])
			if ResourceLoader.exists(tex_path):
				cs.set_layer(layer, load(tex_path))
		cs.visible = true
