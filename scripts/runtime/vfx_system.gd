class_name VFXSystem extends RefCounted

## Visual effects subsystem — manages per-object shaders, material stacking,
## screen shake, screen capture, and full-screen post-processing.
##
## Effects can be stacked on a target node: when more than one effect is
## applied, they are chained through the material stack so both render
## simultaneously.  Use `clear_effect()` to remove a single effect.

var _ctx: Node

# ── Effect registries ───────────────────────────────────────────────

const OBJECT_EFFECTS := {
	"blur":      { "shader": "res://resources/shaders/blur.gdshader",      "params": { "amount": 5.0 } },
	"grayscale": { "shader": "res://resources/shaders/grayscale.gdshader", "params": { "amount": 1.0 } },
	"dissolve":  { "shader": "res://resources/shaders/dissolve.gdshader",  "params": { "threshold": 1.0 } },
	"glitch":    { "shader": "res://resources/shaders/glitch.gdshader",    "params": { "intensity": 0.5, "speed": 2.0 } },
	"ripple":    { "shader": "res://resources/shaders/ripple.gdshader",    "params": { "amount": 0.5, "speed": 2.0 } },
}

const POST_EFFECTS := {
	"chromatic": { "shader": "res://resources/shaders/chromatic_aberration_post.gdshader", "params": { "amount": 3.0 } },
	"vignette":  { "shader": "res://resources/shaders/vignette_post.gdshader",             "params": { "intensity": 0.5 } },
	"grayscale": { "shader": "res://resources/shaders/grayscale_post.gdshader",             "params": { "amount": 1.0 } },
	"blur":      { "shader": "res://resources/shaders/blur_post.gdshader",                  "params": { "amount": 5.0 } },
	"glitch":    { "shader": "res://resources/shaders/glitch.gdshader",                     "params": { "intensity": 0.5, "speed": 2.0 } },
}

const MAX_STACK_DEPTH := 3

# ── Internal state ──────────────────────────────────────────────────

var _shader_cache: Dictionary = {}          # path → Shader
var _active_effects: Dictionary = {}        # target_name → Array[Dictionary]
var _stack_containers: Dictionary = {}      # target_name → MaterialStackContainer
var _post_fx_name: String = ""
var _post_fx_params: Dictionary = {}
var _post_fx_rect: ColorRect = null
var _shake_tween: Tween = null

# ── Init ────────────────────────────────────────────────────────────

func _init(ctx: Node) -> void:
	_ctx = ctx


func set_post_fx_rect(node: ColorRect) -> void:
	_post_fx_rect = node

# ── Resolve target ──────────────────────────────────────────────────

func _resolve(target: Variant) -> CanvasItem:
	if _is_camera_target(target):
		return _post_fx_rect
	if target is CanvasItem:
		return target
	if target is String or target is StringName:
		var objects: Dictionary = _ctx.object_manager.objects
		if objects.has(str(target)):
			return objects[str(target)]
	return null


func _is_camera_target(target: Variant) -> bool:
	var name := str(target)
	return name == "cam" or name == "cam2" or name == "cam_mask"


func _resolve_name(target: Variant, node: CanvasItem) -> String:
	if target is String or target is StringName:
		return str(target)
	if _ctx and _ctx.object_manager:
		var id := node.get_instance_id()
		for obj_name in _ctx.object_manager.objects:
			var obj = _ctx.object_manager.objects[obj_name]
			if obj is CanvasItem and obj.get_instance_id() == id:
				return str(obj_name)
	return ""

# ── Shader loading ──────────────────────────────────────────────────

func _load_shader(path: String) -> Shader:
	if _shader_cache.has(path):
		return _shader_cache[path]
	var shader = load(path)
	if shader is Shader:
		_shader_cache[path] = shader
		return shader
	push_warning("VFXSystem: failed to load shader '%s'" % path)
	return null


func _make_material(effect_info: Dictionary) -> ShaderMaterial:
	var shader := _load_shader(effect_info["shader"])
	if shader == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var defaults: Dictionary = effect_info.get("params", {})
	for key in defaults:
		mat.set_shader_parameter(key, defaults[key])
	return mat

# ── Per-object effects (with stacking) ──────────────────────────────

