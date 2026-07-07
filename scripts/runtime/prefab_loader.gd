class_name PrefabLoader extends RefCounted

## Runtime prefab loading subsystem with category-based lifecycle.
##
## Loads `.tscn` scenes at scenario-author request, instantiates them into the
## scene tree, and registers them in ObjectManager by name so that existing APIs
## (move, tint, o.anim, vfx, hide, show) work transparently on loaded prefabs.
##
## Categories control lifecycle scope:
##   WORLD      — game-world objects; destroyed on reset_world / chapter jump
##   UI         — HUD-layer elements; destroyed on cleanup_display / exit GameView
##   PERSISTENT — survives node transitions; only destroyed explicitly or with force
##
## Design: idempotent loading (same name + same path reuses the instance).

enum PrefabCategory {
	WORLD = 0,       # game-world objects
	UI = 1,          # HUD-layer elements
	PERSISTENT = 2,  # survives node transitions
}

var _ctx: Node

## name → { "node": Node, "path": String, "category": int }
var _prefabs: Dictionary = {}

## full resource path → PackedScene (avoids repeated disk reads)
var _scene_cache: Dictionary = {}


func _init(ctx: Node) -> void:
	_ctx = ctx


# ── Public API ──────────────────────────────────────────────────────────

## Load and instantiate a prefab.
## @param category  PrefabCategory enum value. Accepts `true`/`false` for backward compat:
##                   true → UI, false → WORLD.
func load_prefab(name: String, path: String, coord = null, color = null, category = PrefabCategory.WORLD) -> Node:
	# Backward compat: accept bool for category.
	var cat: int = _normalize_category(category)
	var full_path := _resolve_path(path)

	# Idempotent: same name + same path → reuse.
	if _prefabs.has(name):
		var existing: Dictionary = _prefabs[name]
		var node = existing["node"]
		if is_instance_valid(node) and str(existing["path"]) == full_path:
			node.visible = true
			if coord != null:
				_ctx.graphics.move(node, coord)
			if color != null:
				_ctx.graphics.tint(node, color)
			return node
		# Different path or stale node → destroy old first.
		_destroy(name)

	# Load and instantiate.
	var packed := _load_scene(full_path)
	if packed == null:
		push_warning("PrefabLoader: failed to load '%s' from '%s'" % [name, full_path])
		return null

	var instance: Node = packed.instantiate()
	if instance == null:
		push_warning("PrefabLoader: instantiate returned null for '%s'" % name)
		return null
	instance.name = "Prefab_" + name

	# Parent to world or UI container.
	if cat == PrefabCategory.UI:
		var parent := _ui_parent()
		if parent:
			parent.add_child(instance)
	else:
		var world := _world()
		if world:
			world.add_child(instance)

	# Register in ObjectManager so move/tint/o.anim/vfx can find it by name.
	_ctx.object_manager.bind_object_runtime(name, instance)

	_prefabs[name] = { "node": instance, "path": full_path, "category": cat }

	# Apply optional initial transform and color.
	if coord != null:
		_ctx.graphics.move(instance, coord)
	if color != null:
		_ctx.graphics.tint(instance, color)

	# If the prefab root has a setup method, call it with the context.
	if instance.has_method("setup_prefab"):
		instance.setup_prefab(_ctx)

	return instance


## Show a prefab by name.
func show_prefab(name: String) -> void:
	var node := get_prefab(name)
	if node:
		node.visible = true


## Hide a prefab by name.
func hide_prefab(name: String) -> void:
	var node := get_prefab(name)
	if node:
		node.visible = false


## Destroy a single prefab regardless of category.
func destroy_prefab(name: String) -> void:
	_destroy(name)


## Destroy all prefabs. By default, PERSISTENT prefabs are preserved.
## Pass force=true to destroy everything (e.g., hot reload, shutdown).
func destroy_all(force: bool = false) -> void:
	var to_destroy: Array[String] = []
	for name in _prefabs.keys():
		var data: Dictionary = _prefabs[name]
		var cat: int = int(data.get("category", PrefabCategory.WORLD))
		if cat == PrefabCategory.PERSISTENT and not force:
			continue
		to_destroy.append(name)
	for name in to_destroy:
		_destroy(name)


## Destroy all prefabs in a specific category.
func destroy_by_category(category: int) -> void:
	var cat: int = _normalize_category(category)
	var to_destroy: Array[String] = []
	for name in _prefabs.keys():
		var data: Dictionary = _prefabs[name]
		if int(data.get("category", PrefabCategory.WORLD)) == cat:
			to_destroy.append(name)
	for name in to_destroy:
		_destroy(name)


## Check if a prefab is loaded.
func has_prefab(name: String) -> bool:
	if not _prefabs.has(name):
		return false
	return is_instance_valid(_prefabs[name]["node"])


