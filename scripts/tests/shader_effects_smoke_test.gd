extends SceneTree

## Headless smoke test for Phase 14 shader effects.
## Verifies all new shaders compile, register correctly, and support snapshot/restore.
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
		await _test_new_object_effects(vfx, scene)
		await _test_post_effects(vfx)
		_test_snapshot_restore_new(vfx, scene)
		_test_query_uniforms(vfx)
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

	var new_effects := [
		"pixelate", "mosaic", "kaleidoscope", "swirl",
		"radial_blur", "zoom_blur", "edge_detect", "invert",
	]
	for name in new_effects:
		_expect(obj_effects.has(name), "OBJECT_EFFECTS should include %s" % name)
		_expect(post_effects.has(name), "POST_EFFECTS should include %s" % name)

	# Also check existing effects still exist.
	_expect(obj_effects.has("blur"), "OBJECT_EFFECTS should include blur")
	_expect(obj_effects.has("glitch"), "OBJECT_EFFECTS should include glitch")
	_expect(post_effects.has("chromatic"), "POST_EFFECTS should include chromatic")
	_expect(post_effects.has("vignette"), "POST_EFFECTS should include vignette")


# ── Object effects ──────────────────────────────────────────────────

func _test_new_object_effects(vfx: Variant, scene: Node) -> void:
	var world: Node2D = scene.get_node_or_null("GameView/World") as Node2D
	if world == null:
		return

	# Test each new object effect loads and applies without crashing.
	var test_effects := {
		"pixelate": {"amount": 1.0, "pixel_size": 8.0},
		"mosaic": {"amount": 1.0, "tile_size": 8.0},
		"kaleidoscope": {"amount": 1.0, "segments": 6.0},
		"swirl": {"amount": 1.0, "strength": 2.0},
		"radial_blur": {"amount": 0.5},
		"zoom_blur": {"amount": 0.3},
		"edge_detect": {"amount": 1.0, "threshold": 0.3},
		"invert": {"amount": 1.0},
	}

	for effect_name in test_effects:
		var params: Dictionary = test_effects[effect_name]
		var t: Variant = vfx.play(effect_name, world, 0.0, params)
		_expect(t != null, "play('%s') should return a Tween" % effect_name)
		await process_frame
		# After applying, world should have a material.
		_expect(world.material != null, "world should have material after play('%s')" % effect_name)
		# Clean up.
		vfx.clear(world, 0.0)
		await process_frame

	# Test stacking with a new effect.
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
	# Post effects need the rect to be set up in the scene. If not available, skip.
	# Verify that post() for new effects doesn't crash when no rect is set.
	# We cannot fully test post() without the rect in headless, but we can
	# verify the registry entries map to valid shader paths that load.
	var new_post := [
		"pixelate", "mosaic", "kaleidoscope", "swirl",
		"radial_blur", "zoom_blur", "edge_detect", "invert",
	]
	for name in new_post:
		var info: Dictionary = vfx.POST_EFFECTS[name]
		var shader_path: String = info["shader"]
		# Load shader to verify it compiles.
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
	_expect(uniforms.size() >= 3, "edge_detect post should have at least 3 uniforms")

	# Unknown effect returns empty array.
	uniforms = vfx.query_uniforms("nonexistent", false)
	_expect(uniforms.is_empty(), "query_uniforms for unknown effect should return []")


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
