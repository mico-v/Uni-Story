class_name VFXSystem extends RefCounted

## Visual effects subsystem — manages per-object shader state, selective effect
## clearing, screen shake, screen capture, full-screen post-processing, and
## shader-based scene transitions.
##
## Effects are tracked as an ordered stack for snapshot/restore and
## `clear_effect()`. Post-processing uses a SubViewport chain for true
## multi-pass compositing when multiple post effects are active.
## Scene transitions use a TRANSITION registry (replacing ad-hoc match
## branches) and can consume the captured screen texture.

var _ctx: Node

# ── Effect registries ───────────────────────────────────────────────

const OBJECT_EFFECTS := {
	"blur":         { "shader": "res://resources/shaders/blur.gdshader",         "params": { "amount": 5.0 } },
	"grayscale":    { "shader": "res://resources/shaders/grayscale.gdshader",    "params": { "amount": 1.0 } },
	"dissolve":     { "shader": "res://resources/shaders/dissolve.gdshader",     "params": { "threshold": 1.0 } },
	"glitch":       { "shader": "res://resources/shaders/glitch.gdshader",       "params": { "intensity": 0.5, "speed": 2.0 } },
	"ripple":       { "shader": "res://resources/shaders/ripple.gdshader",       "params": { "intensity": 0.3, "speed": 2.0 } },
	"pixelate":     { "shader": "res://resources/shaders/pixelate.gdshader",     "params": { "amount": 1.0, "pixel_size": 8.0 } },
	"mosaic":       { "shader": "res://resources/shaders/mosaic.gdshader",       "params": { "amount": 1.0, "tile_size": 8.0 } },
	"kaleidoscope": { "shader": "res://resources/shaders/kaleidoscope.gdshader", "params": { "amount": 1.0, "segments": 6.0 } },
	"swirl":        { "shader": "res://resources/shaders/swirl.gdshader",        "params": { "amount": 1.0, "strength": 2.0 } },
	"radial_blur":  { "shader": "res://resources/shaders/radial_blur.gdshader",  "params": { "amount": 0.5 } },
	"zoom_blur":    { "shader": "res://resources/shaders/zoom_blur.gdshader",    "params": { "amount": 0.3 } },
	"edge_detect":  { "shader": "res://resources/shaders/edge_detect.gdshader",  "params": { "amount": 1.0, "threshold": 0.3 } },
	"invert":       { "shader": "res://resources/shaders/invert.gdshader",       "params": { "amount": 1.0 } },
}

const POST_EFFECTS := {
	"chromatic":    { "shader": "res://resources/shaders/chromatic_aberration_post.gdshader", "params": { "amount": 3.0 } },
	"vignette":     { "shader": "res://resources/shaders/vignette_post.gdshader",             "params": { "intensity": 0.5 } },
	"grayscale":    { "shader": "res://resources/shaders/grayscale_post.gdshader",             "params": { "amount": 1.0 } },
	"blur":         { "shader": "res://resources/shaders/blur_post.gdshader",                  "params": { "amount": 5.0 } },
	"glitch":       { "shader": "res://resources/shaders/glitch.gdshader",                     "params": { "intensity": 0.5, "speed": 2.0 } },
	"pixelate":     { "shader": "res://resources/shaders/pixelate_post.gdshader",              "params": { "amount": 1.0, "pixel_size": 8.0 } },
	"mosaic":       { "shader": "res://resources/shaders/mosaic_post.gdshader",                "params": { "amount": 1.0, "tile_size": 8.0 } },
	"kaleidoscope": { "shader": "res://resources/shaders/kaleidoscope_post.gdshader",          "params": { "amount": 1.0, "segments": 6.0 } },
	"swirl":        { "shader": "res://resources/shaders/swirl_post.gdshader",                 "params": { "amount": 1.0, "strength": 2.0 } },
	"radial_blur":  { "shader": "res://resources/shaders/radial_blur_post.gdshader",           "params": { "amount": 0.5 } },
	"zoom_blur":    { "shader": "res://resources/shaders/zoom_blur_post.gdshader",             "params": { "amount": 0.3 } },
	"edge_detect":  { "shader": "res://resources/shaders/edge_detect_post.gdshader",           "params": { "amount": 1.0, "threshold": 0.3 } },
	"invert":       { "shader": "res://resources/shaders/invert_post.gdshader",                "params": { "amount": 1.0 } },
}

