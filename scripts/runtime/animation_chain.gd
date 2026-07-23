class_name AnimationChain extends RefCounted

signal finished

## One sequential animation sequence backed by a single Tween. Chained calls
## (`.PropertyVector3(...).PropertyColor(...)`) append steps that play one after
## another. A separate `o.anim...` statement builds a separate chain, and Godot
## runs separate tweens concurrently — giving the "chained = sequential,
## separate statements = parallel" semantics the scenarios rely on.
##
## Phase 6: adds animation domain, pause/resume, easing parser, and more
## property types (float, vector2, rotation, scale, alpha).

var _ctx: Node
var _tween: Tween
var _is_finished := false
var _is_paused := false

## Animation domain (from AnimationSystem.Domain enum).
var domain: int = 0  # PER_DIALOGUE
## Named holding group (only meaningful when domain == HOLDING).
var holding_group: String = ""
## Easing string for the next step.
var easing_str: String = ""


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


func _step_tween(node: CanvasItem, prop: String, final: Variant, duration: float) -> PropertyTweener:
	if node == null:
		return null
	var pt := _tween.tween_property(node, prop, final, duration)
	if not easing_str.is_empty():
		var parsed := AnimationSystem.parse_easing(easing_str)
		easing_str = ""
		if parsed[0] >= 0:
			pt.set_ease(parsed[0])
		if parsed[1] >= 0:
			pt.set_trans(parsed[1])
	return pt


func _step(node: CanvasItem, prop: String, final: Variant, duration: float, immediate: bool) -> void:
	if node == null:
		return
	if immediate or duration <= 0.0:
		_tween.tween_callback(node.set.bind(prop, final))
	else:
		_step_tween(node, prop, final, duration)


# ── Then / And ─────────────────────────────────────────────────────────

## Explicit `then` — ensure sequential ordering (same as chaining, but explicit).
func then() -> AnimationChain:
	return self


## Start a parallel branch. Subsequent chained calls in the returned object
## will run concurrently with this chain's remaining steps.
func and_anim() -> AnimationChain:
	# Create a new chain that shares the same completion tracking.
	var parallel := AnimationChain.new(_ctx)
	parallel.domain = domain
	parallel.holding_group = holding_group
	_ctx.animation._track(parallel)
	return parallel


# ── Property methods ────────────────────────────────────────────────────

func PropertyFloat(obj: Variant, prop: String, value: float, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), prop, value, duration, false)
	return self


func PropertyVector2(obj: Variant, prop: String, value: Vector2, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), prop, value, duration, false)
	return self


func PropertyVector3(obj: Variant, prop: String, value: Vector3, duration: float = 0.5, immediate: bool = false) -> AnimationChain:
	_step(_resolve(obj), prop, _map_vec3(prop, value), duration, immediate)
	return self


func PropertyColor(obj: Variant, prop: String, value: Color, duration: float = 0.5, immediate: bool = false) -> AnimationChain:
	_step(_resolve(obj), prop, value, duration, immediate)
	return self


func MoveTo(obj: Variant, pos: Vector2, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), "position", pos, duration, false)
	return self


func FadeTo(obj: Variant, alpha: float, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), "modulate:a", clampf(alpha, 0.0, 1.0), duration, false)
	return self


func RotateTo(obj: Variant, degrees: float, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), "rotation_degrees", degrees, duration, false)
	return self


func ScaleTo(obj: Variant, scale: Vector2, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), "scale", scale, duration, false)
	return self


func TintTo(obj: Variant, color: Color, duration: float = 0.5) -> AnimationChain:
	_step(_resolve(obj), "modulate", color, duration, false)
	return self


func Delay(seconds: float) -> AnimationChain:
	_tween.tween_interval(seconds)
	return self


# ── Pause / Resume / Stop ──────────────────────────────────────────────

func pause() -> void:
	if _is_finished or _is_paused:
		return
	_is_paused = true
	if _tween and _tween.is_valid():
		_tween.pause()


func resume() -> void:
	if not _is_paused:
		return
	_is_paused = false
	if _tween and _tween.is_valid():
		_tween.play()


func is_running() -> bool:
	return not _is_finished


func stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_is_finished = true
	_is_paused = false


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
	finished.emit()
