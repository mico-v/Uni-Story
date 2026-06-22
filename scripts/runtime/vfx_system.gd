class_name VFXSystem extends RefCounted

## Visual effects subsystem — manages per-object shaders, screen shake, and
## full-screen post-processing.  All effects are fire-and-forget from the
## scenario author's perspective via `vfx()` / `clear_vfx()` / `shake()` /
## `post_fx()` / `clear_post_fx()` helpers in BaseBlock.

var _ctx: Node

# ── Effect registries ───────────────────────────────────────────────

const OBJECT_EFFECTS := {
	"blur":      { "shader": "res://resources/shaders/blur.gdshader",      "params": { "amount": 5.0 } },
	"grayscale": { "shader": "res://resources/shaders/grayscale.gdshader", "params": { "amount": 1.0 } },
	"dissolve":  { "shader": "res://resources/shaders/dissolve.gdshader",  "params": { "threshold": 1.0 } },
}

const POST_EFFECTS := {
	"chromatic": { "shader": "res://resources/shaders/chromatic_aberration.gdshader", "params": { "amount": 3.0 } },
	"vignette":  { "shader": "res://resources/shaders/vignette.gdshader",             "params": { "intensity": 0.5 } },
}

# ── Internal state ──────────────────────────────────────────────────

var _shader_cache: Dictionary = {}          # path → Shader
var _active_materials: Dictionary = {}      # node instance_id → ShaderMaterial
var _active_effects: Dictionary = {}        # object_name → { effect, params }
var _post_fx_name: String = ""              # active post-FX effect name
var _post_fx_params: Dictionary = {}        # active post-FX param overrides
var _post_fx_rect: ColorRect = null         # full-screen post-process target
var _shake_tween: Tween = null

# ── Init ────────────────────────────────────────────────────────────

func _init(ctx: Node) -> void:
	_ctx = ctx


func set_post_fx_rect(node: ColorRect) -> void:
	_post_fx_rect = node

# ── Resolve target ──────────────────────────────────────────────────

func _resolve(target: Variant) -> CanvasItem:
	if target is CanvasItem:
		return target
	if target is String or target is StringName:
		var objects: Dictionary = _ctx.object_manager.objects
		if objects.has(str(target)):
			return objects[str(target)]
	return null

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

# ── Material helpers ────────────────────────────────────────────────

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

# ── Per-object effects ──────────────────────────────────────────────

## Apply a named effect to a target node.  Tweens the primary parameter from
## its current value to *target_value* (or the effect's default) over *duration*
## seconds.  Returns the Tween so the caller can `await` it.
func play(effect_name: String, target: Variant, duration: float = 0.5, params: Dictionary = {}) -> Tween:
	var node := _resolve(target)
	if node == null:
		push_warning("VFXSystem.play: cannot resolve target '%s'" % str(target))
		return _null_tween()

	if not OBJECT_EFFECTS.has(effect_name):
		push_warning("VFXSystem.play: unknown effect '%s'" % effect_name)
		return _null_tween()

	# Track effect by object name for snapshot/restore.
	var obj_name := _resolve_name(target, node)
	if not obj_name.is_empty():
		_active_effects[obj_name] = {"effect": effect_name, "params": params.duplicate()}

	var effect_info: Dictionary = OBJECT_EFFECTS[effect_name]
	var mat := _get_or_create_material(node, effect_info)
	if mat == null:
		return _null_tween()

	# Apply any param overrides instantly.
	for key in params:
		mat.set_shader_parameter(key, params[key])

	# Determine which parameter to animate and its target value.
	var anim_key := ""
	var anim_value: Variant = null
	if params.is_empty():
		# Use defaults — pick the first param as the animated one.
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


