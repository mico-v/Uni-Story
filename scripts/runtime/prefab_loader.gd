class_name PrefabLoader extends RefCounted

## Runtime prefab loading subsystem.
##
## Loads `.tscn` scenes at scenario-author request, instantiates them into the
## scene tree, and registers them in ObjectManager by name so that existing APIs
## (move, tint, o.anim, vfx, hide, show) work transparently on loaded prefabs.
##
## Design: idempotent loading (same name + same path reuses the instance),
## world-space prefabs parent to o.world, UI prefabs parent to a lazy-created
## Control under Hud.

var _ctx: Node

## name → { "node": Node, "path": String, "ui": bool }
var _prefabs: Dictionary = {}

## full resource path → PackedScene (avoids repeated disk reads)
var _scene_cache: Dictionary = {}


func _init(ctx: Node) -> void:
	_ctx = ctx


# ── Public API ──────────────────────────────────────────────────────────

func load_prefab(name: String, path: String, coord = null, color = null, ui: bool = false) -> Node:
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
	if ui:
		var parent := _ui_parent()
		if parent:
			parent.add_child(instance)
	else:
		var world := _world()
		if world:
			world.add_child(instance)

	# Register in ObjectManager so move/tint/o.anim/vfx can find it by name.
	_ctx.object_manager.bind_object_runtime(name, instance)

	_prefabs[name] = { "node": instance, "path": full_path, "ui": ui }

	# Apply optional initial transform and color.
	if coord != null:
		_ctx.graphics.move(instance, coord)
	if color != null:
		_ctx.graphics.tint(instance, color)

	# If the prefab root has a setup method, call it with the context.
	if instance.has_method("setup_prefab"):
		instance.setup_prefab(_ctx)

	return instance


func show_prefab(name: String) -> void:
	var node := get_prefab(name)
	if node:
		node.visible = true


func hide_prefab(name: String) -> void:
	var node := get_prefab(name)
	if node:
		node.visible = false


func destroy_prefab(name: String) -> void:
	_destroy(name)


func destroy_all() -> void:
	for name in _prefabs.keys():
		_destroy(name)


func has_prefab(name: String) -> bool:
	if not _prefabs.has(name):
		return false
	return is_instance_valid(_prefabs[name]["node"])


func get_prefab(name: String) -> Node:
	if not _prefabs.has(name):
		return null
	var node = _prefabs[name]["node"]
	if is_instance_valid(node):
		return node
	# Stale reference → clean up.
	_prefabs.erase(name)
	return null


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
			"ui": bool(data["ui"]),
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

func _destroy(name: String) -> void:
	if not _prefabs.has(name):
		return
	var data: Dictionary = _prefabs[name]
	var node = data["node"]
	if is_instance_valid(node):
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
	if game_vc == null:
		# Try through the game view controller reference.
		if _ctx.has_method("get_game_vc"):
			var vc = _ctx.get_game_vc()
			if vc and vc.has_method("get_hud"):
				var hud = vc.get_hud()
				if hud is Control:
					return _ensure_prefab_ui(hud)
		return null
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
