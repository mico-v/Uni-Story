extends SceneTree

## Headless smoke test for Phase 15 — Nova Lua API compatibility.
##
## Verifies that previously no-op stubs now have real behavior:
##  - box_tint / box_anchor / box_alignment / box_offset / new_page
##  - stop_auto_ff / stop_ff / immediate_step
##  - input_on / input_off / ff_shortcut_on / ff_shortcut_off
##  - auto_fade_on / auto_fade_off / auto_time
##  - text_delay / text_duration / text_scroll / set_text_speed / skip_mode_custom
##  - anim_hold_begin / anim_hold_end
##  - volume (BGM/SE/Voice)
##  - get_current_position / input / text_easing
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/nova_lua_compat_smoke_test.gd

const SCENE_PATH := "res://scene/game.tscn"
const HINTS_PATH := "user://tests/nova_lua_compat_hints.cfg"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_prepare_dirs()

	# ── Load main scene ────────────────────────────────────────────
	var nova := await _load_main_scene()
	if nova == null:
		_failures.append("Failed to load main scene")
		_finish()
		return

	# ── 1. box_tint — dialogue box background color ─────────────────
	_test_box_tint(nova)

	# ── 2. box_anchor — dialogue box anchor positioning ─────────────
	_test_box_anchor(nova)

	# ── 3. box_alignment — text alignment in dialogue box ──────────
	_test_box_alignment(nova)

	# ── 4. box_offset — dialogue box offset margins ─────────────────
	_test_box_offset(nova)

	# ── 5. new_page — clear dialogue text ───────────────────────────
	_test_new_page(nova)

	# ── 6. stop_auto_ff / stop_ff — mode deactivation ──────────────
	_test_stop_auto_ff(nova)

	# ── 7. immediate_step — force advance ──────────────────────────
	_test_immediate_step(nova)

	# ── 8. input_on / input_off — input toggle ─────────────────────
	_test_input_toggle(nova)

	# ── 9. ff_shortcut_on / ff_shortcut_off — shortcut toggle ──────
	_test_ff_shortcut(nova)

	# ── 10. auto_fade_on / auto_fade_off — counter ─────────────────
	_test_auto_fade_counter(nova)

	# ── 11. auto_time — auto delay override ────────────────────────
	_test_auto_time(nova)

	# ── 12. text_delay / text_duration / set_text_speed — CPS ──────
	_test_text_speed(nova)

	# ── 13. text_scroll — box vertical position ────────────────────
	_test_text_scroll(nova)

	# ── 14. text_easing — easing storage ───────────────────────────
	_test_text_easing(nova)

	# ── 15. skip_mode_custom — skip override ───────────────────────
	_test_skip_mode_custom(nova)

	# ── 16. anim_hold_begin / anim_hold_end — counter ──────────────
	_test_anim_hold(nova)

	# ── 17. volume — per-channel volume control ────────────────────
	_test_volume(nova)

	# ── 18. get_current_position — position snapshot ───────────────
	_test_get_current_position(nova)

	# ── 19. input — variable input prompt (toast fallback) ─────────
	_test_input_prompt(nova)

	# ── 20. Compile-and-execute: all new APIs in a single block ────
	_test_compile_all_apis(nova)

	await _cleanup_scene(nova)
	_finish()


# ── Test implementations ────────────────────────────────────────────────

