class_name GDRuntime extends RefCounted

## Compiles NovaScript command blocks into real GDScript classes at runtime.
##
## Instead of string-parsing the scenario commands (the old approach), every
## block is wrapped into a `extends BaseBlock` class with the user's code placed
## verbatim inside `__eval()`. Godot compiles it, we instantiate it, inject the
## NovaController as `_ctx`, and call `run()`. Backslash line continuations,
## method chains (`o.anim.X().Y()`), `Vector3(...)`, `Color(...)`, dictionaries
## etc. are all handled natively by the GDScript compiler.

const BASE_BLOCK_PATH := "res://scripts/runtime/base_block.gd"
const EngineLogScript := preload("res://scripts/core/engine_log.gd")
const ASYNC_TIMEOUT := 30.0

var _ctx: Node
var _cache: Dictionary = {}  # source string -> GDScript
var _running_async := false
var had_error := false
var last_error: String = ""


func _init(ctx: Node) -> void:
	_ctx = ctx


## Clear the compile cache. Used by hot reload to force recompilation
## of scenario blocks whose source has changed.
func clear_cache() -> void:
	_cache.clear()


func clear_errors() -> void:
	had_error = false
	last_error = ""


## Compile a block of statements into an instantiable GDScript. Returns null on
## a compile error (already pushed to the error log).
func compile_block(source: String) -> GDScript:
	var key := source
	if _cache.has(key):
		return _cache[key]

	var wrapped := _wrap_statements(source)
	var script := GDScript.new()
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		had_error = true
		last_error = "GDRuntime: failed to compile block (err %d):\n%s" % [err, wrapped]
		EngineLogScript.error(EngineLogScript.Category.RUNTIME, "GDRuntime", last_error)
		return null

	_cache[key] = script
	return script


## Compile and immediately run a block, returning its result.
func run_block(source: String) -> Variant:
	var script := compile_block(source)
	if script == null:
		return null
	var inst = script.new()
	inst._ctx = _ctx
	return inst.run()


## Compile and run a block, returning a coroutine/awaitable when present.
## Has a safety timeout (ASYNC_TIMEOUT seconds) to prevent the story from
## hanging forever on dead loops or never-completing Tweens.
func run_block_async(source: String):
	# Safety valve: if a previous async is stuck, force-clear the guard
	# so the story can continue rather than deadlocking.
	if _running_async:
		EngineLogScript.warn(EngineLogScript.Category.RUNTIME, "GDRuntime", "previous async still running, forcing continue")
	_running_async = true

	var script := compile_block(source)
	if script == null:
		_running_async = false
		return null
	var inst = script.new()
	inst._ctx = _ctx
	var result = inst.run()

	if _is_awaitable(result):
		var state := {"completed": false, "timed_out": false}
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = ASYNC_TIMEOUT
		_ctx.add_child(timer)
		timer.timeout.connect(func() -> void:
			if not state["completed"]:
				state["timed_out"] = true
				had_error = true
				last_error = "GDRuntime: async block timed out after %ds:\n%s" % [ASYNC_TIMEOUT, source]
				EngineLogScript.error(EngineLogScript.Category.RUNTIME, "GDRuntime", last_error)
		)
		timer.start()
		await _await_possible_async_result(result)
		if not state["timed_out"]:
			state["completed"] = true
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		_running_async = false
	else:
		_running_async = false
		return result

	return result


## Check whether a value needs awaiting.
func _is_awaitable(value: Variant) -> bool:
	if value == null:
		return false
	if value is Signal:
		return true
	if value is Tween:
		return true
	if value is Object:
		var cls = value.get_class()
		if cls == "GDScriptFunctionState":
			return true
		if cls == "AnimationChain" and value.has_method("await_finished"):
			return true
	if value is Timeline:
		return true
	return false


func _await_possible_async_result(value: Variant):
	if value == null:
		return null

	if value is Signal:
		await value
		return null

	if value is Tween:
		await value.finished
		return null

	if value is Object and value.get_class() == "GDScriptFunctionState":
		await value
		return null

	if value is Object and value.get_class() == "AnimationChain" and value.has_method("await_finished"):
		await value.await_finished()
		return null

	if value is Timeline:
		await value.await_finished()
		return null

	return value


func _wrap_statements(source: String) -> String:
	# Indent every line by one tab so it nests under __eval().
	var body := source.strip_edges()
	if body.is_empty():
		body = "pass"
	var indented := ""
	for line in body.split("\n"):
		indented += "\t" + line + "\n"
	return "extends BaseBlock\nfunc __eval():\n%s" % indented
