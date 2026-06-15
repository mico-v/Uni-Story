class_name AnimationChain extends RefCounted

signal finished

## One sequential animation sequence backed by a single Tween. Chained calls
## (`.PropertyVector3(...).PropertyColor(...)`) append steps that play one after
## another. A separate `o.anim...` statement builds a separate chain, and Godot
## runs separate tweens concurrently — giving the "chained = sequential,
## separate statements = parallel" semantics the scenarios rely on.

var _ctx: Node
var _tween: Tween
var _is_finished := false


func _init(ctx: Node) -> void:
	_ctx = ctx
	_tween = ctx.get_tree().create_tween()
	_tween.set_parallel(false)
	_tween.finished.connect(_on_tween_finished)


func _resolve(obj: Variant) -> CanvasItem:
	if obj is CanvasItem:
		return obj
	if obj is String or obj is StringName:
		var objects: Dictionary = _ctx.object_manager.objects
		if objects.has(str(obj)):
			return objects[str(obj)]
	return null


static func _map_vec3(prop: String, v: Vector3) -> Variant:
	match prop:
		"position", "scale":
			return Vector2(v.x, v.y)
		"rotation_degrees":
			return v.z
		_:
			return v


func _step(node: CanvasItem, prop: String, final: Variant, duration: float, immediate: bool) -> void:
	if node == null:
		return
	if immediate or duration <= 0.0:
		_tween.tween_callback(node.set.bind(prop, final))
	else:
		_tween.tween_property(node, prop, final, duration)


func PropertyVector3(obj: Variant, prop: String, value: Vector3, duration: float = 0.5, immediate: bool = false) -> AnimationChain:
	_step(_resolve(obj), prop, _map_vec3(prop, value), duration, immediate)
	return self


func PropertyColor(obj: Variant, prop: String, value: Color, duration: float = 0.5, immediate: bool = false) -> AnimationChain:
	_step(_resolve(obj), prop, value, duration, immediate)
	return self


func Delay(seconds: float) -> AnimationChain:
	_tween.tween_interval(seconds)
	return self


## Returns whether the chain is still running.
func is_running() -> bool:
	return not _is_finished


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_is_finished = true


## Awaitable helper used by runtime wrappers that want to wait for the chain to
## finish before continuing the story.
func await_finished() -> void:
	if _is_finished:
		return
	if _tween == null:
		_is_finished = true
		return
	await _tween.finished
	_is_finished = true


func _on_tween_finished() -> void:
	_is_finished = true
	emit_signal("finished")
