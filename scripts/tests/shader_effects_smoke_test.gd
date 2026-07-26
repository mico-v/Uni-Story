extends SceneTree

## Headless smoke test for Phase 14 + Phase 16 shader effects.
## Verifies all shaders compile, register correctly, and support snapshot/restore.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/shader_effects_smoke_test.gd

const MAIN_SCENE := "res://scene/game.tscn"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	if packed == null:
		_expect(false, "main scene should load")
		_finish()
		return

	var scene: Node = packed.instantiate()
	if scene == null:
		_expect(false, "main scene should instantiate")
		_finish()
		return
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	var vfx: Variant = scene.get("vfx")
	if vfx == null:
		_expect(false, "VFXSystem should exist")
	else:
		_test_shader_registry(vfx)
		await _test_compile_all(vfx)
		await _test_new_object_effects(vfx, scene)
		await _test_post_effects(vfx)
		await _test_snapshot_restore_new(vfx, scene)
		_test_query_uniforms(vfx)
		_test_aliases(vfx)
		vfx.clear_all()

	root.remove_child(scene)
	scene.free()
	await process_frame
	await process_frame
	_finish()


# ── Registry checks ─────────────────────────────────────────────────

func _test_shader_registry(vfx: Variant) -> void:
	var obj_effects: Dictionary = vfx.OBJECT_EFFECTS
	var post_effects: Dictionary = vfx.POST_EFFECTS

	# Phase 14 effects
	var phase14 := [
		"pixelate", "mosaic", "kaleidoscope", "swirl",
		"radial_blur", "zoom_blur", "edge_detect", "invert",
	]
	for name in phase14:
		_expect(obj_effects.has(name), "OBJECT_EFFECTS should include %s" % name)
		_expect(post_effects.has(name), "POST_EFFECTS should include %s" % name)

	# Phase 16 — screen effects
	var phase16_screen := [
		"barrel", "barrel_hyper", "glow", "overglow", "overlay",
		"rain", "wiggle", "flip_grid",
	]
	for name in phase16_screen:
		_expect(obj_effects.has(name), "OBJECT_EFFECTS should include %s" % name)

	# Phase 16 — blur variants
	var phase16_blur := [
		"gaussian_blur", "lens_blur", "motion_blur", "rotation_blur",
	]
	for name in phase16_blur:
		_expect(obj_effects.has(name), "OBJECT_EFFECTS should include %s" % name)

	# Phase 16 — color / special
	var phase16_color := [
		"mono", "sharpen", "shake", "rand_roll", "blink", "broken_tv",
		"color", "colorless", "fade", "fade_global", "fade_radial_blur",
		"gray_wave", "water", "default",
	]
	for name in phase16_color:
		_expect(obj_effects.has(name), "OBJECT_EFFECTS should include %s" % name)

	# Phase 16 — post-only effects
	var phase16_post := [
		"barrel", "barrel_hyper", "glow", "overglow", "overlay",
		"rain", "wiggle", "gaussian_blur", "lens_blur", "motion_blur",
		"rotation_blur", "mono", "sharpen", "shake", "rand_roll",
		"blink", "broken_tv", "color", "fade", "fade_global",
		"gray_wave", "water", "ripple_move", "roll",
	]
	for name in phase16_post:
		_expect(post_effects.has(name), "POST_EFFECTS should include %s" % name)

	# Existing effects still exist
	_expect(obj_effects.has("blur"), "OBJECT_EFFECTS should include blur")
	_expect(obj_effects.has("glitch"), "OBJECT_EFFECTS should include glitch")
	_expect(post_effects.has("chromatic"), "POST_EFFECTS should include chromatic")
	_expect(post_effects.has("vignette"), "POST_EFFECTS should include vignette")

	# Transition effects
	var trans: Dictionary = vfx.TRANSITION_EFFECTS
	_expect(trans.has("dissolve"), "TRANSITION_EFFECTS should include dissolve")
	_expect(trans.has("wipe"), "TRANSITION_EFFECTS should include wipe")
	_expect(trans.has("fade"), "TRANSITION_EFFECTS should include fade")
	_expect(trans.has("flip_grid"), "TRANSITION_EFFECTS should include flip_grid")
	_expect(trans.has("roll"), "TRANSITION_EFFECTS should include roll")
	_expect(trans.has("fade_radial_blur"), "TRANSITION_EFFECTS should include fade_radial_blur")


# ── Compilation check ───────────────────────────────────────────────

