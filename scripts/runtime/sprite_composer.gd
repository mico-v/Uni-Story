class_name SpriteComposer extends RefCounted

## Manages named character立绘 built from layered images. A character is a
## CompositeSprite added to the world layer and registered in ObjectManager under
## its name, so move/tint/o.anim and show/hide work on it like any display object.
##
## Layer images resolve under `<resource_root><char_folder>/<layer>_<key>.png`,
## e.g. characters/renna/face_smile.png. The "body" layer takes just the folder
## base name: characters/renna/body.png (or body_<key> if a key is given).

const CHAR_ROOT := "characters/"
const NOVA_STANDING_ROOT := "Standings/"
const NOVA_PIXELS_PER_UNIT := 100.0
const NOVA_LAYER_ORDER: Array[String] = ["body", "blush", "mouth", "eye", "eyebrow", "hair", "sweat", "effect"]
const NOVA_DEFAULT_POSES: Dictionary = {
	"ergong": {"normal": "body+mouth_smile+eye_normal+eyebrow_normal+hair"},
	"gaotian": {
		"normal": "body+mouth_smile+eye_normal+eyebrow_normal+hair",
		"cry": "body+mouth_smile+eye_cry+eyebrow_normal+hair",
	},
	"qianye": {"normal": "body+mouth_close+eye_normal+eyebrow_normal+hair"},
	"xiben": {"normal": "body+mouth_close+eye_normal+eyebrow_normal+hair"},
}

var _ctx: Node
var _chars: Dictionary = {}  # name -> CompositeSprite
var _nova_asset_offsets: Dictionary = {}  # "char/layer" -> Vector2


func _init(ctx: Node) -> void:
	_ctx = ctx


func _world() -> Node2D:
	return _ctx.object_manager.objects.get("world")


func _char_dir(char_name: String) -> String:
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var nova_dir := _nova_standing_dir(char_name)
	if not nova_dir.is_empty():
		return root + NOVA_STANDING_ROOT + nova_dir + "/"
	return root + CHAR_ROOT + char_name + "/"


func _nova_standing_dir(char_name: String) -> String:
	match char_name.to_lower():
		"ergong":
			return "Ergong"
		"gaotian":
			return "Gaotian"
		"qianye":
			return "Qianye"
		"xiben":
			return "Xiben"
		_:
			return ""


func is_nova_character(char_name: String) -> bool:
	return not _nova_standing_dir(char_name).is_empty()


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



func _layer_offset(char_name: String, layer: String) -> Vector2:
	if not is_nova_character(char_name):
		return Vector2.ZERO
	var key := "%s/%s" % [char_name.to_lower(), layer]
	if _nova_asset_offsets.has(key):
		return _nova_asset_offsets[key]
	var offset := _load_nova_layer_offset(char_name, layer)
	_nova_asset_offsets[key] = offset
	return offset


func _load_nova_layer_offset(char_name: String, layer: String) -> Vector2:
	var paths: Array[String] = []
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	paths.append(root + NOVA_STANDING_ROOT + _nova_standing_dir(char_name) + "/" + layer + ".asset")
	paths.append("res://Nova/Assets/Resources/Standings/%s/%s.asset" % [_nova_standing_dir(char_name), layer])
	for path in paths:
		var offset: Variant = _parse_asset_offset(path)
		if offset is Vector2:
			return offset
	return Vector2.ZERO


func _parse_asset_offset(path: String) -> Variant:
	if path.is_empty():
		return null
	var abs_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs_path):
		return null
	var text := FileAccess.get_file_as_string(abs_path)
	if text.is_empty():
		return null
	var rx := RegEx.new()
	if rx.compile(r"offset:\s*\{x:\s*([-0-9.]+),\s*y:\s*([-0-9.]+),\s*z:\s*([-0-9.]+)\}") != OK:
		return null
	var match := rx.search(text)
	if match == null:
		return null
	return Vector2(float(match.get_string(1)) * NOVA_PIXELS_PER_UNIT, -float(match.get_string(2)) * NOVA_PIXELS_PER_UNIT)


