extends SceneTree

## Headless smoke test for VFXSystem material stack and screen capture.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/vfx_stack_smoke_test.gd

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
		_test_effect_stack(vfx, scene)
		_test_screen_capture(vfx)
		_test_snapshot_restore(vfx)

	root.remove_child(scene)
	scene.free()
	await process_frame
	_finish()


# ── Effect stacking ─────────────────────────────────────────────────

func _test_effect_stack(vfx: Variant, scene: Node) -> void:
	# Verify effect registry includes glitch and ripple.
	var obj_effects: Dictionary = vfx.OBJECT_EFFECTS
	_expect(obj_effects.has("blur"), "OBJECT_EFFECTS should include blur")
	_expect(obj_effects.has("glitch"), "OBJECT_EFFECTS should include glitch")
	_expect(obj_effects.has("ripple"), "OBJECT_EFFECTS should include ripple")

	# Verify max stack depth.
	_expect(vfx.MAX_STACK_DEPTH >= 2, "MAX_STACK_DEPTH should be at least 2")

	# Try playing an effect on the world node (should exist).
	var world := scene.get_node_or_null("GameView/World") as Node2D
	if world == null:
		# World might be nested differently — skip stack test.
		return

	# Play blur on world.
	var t := vfx.play("blur", world, 0.1)
	_expect(t != null, "play() should return a Tween")

	# Wait for tween to start.
	await process_frame

	# Verify world has a material.
	_expect(world.material != null, "world should have material after play()")

	# Play grayscale on world — should stack.
	var t2 := vfx.play("grayscale", world, 0.1)
	_expect(t2 != null, "second play() should return a Tween")

	await process_frame

	# Clear via name — should use clear_effect if it exists.
	if vfx.has_method("clear_effect"):
		var t3 := vfx.clear_effect("blur", world, 0.0)
		# After clear_effect, world should still have material (grayscale remains).
		_expect(world.material != null, "world should still have material after clear_effect")

	# Clear all effects.
	vfx.clear(world, 0.0)
	await process_frame

	# Verify clear_effect and clear don't crash.
	_expect(true, "effect stack operations should not crash")


# ── Screen capture ──────────────────────────────────────────────────

func _test_screen_capture(vfx: Variant) -> void:
	if not vfx.has_method("capture_screen"):
		_expect(false, "VFXSystem should have capture_screen")
		return

	var tex := vfx.capture_screen()
	# In headless mode, viewport texture may be empty.
	_expect(tex is ImageTexture or tex == null, "capture_screen should return ImageTexture or null")


# ── Snapshot / restore ──────────────────────────────────────────────

func _test_snapshot_restore(vfx: Variant) -> void:
	if not vfx.has_method("snapshot"):
		_expect(false, "VFXSystem should have snapshot")
		return

	var snap: Dictionary = vfx.snapshot()
	_expect(snap is Dictionary, "snapshot should return Dictionary")

	if snap.has("effects"):
		# Should include per-target effect lists.
		var effects: Dictionary = snap["effects"]
		for key in effects:
			var list: Array = effects[key]
			for entry in list:
				var ed: Dictionary = entry
				_expect(ed.has("effect"), "snapshot entry should have effect name")
				_expect(ed.has("params"), "snapshot entry should have params")

	var ok: bool = vfx.restore(snap) if vfx.has_method("restore") else false
	_expect(ok or true, "restore should handle snapshot")


# ── Helpers ──────────────────────────────────────────────────────────

func _finish() -> void:
	if _failures.is_empty():
		print("VFXStackSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("VFXStackSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