func _test_compile_all(vfx: Variant) -> void:
	var all_effects: Array = (vfx.OBJECT_EFFECTS as Dictionary).keys()
	for name in all_effects:
		var info: Dictionary = vfx.OBJECT_EFFECTS[name]
		var path: String = info["shader"]
		var shader := load(path)
		_expect(shader is Shader, "Object shader '%s' should load for '%s'" % [path, name])

	var all_post: Array = (vfx.POST_EFFECTS as Dictionary).keys()
	for name in all_post:
		var info: Dictionary = vfx.POST_EFFECTS[name]
		var path: String = info["shader"]
		var shader := load(path)
		_expect(shader is Shader, "POST shader '%s' should load for '%s'" % [path, name])


# ── Object effects ──────────────────────────────────────────────────

func _test_new_object_effects(vfx: Variant, scene: Node) -> void:
	var world: Node2D = scene.get_node_or_null("GameView/World") as Node2D
	if world == null:
		return

	# Phase 14 effects
	var test_effects := {
		"pixelate": {"amount": 1.0, "pixel_size": 8.0},
		"mosaic": {"amount": 1.0, "tile_size": 8.0},
		"kaleidoscope": {"amount": 1.0, "segments": 6.0},
		"swirl": {"amount": 1.0, "strength": 2.0},
		"radial_blur": {"amount": 0.5},
		"zoom_blur": {"amount": 0.3},
		"edge_detect": {"amount": 1.0, "threshold": 0.3},
		"invert": {"amount": 1.0},
		# Phase 16 sample effects
		"barrel": {"sigma": 0.2},
		"glow": {"size": 1.0, "strength": 1.0},
		"wiggle": {"intensity": 0.3},
		"blink": {"speed": 5.0, "strength": 1.0},
		"broken_tv": {"intensity": 0.5},
		"mono": {"amount": 1.0},
		"sharpen": {"strength": 1.0},
		"shake": {"intensity": Vector2(0.05, 0.05)},
		"water": {"intensity": 0.3},
	}

	for effect_name in test_effects:
		var params: Dictionary = test_effects[effect_name]
		var t: Variant = vfx.play(effect_name, world, 0.0, params)
		_expect(t != null, "play('%s') should return a Tween" % effect_name)
		await process_frame
		_expect(world.material != null, "world should have material after play('%s')" % effect_name)
		vfx.clear(world, 0.0)
		await process_frame

	# Test stacking with new effects.
	vfx.play("pixelate", world, 0.0, {"amount": 1.0, "pixel_size": 6.0})
	await process_frame
	vfx.play("invert", world, 0.0, {"amount": 0.5})
	await process_frame
	await process_frame
	var stacked: Dictionary = vfx.snapshot()
	var world_effects: Array = stacked.get("effects", {}).get("world", [])
	_expect(world_effects.size() == 2, "stacked world effects should be 2")
	vfx.clear(world, 0.0)
	await process_frame


# ── Post effects ────────────────────────────────────────────────────

func _test_post_effects(vfx: Variant) -> void:
	var all_post := [
		# Phase 14
		"pixelate", "mosaic", "kaleidoscope", "swirl",
		"radial_blur", "zoom_blur", "edge_detect", "invert",
		# Phase 16
		"barrel", "barrel_hyper", "glow", "overglow", "overlay",
		"rain", "wiggle", "gaussian_blur", "lens_blur", "motion_blur",
		"rotation_blur", "mono", "sharpen", "shake", "rand_roll",
		"blink", "broken_tv", "color", "fade", "fade_global",
		"gray_wave", "water", "ripple_move", "roll",
	]
	for name in all_post:
		var info: Dictionary = vfx.POST_EFFECTS[name]
		var shader_path: String = info["shader"]
		var shader := load(shader_path)
		_expect(shader is Shader, "POST shader '%s' should load for %s" % [shader_path, name])
		var mat := ShaderMaterial.new()
		mat.shader = shader
		_expect(mat.shader == shader, "ShaderMaterial should accept shader for '%s'" % name)


# ── Snapshot / restore with new effects ─────────────────────────────

func _test_snapshot_restore_new(vfx: Variant, scene: Node) -> void:
	var world: Node2D = scene.get_node_or_null("GameView/World") as Node2D
	if world == null:
		return

	vfx.play("edge_detect", world, 0.0, {"amount": 0.8, "threshold": 0.2})
	await process_frame
	await process_frame

	var snap: Dictionary = vfx.snapshot()
	_expect(snap.has("effects"), "snapshot should contain effects after edge_detect play")

	vfx.clear(world, 0.0)
	await process_frame
	await process_frame

	_expect(world.material == null, "world should have no material after clear")

	vfx.restore(snap)
	await process_frame
	await process_frame

	var restored: Dictionary = vfx.snapshot()
	var restored_map: Dictionary = restored.get("effects", {})
	var r_world: Array = restored_map.get("world", [])
	_expect(r_world.size() == 1, "restore should recreate edge_detect effect")
	if r_world.size() == 1:
		_expect(str(r_world[0].get("effect", "")) == "edge_detect", "restored effect should be edge_detect")

	vfx.clear(world, 0.0)