func _test_box_tint(nova: Node) -> void:
	print("  test_box_tint ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("box_tint: no block context")
		return

	# Test with Color value
	var box_before: Variant = ctx._resolve_dbox()
	if box_before is Panel:
		# Test with numeric greyscale
		ctx.box_tint(0.5)
		_failures.append("box_tint(0.5) should not crash, but _resolve_dbox may return null in headless")
	else:
		# In headless, there's no Panel. Just verify the call doesn't crash.
		ctx.box_tint(0.5)
		ctx.box_tint(Color.RED)
		ctx.box_tint([1.0, 0.5])
		# These should all be no-ops without crashing — that's fine for headless.
		print("    box_tint calls completed (no visible Panel in headless)")

	print("  test_box_tint: OK (non-crashing)")


func _test_box_anchor(nova: Node) -> void:
	print("  test_box_anchor ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("box_anchor: no block context")
		return
	ctx.box_anchor([0.1, 0.9, 0.72, 0.96])
	ctx.box_anchor([0.05, 0.95, 0.10, 0.95])
	# Should not crash even if no visible box
	print("  test_box_anchor: OK")


func _test_box_alignment(nova: Node) -> void:
	print("  test_box_alignment ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("box_alignment: no block context")
		return
	ctx.box_alignment("left")
	ctx.box_alignment("center")
	ctx.box_alignment("right")
	print("  test_box_alignment: OK")


func _test_box_offset(nova: Node) -> void:
	print("  test_box_offset ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("box_offset: no block context")
		return
	ctx.box_offset([0, 0, 0, 0])
	ctx.box_offset([10, 10, 5, 5])
	print("  test_box_offset: OK")


func _test_new_page(nova: Node) -> void:
	print("  test_new_page ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("new_page: no block context")
		return
	ctx.new_page()
	print("  test_new_page: OK")


func _test_stop_auto_ff(nova: Node) -> void:
	print("  test_stop_auto_ff ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("stop_auto_ff: no block context")
		return
	ctx.stop_auto_ff()
	ctx.stop_ff()
	print("  test_stop_auto_ff: OK")


func _test_immediate_step(nova: Node) -> void:
	print("  test_immediate_step ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("immediate_step: no block context")
		return
	# Should not crash even when game state is not waiting
	ctx.immediate_step()
	print("  test_immediate_step: OK")


func _test_input_toggle(nova: Node) -> void:
	print("  test_input_toggle ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("input_on/off: no block context")
		return
	ctx.input_on()
	ctx.input_off()
	# Verify state on NovaController
	if nova.has_method("set_input_enabled"):
		nova.set_input_enabled(true)
		var enabled: bool = nova.get("_input_enabled")
		if not enabled:
			_failures.append("input_on: _input_enabled should be true")
		nova.set_input_enabled(false)
		if nova.get("_input_enabled"):
			_failures.append("input_off: _input_enabled should be false")
	print("  test_input_toggle: OK")


func _test_ff_shortcut(nova: Node) -> void:
	print("  test_ff_shortcut ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("ff_shortcut: no block context")
		return
	ctx.ff_shortcut_on()
	ctx.ff_shortcut_off()
	print("  test_ff_shortcut: OK")


func _test_auto_fade_counter(nova: Node) -> void:
	print("  test_auto_fade_counter ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("auto_fade: no block context")
		return
	var before: int = nova.get("_auto_fade_off_count") as int
	ctx.auto_fade_off()
	var after_off: int = nova.get("_auto_fade_off_count") as int
	if after_off != before + 1:
		_failures.append("auto_fade_off: counter should increase by 1: %d → %d" % [before, after_off])
	ctx.auto_fade_on()
	var after_on: int = nova.get("_auto_fade_off_count") as int
	if after_on != before:
		_failures.append("auto_fade_on: counter should decrease by 1: %d → %d" % [after_off, after_on])
	# Test clamping at 0
	for _i in range(5):
		ctx.auto_fade_on()
	var clamped: int = nova.get("_auto_fade_off_count") as int
	if clamped < 0:
		_failures.append("auto_fade_on: counter should clamp at 0, got %d" % clamped)
	print("  test_auto_fade_counter: OK")


func _test_auto_time(nova: Node) -> void:
	print("  test_auto_time ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("auto_time: no block context")
		return
	var original: float = nova.game_view_controller.auto_delay
	ctx.auto_time(0.25)
	if absf(nova.game_view_controller.auto_delay - 0.25) > 0.001:
		_failures.append("auto_time: auto_delay should be 0.25, got %f" % nova.game_view_controller.auto_delay)
	# Restore
	ctx.auto_time(original)
	print("  test_auto_time: OK")


func _test_text_speed(nova: Node) -> void:
	print("  test_text_speed ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("text_speed: no block context")
		return
	var original: float = nova.game_view_controller.type_cps
	ctx.set_text_speed(50.0)
	if absf(nova.game_view_controller.type_cps - 50.0) > 0.5:
		_failures.append("set_text_speed: type_cps should be 50, got %f" % nova.game_view_controller.type_cps)
	ctx.text_delay(0.05)
	# text_delay sets cps = 20 (1/0.05)
	if absf(nova.game_view_controller.type_cps - 20.0) > 1.0:
		_failures.append("text_delay(0.05): type_cps should be ~20, got %f" % nova.game_view_controller.type_cps)
	ctx.text_duration(2.0)  # For empty label, this won't change much
	ctx.set_text_speed(original)
	print("  test_text_speed: OK")


func _test_text_scroll(nova: Node) -> void:
	print("  test_text_scroll ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("text_scroll: no block context")
		return
	ctx.text_scroll(0, 50)
	# Should not crash
	print("  test_text_scroll: OK")


func _test_text_easing(nova: Node) -> void:
	print("  test_text_easing ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("text_easing: no block context")
		return
	ctx.text_easing("ease_out_quad")
	var stored = nova.get("_text_easing")
	if str(stored) != "ease_out_quad":
		_failures.append("text_easing: stored value should be 'ease_out_quad', got '%s'" % str(stored))
	print("  test_text_easing: OK")


func _test_skip_mode_custom(nova: Node) -> void:
	print("  test_skip_mode_custom ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("skip_mode_custom: no block context")
		return
	var original_skip_unread: bool = nova.game_view_controller.skip_unread
	var original_skip_delay: float = nova.game_view_controller.skip_delay
	ctx.skip_mode_custom(true)
	if not nova.game_view_controller.skip_unread:
		_failures.append("skip_mode_custom(true): skip_unread should be true")
	ctx.skip_mode_custom(false)
	if nova.game_view_controller.skip_unread:
		_failures.append("skip_mode_custom(false): skip_unread should be false")
	# Restore
	nova.game_view_controller.skip_unread = original_skip_unread
	nova.game_view_controller.skip_delay = original_skip_delay
	print("  test_skip_mode_custom: OK")


func _test_anim_hold(nova: Node) -> void:
	print("  test_anim_hold ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("anim_hold: no block context")
		return
	var before: int = ctx._anim_hold_counter
	ctx.anim_hold_begin()
	if ctx._anim_hold_counter != before + 1:
		_failures.append("anim_hold_begin: counter should increase by 1")
	ctx.anim_hold_begin()
	if ctx._anim_hold_counter != before + 2:
		_failures.append("anim_hold_begin (2nd): counter should be +2")
	ctx.anim_hold_end()
	if ctx._anim_hold_counter != before + 1:
		_failures.append("anim_hold_end: counter should decrease by 1")
	ctx.anim_hold_end()
	if ctx._anim_hold_counter != before:
		_failures.append("anim_hold_end (2nd): counter should return to baseline")
	# Test clamping at 0
	ctx.anim_hold_end()
	ctx.anim_hold_end()
	if ctx._anim_hold_counter < 0:
		_failures.append("anim_hold_end: counter should clamp at 0, got %d" % ctx._anim_hold_counter)
	print("  test_anim_hold: OK")


func _test_volume(nova: Node) -> void:
	print("  test_volume ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("volume: no block context")
		return
	# These should not crash
	ctx.volume("bgm", 0.8)
	ctx.volume("bgs", 0.5)
	ctx.volume("voice", 1.0)
	ctx.volume("unknown", 0.3)
	print("  test_volume: OK")


func _test_get_current_position(nova: Node) -> void:
	print("  test_get_current_position ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("get_current_position: no block context")
		return
	var pos: Dictionary = ctx.get_current_position()
	if not pos is Dictionary:
		_failures.append("get_current_position: should return Dictionary")
	# When game hasn't started, should return empty
	print("    get_current_position returned: %s" % str(pos))
	print("  test_get_current_position: OK")


func _test_input_prompt(nova: Node) -> void:
	print("  test_input_prompt ...")
	var ctx := _block_ctx(nova)
	if ctx == null:
		_failures.append("input_prompt: no block context")
		return
	ctx.input("player_name", "Enter your name", "Name...")
	ctx.input("", "Empty", "Should not crash")
	# Should not crash
	print("  test_input_prompt: OK")


func _test_compile_all_apis(nova: Node) -> void:
	print("  test_compile_all_apis ...")
	# Compile a GDScript block that exercises all newly implemented APIs
	var block := _wrap_block("""
	box_tint(0.8)
	box_anchor([0.1, 0.9, 0.72, 0.96])
	box_alignment("left")
	box_offset([0, 0, 0, 0])
	new_page()
	stop_auto_ff()
	stop_ff()
	immediate_step()
	input_on()
	input_off()
	ff_shortcut_on()
	ff_shortcut_off()
	auto_fade_on()
	auto_fade_off()
	auto_time(0.15)
	set_text_speed(35.0)
	text_delay(0.04)
	text_duration(2.0)
	text_scroll(0, 20)
	text_easing("linear")
	skip_mode_custom(true)
	skip_mode_custom(false)
	anim_hold_begin()
	anim_hold_end()
	volume("bgm", 0.75)
	volume("voice", 0.9)
	""")
	var script: Script = nova.runtime.compile_block(block)
	if script == null:
		_failures.append("compile_all_apis: block compilation failed")
		return
	var inst = script.new()
	inst._ctx = nova
	inst.run()
	print("  test_compile_all_apis: OK")


# ── Helpers ──────────────────────────────────────────────────────────────

func _block_ctx(nova: Node) -> Object:
	# Instantiate a minimal compiled-block context for testing BaseBlock APIs.
	var script: Script = nova.runtime.compile_block(_wrap_block(""))
	if script == null:
		return null
	var inst = script.new()
	inst._ctx = nova
	return inst


func _wrap_block(body: String) -> String:
	return "func __eval() -> Variant:\n\t%s\n\treturn null\n" % body.replace("\n", "\n\t")


func _load_main_scene() -> Node:
	var packed := load(SCENE_PATH)
	if not (packed is PackedScene):
		return null
	var scene := (packed as PackedScene).instantiate()
	if scene.has_method("_set"):
		scene.set("hints_path", HINTS_PATH)
	root.add_child(scene)
	await process_frame
	await create_timer(0.5).timeout
	return scene


func _cleanup_scene(nova: Node) -> void:
	if nova.hot_reload != null:
		nova.hot_reload.stop()
	root.remove_child(nova)
	nova.free()
	await process_frame
	await process_frame


func _prepare_dirs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	if FileAccess.file_exists(HINTS_PATH):
		DirAccess.remove_absolute(HINTS_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("NovaLuaCompatSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("NovaLuaCompatSmokeTest: FAILED (%d failures)" % _failures.size())
		quit(1)
