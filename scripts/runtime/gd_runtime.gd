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

var _ctx: Node
var _cache: Dictionary = {}  # source hash -> GDScript


func _init(ctx: Node) -> void:
	_ctx = ctx


## Clear the compile cache. Used by hot reload to force recompilation
## of scenario blocks whose source has changed.
func clear_cache() -> void:
	_cache.clear()


## Compile a block of statements into an instantiable GDScript. Returns null on
## a compile error (already pushed to the error log).
func compile_block(source: String) -> GDScript:
	var key := source.hash()
	if _cache.has(key):
		return _cache[key]

	var wrapped := _wrap_statements(source)
	var script := GDScript.new()
	script.source_code = wrapped
	var err := script.reload()
	if err != OK:
		push_error("GDRuntime: failed to compile block (err %d):\n%s" % [err, wrapped])
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
func run_block_async(source: String):
	var script := compile_block(source)
	if script == null:
		return null
	var inst = script.new()
	inst._ctx = _ctx
	var result = inst.run()
	return await _await_possible_async_result(result)


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