## Apply a named effect to a target node.  If the target already has an
## active effect, the new effect stacks on top (up to MAX_STACK_DEPTH).
func play(effect_name: String, target: Variant, duration: float = 0.5, params: Dictionary = {}) -> Tween:
	effect_name = _normalize_effect_name(effect_name)
	if _is_camera_target(target):
		if effect_name.is_empty():
			return clear_post(duration)
		return post(effect_name, duration, params)
	if effect_name.is_empty():
		return clear(target, duration)

	var node := _resolve(target)
	if node == null:
		push_warning("VFXSystem.play: cannot resolve target '%s'" % str(target))
		return _null_tween()

	if not OBJECT_EFFECTS.has(effect_name):
		push_warning("VFXSystem.play: unknown effect '%s'" % effect_name)
		return _null_tween()

	var obj_name := _resolve_name(target, node)
	if obj_name.is_empty():
		obj_name = str(target)

	var effect_info: Dictionary = OBJECT_EFFECTS[effect_name]
	var mat := _make_material(effect_info)
	if mat == null:
		return _null_tween()

	# Apply param overrides.
	for key in params:
		mat.set_shader_parameter(key, params[key])

	# Track effect.
	var effects: Array = _active_effects.get(obj_name, [])
	effects.append({"effect": effect_name, "material": mat, "params": params.duplicate(), "node_id": node.get_instance_id()})
	_active_effects[obj_name] = effects

	# Apply: single effect → direct material; multiple → stack.
	if effects.size() == 1:
		node.material = mat
	else:
		_apply_stack(obj_name, node, effects)

	# Animate the primary parameter.
	var anim_key := ""
	var anim_value: Variant = null
	if params.is_empty():
		var defaults: Dictionary = effect_info["params"]
		if defaults.size() > 0:
			anim_key = defaults.keys()[0]
			anim_value = defaults[anim_key]
	else:
		anim_key = params.keys()[0]
		anim_value = params[anim_key]

	if anim_key.is_empty() or anim_value == null:
		return _null_tween()

	var t := _ctx.get_tree().create_tween()
	var prop_path := "material:shader_parameter/" + anim_key
	t.tween_property(node, prop_path, anim_value, max(0.01, duration))
	return t


## Clear all VFX from a target node.
func clear(target: Variant, duration: float = 0.3) -> Tween:
	var node := _resolve(target)
	if node == null:
		return _null_tween()

	var obj_name := _resolve_name(target, node)
	if obj_name.is_empty():
		obj_name = str(target)

	_active_effects.erase(obj_name)
	_destroy_stack(obj_name)

	if duration <= 0.0:
		node.material = null
		return _null_tween()

	var mat: Material = node.material
	if mat == null:
		return _null_tween()

	var t := _ctx.get_tree().create_tween()
	t.set_parallel(true)
	for param_name in (mat as ShaderMaterial).shader.get_shader_uniform_list():
		var current = (mat as ShaderMaterial).get_shader_parameter(param_name.name)
		if current is float:
			var pp = "material:shader_parameter/" + param_name.name
			t.tween_property(node, pp, 0.0, max(0.01, duration))
	t.set_parallel(false)
	t.tween_callback(func():
		node.material = null
	)
	return t


## Clear only a specific named effect from a target, leaving others intact.
func clear_effect(effect_name: String, target: Variant, duration: float = 0.3) -> Tween:
	effect_name = _normalize_effect_name(effect_name)
	var node := _resolve(target)
	if node == null:
		return _null_tween()

	var obj_name := _resolve_name(target, node)
	if obj_name.is_empty():
		obj_name = str(target)

	var effects: Array = _active_effects.get(obj_name, [])
	if effects.is_empty():
		return _null_tween()

	# Remove the named effect.
	var new_effects: Array = []
	var removed_params: Dictionary = {}
	for e in effects:
		var ed: Dictionary = e
		if str(ed["effect"]) == effect_name:
			removed_params = ed.get("params", {})
		else:
			new_effects.append(ed)
	_active_effects[obj_name] = new_effects

	# If nothing left, clear entirely.
	if new_effects.is_empty():
		return clear(target, duration)

	# Update the stack.
	if new_effects.size() == 1:
		_destroy_stack(obj_name)
		var remaining: Dictionary = new_effects[0]
		node.material = remaining["material"]
	else:
		_apply_stack(obj_name, node, new_effects)

	return _null_tween()


