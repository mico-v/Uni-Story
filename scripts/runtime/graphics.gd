class_name Graphics extends RefCounted

## show/hide/move/tint for display objects (bg, fg, sprites...).
## An object can be passed by node reference (`o.fg`) or by name (`"fg"`).

var _ctx: Node
var _visual_profile: Resource = null


func _init(ctx: Node) -> void:
	_ctx = ctx


func configure(profile: Resource) -> void:
	_visual_profile = profile


func _resolve(obj: Variant) -> CanvasItem:
	if obj is CanvasItem:
		return obj
	if obj is String or obj is StringName:
		var objects: Dictionary = _ctx.object_manager.objects
		var key := str(obj)
		if objects.has(key) and objects[key] is CanvasItem:
			return objects[key]
	push_warning("Graphics: unknown display object '%s'" % str(obj))
	return null


func show(obj: Variant, image_path: String, coord = null, color = null) -> void:
	var node := _resolve(obj)
	if node == null:
		return
	var obj_name: String = str(obj)
	var image_name := _resolve_image_name(str(obj), image_path)
	if image_name.find("+") != -1:
		_show_composite(node, image_name, coord, color)
		return

	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var folder := ""
	if node.has_meta("folder"):
		folder = str(node.get_meta("folder")) + "/"
	var path := root + folder + image_name + ".png"

	var tex := _load_texture(path)
	if tex == null:
		return
	if tex != null and node is TextureRect:
		(node as TextureRect).texture = tex
	elif tex != null and node is Sprite2D:
		_hide_composite_layers(node as Sprite2D)
		(node as Sprite2D).texture = tex

	if _should_auto_fit_fullscreen(obj_name, coord):
		_fit_cover(node, tex)
		node.set_meta("graphics_auto_fit_fullscreen", true)
	elif coord != null:
		node.set_meta("graphics_auto_fit_fullscreen", false)
		move(node, coord)
	else:
		node.set_meta("graphics_auto_fit_fullscreen", false)
	if color != null:
		tint(node, color)
	else:
		node.modulate = Color.WHITE
	node.visible = true
	# Auto-unlock CG gallery entry if this image matches a gallery CG.
	if _ctx.has_method("unlock_cg_by_path"):
		_ctx.unlock_cg_by_path(path)


func _resolve_image_name(obj_name: String, image_path: String) -> String:
	if obj_name == "cg":
		var pose := image_path.strip_edges()
		if pose.begins_with("cg/"):
			pose = pose.substr(3)
		pose = _resolve_visual_alias(obj_name, pose)
		return _prefix_composite_parts("cg", pose)
	return image_path.strip_edges()


func _resolve_visual_alias(obj_name: String, image_name: String) -> String:
	if _visual_profile != null and _visual_profile.has_method("resolve_image_alias"):
		return str(_visual_profile.call("resolve_image_alias", obj_name, image_name))
	return image_name


func _prefix_composite_parts(folder: String, image_name: String) -> String:
	var out: Array[String] = []
	for raw_part in image_name.split("+", false):
		var part := str(raw_part).strip_edges()
		if part.is_empty():
			continue
		if part.begins_with("res://") or part.find("/") != -1:
			out.append(part)
		else:
			out.append("%s/%s" % [folder, part])
	var joined := ""
	for part in out:
		if not joined.is_empty():
			joined += "+"
		joined += part
	return joined


