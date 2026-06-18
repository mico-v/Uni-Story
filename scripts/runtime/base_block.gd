class_name BaseBlock extends RefCounted

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

func is_end(name = null) -> void:
	_ctx.script_loader.is_end(name)


# --- graphics API (meaningful during lazy/runtime execution) -----------------

func show(obj: Variant, image_path: String, coord = null, color = null) -> void:
	_ctx.graphics.show(obj, image_path, coord, color)

func hide(obj: Variant) -> void:
	_ctx.graphics.hide(obj)

func move(obj: Variant, coord: Variant, scale = null, angle = null) -> void:
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

func set_box(pos_name: Variant = "bottom") -> void:
	_ctx.dialogue_box.set_box(pos_name)


# --- camera / transition API -------------------------------------------------

func cam(coord: Variant, scale = null, angle = null) -> void:
	_ctx.camera.move_camera(coord, scale, angle)

func trans(kind: String = "fade", duration: float = 0.5):
	return _ctx.transition.play(kind, duration)


# --- VFX / shader API --------------------------------------------------------

func vfx(effect_name: String, target: Variant, duration: float = 0.5, params: Dictionary = {}):
	return _ctx.vfx.play(effect_name, target, duration, params)

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


# --- audio API ---------------------------------------------------------------

func play_bgm(path: String, fade: float = 0.0):
	return _ctx.audio.play_bgm(path, fade)

func stop_bgm(fade: float = 0.0):
	return _ctx.audio.stop_bgm(fade)

func play_se(path: String, volume_db: float = 0.0) -> void:
	_ctx.audio.play_se(path, volume_db)

func play_voice(path: String):
	return _ctx.audio.play_voice(path)


# --- variables API -----------------------------------------------------------

func set_var(name: String, value: Variant) -> void:
	_ctx.variables.set_var(name, value)

func get_var(name: String, default: Variant = null) -> Variant:
	return _ctx.variables.get_var(name, default)

func has_var(name: String) -> bool:
	return _ctx.variables.has_var(name)

func add_var(name: String, delta: float) -> void:
	_ctx.variables.add_var(name, delta)