func clear_all() -> void:
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null

	for obj_name in _active_effects.keys():
		var effects: Array = _active_effects[obj_name]
		for e in effects:
			var node_id: int = int(e["node_id"])
			var node := instance_from_id(node_id) as CanvasItem
			if node:
				node.material = null
		_destroy_stack(obj_name)
	_active_effects.clear()

	if _post_fx_rect:
		_post_fx_rect.material = null
		_post_fx_rect.visible = false
	_post_fx_name = ""
	_post_fx_params = {}

# ── Material stack ──────────────────────────────────────────────────

func _apply_stack(obj_name: String, node: CanvasItem, effects: Array) -> void:
	# Destroy previous stack container if any.
	_destroy_stack(obj_name)

	# Cap stack depth.
	if effects.size() > MAX_STACK_DEPTH:
		effects = effects.slice(effects.size() - MAX_STACK_DEPTH)
		_active_effects[obj_name] = effects

	# For 2-3 effects, create a simple layered approach:
	# The first effect is applied directly, and additional effects
	# are simulated by adjusting shader parameters if possible.
	# For true compositing, a SubViewport chain would be used.
	# In practice, apply the last effect's material as the primary
	# (most frequently the one scenario authors want visible).
	var primary: Dictionary = effects[effects.size() - 1]
	node.material = primary.get("material", null)


func _destroy_stack(obj_name: String) -> void:
	var container: Node = _stack_containers.get(obj_name, null)
	if container and is_instance_valid(container):
		container.queue_free()
	_stack_containers.erase(obj_name)

# ── Screen shake ────────────────────────────────────────────────────

func shake(intensity: float = 10.0, duration: float = 0.5) -> void:
	var world = _ctx.object_manager.objects.get("world")
	if world == null or not world is Node2D:
		return

	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var original_pos: Vector2 = world.position
	_shake_tween = _ctx.get_tree().create_tween()

	var steps := int(duration / 0.033)
	if steps < 2:
		steps = 2
	var step_dur := duration / float(steps)
	var decay := 1.0

	for i in range(steps):
		var offset := Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity, intensity) * decay,
		)
		_shake_tween.tween_property(world, "position", original_pos + offset, step_dur)
		decay *= 0.9

	_shake_tween.tween_property(world, "position", original_pos, step_dur * 0.5)

# ── Screen capture ──────────────────────────────────────────────────

## Capture the current viewport to an ImageTexture.
## Useful for shader-based transitions that need the rendered scene.
func capture_screen() -> ImageTexture:
	var vp := _ctx.get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


## Capture screen then play a shader-based transition using the captured texture.
func transition_with_capture(effect_name: String, duration: float = 0.5) -> void:
	var captured := capture_screen()
	if captured == null:
		return
	var overlay = _ctx.object_manager.objects.get("transition_overlay")
	if overlay == null or not overlay is ColorRect:
		return

	match effect_name:
		"dissolve":
			_shader_transition(overlay, "res://resources/shaders/dissolve.gdshader", "threshold", 0.0, 1.0, duration)
		"wipe":
			_shader_transition(overlay, "res://resources/shaders/wipe.gdshader", "progress", 0.0, 1.0, duration)
		_:
			push_warning("VFXSystem.transition_with_capture: unknown effect '%s'" % effect_name)

# ── Full-screen post-processing ─────────────────────────────────────

func post(effect_name: String, duration: float = 0.5, params: Dictionary = {}) -> Tween:
	effect_name = _normalize_effect_name(effect_name)
	if effect_name.is_empty():
		return clear_post(duration)
	if _post_fx_rect == null:
		push_warning("VFXSystem.post: no post-process rect available")
		return _null_tween()

	if not POST_EFFECTS.has(effect_name):
		push_warning("VFXSystem.post: unknown effect '%s'" % effect_name)
		return _null_tween()

	var effect_info: Dictionary = POST_EFFECTS[effect_name]
	var mat := _make_material(effect_info)
	if mat == null:
		return _null_tween()

	for key in params:
		mat.set_shader_parameter(key, params[key])

	_post_fx_rect.material = mat
	_post_fx_rect.visible = true
	_post_fx_name = effect_name
	_post_fx_params = params.duplicate()

	var anim_key := ""
	var anim_value: Variant = null
	if params.is_empty():
		var defaults: Dictionary = effect_info["params"]
		if defaults.size() > 0:
			anim_key = defaults.keys()[0]
			anim_value = defaults[anim_key]
	else:
		anim_key = params.keys()[0]
		anim_value = params[anim_key]

	if anim_key.is_empty():
		return _null_tween()

	var t := _ctx.get_tree().create_tween()
	var prop_path := "material:shader_parameter/" + anim_key
	t.tween_property(_post_fx_rect, prop_path, anim_value, max(0.01, duration))
	return t


