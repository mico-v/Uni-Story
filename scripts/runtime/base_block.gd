class_name BaseBlock extends RefCounted

const NovaAnimationCompatScript := preload("res://scripts/runtime/nova_animation_compat.gd")

## Base class for every compiled NovaScript block.
##
## Each `<|...|>` / `@<|...|>` block in a scenario is wrapped into a GDScript
## class that `extends BaseBlock` and puts the user code inside `__eval()`.
## All presentation/flow API the scripts may call are defined here so that the
## compiled block can call them directly (e.g. `show("bg", "cg/rain")`).
##
## `_ctx` is the NovaController instance, injected right after `.new()`.

var _ctx: Node


func run() -> Variant:
	return __eval()


func __eval() -> Variant:
	push_error("BaseBlock.__eval must be overridden by the compiled block")
	return null


# --- shortcuts ---------------------------------------------------------------

var o: Dictionary:
	get: return _ctx.object_manager.objects

var c: Dictionary:
	get: return _ctx.object_manager.constants

var nova: Node:
	get: return _ctx

var anim:
	get: return NovaAnimationCompatScript.new(_ctx)

var anim_hold:
	get: return NovaAnimationCompatScript.new(_ctx)

var pos_c: Array:
	get: return _nova_pos(0.50)

var pos_l: Array:
	get: return _nova_pos(0.36)

var pos_r: Array:
	get: return _nova_pos(0.64)

var pos_cl: Array:
	get: return _nova_pos(0.43)

var pos_cr: Array:
	get: return _nova_pos(0.57)

var color_sunset: Array:
	get: return [1.0, 0.78, 0.55, 1.0]

var bg: String:
	get: return "bg"

var fg: String:
	get: return "fg"

var cg: String:
	get: return "cg"

var bgm: String:
	get: return "bgm"

var bgs: String:
	get: return "bgs"

var voice: String:
	get: return "voice"


# --- flow chart API (meaningful during the eager/parse pass) -----------------

func label(name: String, display_name = null) -> void:
	_ctx.script_loader.label(name, display_name)

func jump_to(dest: String) -> void:
	# During play, a lazy block jump redirects the story immediately; during the
	# eager parse pass it sets the node's fall-through target.
	if _ctx.game_state.current_node != null and not _ctx.game_state.is_ended:
		_ctx.game_state.pending_jump = StringName(dest)
	else:
		_ctx.script_loader.jump_to(dest)

func jump_if(cond: bool, dest: String) -> void:
	if cond:
		jump_to(dest)

func branch(branches: Array) -> void:
	_ctx.script_loader.branch(branches)

func is_chapter() -> void:
	_ctx.script_loader.is_chapter()

func is_start() -> void:
	_ctx.script_loader.is_start()

func is_unlocked_start() -> void:
	_ctx.script_loader.is_unlocked_start()

func is_debug() -> void:
	_ctx.script_loader.is_debug()

func is_save_point() -> void:
	_ctx.script_loader.is_save_point()

func is_end(end_name = null) -> void:
	_ctx.script_loader.is_end(end_name)


# --- graphics API (meaningful during lazy/runtime execution) -----------------

func show(obj: Variant, image_path: String = "", coord = null, color = null) -> void:
	var obj_name := str(obj)
	# Nova Lua show() uses integer 0 to mean "default / no effect", not a color tint.
	if color == 0:
		color = null
	# Nova color-name shorthand for display objects: 'black' on bg/fg means tint, not image.
	if image_path == "black" and (obj_name == "bg" or obj_name == "fg"):
		_ctx.graphics.tint(obj, Color.BLACK)
		var node: CanvasItem = _ctx.graphics._resolve(obj)
		if node:
			node.visible = true
		return
	if obj_name == "cg":
		_show_nova_cg(obj_name, image_path, coord, color)
		return
	if _is_nova_character(obj_name):
		_show_nova_character(obj_name, image_path, coord, color)
		return
	_ctx.graphics.show(obj, _nova_image_path(obj_name, image_path), coord, color)

func hide(obj: Variant) -> void:
	var obj_name := str(obj)
	if _is_nova_character(obj_name):
		_ctx.composer.hide_char(obj_name)
		return
	_ctx.graphics.hide(obj)

func move(obj: Variant, coord: Variant, scale = null, angle = null) -> void:
	if _is_nova_character(str(obj)):
		_ctx.composer.move_char(str(obj), coord, scale, angle)
		return
	if _is_camera_target(obj):
		_ctx.camera.move_camera(coord, scale, angle)
		return
	_ctx.graphics.move(obj, coord, scale, angle)

func tint(obj: Variant, color: Variant) -> void:
	_ctx.graphics.tint(obj, color)


# --- character立绘 composition API -------------------------------------------

func show_char(char_name: String, layers: Variant = {}, coord = null, color = null) -> void:
	_ctx.composer.show_char(char_name, layers, coord, color)

func set_layer(char_name: String, layer: String, key: Variant = "") -> void:
	_ctx.composer.set_layer(char_name, layer, key)

func hide_char(char_name: String) -> void:
	_ctx.composer.hide_char(char_name)


# --- avatar (头像) API --------------------------------------------------------

func set_avatar(char_name: String, key: Variant = "") -> void:
	_ctx.avatar.set_avatar(char_name, key)

func clear_avatar() -> void:
	_ctx.avatar.clear_avatar()


# --- dialogue box API --------------------------------------------------------

func set_box(pos_name: Variant = "bottom", _style: Variant = null, _clear: Variant = true) -> void:
	_ctx.dialogue_box.set_box(pos_name)


# --- camera / transition API -------------------------------------------------

func cam(coord: Variant, scale = null, angle = null) -> void:
	_ctx.camera.move_camera(coord, scale, angle)

func trans(kind: String = "fade", duration: float = 0.5):
	return _ctx.transition.play(kind, duration)


# --- VFX / shader API --------------------------------------------------------

func vfx(arg1: Variant = null, arg2: Variant = null, arg3: Variant = null, arg4: Variant = null, arg5: Variant = null):
	if _is_nova_camera_target(arg1):
		return _nova_camera_vfx(arg2, arg3, arg4, arg5)
	var effect_name := str(arg1)
	var target: Variant = arg2
	var duration := _to_float(arg3, 0.5)
	var params: Dictionary = arg4 if arg4 is Dictionary else {}
	var effect_key := _nova_effect_alias(effect_name)
	if effect_key.is_empty():
		return _ctx.vfx.clear(target, duration)
	return _ctx.vfx.play(effect_key, target, duration, params)

func clear_vfx(target: Variant, duration: float = 0.3):
	return _ctx.vfx.clear(target, duration)

func post_fx(effect_name: String, duration: float = 0.5, params: Dictionary = {}):
	return _ctx.vfx.post(effect_name, duration, params)

func clear_post_fx(duration: float = 0.3):
	return _ctx.vfx.clear_post(duration)

func shake(intensity: float = 10.0, duration: float = 0.5):
	return _ctx.vfx.shake(intensity, duration)


# --- prefab API ----------------------------------------------------------------

func load_prefab(name: String, path: String, coord = null, color = null, ui: bool = false):
	return _ctx.prefab_loader.load_prefab(name, path, coord, color, ui)

func show_prefab(name: String) -> void:
	_ctx.prefab_loader.show_prefab(name)

func hide_prefab(name: String) -> void:
	_ctx.prefab_loader.hide_prefab(name)

func destroy_prefab(name: String) -> void:
	_ctx.prefab_loader.destroy_prefab(name)


# --- misc --------------------------------------------------------------------

func wait(seconds: float):
	return _ctx.animation.wait(seconds)


func timeline() -> Timeline:
	return Timeline.new(_ctx)


func play_video(path: String, skippable: bool = true):
	return _ctx.video_system.play_video(path, skippable)


func show_toast(message: String, duration: float = 2.0) -> void:
	_ctx.dialog_system.show_toast(message, duration)


func show_confirm(title: String, message: String):
	return _ctx.dialog_system.show_confirm(title, message)


func preload_asset(path: String) -> void:
	_ctx.preload_system.preload_asset(path)


func cancel_preload(path: String) -> void:
	_ctx.preload_system.cancel_preload(path)


func cancel_all_preloads() -> void:
	_ctx.preload_system.cancel_all()


# --- audio API ---------------------------------------------------------------

func play_bgm(path: String, fade: float = 0.0):
	return _ctx.audio.play_bgm(path, fade)

func stop_bgm(fade: float = 0.0):
	return _ctx.audio.stop_bgm(fade)