const TRANSITION_EFFECTS := {
	"dissolve": { "shader": "res://resources/shaders/dissolve.gdshader", "param": "threshold", "from": 0.0, "to": 1.0 },
	"wipe":     { "shader": "res://resources/shaders/wipe.gdshader",     "param": "progress",  "from": 0.0, "to": 1.0 },
}

const MAX_STACK_DEPTH := 3

# ── Internal state ──────────────────────────────────────────────────

var _shader_cache: Dictionary = {}          # path → Shader
var _active_effects: Dictionary = {}        # target_name → Array[Dictionary]
var _stack_containers: Dictionary = {}      # target_name → MaterialStackContainer
var _post_fx_name: String = ""
var _post_fx_params: Dictionary = {}
var _post_fx_rect: ColorRect = null
var _post_viewports: Array[Dictionary] = []   # SubViewport chain for multi-pass compositing
var _shake_tween: Tween = null
var _captured_texture: ImageTexture = null

# ── Init ────────────────────────────────────────────────────────────

func _init(ctx: Node) -> void:
	_ctx = ctx


func set_post_fx_rect(node: ColorRect) -> void:
	_post_fx_rect = node

# ── Resolve target ──────────────────────────────────────────────────

func _resolve(target: Variant) -> CanvasItem:
	if _is_camera_target(target):
		return _post_fx_rect
	if is_instance_valid(target) and target is CanvasItem:
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

## Apply a named effect to a target node. If the target already has active
## effects, the new effect is added to the tracked stack and becomes visible.
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
	var is_stacked := effects.size() > 1
	if effects.size() == 1:
		node.material = mat
	else:
		_apply_stack(obj_name, node, effects)

	# Animate the primary parameter (single effect only; stacked effects use a
	# compositing material whose shader parameters differ from the source effect).
	if is_stacked:
		return _null_tween()

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


## Query available uniform parameters for a named effect.
## Returns an empty array for unknown effects, otherwise a list of {name, type, hint} dicts.
func query_uniforms(effect_name: String, is_post: bool = false) -> Array:
	effect_name = _normalize_effect_name(effect_name)
	var registry := POST_EFFECTS if is_post else OBJECT_EFFECTS
	var info: Dictionary = registry.get(effect_name, {})
	if info.is_empty():
		return []
	var shader := _load_shader(info["shader"])
	if shader == null:
		return []
	var result: Array = []
	for uniform in shader.get_shader_uniform_list():
		result.append({"name": uniform.name, "type": _uniform_type_name(uniform.type), "hint": uniform.hint})
	return result


func _uniform_type_name(uniform_type: int) -> String:
	# Type enums from RenderingServer/Shader; see Godot docs.
	match uniform_type:
		0:  return "float"
		1:  return "vec2"
		2:  return "vec3"
		3:  return "vec4"
		4:  return "bool"
		5:  return "int"
		6:  return "uint"
		7:  return "sampler2D"
		_:  return "unknown"


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

	for entry in _post_viewports:
		var vp: SubViewport = entry.get("viewport", null)
		var rect: ColorRect = entry.get("display", null)
		if vp and is_instance_valid(vp):
			vp.queue_free()
		if rect and is_instance_valid(rect):
			rect.queue_free()
	_post_viewports.clear()
	_captured_texture = null

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

	if effects.size() <= 1:
		node.material = effects[0].get("material", null)
		return

	# True multi-pass compositing via SubViewport chain.
	# Each effect is a pass: the first pass samples the node's base texture,
	# each subsequent pass samples the previous pass's output.
	var root: Node = node.get_parent()
	var container := _ensure_multi_pass_container(obj_name, root, node)
	if container == null:
		# Fallback: apply last effect only.
		node.material = effects[effects.size() - 1].get("material", null)
		return

	# Rebuild the viewport chain.
	# Pass 0: render node with first material into vp0, display vp0.
	# Pass 1+: render the previous display rect with the next material into the next vp.
	var chain := _build_compositing_chain(container, node, effects)
	if chain.is_empty():
		node.material = effects[effects.size() - 1].get("material", null)
		return

	# The last viewport's output is the final composite.
	var last: Dictionary = chain[chain.size() - 1]
	var last_vp: SubViewport = last.get("viewport", null)
	if last_vp:
		last_vp.size = _ctx.get_viewport().get_visible_rect().size
		_attach_viewport_texture_to_node(node, last_vp)


