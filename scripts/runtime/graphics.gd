class_name Graphics extends RefCounted

## show/hide/move/tint for display objects (bg, fg, sprites...).
## An object can be passed by node reference (`o.fg`) or by name (`"fg"`).

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx


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

	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var folder := ""
	if node.has_meta("folder"):
		folder = str(node.get_meta("folder")) + "/"
	var path := root + folder + image_path + ".png"

	var tex := _load_texture(path)
	if tex != null and node is TextureRect:
		(node as TextureRect).texture = tex
	elif tex != null and node is Sprite2D:
		(node as Sprite2D).texture = tex

	if coord != null:
		move(node, coord)
	if color != null:
		tint(node, color)
	node.visible = true


func hide(obj: Variant) -> void:
	var node := _resolve(obj)
	if node:
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