# ── Uniform query ───────────────────────────────────────────────────

func _test_query_uniforms(vfx: Variant) -> void:
	if not vfx.has_method("query_uniforms"):
		_expect(false, "VFXSystem should have query_uniforms method")
		return

	var uniforms: Array = vfx.query_uniforms("pixelate", false)
	_expect(uniforms.size() >= 2, "pixelate should have at least 2 uniforms (pixel_size, amount)")

	uniforms = vfx.query_uniforms("edge_detect", true)
	_expect(uniforms.size() >= 2, "edge_detect post should have at least 2 uniforms")

	# Phase 16 effects
	uniforms = vfx.query_uniforms("barrel", false)
	_expect(not uniforms.is_empty(), "barrel should have uniforms")

	uniforms = vfx.query_uniforms("glow", false)
	_expect(not uniforms.is_empty(), "glow should have uniforms")

	uniforms = vfx.query_uniforms("blink", false)
	_expect(not uniforms.is_empty(), "blink should have uniforms")

	# Unknown effect returns empty array
	uniforms = vfx.query_uniforms("nonexistent", false)
	_expect(uniforms.is_empty(), "query_uniforms for unknown effect should return []")


# ── Alias resolution ────────────────────────────────────────────────

func _test_aliases(vfx: Variant) -> void:
	if not vfx.has_method("_normalize_effect_name"):
		return

	# Phase 14 aliases
	_expect(_call_normalize(vfx, "mono") == "grayscale", "mono → grayscale")
	_expect(_call_normalize(vfx, "radial_blur") == "blur", "radial_blur → blur")
	_expect(_call_normalize(vfx, "kaleido") == "kaleidoscope", "kaleido → kaleidoscope")
	_expect(_call_normalize(vfx, "twirl") == "swirl", "twirl → swirl")
	_expect(_call_normalize(vfx, "edges") == "edge_detect", "edges → edge_detect")

	# Phase 16 aliases
	_expect(_call_normalize(vfx, "fisheye") == "barrel", "fisheye → barrel")
	_expect(_call_normalize(vfx, "bloom") == "glow", "bloom → glow")
	_expect(_call_normalize(vfx, "overexposure") == "overglow", "overexposure → overglow")
	_expect(_call_normalize(vfx, "raindrop") == "rain", "raindrop → rain")
	_expect(_call_normalize(vfx, "wobble") == "wiggle", "wobble → wiggle")
	_expect(_call_normalize(vfx, "page_flip") == "flip_grid", "page_flip → flip_grid")
	_expect(_call_normalize(vfx, "gaussian") == "gaussian_blur", "gaussian → gaussian_blur")
	_expect(_call_normalize(vfx, "dof") == "lens_blur", "dof → lens_blur")
	_expect(_call_normalize(vfx, "motionblur") == "motion_blur", "motionblur → motion_blur")
	_expect(_call_normalize(vfx, "circular_blur") == "rotation_blur", "circular_blur → rotation_blur")
	_expect(_call_normalize(vfx, "sharp") == "sharpen", "sharp → sharpen")
	_expect(_call_normalize(vfx, "camerashake") == "shake", "camerashake → shake")
	_expect(_call_normalize(vfx, "random_roll") == "rand_roll", "random_roll → rand_roll")
	_expect(_call_normalize(vfx, "flash") == "blink", "flash → blink")
	_expect(_call_normalize(vfx, "crt") == "broken_tv", "crt → broken_tv")
	_expect(_call_normalize(vfx, "hsv") == "color", "hsv → color")
	_expect(_call_normalize(vfx, "desaturate") == "colorless", "desaturate → colorless")
	_expect(_call_normalize(vfx, "darken") == "fade", "darken → fade")
	_expect(_call_normalize(vfx, "global_fade") == "fade_global", "global_fade → fade_global")
	_expect(_call_normalize(vfx, "radial_fade") == "fade_radial_blur", "radial_fade → fade_radial_blur")
	_expect(_call_normalize(vfx, "wave_grayscale") == "gray_wave", "wave_grayscale → gray_wave")
	_expect(_call_normalize(vfx, "underwater") == "water", "underwater → water")
	_expect(_call_normalize(vfx, "moving_ripple") == "ripple_move", "moving_ripple → ripple_move")
	_expect(_call_normalize(vfx, "rotate") == "roll", "rotate → roll")


func _call_normalize(vfx: Variant, name: String) -> String:
	return vfx._normalize_effect_name(name)


# ── Helpers ──────────────────────────────────────────────────────────

func _finish() -> void:
	if _failures.is_empty():
		print("ShaderEffectsSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ShaderEffectsSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