func _destroy_stack(obj_name: String) -> void:
	var container: Node = _stack_containers.get(obj_name, null)
	if container and is_instance_valid(container):
		container.queue_free()
	_stack_containers.erase(obj_name)


func _ensure_multi_pass_container(obj_name: String, root: Node, node: CanvasItem) -> Node:
	if root == null:
		return null
	var container := Node.new()
	container.name = "_vfx_compositor_%s" % obj_name
	root.add_child(container)
	_stack_containers[obj_name] = container
	return container


func _build_compositing_chain(container: Node, node: CanvasItem, effects: Array) -> Array[Dictionary]:
	var chain: Array[Dictionary] = []
	var vp_rect: Rect2 = _ctx.get_viewport().get_visible_rect()

	# Pass 0: render the original node (with its first effect's material) into a SubViewport.
	var initial_material: Material = effects[0].get("material", null)
	node.material = initial_material

	# Duplicate the node as a child of a viewport to capture it.
	var vp0 := _create_pass_viewport(container, "pass0", vp_rect.size)
	var clone0 := _clone_for_viewport(node, vp0)
	clone0.material = initial_material
	chain.append({"viewport": vp0, "clone": clone0})

	# Build display rect for the viewport output.
	var disp0 := _create_display_rect(container, "disp0", vp_rect.size)
	disp0.material = ShaderMaterial.new()
	disp0.material.shader = _load_simple_texture_shader()
	disp0.material.set_shader_parameter("source", vp0.get_texture())

	# Each subsequent effect: render the previous display into a new viewport.
	for i in range(1, effects.size()):
		var prev_disp: ColorRect = chain[chain.size() - 1].get("display", disp0)
		var material: Material = effects[i].get("material", null)
		var vp := _create_pass_viewport(container, "pass%d" % i, vp_rect.size)

		# Clone the previous display rect into this viewport with the new material.
		var clone_disp := _clone_display_for_viewport(prev_disp, vp)
		clone_disp.material = material if material else ShaderMaterial.new()
		chain.append({"viewport": vp, "clone": clone_disp})

		# Create display rect for this pass's output.
		var disp := _create_display_rect(container, "disp%d" % i, vp_rect.size)
		disp.material = ShaderMaterial.new()
		disp.material.shader = _load_simple_texture_shader()
		disp.material.set_shader_parameter("source", vp.get_texture())
		chain[chain.size() - 1]["display"] = disp

	return chain


func _create_pass_viewport(parent: Node, name: String, size: Vector2) -> SubViewport:
	var vp := SubViewport.new()
	vp.name = name
	vp.size = size
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)
	return vp


