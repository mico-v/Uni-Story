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
	if _is_default_effect_value(color):
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
	if _is_profile_character(obj_name):
		_show_profile_character(obj_name, image_path, coord, color)
		return
	_ctx.graphics.show(obj, _nova_image_path(obj_name, image_path), coord, color)

func hide(obj: Variant) -> void:
	var obj_name := str(obj)
	if _is_profile_character(obj_name):
		_ctx.composer.hide_char(obj_name)
		return
	_ctx.graphics.hide(obj)

func move(obj: Variant, coord: Variant, scale = null, angle = null) -> void:
	if _is_profile_character(str(obj)):
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

## Clear only a specific named effect from a target, leaving other stacked effects intact.
func clear_effect(effect_name: String, target: Variant, duration: float = 0.3):
	return _ctx.vfx.clear_effect(effect_name, target, duration)

## Capture the current game screen to a texture (for script-driven transitions).
func capture_screen():
	return _ctx.vfx.capture_screen()

## Capture screen then play a shader-based transition.
func capture_transition(effect_name: String, duration: float = 0.5):
	return _ctx.vfx.transition_with_capture(effect_name, duration)


# --- prefab API ----------------------------------------------------------------

func load_prefab(name: String, path: String, coord = null, color = null, category = PrefabLoader.PrefabCategory.WORLD):
	return _ctx.prefab_loader.load_prefab(name, path, coord, color, category)

func load_ui_prefab(name: String, path: String, coord = null, color = null):
	return _ctx.prefab_loader.load_prefab(name, path, coord, color, PrefabLoader.PrefabCategory.UI)

func load_persistent_prefab(name: String, path: String, coord = null, color = null):
	return _ctx.prefab_loader.load_prefab(name, path, coord, color, PrefabLoader.PrefabCategory.PERSISTENT)

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


func preload_asset(path: String, type: String = "", priority: int = 0) -> void:
	_ctx.preload_system.preload_asset(path, type, priority)


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

func play_voice(path: String, override_auto_voice: bool = true):
	var system := _auto_voice_system()
	if _is_runtime_voice_suppressed():
		if override_auto_voice and system != null:
			system.call("skip_next")
		return false
	if system != null and system.has_method("play_explicit_path"):
		return system.call("play_explicit_path", path, override_auto_voice)
	if _ctx.backlog and _ctx.backlog.has_method("note_voice"):
		_ctx.backlog.note_voice(path)
	return _ctx.audio.play_voice(path)


func play(channel: Variant, path: String, fade: float = 0.0, vol_db: Variant = null):
	var channel_name := str(channel)
	match channel_name:
		"bgm":
			return play_bgm(_audio_path("BGM", path), fade)
		"bgs":
			play_se(_audio_path("Sounds", path), _linear_volume_to_db(vol_db))
		"voice":
			return play_voice(str(path))
		_:
			play_se(_audio_path("Sounds", path), _linear_volume_to_db(vol_db))
	return null


func sound(path: String, vol_db: Variant = null) -> void:
	play_se(_audio_path("Sounds", path), _linear_volume_to_db(vol_db))


func auto_voice_on(speaker: String, start_id: Variant = null) -> void:
	var system := _auto_voice_system()
	if system != null:
		system.call("enable", speaker, start_id)


func auto_voice_off(speaker: String = "") -> void:
	var system := _auto_voice_system()
	if system == null:
		return
	if speaker.strip_edges().is_empty():
		system.call("disable_all")
	else:
		system.call("disable", speaker)


func auto_voice_off_all() -> void:
	var system := _auto_voice_system()
	if system != null:
		system.call("disable_all")


func set_auto_voice_delay(seconds: Variant = 0.0) -> void:
	var system := _auto_voice_system()
	if system != null:
		system.call("set_next_delay", seconds)


func auto_voice_skip() -> void:
	var system := _auto_voice_system()
	if system != null:
		system.call("skip_next")


func box_hide_show(_seconds: Variant = 0.0) -> void:
	set_box("hide")
	set_box()


