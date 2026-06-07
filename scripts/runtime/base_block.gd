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
	_ctx.script_loader.jump_to(dest)

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


# --- dialogue box API --------------------------------------------------------

func set_box(pos_name: Variant = "bottom") -> void:
	_ctx.dialogue_box.set_box(pos_name)


# --- audio API ---------------------------------------------------------------

func play_bgm(path: String, fade: float = 0.0) -> void:
	_ctx.audio.play_bgm(path, fade)

func stop_bgm(fade: float = 0.0) -> void:
	_ctx.audio.stop_bgm(fade)

func play_se(path: String, volume_db: float = 0.0) -> void:
	_ctx.audio.play_se(path, volume_db)

func play_voice(path: String) -> void:
	_ctx.audio.play_voice(path)


# --- camera / transition API -------------------------------------------------

func cam(coord: Variant, scale = null, angle = null) -> void:
	_ctx.camera.move_camera(coord, scale, angle)

func trans(kind: String = "fade", duration: float = 0.5) -> void:
	_ctx.transition.play(kind, duration)


# --- misc --------------------------------------------------------------------

func wait(seconds: float) -> void:
	_ctx.animation.wait(seconds)
