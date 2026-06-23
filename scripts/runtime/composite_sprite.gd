class_name CompositeSprite extends Node2D

## A layered character sprite (立绘). Holds an ordered set of named layers, each
## a Sprite2D, drawn back-to-front. Swapping one layer (e.g. "face" expression or
## "mouth") leaves the others untouched. Being a Node2D it is a CanvasItem, so
## move/tint/o.anim operate on the whole character via its position/scale/modulate.

## Default draw order; lower index = drawn first (behind).
const DEFAULT_LAYER_ORDER: Array[String] = ["body", "clothes", "face", "mouth", "effect"]

var _layers: Dictionary = {}  # layer_name -> Sprite2D
var _order: Array[String] = DEFAULT_LAYER_ORDER.duplicate()


func _ensure_layer(layer_name: String) -> Sprite2D:
	if _layers.has(layer_name):
		return _layers[layer_name]
	var spr := Sprite2D.new()
	spr.name = "Layer_" + layer_name
	spr.centered = true
	add_child(spr)
	_layers[layer_name] = spr
	_reorder()
	return spr


func _reorder() -> void:
	# Apply z ordering by the configured layer order; unknown layers go on top.
	for layer_name in _layers:
		var idx := _order.find(layer_name)
		if idx == -1:
			idx = _order.size()
		(_layers[layer_name] as Sprite2D).z_index = idx


## Set (or replace) a layer's texture. Pass null to clear that layer.
func set_layer(layer_name: String, texture: Texture2D) -> void:
	if texture == null:
		if _layers.has(layer_name):
			_layers[layer_name].visible = false
		return
	var spr := _ensure_layer(layer_name)
	spr.texture = texture
	spr.visible = true


func has_layer(layer_name: String) -> bool:
	return _layers.has(layer_name)


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