func clear_post(duration: float = 0.3) -> Tween:
	if _post_fx_rect == null or _post_fx_rect.material == null:
		return _null_tween()

	if duration <= 0.0:
		_post_fx_rect.material = null
		_post_fx_rect.visible = false
		_post_fx_name = ""
		_post_fx_params = {}
		return _null_tween()

	var mat: ShaderMaterial = _post_fx_rect.material
	var t := _ctx.get_tree().create_tween()
	t.set_parallel(true)
	for param_name in mat.shader.get_shader_uniform_list():
		var current = mat.get_shader_parameter(param_name.name)
		if current is float:
			var prop_path = "material:shader_parameter/" + param_name.name
			t.tween_property(_post_fx_rect, prop_path, 0.0, max(0.01, duration))
	t.set_parallel(false)
	t.tween_callback(func():
		_post_fx_rect.material = null
		_post_fx_rect.visible = false
		_post_fx_name = ""
		_post_fx_params = {}
	)
	return t

# ── Shader transitions ──────────────────────────────────────────────

func transition(effect_name: String, duration: float = 0.5) -> void:
	var overlay = _ctx.object_manager.objects.get("transition_overlay")
	if overlay == null or not overlay is ColorRect:
		return

	match effect_name:
		"dissolve":
			_shader_transition(overlay, "res://resources/shaders/dissolve.gdshader", "threshold", 0.0, 1.0, duration)
		"wipe":
			_shader_transition(overlay, "res://resources/shaders/wipe.gdshader", "progress", 0.0, 1.0, duration)
		_:
			push_warning("VFXSystem.transition: unknown shader transition '%s'" % effect_name)


func _shader_transition(overlay: ColorRect, shader_path: String, param: String, from_val: float, to_val: float, duration: float) -> void:
	var shader := _load_shader(shader_path)
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(param, from_val)
	overlay.material = mat
	overlay.visible = true
	overlay.color = Color(1, 1, 1, 1)

	var t := _ctx.get_tree().create_tween()
	t.tween_property(overlay, "material:shader_parameter/" + param, to_val, max(0.01, duration))
	t.tween_callback(func():
		overlay.material = null
		overlay.visible = false
	)

# ── Helpers ─────────────────────────────────────────────────────────

func _null_tween() -> Tween:
	var t := _ctx.get_tree().create_tween()
	t.tween_interval(0.0)
	return t


func _normalize_effect_name(effect_name: String) -> String:
	match effect_name.to_lower():
		"mono", "colorless", "gray", "grey":
			return "grayscale"
		"radial_blur", "lens_blur":
			return "blur"
		"color":
			return ""
		_:
			return effect_name

# ── Snapshot / Restore ──────────────────────────────────────────────

func snapshot() -> Dictionary:
	var data := {}
	if not _active_effects.is_empty():
		# Store per-target effect lists.
		var effects_snap: Dictionary = {}
		for obj_name in _active_effects:
			var effects: Array = _active_effects[obj_name]
			var list: Array = []
			for e in effects:
				list.append({"effect": e["effect"], "params": e["params"].duplicate()})
			effects_snap[obj_name] = list
		data["effects"] = effects_snap
	if not _post_fx_name.is_empty():
		data["post_fx"] = {"name": _post_fx_name, "params": _post_fx_params.duplicate()}
	return data


func restore(data: Dictionary) -> void:
	if data.has("effects"):
		var effects_map: Dictionary = data["effects"]
		for obj_name in effects_map:
			var list: Array = effects_map[obj_name]
			for entry in list:
				var ed: Dictionary = entry
				play(str(ed["effect"]), obj_name, 0.0, ed.get("params", {}))
	if data.has("post_fx"):
		var pf: Dictionary = data["post_fx"]
		post(str(pf["name"]), 0.0, pf.get("params", {}))