func _show_composite(node: CanvasItem, image_name: String, coord = null, color = null) -> void:
	if node is Sprite2D:
		var spr := node as Sprite2D
		var parts: PackedStringArray = image_name.split("+", false)
		if parts.is_empty():
			return
		var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
		var folder := ""
		if node.has_meta("folder"):
			folder = str(node.get_meta("folder")) + "/"
		var base_path := root + folder + str(parts[0]) + ".png"
		var base_tex := _load_texture(base_path)
		if base_tex:
			spr.texture = base_tex
		else:
			return
		var base_size: Vector2 = base_tex.get_size()
		var overlay_origin: Vector2 = base_size * 0.5
		if spr.centered:
			overlay_origin = Vector2.ZERO
		var used_overlay_count: int = maxi(0, parts.size() - 1)
		for i in range(1, parts.size()):
			var overlay_path := root + folder + str(parts[i]) + ".png"
			var overlay_tex := _load_texture(overlay_path)
			var overlay := _ensure_composite_layer(spr, i - 1)
			overlay.texture = overlay_tex
			overlay.position = overlay_origin
			overlay.visible = overlay_tex != null
		_hide_composite_layers(spr, used_overlay_count)
		if coord != null:
			node.set_meta("graphics_auto_fit_fullscreen", false)
			move(node, coord)
		elif str(node.name).to_lower() == "foreground" and image_name.begins_with("cg/"):
			_fit_cover(node, base_tex)
			node.set_meta("graphics_auto_fit_fullscreen", true)
		if color != null:
			tint(node, color)
		else:
			node.modulate = Color.WHITE
		node.visible = true
		if _ctx.has_method("unlock_cg_by_path"):
			_ctx.unlock_cg_by_path(base_path)


func _ensure_composite_layer(parent: Sprite2D, layer_index: int) -> Sprite2D:
	var child_name := "CompositeLayer%d" % layer_index
	var existing := parent.get_node_or_null(child_name)
	if existing is Sprite2D:
		return existing as Sprite2D
	var layer := Sprite2D.new()
	layer.name = child_name
	layer.centered = true
	layer.z_index = layer_index + 1
	layer.set_meta("graphics_composite_layer", layer_index)
	parent.add_child(layer)
	return layer


func _hide_composite_layers(parent: Sprite2D, used_count: int = 0) -> void:
	for child in parent.get_children():
		if child is Sprite2D and child.has_meta("graphics_composite_layer"):
			var layer_index := int(child.get_meta("graphics_composite_layer"))
			if layer_index >= used_count:
				var layer := child as Sprite2D
				layer.texture = null
				layer.visible = false


func hide(obj: Variant) -> void:
	var node := _resolve(obj)
	if node:
		if node is Sprite2D:
			_hide_composite_layers(node as Sprite2D)
		node.visible = false


func move(obj: Variant, coord: Variant, scale = null, angle = null) -> void:
	var node := _resolve(obj)
	if node == null:
		return

	# Coord array can carry [x, y, scale, ?, angle] like the original scripts.
	if coord is Array:
		var arr := coord as Array
		if scale == null and arr.size() > 2 and _is_num(arr[2]):
			scale = float(arr[2])
		if angle == null and arr.size() > 4 and _is_num(arr[4]):
			angle = float(arr[4])
		if arr.size() >= 2 and _is_num(arr[0]) and _is_num(arr[1]):
			node.position = Vector2(float(arr[0]), float(arr[1]))
	elif coord is Vector2:
		node.position = coord
	elif coord is Vector3:
		node.position = Vector2(coord.x, coord.y)

	if scale != null:
		if _is_num(scale):
			node.scale = Vector2(float(scale), float(scale))
		elif scale is Vector2:
			node.scale = scale
		elif scale is Vector3:
			node.scale = Vector2(scale.x, scale.y)
	if angle != null:
		if _is_num(angle):
			node.rotation_degrees = float(angle)
		elif angle is Vector3:
			node.rotation_degrees = angle.z


func tint(obj: Variant, color: Variant) -> void:
	var node := _resolve(obj)
	if node == null:
		return
	node.modulate = _to_color(color)


func fit_fullscreen_objects() -> void:
	var objects: Dictionary = _ctx.object_manager.objects
	for key in objects:
		var node = objects[key]
		if not (node is CanvasItem):
			continue
		if not bool((node as CanvasItem).get_meta("graphics_auto_fit_fullscreen", false)):
			continue
		var tex: Texture2D = _texture_for_node(node as CanvasItem)
		if tex != null:
			_fit_cover(node as CanvasItem, tex)