func box_tint(color_or_value: Variant = null) -> void:
	if _ctx == null:
		return
	var box := _resolve_dbox()
	if box == null:
		return
	var target_color: Color
	if color_or_value is Color:
		target_color = color_or_value
	elif color_or_value is int or color_or_value is float:
		var v := clampf(float(color_or_value), 0.0, 1.0)
		target_color = Color(v, v, v, 0.82)
	elif color_or_value is Array and (color_or_value as Array).size() >= 2:
		var arr := color_or_value as Array
		if arr.size() >= 4:
			target_color = Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
		else:
			target_color = Color(float(arr[0]), float(arr[0]), float(arr[0]), float(arr[1]))
	else:
		return
	# Update StyleBoxFlat background
	if box is Panel:
		var sb := box.get_theme_stylebox("panel", "Panel") as StyleBoxFlat
		if sb:
			sb.bg_color = target_color
			box.add_theme_stylebox_override("panel", sb)
		else:
			var new_sb := StyleBoxFlat.new()
			new_sb.bg_color = target_color
			box.add_theme_stylebox_override("panel", new_sb)


func env_tint(obj: Variant, color: Variant = null) -> void:
	tint(obj, color)


func avatar_show(_speaker: Variant = null, _key: Variant = "") -> void:
	pass


func avatar_hide() -> void:
	clear_avatar()


func video_play(path: String = "") -> void:
	var resolved_path := path.strip_edges()
	if resolved_path.is_empty():
		resolved_path = str(get_temp_var("_video_path", "Videos/Call.mp4"))
	play_video(resolved_path)


func video(path: String = "") -> void:
	if not path.is_empty():
		var resolved_path := path
		if not resolved_path.contains("/"):
			resolved_path = "Videos/" + resolved_path
		if resolved_path.get_extension().is_empty():
			resolved_path += ".mp4"
		set_temp_var("_video_path", resolved_path)


func video_hide() -> void:
	if _ctx.video_system:
		_ctx.video_system.stop()


func video_duration() -> float:
	return 0.0


var _anim_hold_counter: int = 0

func anim_hold_begin() -> void:
	_anim_hold_counter += 1


func anim_hold_end() -> void:
	_anim_hold_counter = maxi(0, _anim_hold_counter - 1)


func stop_auto_ff() -> void:
	if _ctx and _ctx.has_method("deactivate_auto_mode"):
		_ctx.deactivate_auto_mode()


func stop_ff() -> void:
	if _ctx and _ctx.has_method("deactivate_skip_mode"):
		_ctx.deactivate_skip_mode()


func input_on() -> void:
	if _ctx and _ctx.has_method("set_input_enabled"):
		_ctx.set_input_enabled(true)


func input_off() -> void:
	if _ctx and _ctx.has_method("set_input_enabled"):
		_ctx.set_input_enabled(false)


func ff_shortcut_on() -> void:
	if _ctx and _ctx.has_method("set_ff_shortcut_enabled"):
		_ctx.set_ff_shortcut_enabled(true)


func ff_shortcut_off() -> void:
	if _ctx and _ctx.has_method("set_ff_shortcut_enabled"):
		_ctx.set_ff_shortcut_enabled(false)


func auto_fade_on() -> void:
	if _ctx == null:
		return
	var counter := _ctx.get("_auto_fade_off_count") as int
	counter = maxi(0, counter - 1)
	_ctx.set("_auto_fade_off_count", counter)


func auto_fade_off() -> void:
	if _ctx == null:
		return
	var counter := _ctx.get("_auto_fade_off_count") as int
	_ctx.set("_auto_fade_off_count", counter + 1)


func auto_time(seconds: Variant = 0.0) -> void:
	if _ctx and _ctx.game_view_controller:
		_ctx.game_view_controller.auto_delay = _to_float(seconds, 0.10)


func immediate_step() -> void:
	# Force immediate advance to next dialogue entry.
	if _ctx and _ctx.game_state and _ctx.game_state.is_waiting_input:
		_ctx.game_state.continue_after_input()


func minigame(loader: Variant = null, minigame_name: Variant = null) -> void:
	## Load and start a minigame scene using the interrupt protocol.
	##
	## Nova compat: minigame(__Nova.uiPrefabLoader, 'ExampleMinigame') is
	## translated to minigame("ui_prefab_loader", "ExampleMinigame").
	##
	## Flow:
	##   1. begin_interrupt() blocks story advance.
	##   2. The minigame scene is loaded via PrefabLoader.
	##   3. Player interacts with the minigame.
	##   4. Minigame destroys itself → teardown_prefab() → end_interrupt().
	##   5. Story can continue from the next dialogue entry.
	var loader_name := str(loader) if loader != null else ""
	var target_name := str(minigame_name) if minigame_name != null else ""
	if target_name.is_empty():
		return

	# Begin interrupt to block story advance.
	begin_interrupt()

	# Determine category: uiPrefabLoader → UI, prefabLoader → WORLD.
	var category := PrefabLoader.PrefabCategory.WORLD
	if loader_name == "ui_prefab_loader":
		category = PrefabLoader.PrefabCategory.UI

	# Resolve the minigame scene path.
	var minigame_path := "minigame/%s.tscn" % target_name

	# Load via the prefab loader so it participates in lifecycle management.
	if _ctx.prefab_loader and _ctx.prefab_loader.has_method("load_prefab"):
		_ctx.prefab_loader.load_prefab(target_name, minigame_path, null, null, category)


