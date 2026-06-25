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
	if coord != null:
		_move_target(obj, coord)
	return self


func tint(obj: Variant, color: Variant = null, _duration: Variant = null, _easing: Variant = null) -> NovaAnimationCompat:
	if color != null:
		_tint_target(obj, color)
	return self


func volume(_target: Variant, _volume: Variant = null, _duration: Variant = null) -> NovaAnimationCompat:
	return self


func fade_out(target: Variant = null, duration: Variant = 0.0) -> NovaAnimationCompat:
	if str(target) == "bgm" and _ctx and _ctx.audio:
		_ctx.audio.stop_bgm(_to_float(duration, 0.0))
	elif str(target) == "bgs" and _ctx and _ctx.audio:
		_ctx.audio.stop_se()
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
		var args: Array = []
		for arg in [arg1, arg2, arg3]:
			args.append(arg)
		while not args.is_empty() and args.back() == null:
			args.pop_back()
		callable_or_obj.callv(args)
		return self
	var action_name := str(callable_or_obj)
	match action_name:
		"show":
			_show_target(arg1, str(arg2), arg3)
		"hide":
			_hide_target(arg1)
		"vfx":
			_play_vfx(arg1, arg2, arg3)
		"video_hide":
			if _ctx and _ctx.video_system:
				_ctx.video_system.stop()
		_:
			if callable_or_obj != null:
				_show_target(callable_or_obj, str(arg1), arg2)
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
	_play_vfx(target, effect, _range, duration, params)
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
	_show_target(target_name, str(image_or_action))


func _move_target(obj: Variant, coord: Variant) -> void:
	if _is_nova_character(str(obj)) and _ctx and _ctx.composer:
		_ctx.composer.move_char(str(obj), coord)
		return
	if _is_camera_target(obj) and _ctx and _ctx.camera:
		_ctx.camera.move_camera(coord)
		return
	if _ctx and _ctx.graphics:
		_ctx.graphics.move(obj, coord)


func _tint_target(obj: Variant, color: Variant) -> void:
	if _is_nova_character(str(obj)) and _ctx and _ctx.composer:
		_ctx.composer.tint_char(str(obj), color)
		return
	if _ctx and _ctx.graphics:
		_ctx.graphics.tint(obj, color)


func _show_target(obj: Variant, image_path: String = "", coord: Variant = null) -> void:
	if _ctx == null:
		return
	var name := str(obj)
	if _is_nova_character(name) and _ctx.composer:
		if coord == null:
			coord = _nova_pos(0.50)
		_ctx.composer.show_char(name, _nova_pose_layers(image_path), coord)
		return
	if _ctx.has_method("show"):
		_ctx.show(obj, image_path, coord)
	elif _ctx.graphics:
		_ctx.graphics.show(obj, _nova_image_path(name, image_path), coord)


func _hide_target(obj: Variant) -> void:
	if _ctx == null:
		return
	if _is_nova_character(str(obj)) and _ctx.composer:
		_ctx.composer.hide_char(str(obj))
		return
	if _ctx.has_method("hide"):
		_ctx.hide(obj)
	elif _ctx.graphics:
		_ctx.graphics.hide(obj)


func _play_vfx(target: Variant, effect: Variant, range_or_duration: Variant = null, duration: Variant = 0.5, params: Variant = {}) -> void:
	if _ctx == null or _ctx.vfx == null:
		return
	var effect_name := _effect_name(effect)
	var seconds := _to_float(duration, _to_float(range_or_duration, 0.5))
	var dict: Dictionary = params if params is Dictionary else {}
	if _is_camera_target(target):
		if effect == null or effect_name.is_empty():
			_ctx.vfx.clear_post(seconds)
		else:
			_ctx.vfx.post(effect_name, seconds, dict)
		return
	if effect == null or effect_name.is_empty():
		_ctx.vfx.clear(target, seconds)
	else:
		_ctx.vfx.play(effect_name, target, seconds, dict)


func _effect_name(effect: Variant) -> String:
	if effect == null:
		return ""
	if effect is Array:
		var arr := effect as Array
		if arr.is_empty() or arr[0] == null:
			return ""
		return _effect_alias(str(arr[0]))
	return _effect_alias(str(effect))


func _effect_alias(effect_name: String) -> String:
	match effect_name.to_lower():
		"mono", "colorless", "gray", "grey":
			return "grayscale"
		"radial_blur":
			return "blur"
		"lens_blur":
			return "blur"
		"color":
			return ""
		_:
			return effect_name


func _is_camera_target(obj: Variant) -> bool:
	var name := str(obj)
	return name == "cam" or name == "cam2" or name == "cam_mask"


func _is_nova_character(char_name: String) -> bool:
	match char_name.to_lower():
		"ergong", "gaotian", "qianye", "xiben":
			return true
		_:
			return false


func _nova_pose_layers(pose: String) -> Dictionary:
	match pose:
		"cry":
			return {"body": "", "eye": "cry", "eyebrow": "down", "mouth": "close", "hair": ""}
		"smile":
			return {"body": "", "eye": "smile", "eyebrow": "happy", "mouth": "smile", "hair": ""}
		_:
			return {"body": "", "eye": "normal", "eyebrow": "normal", "mouth": "close", "hair": ""}


func _nova_image_path(obj_name: String, image_path: String) -> String:
	if image_path.find("/") != -1:
		return image_path
	match obj_name:
		"bg":
			return "Backgrounds/%s" % image_path
		"fg":
			return "foregrounds/%s" % image_path
		"cg":
			return "cg/%s" % image_path
		_:
			return image_path


func _nova_pos(x_ratio: float) -> Array:
	var size := _viewport_size()
	return [size.x * x_ratio, size.y * 0.55, _nova_character_scale()]


func _viewport_size() -> Vector2:
	if _ctx and _ctx.has_method("get_viewport"):
		var vp := _ctx.get_viewport()
		if vp:
			return vp.get_visible_rect().size
	return Vector2(1280, 720)


func _nova_character_scale() -> float:
	var h := _viewport_size().y
	return clampf(h / 2450.0, 0.28, 0.45)


func _to_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback
