class_name AnimationSystem extends RefCounted

## Implements the chainable `o.anim` API used by presentation scripts:
##
##   o.anim.PropertyVector3(o.fg, "position", Vector3(1,1,0), 0.5, false)
##          .PropertyColor(o.fg, "modulate", Color(1,1,1,0.5), 1.0, false)
##
## Each call appends a step. Chained calls on the same `o.anim` run
## SEQUENTIALLY; separate `o.anim...` statements run in PARALLEL (each starts a
## fresh chain). The boolean last arg is `immediate` (skip tween, set instantly).
##
## Property names are in display-space (Vector2 position/scale, Color modulate).
## Vector3 z is used for rotation_degrees; x/y for position/scale.

var _ctx: Node
var _tree: SceneTree

# The chain currently being built. Reset whenever a new top-level statement
# touches o.anim (detected by a one-frame deferred flush).
var _active_tween: Tween = null


func _init(ctx: Node) -> void:
	_ctx = ctx
	_tree = ctx.get_tree()


func _resolve(obj: Variant) -> CanvasItem:
	if obj is CanvasItem:
		return obj
	if obj is String or obj is StringName:
		var objects: Dictionary = _ctx.object_manager.objects
		if objects.has(str(obj)):
			return objects[str(obj)]
	return null


func _ensure_tween() -> Tween:
	if _active_tween != null and _active_tween.is_valid():
		return _active_tween
	_active_tween = _tree.create_tween()
	_active_tween.set_parallel(false)
	# Drop the reference next idle frame so a new statement starts a fresh
	# (parallel) chain, while chained .X().Y() calls reuse this one.
	_clear_next_frame()
	return _active_tween


func _clear_next_frame() -> void:
	# Defer clearing so chained calls in the same statement share the tween.
	if not _tree.process_frame.is_connected(_on_idle):
		_tree.process_frame.connect(_on_idle, CONNECT_ONE_SHOT)


func _on_idle() -> void:
	_active_tween = null


func PropertyVector3(obj: Variant, prop: String, value: Vector3, duration: float = 0.5, immediate: bool = false) -> AnimationSystem:
	var node := _resolve(obj)
	if node == null:
		return self
	var final = _map_vec3(prop, value)
	_apply(node, prop, final, duration, immediate)
	return self


func PropertyColor(obj: Variant, prop: String, value: Color, duration: float = 0.5, immediate: bool = false) -> AnimationSystem:
	var node := _resolve(obj)
	if node == null:
		return self
	_apply(node, prop, value, duration, immediate)
	return self


func _map_vec3(prop: String, v: Vector3) -> Variant:
	match prop:
		"position", "scale":
			return Vector2(v.x, v.y)
		"rotation_degrees":
			return v.z
		_:
			return v


func _apply(node: CanvasItem, prop: String, final: Variant, duration: float, immediate: bool) -> void:
	if immediate or duration <= 0.0:
		node.set(prop, final)
		return
	var tween := _ensure_tween()
	tween.tween_property(node, prop, final, duration)


func wait(seconds: float) -> void:
	var tween := _ensure_tween()
	tween.tween_interval(seconds)