func is_restoring() -> bool:
	return _ctx != null and _ctx.game_state != null and bool(_ctx.game_state.get("is_replaying"))


func current_box() -> Object:
	return _ctx.object_manager.objects.get("default_box")


func text_delay(seconds: Variant = 0.0) -> void:
	if _ctx and _ctx.game_view_controller:
		_ctx.game_view_controller.type_cps = _chars_per_second(_to_float(seconds, 0.0))


func text_duration(seconds: Variant = 0.0) -> void:
	if _ctx and _ctx.game_view_controller:
		var dur := _to_float(seconds, 0.0)
		if dur > 0.0 and _ctx.game_view_controller._story_label:
			_ctx.game_view_controller.type_cps = _ctx.game_view_controller._story_label.text.length() / dur


func text_scroll(from_value: Variant = null, to_value: Variant = null, _duration: Variant = null, _easing: Variant = null) -> void:
	if _ctx == null or _ctx.game_view_controller == null:
		return
	var box := _resolve_dbox()
	if box:
		var target := _to_float(to_value, _to_float(from_value, 0.0))
		box.position.y = -target


func box_anchor(anchor: Variant = null) -> void:
	if anchor is Array and (anchor as Array).size() >= 4:
		var arr := anchor as Array
		var box := _resolve_dbox()
		if box:
			box.anchor_left = float(arr[0])
			box.anchor_right = float(arr[1])
			box.anchor_top = float(arr[2])
			box.anchor_bottom = float(arr[3])
			box.offset_left = 0
			box.offset_right = 0
			box.offset_top = 0
			box.offset_bottom = 0


func box_alignment(alignment: Variant = null) -> void:
	if _ctx == null or _ctx.game_view_controller == null:
		return
	var label: RichTextLabel = _ctx.game_view_controller._story_label
	if label == null:
		return
	var mode := str(alignment).to_lower()
	match mode:
		"left":   label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		"center": label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		"right":  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func new_page() -> void:
	if _ctx and _ctx.game_view_controller:
		var label: RichTextLabel = _ctx.game_view_controller._story_label
		if label:
			label.text = ""


func alert(message: String = "") -> void:
	show_toast(message)


func notify(message: String = "") -> void:
	show_toast(message)


func avatar(key: Variant = "") -> void:
	set_avatar("", key)


func avatar_clear() -> void:
	clear_avatar()


func volume(channel: Variant, value: Variant = null) -> void:
	if _ctx == null or _ctx.audio == null:
		return
	var channel_name := str(channel).to_lower()
	var linear: float = 0.0
	if value is int or value is float:
		linear = clampf(float(value), 0.0, 1.0)
	match channel_name:
		"bgm":
			_ctx.audio.set_bgm_volume(linear)
		"bgs", "se":
			_ctx.audio.set_se_volume(linear)
		"voice":
			_ctx.audio.set_voice_volume(linear)


func stop(channel: Variant = null) -> void:
	if str(channel) == "bgm":
		stop_bgm()


func say(speaker: Variant, voice_id: Variant = "", delay: Variant = 0.0, override_auto_voice: bool = true) -> void:
	if str(voice_id).is_empty():
		return
	var system := _auto_voice_system()
	if system != null and system.has_method("prepare_manual"):
		if _is_runtime_voice_suppressed():
			if override_auto_voice:
				system.call("skip_next")
			return
		system.call("prepare_manual", speaker, voice_id, delay, override_auto_voice)
		return
	play_voice("Voices/%s.ogg" % str(voice_id), override_auto_voice)


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


func _linear_volume_to_db(linear_vol: Variant) -> float:
	if linear_vol is int or linear_vol is float:
		var linear := clampf(float(linear_vol), 0.0, 1.0)
		if linear <= 0.0:
			return -80.0
		return 20.0 * log(linear) / log(10.0)
	return 0.0