func play_se(path: String, volume_db: float = 0.0) -> void:
	_ctx.audio.play_se(path, volume_db)

func play_voice(path: String):
	return _ctx.audio.play_voice(path)


func play(channel: Variant, path: String, fade: float = 0.0, volume: Variant = null):
	var channel_name := str(channel)
	match channel_name:
		"bgm":
			return play_bgm(_audio_path("BGM", path), fade)
		"bgs":
			play_se(_audio_path("Sounds", path), _linear_volume_to_db(volume))
		"voice":
			return play_voice(str(path))
		_:
			play_se(_audio_path("Sounds", path), _linear_volume_to_db(volume))
	return null


func sound(path: String, volume: Variant = null) -> void:
	play_se(_audio_path("Sounds", path), _linear_volume_to_db(volume))


func auto_voice_on(_speaker: String, _start_id: Variant = null) -> void:
	pass


func auto_voice_off(_speaker: String = "") -> void:
	pass


func set_auto_voice_delay(_seconds: Variant = 0.0) -> void:
	pass


func box_hide_show(_seconds: Variant = 0.0) -> void:
	set_box("hide")
	set_box()


func box_tint(_color: Variant = null) -> void:
	pass


func env_tint(obj: Variant, color: Variant = null) -> void:
	tint(obj, color)


func avatar_show(_speaker: Variant = null, _key: Variant = "") -> void:
	pass


func avatar_hide() -> void:
	clear_avatar()


func video_play(path: String = "Videos/Call.mp4") -> void:
	play_video(path)


func video(path: String = "") -> void:
	if not path.is_empty():
		set_temp_var("_video_path", "Videos/%s.mp4" % path)


func video_hide() -> void:
	if _ctx.video_system:
		_ctx.video_system.stop()


func video_duration() -> float:
	return 0.0


func anim_hold_begin() -> void:
	pass


func anim_hold_end() -> void:
	pass


func stop_auto_ff() -> void:
	pass


func stop_ff() -> void:
	pass


func input_on() -> void:
	pass


func input_off() -> void:
	pass


func ff_shortcut_on() -> void:
	pass


func ff_shortcut_off() -> void:
	pass


func auto_fade_on() -> void:
	pass


func auto_fade_off() -> void:
	pass


func auto_time(_seconds: Variant = 0.0) -> void:
	pass


func immediate_step() -> void:
	pass


func minigame(_loader: Variant = null, _name: Variant = null) -> void:
	pass


func is_restoring() -> bool:
	return false


func current_box() -> Object:
	return _ctx.object_manager.objects.get("default_box")


func text_delay(_seconds: Variant = 0.0) -> void:
	pass


func text_duration(_seconds: Variant = 0.0) -> void:
	pass


func text_scroll(_from: Variant = null, _to: Variant = null, _duration: Variant = null, _easing: Variant = null) -> void:
	pass


func box_anchor(_anchor: Variant = null) -> void:
	pass


func box_alignment(_alignment: Variant = null) -> void:
	pass


func new_page() -> void:
	pass


func alert(message: String = "") -> void:
	show_toast(message)


func notify(message: String = "") -> void:
	show_toast(message)


func avatar(key: Variant = "") -> void:
	set_avatar("", key)


func avatar_clear() -> void:
	clear_avatar()


func volume(_channel: Variant, _value: Variant = null) -> void:
	pass


func stop(channel: Variant = null) -> void:
	if str(channel) == "bgm":
		stop_bgm()


func say(_speaker: Variant, voice_id: Variant = "") -> void:
	if str(voice_id).is_empty():
		return
	play_voice("Voices/%s.ogg" % str(voice_id))


# --- variables API -----------------------------------------------------------

func set_var(name: String, value: Variant) -> void:
	_ctx.variables.set_var(name, value)

func get_var(name: String, default: Variant = null) -> Variant:
	return _ctx.variables.get_var(name, default)

func has_var(name: String) -> bool:
	return _ctx.variables.has_var(name)

func add_var(name: String, delta: float) -> void:
	_ctx.variables.add_var(name, delta)


func get_nova_variable(name: String, global: bool = false, default: Variant = null) -> Variant:
	if global:
		return _ctx.variables.get_global(name, default)
	return _ctx.variables.get_var(name, default)