## Clear all VFX from a target node, optionally tweening parameters back to
## zero first.  Removes the material after the tween finishes.
func clear(target: Variant, duration: float = 0.3) -> Tween:
	var node := _resolve(target)
	if node == null:
		return _null_tween()

	# Remove tracking by object name.
	var obj_name := _resolve_name(target, node)
	if not obj_name.is_empty():
		_active_effects.erase(obj_name)

	var id := node.get_instance_id()
	if not _active_materials.has(id):
		return _null_tween()

	var mat: ShaderMaterial = _active_materials[id]
	if duration <= 0.0:
		_remove_material(node, id)
		return _null_tween()

	# Tween all float parameters back to 0.
	var t := _ctx.get_tree().create_tween()
	t.set_parallel(true)
	for param_name in mat.shader.get_shader_uniform_list():
		var current = mat.get_shader_parameter(param_name.name)
		if current is float:
			var prop_path = "material:shader_parameter/" + param_name.name
			t.tween_property(node, prop_path, 0.0, max(0.01, duration))
	t.set_parallel(false)
	t.tween_callback(_remove_material.bind(node, id))
	return t


func _get_or_create_material(node: CanvasItem, effect_info: Dictionary) -> ShaderMaterial:
	var id := node.get_instance_id()
	if _active_materials.has(id):
		return _active_materials[id]
	var mat := _make_material(effect_info)
	if mat == null:
		return null
	node.material = mat
	_active_materials[id] = mat
	return mat


func _remove_material(node: CanvasItem, id: int) -> void:
	node.material = null
	_active_materials.erase(id)

# ── Screen shake ────────────────────────────────────────────────────

## Shake the World node with decreasing intensity.
func shake(intensity: float = 10.0, duration: float = 0.5) -> void:
	var world = _ctx.object_manager.objects.get("world")
	if world == null or not world is Node2D:
		return

	# Kill any running shake.
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()

	var original_pos: Vector2 = world.position
	_shake_tween = _ctx.get_tree().create_tween()

	# Use ~16 steps for smooth shake.
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
		decay *= 0.9  # gradual decay

	_shake_tween.tween_property(world, "position", original_pos, step_dur * 0.5)

# ── Full-screen post-processing ─────────────────────────────────────

## Apply a named post-processing effect to the full-screen overlay.
func post(effect_name: String, duration: float = 0.5, params: Dictionary = {}) -> Tween:
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

	# Apply param overrides.
	for key in params:
		mat.set_shader_parameter(key, params[key])

	_post_fx_rect.material = mat
	_post_fx_rect.visible = true
	_post_fx_name = effect_name
	_post_fx_params = params.duplicate()

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

	if anim_key.is_empty():
		return _null_tween()

	var t := _ctx.get_tree().create_tween()
	var prop_path := "material:shader_parameter/" + anim_key
	t.tween_property(_post_fx_rect, prop_path, anim_value, max(0.01, duration))
	return t


## Clear the full-screen post-processing overlay.
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

# ── Shader transitions (called by TransitionSystem) ─────────────────

## Play a shader-based transition on the TransitionOverlay.
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

## Returns a zero-duration tween for callers that want to `await` the result.
func _null_tween() -> Tween:
	var t := _ctx.get_tree().create_tween()
	t.tween_interval(0.0)
	return t


# ── Name resolution helper ────────────────────────────────────────────

func _resolve_name(target: Variant, node: CanvasItem) -> String:
	if target is String or target is StringName:
		return str(target)
	# Try to find the object name by matching instance ID.
	if _ctx and _ctx.object_manager:
		var id := node.get_instance_id()
		for obj_name in _ctx.object_manager.objects:
			var obj = _ctx.object_manager.objects[obj_name]
			if obj is CanvasItem and obj.get_instance_id() == id:
				return str(obj_name)
	return ""


# ── Snapshot / Restore ─────────────────────────────────────────────────

func snapshot() -> Dictionary:
	var data := {}
	if not _active_effects.is_empty():
		data["effects"] = _active_effects.duplicate(true)
	if not _post_fx_name.is_empty():
		data["post_fx"] = {"name": _post_fx_name, "params": _post_fx_params.duplicate()}
	return data


func restore(data: Dictionary) -> void:
	# Re-apply per-object effects.
	if data.has("effects"):
		var effects: Dictionary = data["effects"]
		for obj_name in effects:
			var info: Dictionary = effects[obj_name]
			play(str(info["effect"]), obj_name, 0.0, info.get("params", {}))
	# Re-apply post-FX.
	if data.has("post_fx"):
		var pf: Dictionary = data["post_fx"]
		post(str(pf["name"]), 0.0, pf.get("params", {}))