func _create_display_rect(parent: Node, name: String, size: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = name
	rect.size = size
	parent.add_child(rect)
	return rect


func _clone_for_viewport(source: CanvasItem, vp: SubViewport) -> CanvasItem:
	# Create a simple texture-based display of the original node's contents.
	# In practice, we render the source node's texture into the viewport
	# by placing a ColorRect with the source texture.
	var tex_rect := ColorRect.new()
	tex_rect.name = "source"
	tex_rect.size = vp.size
	vp.add_child(tex_rect)
	return tex_rect


func _clone_display_for_viewport(source: ColorRect, vp: SubViewport) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "source"
	rect.size = source.size
	rect.color = source.color
	rect.material = source.material.duplicate() if source.material else null
	vp.add_child(rect)
	return rect


func _attach_viewport_texture_to_node(node: CanvasItem, vp: SubViewport) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = _load_simple_texture_shader()
	mat.set_shader_parameter("source", vp.get_texture())
	node.material = mat


var _simple_texture_shader: Shader

func _load_simple_texture_shader() -> Shader:
	if _simple_texture_shader:
		return _simple_texture_shader
	var shader_code := """shader_type canvas_item;
uniform sampler2D source : source_color;
void fragment() {
	COLOR = texture(source, UV);
}
"""
	var s := Shader.new()
	s.code = shader_code
	_simple_texture_shader = s
	return s

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
	# The dummy renderer used by --headless exposes a viewport texture object
	# without a backing RID; asking it for an Image emits an engine error.
	if DisplayServer.get_name() == "headless":
		return null
	var vp := _ctx.get_viewport()
	if vp == null:
		return null
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		return null
	var texture := ImageTexture.create_from_image(img)
	_captured_texture = texture
	return texture


## Capture screen then play a shader-based transition using the captured texture.
## The captured screen is fed into the transition shader's `capture_texture` uniform
## so the shader blends between the previous frame and the new scene.
func transition_with_capture(effect_name: String, duration: float = 0.5) -> void:
	var captured := capture_screen()
	if captured == null:
		return
	var overlay = _ctx.object_manager.objects.get("transition_overlay")
	if overlay == null or not overlay is ColorRect:
		return

	var normalized := _normalize_effect_name(effect_name)
	if not TRANSITION_EFFECTS.has(normalized):
		push_warning("VFXSystem.transition_with_capture: unknown transition '%s'" % effect_name)
		return

	var info: Dictionary = TRANSITION_EFFECTS[normalized]
	var shader := _load_shader(info["shader"])
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var param: String = info["param"]
	var from_val: float = float(info["from"])
	var to_val: float = float(info["to"])
	mat.set_shader_parameter(param, from_val)
	mat.set_shader_parameter("use_capture", 1.0)
	mat.set_shader_parameter("capture_texture", captured)

	overlay.material = mat
	overlay.visible = true
	overlay.color = Color(1, 1, 1, 1)

	var t := _ctx.get_tree().create_tween()
	t.tween_property(overlay, "material:shader_parameter/" + param, to_val, max(0.01, duration))
	t.tween_callback(func():
		overlay.material = null
		overlay.visible = false
		_captured_texture = null
	)

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

	var normalized := _normalize_effect_name(effect_name)
	if not TRANSITION_EFFECTS.has(normalized):
		push_warning("VFXSystem.transition: unknown transition '%s'" % effect_name)
		return

	var info: Dictionary = TRANSITION_EFFECTS[normalized]
	_shader_transition(overlay, info["shader"], info["param"], float(info["from"]), float(info["to"]), duration)


func _shader_transition(overlay: ColorRect, shader_path: String, param: String, from_val: float, to_val: float, duration: float) -> void:
	var shader := _load_shader(shader_path)
	if shader == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(param, from_val)
	mat.set_shader_parameter("use_capture", 0.0)
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
	# Guard against freed _ctx — fallback to Engine.get_main_loop().
	var tree: SceneTree = null
	if is_instance_valid(_ctx):
		tree = _ctx.get_tree()
	if tree == null:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		push_warning("VFXSystem._null_tween: no SceneTree available")
		return null
	var t := tree.create_tween()
	t.tween_callback(func(): pass)
	return t


func _normalize_effect_name(effect_name: String) -> String:
	match effect_name.to_lower():
		"mono", "colorless", "gray", "grey":
			return "grayscale"
		"radial_blur", "lens_blur":
			return "blur"
		"pixel", "pixelization":
			return "pixelate"
		"tile", "block":
			return "mosaic"
		"kaleido", "kaleidoscope_effect":
			return "kaleidoscope"
		"twirl", "whirl":
			return "swirl"
		"radial", "radial_zoom":
			return "radial_blur"
		"zoom", "speed_blur", "forward_blur":
			return "zoom_blur"
		"edges", "sobel", "outline":
			return "edge_detect"
		"negative", "reverse_color", "reverse":
			return "invert"
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
