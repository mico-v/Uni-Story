class_name NovaAnimationCompat extends RefCounted

## Small compatibility proxy for Nova's Lua `anim:*` chains.
##
## Phase 2 playback compatibility focuses on accepting upstream scenario syntax
## without crashing. Methods map simple operations to current runtime systems and
## return `self` so Nova-style chained calls keep compiling.

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx


func move(obj: Variant, coord: Variant = null, _duration: Variant = null, _easing: Variant = null) -> NovaAnimationCompat:
	if coord != null and _ctx and _ctx.graphics:
		_ctx.graphics.move(obj, coord)
	return self


func tint(obj: Variant, color: Variant = null, _duration: Variant = null, _easing: Variant = null) -> NovaAnimationCompat:
	if color != null and _ctx and _ctx.graphics:
		_ctx.graphics.tint(obj, color)
	return self


func volume(_target: Variant, _volume: Variant = null, _duration: Variant = null) -> NovaAnimationCompat:
	return self


func fade_out(target: Variant = null, duration: Variant = 0.0) -> NovaAnimationCompat:
	if str(target) == "bgm" and _ctx and _ctx.audio:
		_ctx.audio.stop_bgm(_to_float(duration, 0.0))
	return self


func fade_in(target: Variant = null, path: Variant = "", _volume: Variant = null, duration: Variant = 0.0) -> NovaAnimationCompat:
	if str(target) == "bgm" and _ctx and _ctx.has_method("play"):
		_ctx.play("bgm", str(path), _to_float(duration, 0.0))
	return self


func wait(_seconds: Variant = 0.0) -> NovaAnimationCompat:
	return self


func wait_all(_target: Variant = null) -> NovaAnimationCompat:
	return self


func action(callable_or_obj: Variant = null, arg1: Variant = null, arg2: Variant = null, arg3: Variant = null) -> NovaAnimationCompat:
	if callable_or_obj is Callable:
		callable_or_obj.call()
	elif _ctx and _ctx.has_method("show") and callable_or_obj != null:
		_ctx.show(callable_or_obj, arg1, arg2, arg3)
	return self


func _and() -> NovaAnimationCompat:
	return self


func stop() -> NovaAnimationCompat:
	return self


func loop(_callable: Variant = null) -> NovaAnimationCompat:
	return self


func trans(target: Variant = null, image_or_action: Variant = null, _kind: Variant = "fade", _duration: Variant = 0.0, _params: Variant = {}, _extra: Variant = null) -> NovaAnimationCompat:
	_apply_transition_target(target, image_or_action)
	return self


func trans2(target: Variant = null, image_or_action: Variant = null, kind: Variant = "fade", duration: Variant = 0.0, params: Variant = {}, extra: Variant = null) -> NovaAnimationCompat:
	return trans(target, image_or_action, kind, duration, params)


func trans_fade(target: Variant = null, image_or_action: Variant = null, duration: Variant = 0.0, params: Variant = {}) -> NovaAnimationCompat:
	return trans(target, image_or_action, "fade", duration, params)


func trans_left(target: Variant = null, image_or_action: Variant = null, duration: Variant = 0.0, params: Variant = {}) -> NovaAnimationCompat:
	return trans(target, image_or_action, "left", duration, params)


func trans_right(target: Variant = null, image_or_action: Variant = null, duration: Variant = 0.0, params: Variant = {}) -> NovaAnimationCompat:
	return trans(target, image_or_action, "right", duration, params)


func trans_up(target: Variant = null, image_or_action: Variant = null, duration: Variant = 0.0, params: Variant = {}) -> NovaAnimationCompat:
	return trans(target, image_or_action, "up", duration, params)


func trans_down(target: Variant = null, image_or_action: Variant = null, duration: Variant = 0.0, params: Variant = {}) -> NovaAnimationCompat:
	return trans(target, image_or_action, "down", duration, params)


func vfx(target: Variant = null, effect: Variant = "", _range: Variant = null, duration: Variant = 0.5, params: Variant = {}, _extra: Variant = null) -> NovaAnimationCompat:
	if _ctx and _ctx.vfx:
		_ctx.vfx.play(str(effect), target, _to_float(duration, 0.5), params if params is Dictionary else {})
	return self


func vfx_multi(target: Variant = null, effect: Variant = "", duration: Variant = 0.5, params: Variant = {}) -> NovaAnimationCompat:
	return vfx(target, effect, null, duration, params)


func cam_punch() -> NovaAnimationCompat:
	if _ctx and _ctx.vfx:
		_ctx.vfx.shake(8.0, 0.2)
	return self


func box_anchor(_anchor: Variant = null, _duration: Variant = null, _easing: Variant = null) -> NovaAnimationCompat:
	return self


func box_tint(_color: Variant = null, _duration: Variant = null) -> NovaAnimationCompat:
	return self


func _apply_transition_target(target: Variant, image_or_action: Variant) -> void:
	if image_or_action is Callable:
		image_or_action.call()
		return
	if image_or_action == null:
		return
	var target_name := str(target)
	if target_name == "cam" or target_name == "cam2" or target_name == "cam_mask":
		return
	if _ctx and _ctx.has_method("show"):
		_ctx.show(target_name, str(image_or_action))


func _to_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback
