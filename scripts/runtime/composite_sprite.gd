class_name CompositeSprite extends Node2D

## A layered character sprite (立绘). Holds an ordered set of named layers, each
## a Sprite2D, drawn back-to-front. Swapping one layer (e.g. "face" expression or
## "mouth") leaves the others untouched. Being a Node2D it is a CanvasItem, so
## move/tint/o.anim operate on the whole character via its position/scale/modulate.

## Default draw order; lower index = drawn first (behind).
const DEFAULT_LAYER_ORDER: Array[String] = ["hair", "body", "clothes", "face", "eye", "eyebrow", "mouth", "blush", "effect"]

var _layers: Dictionary = {}  # layer_name -> Sprite2D
var _order: Array[String] = DEFAULT_LAYER_ORDER.duplicate()


func _ensure_layer(layer_name: String) -> Sprite2D:
	if _layers.has(layer_name):
		return _layers[layer_name]
	var spr := Sprite2D.new()
	spr.name = "Layer_" + layer_name
	spr.centered = true
	spr.z_as_relative = true
	spr.z_index = 0
	add_child(spr)
	_layers[layer_name] = spr
	_reorder()
	return spr


func _reorder() -> void:
	# Keep layer ordering local to this character. Using child z_index here can
	# make a character draw above the HUD; tree order is enough inside one sprite.
	var ordered_names: Array[String] = []
	for layer_name in _layers:
		ordered_names.append(str(layer_name))
	ordered_names.sort_custom(func(a: String, b: String) -> bool:
		var a_idx := _layer_order_index(a)
		var b_idx := _layer_order_index(b)
		if a_idx == b_idx:
			return a < b
		return a_idx < b_idx
	)
	for i in range(ordered_names.size()):
		var spr: Sprite2D = _layers[ordered_names[i]]
		spr.z_index = 0
		move_child(spr, i)


func _layer_order_index(layer_name: String) -> int:
	var exact_idx := _order.find(layer_name)
	if exact_idx != -1:
		return exact_idx
	for i in range(_order.size()):
		var group_name := _order[i]
		if not group_name.is_empty() and layer_name.begins_with(group_name + "_"):
			return i
	return _order.size()


func set_layer_order(layer_order: Array[String]) -> void:
	_order = layer_order.duplicate() if not layer_order.is_empty() else DEFAULT_LAYER_ORDER.duplicate()
	_reorder()


func hide_layers_except(layer_names: Array[String]) -> void:
	for layer_name in _layers:
		if not layer_names.has(layer_name):
			var spr: Sprite2D = _layers[layer_name]
			spr.texture = null
			spr.visible = false


func hide_layer_group(group_name: String) -> void:
	for layer_name in _layers:
		if layer_name == group_name or str(layer_name).begins_with(group_name + "_"):
			var spr: Sprite2D = _layers[layer_name]
			spr.texture = null
			spr.visible = false


## Set (or replace) a layer's texture. Pass null to clear that layer.
func set_layer(layer_name: String, texture: Texture2D, offset: Vector2 = Vector2.ZERO, layer_scale: Vector2 = Vector2.ONE) -> void:
	if texture == null:
		if _layers.has(layer_name):
			var existing: Sprite2D = _layers[layer_name]
			existing.texture = null
			existing.visible = false
		return
	var spr := _ensure_layer(layer_name)
	spr.texture = texture
	spr.position = offset
	spr.scale = layer_scale
	spr.visible = true


func has_layer(layer_name: String) -> bool:
	return _layers.has(layer_name)


func has_visible_layer(layer_name: String) -> bool:
	if not _layers.has(layer_name):
		return false
	var spr: Sprite2D = _layers[layer_name]
	return spr.visible and spr.texture != null


func visible_layer_count() -> int:
	var count := 0
	for layer_name in _layers:
		if has_visible_layer(layer_name):
			count += 1
	return count


func layer_position(layer_name: String) -> Vector2:
	if not _layers.has(layer_name):
		return Vector2.ZERO
	return (_layers[layer_name] as Sprite2D).position


func clear_layers() -> void:
	for spr in _layers.values():
		spr.queue_free()
	_layers.clear()


## Report the snapshot of which texture each layer currently uses (for save).
func layer_state() -> Dictionary:
	var out := {}
	for layer_name in _layers:
		var spr: Sprite2D = _layers[layer_name]
		if spr.visible and spr.texture:
			out[layer_name] = spr.texture.resource_path
	return out