## Get a loaded prefab node by name.
func get_prefab(name: String) -> Node:
	if not _prefabs.has(name):
		return null
	var node = _prefabs[name]["node"]
	if is_instance_valid(node):
		return node
	# Stale reference → clean up.
	_prefabs.erase(name)
	return null


## Get all prefab names in a given category.
func get_prefabs_by_category(category: int) -> Array[String]:
	var cat: int = _normalize_category(category)
	var result: Array[String] = []
	for name in _prefabs.keys():
		var data: Dictionary = _prefabs[name]
		if int(data.get("category", PrefabCategory.WORLD)) == cat:
			result.append(name)
	return result


## Get the category of a loaded prefab.
func get_prefab_category(name: String) -> int:
	if not _prefabs.has(name):
		return -1
	return int(_prefabs[name].get("category", PrefabCategory.WORLD))


# ── Save/Load ───────────────────────────────────────────────────────────

func snapshot() -> Dictionary:
	var loaded := {}
	for name in _prefabs.keys():
		var data: Dictionary = _prefabs[name]
		var node = data["node"]
		if not is_instance_valid(node):
			continue
		var entry := {
			"path": str(data["path"]),
			"category": int(data.get("category", PrefabCategory.WORLD)),
			"visible": node.visible if node is CanvasItem else true,
		}
		if node is CanvasItem:
			var ci: CanvasItem = node
			entry["position_x"] = ci.position.x
			entry["position_y"] = ci.position.y
			entry["scale_x"] = ci.scale.x
			entry["scale_y"] = ci.scale.y
			entry["rotation"] = ci.rotation_degrees
			entry["modulate_r"] = ci.modulate.r
			entry["modulate_g"] = ci.modulate.g
			entry["modulate_b"] = ci.modulate.b
			entry["modulate_a"] = ci.modulate.a
		loaded[name] = entry
	return { "loaded": loaded }


func restore(state: Dictionary) -> void:
	var saved: Dictionary = state.get("loaded", {})
	# Apply saved transform/visibility to prefabs that replay re-created.
	for name in saved.keys():
		var node := get_prefab(name)
		if node == null or not (node is CanvasItem):
			continue
		var entry: Dictionary = saved[name]
		var ci: CanvasItem = node
		ci.visible = bool(entry.get("visible", true))
		ci.position = Vector2(
			float(entry.get("position_x", 0.0)),
			float(entry.get("position_y", 0.0)),
		)
		ci.scale = Vector2(
			float(entry.get("scale_x", 1.0)),
			float(entry.get("scale_y", 1.0)),
		)
		ci.rotation_degrees = float(entry.get("rotation", 0.0))
		ci.modulate = Color(
			float(entry.get("modulate_r", 1.0)),
			float(entry.get("modulate_g", 1.0)),
			float(entry.get("modulate_b", 1.0)),
			float(entry.get("modulate_a", 1.0)),
		)


# ── Internal ────────────────────────────────────────────────────────────

func _normalize_category(value) -> int:
	# Backward compat: bool → category
	if value is bool:
		return PrefabCategory.UI if value else PrefabCategory.WORLD
	if value is int:
		if value == PrefabCategory.UI or value == PrefabCategory.WORLD or value == PrefabCategory.PERSISTENT:
			return value
	return PrefabCategory.WORLD


func _destroy(name: String) -> void:
	if not _prefabs.has(name):
		return
	var data: Dictionary = _prefabs[name]
	var node = data["node"]
	if is_instance_valid(node):
		# Call teardown hook if available.
		if node.has_method("teardown_prefab"):
			node.teardown_prefab(_ctx)
		node.queue_free()
	_prefabs.erase(name)
	# Remove from ObjectManager so stale names don't linger.
	_ctx.object_manager.unbind_object_runtime(name)


func _load_scene(full_path: String) -> PackedScene:
	if _scene_cache.has(full_path):
		return _scene_cache[full_path]
	if ResourceLoader.exists(full_path):
		var res = load(full_path)
		if res is PackedScene:
			_scene_cache[full_path] = res
			return res
		push_warning("PrefabLoader: '%s' is not a PackedScene" % full_path)
		return null
	push_warning("PrefabLoader: resource not found '%s'" % full_path)
	return null


func _resolve_path(path: String) -> String:
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var full := root + path
	if not full.ends_with(".tscn"):
		full += ".tscn"
	return full


func _world() -> Node2D:
	var w = _ctx.object_manager.objects.get("world")
	if w is Node2D:
		return w
	return null


func _ui_parent() -> Control:
	if _ctx == null:
		return null
	var game_vc = _ctx.get_node_or_null("GameView")
	if game_vc != null and game_vc.has_method("get_hud"):
		var hud = game_vc.get_hud()
		if hud is Control:
			return _ensure_prefab_ui(hud)
	return null


func _ensure_prefab_ui(hud: Control) -> Control:
	var existing = hud.get_node_or_null("PrefabUI")
	if existing is Control:
		return existing
	var container := Control.new()
	container.name = "PrefabUI"
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(container)
	return container
