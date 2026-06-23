class_name PreloadSystem extends RefCounted

## Background asset preloading system.
## Uses Godot's threaded resource loading to pre-load textures, audio, etc.
## before they're needed, avoiding hitches during gameplay.
##
## Usage from NovaScript:
##   @<|
##       preload_asset("characters/renna/body.png")
##       preload_asset("backgrounds/sunset.png")
##       preload_asset("bgm/theme1.ogg")
##   |>
##
## Preloaded resources are cached and returned by the regular load() path.

var _ctx: Node
var _cache: Dictionary = {}        # path -> Resource
var _pending: Array = []           # paths currently loading
var _polling := false
var _lru_order: Array[String] = []   # LRU order tracking
const MAX_CACHE_SIZE := 128


func _init(ctx: Node) -> void:
	_ctx = ctx


## Request an asset to be preloaded in the background.
## `path` is relative to resource_root or an absolute res:// path.
func preload_asset(path: String) -> void:
	var full_path := _resolve_path(path)
	if _cache.has(full_path):
		return  # already cached
	if not ResourceLoader.exists(full_path):
		push_warning("PreloadSystem: asset not found '%s'" % full_path)
		return
	# Start threaded load.
	ResourceLoader.load_threaded_request(full_path, "", true)
	if not _pending.has(full_path):
		_pending.append(full_path)
	_start_polling()


## Check if a preloaded asset is ready.
func is_ready(path: String) -> bool:
	var full_path := _resolve_path(path)
	if _cache.has(full_path):
		_touch(full_path)
		return true
	var status := ResourceLoader.load_threaded_get_status(full_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res = ResourceLoader.load_threaded_get(full_path)
		if res != null:
			_cache[full_path] = res
			_touch(full_path)
			_evict_if_needed()
		return true
	return false


## Get a preloaded resource. Returns null if not loaded yet.
func get_cached(path: String):
	var full_path := _resolve_path(path)
	if _cache.has(full_path):
		_touch(full_path)
		return _cache[full_path]
	var status := ResourceLoader.load_threaded_get_status(full_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res = ResourceLoader.load_threaded_get(full_path)
		if res != null:
			_cache[full_path] = res
			_touch(full_path)
			_evict_if_needed()
			return res
	return null


## Get the loading progress (0.0 to 1.0).
func get_progress() -> float:
	if _pending.is_empty():
		return 1.0
	var loaded := 0
	for p in _pending:
		var status := ResourceLoader.load_threaded_get_status(p)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			loaded += 1
	return float(loaded) / float(_pending.size())


## Whether all pending preloads are complete.
func is_all_ready() -> bool:
	return _pending.is_empty()


## Cancel a pending preload. Removes it from the pending list and cache.
## Note: the underlying ResourceLoader thread cannot be cancelled in Godot 4,
## so the load may still complete in the background — but the result is discarded.
func cancel_preload(path: String) -> void:
	var full_path := _resolve_path(path)
	_pending.erase(full_path)
	_cache.erase(full_path)
	var idx := _lru_order.find(full_path)
	if idx >= 0:
		_lru_order.remove_at(idx)
	if _pending.is_empty():
		_polling = false


## Cancel all pending preloads.
func cancel_all() -> void:
	_pending.clear()
	_polling = false


## Clear the preload cache (e.g., on hot reload).
func clear_cache() -> void:
	_cache.clear()
	_pending.clear()
	_lru_order.clear()
	_polling = false


## Number of cached resources.
func cache_size() -> int:
	return _cache.size()


# ── Internal ──────────────────────────────────────────────────────────

func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	var root: String = ""
	if _ctx.object_manager:
		var r = _ctx.object_manager.constants.get("resource_root", "")
		root = str(r)
	return root + path


func _start_polling() -> void:
	if _polling:
		return
	_polling = true
	_poll()


func _poll() -> void:
	if _pending.is_empty():
		_polling = false
		return
	var still_pending: Array = []
	for p in _pending:
		var status := ResourceLoader.load_threaded_get_status(p)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var res = ResourceLoader.load_threaded_get(p)
				if res != null:
					_cache[p] = res
					_touch(p)
					_evict_if_needed()
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_warning("PreloadSystem: failed to load '%s'" % p)
			_:
				still_pending.append(p)
	_pending = still_pending
	if not _pending.is_empty():
		# Continue polling on next frame.
		_ctx.get_tree().process_frame.connect(_poll, CONNECT_ONE_SHOT)
	else:
		_polling = false


func _touch(path: String) -> void:
	var idx := _lru_order.find(path)
	if idx >= 0:
		_lru_order.remove_at(idx)
	_lru_order.append(path)


func _evict_if_needed() -> void:
	while _lru_order.size() > MAX_CACHE_SIZE:
		var oldest := _lru_order[0]
		_lru_order.remove_at(0)
		_cache.erase(oldest)