func _to_float(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback


func _is_profile_character(obj_name: String) -> bool:
	var composer: Object = _composer()
	return composer != null and composer.has_method("has_character_profile") and bool(composer.call("has_character_profile", obj_name))


func _show_profile_character(char_name: String, pose: String, coord: Variant, color: Variant) -> void:
	if coord == null:
		coord = _nova_pos(0.50)
	# Nova Lua show() uses 0 to mean "default / no effect", not a color.
	if _is_default_effect_value(color):
		color = null
	var composer: Object = _composer()
	if composer != null and composer.has_method("show_char"):
		composer.call("show_char", char_name, pose, coord, color)


func _show_nova_cg(obj_name: String, pose: String, coord: Variant, color: Variant) -> void:
# Nova Lua show() uses 0 to mean "default / no effect", not a color.
	if _is_default_effect_value(color):
		color = null
	var resolved_pose := _nova_cg_pose(obj_name, pose)
	_ctx.graphics.show(obj_name, resolved_pose, coord, color)


func _is_default_effect_value(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == 0.0


func _composer() -> Object:
	if _ctx == null:
		return null
	return _ctx.get("composer") as Object


func _auto_voice_system() -> Object:
	if _ctx == null:
		return null
	return _ctx.get("auto_voice") as Object


func _is_runtime_voice_suppressed() -> bool:
	return _ctx != null and _ctx.game_state != null and bool(_ctx.game_state.get("is_runtime_voice_suppressed"))


func _nova_cg_pose(_obj_name: String, pose: String) -> String:
	return pose


func _resolve_dbox() -> Control:
	if _ctx == null:
		return null
	var obj := _ctx.object_manager.objects.get("default_box")
	if obj is Control:
		return obj
	return null


func _chars_per_second(delay_seconds: float) -> float:
	if delay_seconds <= 0.0:
		return 30.0  # default
	return 1.0 / delay_seconds


func set_text_speed(cps: float = 30.0) -> void:
	## Runtime dynamic adjustment of typewriter character-per-second rate.
	if _ctx and _ctx.game_view_controller:
		_ctx.game_view_controller.type_cps = maxf(cps, 1.0)


func get_current_position() -> Dictionary:
	if _ctx and _ctx.has_method("get_current_position"):
		return _ctx.get_current_position()
	return {}


func skip_mode_custom(enabled: bool = true) -> void:
	## Enable/disable custom skip mode override.
	if _ctx and _ctx.game_view_controller:
		if enabled:
			_ctx.game_view_controller.skip_unread = true
			_ctx.game_view_controller.skip_delay = 1.0 / 60.0  # fast but not instant
		else:
			_ctx.game_view_controller.skip_unread = false
			_ctx.game_view_controller.skip_delay = 0.05


func text_easing(easing: Variant = null) -> void:
	## Override typewriter text animation easing type. Stored for future animation system use.
	if _ctx:
		_ctx.set("_text_easing", easing)


func input(variable_name: String = "", _title: String = "", _placeholder: String = "") -> void:
	## Nova compat: request text input from player, store result in a variable.
	## Currently shows a toast prompt — full text input dialog can be added later.
	if variable_name.is_empty():
		return
	if _ctx and _ctx.dialog_system:
		_ctx.dialog_system.show_toast("Input: %s" % variable_name, 2.0)


func box_offset(offset: Variant = null) -> void:
	## Nova compat: set dialogue box offset margins (left, right, top, bottom).
	if offset is Array and (offset as Array).size() >= 4:
		var arr := offset as Array
		var box := _resolve_dbox()
		if box:
			box.offset_left = float(arr[0])
			box.offset_right = -float(arr[1])
			box.offset_top = float(arr[2])
			box.offset_bottom = -float(arr[3])

# --- Interrupt / Minigame API -------------------------------------------------

func begin_interrupt() -> int:
	var system := _auto_voice_system()
	if system != null and system.has_method("cancel_pending"):
		system.call("cancel_pending", true, true)
	if _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("begin_interrupt"):
		return _ctx.interrupt_manager.begin_interrupt()
	return -1

func end_interrupt(interrupt_id: int) -> void:
	if _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("end_interrupt"):
		_ctx.interrupt_manager.end_interrupt(interrupt_id)

func is_interrupt_active() -> bool:
	if _ctx.interrupt_manager and _ctx.interrupt_manager.has_method("is_active"):
		return _ctx.interrupt_manager.is_active()
	return false