func _resolve_nova_pose_layers(char_name: String, pose: String) -> Array[String]:
	if pose.is_empty():
		return []
	if pose.find("+") != -1:
		return _normalize_nova_layers(pose.split("+", false))
	var poses: Dictionary = NOVA_DEFAULT_POSES.get(char_name.to_lower(), {})
	if poses.has(pose):
		return _normalize_nova_layers(str(poses[pose]).split("+", false))
	return _normalize_nova_layers([pose])


func _normalize_nova_layers(raw_layers: Array) -> Array[String]:
	var layers: Array[String] = []
	for item in raw_layers:
		var layer := str(item).strip_edges()
		if layer.is_empty():
			continue
		layers.append(layer)
	layers.sort_custom(func(a: String, b: String) -> bool:
		return _nova_layer_order_index(a) < _nova_layer_order_index(b)
	)
	return layers


func _nova_layer_order_index(layer_name: String) -> int:
	var idx := NOVA_LAYER_ORDER.find(layer_name)
	if idx != -1:
		return idx
	if layer_name.begins_with("body"):
		return 0
	if layer_name.begins_with("blush"):
		return 1
	if layer_name.begins_with("mouth"):
		return 2
	if layer_name.begins_with("eyebrow"):
		return 4
	if layer_name.begins_with("eye"):
		return 3
	if layer_name.begins_with("hair"):
		return 5
	if layer_name.begins_with("sweat"):
		return 6
	return 100


func _nova_layer_group(layer_name: String) -> String:
	if layer_name.begins_with("eyebrow"):
		return "eyebrow"
	if layer_name.begins_with("eye"):
		return "eye"
	if layer_name.begins_with("mouth"):
		return "mouth"
	if layer_name.begins_with("hair"):
		return "hair"
	if layer_name.begins_with("body"):
		return "body"
	if layer_name.begins_with("blush"):
		return "blush"
	if layer_name.begins_with("sweat"):
		return "sweat"
	return layer_name


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
	if is_nova_character(char_name):
		cs.set_layer_order(NOVA_LAYER_ORDER)

	var layer_map: Dictionary = {}
	if is_nova_character(char_name):
		var pose_layers: Array[String] = []
		if layers is Dictionary:
			for layer in layers:
				var layer_name := str(layer)
				if str(layers[layer]) == "":
					pose_layers.append(layer_name)
				else:
					pose_layers.append(layer_name + "_" + str(layers[layer]))
		elif layers is String:
			pose_layers = _resolve_nova_pose_layers(char_name, layers)
		elif layers is Array:
			for item in layers:
				pose_layers.append(str(item))
		else:
			pose_layers = _resolve_nova_pose_layers(char_name, "normal")
		var normalized_layers := _normalize_nova_layers(pose_layers)
		cs.hide_layers_except(normalized_layers)
		for layer_name in normalized_layers:
			var tex := _load_layer_texture(char_name, layer_name, null)
			cs.set_layer(layer_name, tex, _layer_offset(char_name, layer_name))
	else:
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


func move_char(char_name: String, coord: Variant, scale = null, angle = null) -> void:
	var cs := _get_or_create(char_name)
	_ctx.graphics.move(cs, coord, scale, angle)


func tint_char(char_name: String, color: Variant) -> void:
	var cs := _get_or_create(char_name)
	_ctx.graphics.tint(cs, color)


## Swap a single layer (e.g. expression / mouth) on an existing character.
func set_layer(char_name: String, layer: String, key: Variant = "") -> void:
	var cs := _get_or_create(char_name)
	var tex := _load_layer_texture(char_name, layer, key)
	var layer_name := layer if key == null or str(key).is_empty() else layer + "_" + str(key)
	var target_layer := layer_name if is_nova_character(char_name) else layer
	if is_nova_character(char_name):
		cs.hide_layer_group(_nova_layer_group(target_layer))
	var offset := _layer_offset(char_name, target_layer)
	cs.set_layer(target_layer, tex, offset)


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
				cs.set_layer(layer, load(tex_path), _layer_offset(char_name, str(layer)))
		cs.visible = true