func set_nova_variable(name: String, value: Variant, global: bool = false) -> void:
	if global:
		_ctx.variables.set_global(name, value)
	else:
		_ctx.variables.set_var(name, value)


func get_temp_var(name: String, default: Variant = null) -> Variant:
	return _ctx.variables.get_temp(name, default)


func set_temp_var(name: String, value: Variant) -> void:
	_ctx.variables.set_temp(name, value)


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


func _is_camera_target(obj: Variant) -> bool:
	var name := str(obj)
	return name == "cam" or name == "cam2" or name == "cam_mask"


func _is_nova_camera_target(obj: Variant) -> bool:
	return _is_camera_target(obj)


func _nova_effect_alias(effect_name: String) -> String:
	match effect_name.to_lower():
		"mono", "colorless":
			return "grayscale"
		"gray", "grey":
			return "grayscale"
		"blur":
			return "blur"
		"lens_blur", "radial_blur":
			return "blur"
		"vignette":
			return "vignette"
		_:
			return effect_name


func _nova_camera_vfx(effect_spec: Variant, range_spec: Variant, duration_spec: Variant, params_spec: Variant) -> Tween:
	if _ctx == null or _ctx.vfx == null:
		return null
	if effect_spec == null:
		return _ctx.vfx.clear_post(_to_float(duration_spec, 0.0))
	if effect_spec is Array:
		var arr := effect_spec as Array
		if arr.is_empty():
			return _ctx.vfx.clear_post(_to_float(duration_spec, 0.0))
		if arr[0] == null:
			var clear_duration := _to_float(duration_spec, 0.0)
			if clear_duration <= 0.0 and arr.size() > 1:
				clear_duration = _to_float(arr[1], 0.0)
			return _ctx.vfx.clear_post(clear_duration)
		var effect := _nova_effect_alias(str(arr[0]))
		if effect.is_empty():
			return _ctx.vfx.clear_post(_to_float(duration_spec, 0.0))
		var effect_params: Dictionary = params_spec if params_spec is Dictionary else {}
		if effect_params.is_empty() and range_spec is Dictionary:
			effect_params = range_spec
		return _ctx.vfx.post(effect, _to_float(duration_spec, 0.5), effect_params)
	var effect_name := _nova_effect_alias(str(effect_spec))
	if effect_name.is_empty():
		return _ctx.vfx.clear_post(_to_float(duration_spec, 0.0))
	var params: Dictionary = params_spec if params_spec is Dictionary else {}
	if params.is_empty() and range_spec is Dictionary:
		params = range_spec
	return _ctx.vfx.post(effect_name, _to_float(duration_spec, 0.5), params)


func _audio_path(folder: String, path: String) -> String:
	if path.find("/") != -1 or path.get_extension() != "":
		return path
	return "%s/%s.ogg" % [folder, path]


func _linear_volume_to_db(volume: Variant) -> float:
	if volume is int or volume is float:
		var linear := clampf(float(volume), 0.0, 1.0)
		if linear <= 0.0:
			return -80.0
		return 20.0 * log(linear) / log(10.0)
	return 0.0


func _to_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback


func _is_nova_character(obj_name: String) -> bool:
	return _nova_character_dir(obj_name) != ""


func _show_nova_character(char_name: String, pose: String, coord: Variant, color: Variant) -> void:
	if coord == null:
		coord = _nova_pos(0.50)
	# Nova Lua show() uses 0 to mean "default / no effect", not a color.
	if color == 0:
		color = null
	_ctx.composer.show_char(char_name, pose, coord, color)


func _show_nova_cg(obj_name: String, pose: String, coord: Variant, color: Variant) -> void:
# Nova Lua show() uses 0 to mean "default / no effect", not a color.
	if color == 0:
		color = null
	var resolved_pose := _nova_cg_pose(obj_name, pose)
	_ctx.graphics.show(obj_name, resolved_pose, coord, color)


func _nova_pose_layers(pose: String) -> Dictionary:
	return {"pose": pose}


func _nova_cg_pose(obj_name: String, pose: String) -> String:
	if pose.find("/") != -1:
		return pose
	match pose:
		"rain":
			return "rain_back"
		"rain_final":
			return "rain_back+rain_text"
		_:
			return pose


func _nova_character_dir(char_name: String) -> String:
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