static func _to_color(color: Variant) -> Color:
	if color is Color:
		return color
	if color is Array:
		var a := color as Array
		var r := float(a[0]) if a.size() > 0 else 1.0
		var g := float(a[1]) if a.size() > 1 else 1.0
		var b := float(a[2]) if a.size() > 2 else 1.0
		var al := float(a[3]) if a.size() > 3 else 1.0
		return Color(r, g, b, al)
	return Color.WHITE


static func _is_num(v: Variant) -> bool:
	return v is int or v is float


func _should_auto_fit_fullscreen(obj_name: String, coord: Variant) -> bool:
	if coord != null:
		return false
	return obj_name == "bg" or obj_name == "cg"


func _fit_cover(node: CanvasItem, texture: Texture2D) -> void:
	if texture == null:
		return
	var viewport_size: Vector2 = _ctx.get_viewport().get_visible_rect().size
	var texture_size: Vector2 = texture.get_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var fit_scale: float = maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
	if node is Sprite2D:
		var sprite: Sprite2D = node as Sprite2D
		sprite.centered = false
		sprite.scale = Vector2(fit_scale, fit_scale)
		sprite.position = (viewport_size - texture_size * fit_scale) * 0.5
	elif node is TextureRect:
		var rect: TextureRect = node as TextureRect
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.offset_left = 0.0
		rect.offset_top = 0.0
		rect.offset_right = 0.0
		rect.offset_bottom = 0.0
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func _texture_for_node(node: CanvasItem) -> Texture2D:
	if node is Sprite2D:
		return (node as Sprite2D).texture
	if node is TextureRect:
		return (node as TextureRect).texture
	return null


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	# Fallback for assets not imported by the editor.
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img:
			return ImageTexture.create_from_image(img)
	push_warning("Graphics: texture not found '%s'" % path)
	return null


## Capture all display object states for saving.
func snapshot() -> Dictionary:
	var state: Dictionary = {}
	var objects: Dictionary = _ctx.object_manager.objects
	for key in objects:
		var node = objects[key]
		if node is CanvasItem:
			state[key] = {
				"visible": node.visible,
				"position": [node.position.x, node.position.y],
				"scale": [node.scale.x, node.scale.y],
				"rotation": node.rotation_degrees,
				"modulate": [node.modulate.r, node.modulate.g, node.modulate.b, node.modulate.a],
				"texture_path": _get_texture_path(node),
			}
	return state


## Restore display object states from a snapshot.
func restore(data: Dictionary) -> void:
	if not data is Dictionary:
		return
	var objects: Dictionary = _ctx.object_manager.objects
	for key in data:
		if not objects.has(key):
			continue
		var node = objects[key]
		if not node is CanvasItem:
			continue
		var obj_state: Dictionary = data[key]
		if obj_state.has("visible"):
			node.visible = bool(obj_state["visible"])
		if obj_state.has("position"):
			var p = obj_state["position"]
			if p is Array and p.size() >= 2:
				node.position = Vector2(float(p[0]), float(p[1]))
		if obj_state.has("scale"):
			var s = obj_state["scale"]
			if s is Array and s.size() >= 2:
				node.scale = Vector2(float(s[0]), float(s[1]))
		if obj_state.has("rotation"):
			node.rotation_degrees = float(obj_state["rotation"])
		if obj_state.has("modulate"):
			var m = obj_state["modulate"]
			if m is Array and m.size() >= 4:
				node.modulate = Color(float(m[0]), float(m[1]), float(m[2]), float(m[3]))
		if obj_state.has("texture_path"):
			var tp := str(obj_state["texture_path"])
			if not tp.is_empty():
				var tex := _load_texture(tp)
				if tex:
					if node is Sprite2D:
						(node as Sprite2D).texture = tex
					elif node is TextureRect:
						(node as TextureRect).texture = tex


func _get_texture_path(node: CanvasItem) -> String:
	if node is TextureRect:
		var tex_rect := node as TextureRect
		if tex_rect.texture:
			return tex_rect.texture.resource_path
	elif node is Sprite2D:
		var spr := node as Sprite2D
		if spr.texture:
			return spr.texture.resource_path
	return ""
