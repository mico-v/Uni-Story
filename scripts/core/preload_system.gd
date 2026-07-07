class_name PreloadSystem extends RefCounted

## Background asset preloading system with per-type LRU caches, priority,
## and reference counting.
##
## Resources are classified into four types, each with its own cache limit:
##   IMAGE   — textures, sprites, backgrounds    (default: 60)
##   AUDIO   — bgm, se, voice                    (default: 20)
##   PREFAB  — .tscn prefabs                     (default: 8)
##   OTHER   — everything else                   (default: 40)
##
## Priority levels bias load order and eviction:
##   HIGH (1)  — loaded first, evicted last
##   NORMAL(0) — default
##   LOW  (-1) — loaded last, evicted first
##
## Reference counting ensures that paired preload/cancel calls work:
##   preload_asset("a.png")           → ref_count=1
##   preload_asset("a.png")           → ref_count=2
##   cancel_preload("a.png")          → ref_count=1 (still cached)
##   cancel_preload("a.png")          → ref_count=0 → evicted
##
## Usage from NovaScript:
##   @<|
##       preload_asset("characters/renna/body.png", "image")
##       preload_asset("bgm/theme1.ogg", "audio", 1)   # high priority
##       preload_asset("ui/some.tscn", "prefab")
##   |>

const EngineLogScript := preload("res://scripts/core/engine_log.gd")

# ── Enums ─────────────────────────────────────────────────────────────

enum AssetType {
	IMAGE = 0,
	AUDIO = 1,
	PREFAB = 2,
	OTHER = 3,
}

enum Priority {
	LOW = -1,
	NORMAL = 0,
	HIGH = 1,
}

const ASSET_TYPE_NAMES: Array[String] = ["image", "audio", "prefab", "other"]
const DEFAULT_CACHE_SIZES: Dictionary = {
	AssetType.IMAGE: 60,
	AssetType.AUDIO: 20,
	AssetType.PREFAB: 8,
	AssetType.OTHER: 40,
}

# ── Entry metadata ────────────────────────────────────────────────────

class CachedEntry extends RefCounted:
	var resource: Resource
	var ref_count: int = 0
	var priority: int = Priority.NORMAL


# ── Per-type cache bucket ─────────────────────────────────────────────

class CacheBucket extends RefCounted:
	var _cache: Dictionary = {}           # String path → CachedEntry
	var _lru_order: Array[String] = []    # LRU order (most recent at end)
	var _pending: Array[String] = []      # paths currently loading
	var _pending_priorities: Dictionary = {}  # pending path → priority
	var max_size: int = 40

	func touch(path: String) -> void:
		var idx: int = _lru_order.find(path)
		if idx >= 0:
			_lru_order.remove_at(idx)
		_lru_order.append(path)

	func evict_if_needed() -> void:
		while _lru_order.size() > max_size:
			# Evict: LOW first, then NORMAL, then HIGH; within same, oldest first.
			var evict_idx: int = -1
			for i in _lru_order.size():
				var e: CachedEntry = _cache.get(_lru_order[i], null)
				var p: int = e.priority if e else Priority.NORMAL
				if evict_idx < 0 or p < _cache.get(_lru_order[evict_idx], CachedEntry.new()).priority:
					evict_idx = i
				elif p == _cache.get(_lru_order[evict_idx], CachedEntry.new()).priority:
					pass  # iterate forward — earlier entries are older
			if evict_idx < 0:
				evict_idx = 0
			var oldest: String = _lru_order[evict_idx]
			_lru_order.remove_at(evict_idx)
			_cache.erase(oldest)

	func clear() -> void:
		_cache.clear()
		_lru_order.clear()
		_pending.clear()
		_pending_priorities.clear()

	func cache_size() -> int:
		return _cache.size()

	func pending_count() -> int:
		return _pending.size()


# ── State ─────────────────────────────────────────────────────────────

var _ctx: Node
var _buckets: Dictionary = {}       # AssetType → CacheBucket
var _polling := false

# Backward-compatible total cache size (sum of per-type maxes).
var max_cache_size: int = 128


func _init(ctx: Node) -> void:
	_ctx = ctx
	# Initialize buckets with default sizes.
	for type in DEFAULT_CACHE_SIZES:
		var bucket := CacheBucket.new()
		bucket.max_size = DEFAULT_CACHE_SIZES[type]
		_buckets[type] = bucket
	_recalc_total()


# ── Configuration ─────────────────────────────────────────────────────

## Configure using a single legacy cache limit (backward compat).
## Distributes proportionally across types.
func configure(cache_limit: int) -> void:
	cache_limit = maxi(4, cache_limit)
	# Proportional distribution matching defaults.
	var total_default: float = 128.0
	var factor: float = float(cache_limit) / total_default
	for type in DEFAULT_CACHE_SIZES:
		var bucket: CacheBucket = _buckets.get(type, CacheBucket.new())
		bucket.max_size = maxi(1, int(float(DEFAULT_CACHE_SIZES[type]) * factor))
		_buckets[type] = bucket
	_recalc_total()

## Configure per-type cache sizes.
func configure_types(image_size: int, audio_size: int, prefab_size: int, other_size: int) -> void:
	_buckets[AssetType.IMAGE].max_size = maxi(1, image_size)
	_buckets[AssetType.AUDIO].max_size = maxi(1, audio_size)
	_buckets[AssetType.PREFAB].max_size = maxi(1, prefab_size)
	_buckets[AssetType.OTHER].max_size = maxi(1, other_size)
	# Evict any excess after resize.
	for type in _buckets:
		(_buckets[type] as CacheBucket).evict_if_needed()
	_recalc_total()


# ── Public API ────────────────────────────────────────────────────────

## Request an asset to be preloaded in the background.
## @param path   Relative to resource_root or absolute res:// path
## @param type   String type hint: "image", "audio", "prefab", or "" for auto
## @param pri    Priority: Priority.HIGH (1), NORMAL (0), LOW (-1)
func preload_asset(path: String, type: String = "", pri: int = Priority.NORMAL) -> void:
	var full_path := _resolve_path(path)
	var at: int = _resolve_type(full_path, type)
	var bucket: CacheBucket = _buckets[at] as CacheBucket

	# Already cached → bump ref_count and touch.
	if bucket._cache.has(full_path):
		var entry: CachedEntry = bucket._cache[full_path] as CachedEntry
		entry.ref_count += 1
		bucket.touch(full_path)
		return

	if not ResourceLoader.exists(full_path):
		EngineLogScript.warn(EngineLogScript.Category.ASSET, "PreloadSystem", "asset not found '%s'" % full_path)
		return

	# Already pending → bump ref_count in cached entry placeholder.
	if bucket._pending.has(full_path):
		# Create a stub entry to track ref_count for pending loads.
		if not bucket._cache.has(full_path):
			var stub := CachedEntry.new()
			stub.ref_count = 1
			bucket._cache[full_path] = stub
		else:
			(bucket._cache[full_path] as CachedEntry).ref_count += 1
		# Update priority if higher.
		var old_pri: int = int(bucket._pending_priorities.get(full_path, Priority.NORMAL))
		if pri > old_pri:
			bucket._pending_priorities[full_path] = pri
		return

	# Start threaded load.
	var type_hint := ""  # Godot auto-detects from extension if empty.
	ResourceLoader.load_threaded_request(full_path, type_hint, true)
	bucket._pending.append(full_path)
	bucket._pending_priorities[full_path] = pri
	# Track ref count in a stub entry before load completes.
	var stub := CachedEntry.new()
	stub.ref_count = 1
	stub.priority = pri
	bucket._cache[full_path] = stub
	_start_polling()


## Check if a preloaded asset is ready.
func is_ready(path: String) -> bool:
	var full_path := _resolve_path(path)
	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		var entry: CachedEntry = bucket._cache.get(full_path, null) as CachedEntry
		if entry != null and entry.resource != null:
			bucket.touch(full_path)
			return true
	return _check_loaded_into_cache(full_path)


## Get a preloaded resource. Returns null if not loaded yet.
func get_cached(path: String):
	var full_path := _resolve_path(path)
	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		var entry: CachedEntry = bucket._cache.get(full_path, null) as CachedEntry
		if entry != null:
			if entry.resource != null:
				bucket.touch(full_path)
				return entry.resource
			# Stub entry exists — check if load just completed.
			return _collect_if_ready(full_path, bucket, entry)
	# Not cached yet — check if a completed load is ready.
	return _check_loaded_into_cache(full_path)


## Get overall loading progress as a Dictionary with per-type breakdown.
func get_progress() -> Dictionary:
	var total_pending: int = 0
	var total_cached: int = 0
	var by_type: Dictionary = {}

	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		var type_name: String = ASSET_TYPE_NAMES[type]
		var pending_count: int = bucket.pending_count()
		var cached_count: int = _count_loaded_in(bucket)
		var type_progress: float = 1.0
		if pending_count > 0:
			type_progress = float(cached_count) / float(pending_count + cached_count)
		by_type[type_name] = {
			"pending": pending_count,
			"cached": cached_count,
			"progress": type_progress,
		}
		total_pending += pending_count
		total_cached += cached_count

	var overall: float = 1.0
	if total_pending + total_cached > 0:
		overall = float(total_cached) / float(total_pending + total_cached)

	return {
		"overall": overall,
		"pending": total_pending,
		"cached": total_cached,
		"by_type": by_type,
	}


## Get progress as a simple float (backward-compatible).
func get_progress_float() -> float:
	var prog: Dictionary = get_progress()
	return float(prog.get("overall", 1.0))


## Whether all pending preloads are complete.
func is_all_ready() -> bool:
	for type in _buckets:
		if (_buckets[type] as CacheBucket).pending_count() > 0:
			return false
	return true


## Cancel a pending preload (reference-counted).
## Decrements the reference count; evicts only when it reaches zero.
func cancel_preload(path: String) -> void:
	var full_path := _resolve_path(path)
	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		var entry: CachedEntry = bucket._cache.get(full_path, null) as CachedEntry
		if entry != null:
			entry.ref_count -= 1
			if entry.ref_count <= 0:
				bucket._cache.erase(full_path)
				var lru_idx: int = bucket._lru_order.find(full_path)
				if lru_idx >= 0:
					bucket._lru_order.remove_at(lru_idx)
				bucket._pending.erase(full_path)
				bucket._pending_priorities.erase(full_path)
			return
		# Also check pending in case the stub was never created.
		for t2 in _buckets:
			var b2: CacheBucket = _buckets[t2] as CacheBucket
			if b2._pending.has(full_path):
				b2._pending.erase(full_path)
				b2._pending_priorities.erase(full_path)
				return
	if _is_all_pending_empty():
		_polling = false


## Cancel all pending preloads regardless of reference count.
func cancel_all() -> void:
	for type in _buckets:
		(_buckets[type] as CacheBucket).clear()
	_polling = false


## Clear the entire preload cache (e.g., on hot reload).
func clear_cache() -> void:
	for type in _buckets:
		(_buckets[type] as CacheBucket).clear()
	_polling = false


## Total number of loaded entries across all caches.
func cache_size() -> int:
	var total: int = 0
	for type in _buckets:
		total += _count_loaded_in(_buckets[type] as CacheBucket)
	return total


# ── Snapshot / Restore ────────────────────────────────────────────────

func snapshot() -> Dictionary:
	var snap: Dictionary = {}
	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		var type_snap: Array = []
		for path in bucket._cache:
			var entry: CachedEntry = bucket._cache[path] as CachedEntry
			if entry != null:
				type_snap.append({
					"path": path,
					"ref_count": entry.ref_count,
					"priority": entry.priority,
				})
		snap[ASSET_TYPE_NAMES[type]] = type_snap
	return snap


func restore(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	# Re-issue preloads for each cached entry.
	for type_name: String in data:
		var at: int = ASSET_TYPE_NAMES.find(type_name)
		if at < 0:
			continue
		var entries: Array = data[type_name] if data[type_name] is Array else []
		for entry_data in entries:
			if not (entry_data is Dictionary):
				continue
			var ed: Dictionary = entry_data as Dictionary
			var path: String = str(ed.get("path", ""))
			var ref_count: int = int(ed.get("ref_count", 1))
			var pri: int = int(ed.get("priority", Priority.NORMAL))
			# Re-issue preload with same priority for each ref_count.
			for _i in range(ref_count):
				preload_asset(path, type_name, pri)
	return true


# ── Internal ──────────────────────────────────────────────────────────

func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	var root: String = ""
	if _ctx.object_manager:
		var r = _ctx.object_manager.constants.get("resource_root", "")
		root = str(r)
	return root + path


## Resolve type from string hint or auto-detect from extension.
func _resolve_type(path: String, type_hint: String) -> int:
	match type_hint.to_lower():
		"image":
			return AssetType.IMAGE
		"audio":
			return AssetType.AUDIO
		"prefab":
			return AssetType.PREFAB
	# Auto-detect from extension.
	var ext := path.get_extension().to_lower()
	match ext:
		"png", "jpg", "jpeg", "webp", "bmp", "svg", "tga":
			return AssetType.IMAGE
		"ogg", "mp3", "wav", "opus":
			return AssetType.AUDIO
		"tscn", "scn":
			return AssetType.PREFAB
	return AssetType.OTHER


func _count_loaded_in(bucket: CacheBucket) -> int:
	var count: int = 0
	for path in bucket._cache:
		var entry: CachedEntry = bucket._cache[path] as CachedEntry
		if entry != null and entry.resource != null:
			count += 1
	return count


func _collect_if_ready(full_path: String, bucket: CacheBucket, entry: CachedEntry) -> Resource:
	var status := ResourceLoader.load_threaded_get_status(full_path)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var res := ResourceLoader.load_threaded_get(full_path)
		if res != null:
			entry.resource = res
			bucket.touch(full_path)
			bucket.evict_if_needed()
		else:
			entry.ref_count -= 1
			if entry.ref_count <= 0:
				bucket._cache.erase(full_path)
		return res
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		entry.ref_count -= 1
		if entry.ref_count <= 0:
			bucket._cache.erase(full_path)
		bucket._pending.erase(full_path)
		bucket._pending_priorities.erase(full_path)
	return null


func _check_loaded_into_cache(full_path: String):
	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		var status := ResourceLoader.load_threaded_get_status(full_path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var res := ResourceLoader.load_threaded_get(full_path)
			if res != null:
				var entry: CachedEntry = bucket._cache.get(full_path, null) as CachedEntry
				if entry != null:
					entry.resource = res
				else:
					entry = CachedEntry.new()
					entry.resource = res
					entry.ref_count = 1
					bucket._cache[full_path] = entry
				bucket.touch(full_path)
				bucket._pending.erase(full_path)
				bucket._pending_priorities.erase(full_path)
				bucket.evict_if_needed()
				return res
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			bucket._pending.erase(full_path)
			bucket._pending_priorities.erase(full_path)
	return null


func _start_polling() -> void:
	if _polling:
		return
	_polling = true
	_poll()


## Poll using priority ordering: HIGH priority items checked first.
func _poll() -> void:
	if _is_all_pending_empty():
		_polling = false
		return

	# Collect pending items sorted by priority (HIGH first).
	var items: Array = []
	for type in _buckets:
		var bucket: CacheBucket = _buckets[type] as CacheBucket
		for p in bucket._pending:
			var pri: int = int(bucket._pending_priorities.get(p, Priority.NORMAL))
			items.append({"path": p, "type": type, "priority": pri})

	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority > b.priority  # HIGH first
	)

	for item in items:
		var path: String = item.path
		var at: int = item.type
		var bucket: CacheBucket = _buckets[at] as CacheBucket
		if not bucket._pending.has(path):
			continue  # Already handled.

		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var res := ResourceLoader.load_threaded_get(path)
				if res != null:
					var entry: CachedEntry = bucket._cache.get(path, null) as CachedEntry
					if entry != null:
						entry.resource = res
						entry.priority = item.priority
					else:
						entry = CachedEntry.new()
						entry.resource = res
						entry.ref_count = 1
						entry.priority = item.priority
						bucket._cache[path] = entry
					bucket.touch(path)
					bucket.evict_if_needed()
				else:
					# Load result was null — remove stub.
					_remove_stub(bucket, path)
				bucket._pending.erase(path)
				bucket._pending_priorities.erase(path)
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				EngineLogScript.warn(EngineLogScript.Category.ASSET, "PreloadSystem", "failed to load '%s'" % path)
				_remove_stub(bucket, path)
				bucket._pending.erase(path)
				bucket._pending_priorities.erase(path)
			_:  # Still loading — keep in pending.
				pass

	if not _is_all_pending_empty():
		# Continue polling on next frame.
		if _ctx and _ctx.get_tree():
			_ctx.get_tree().process_frame.connect(_poll, CONNECT_ONE_SHOT)
	else:
		_polling = false


func _remove_stub(bucket: CacheBucket, path: String) -> void:
	var entry: CachedEntry = bucket._cache.get(path, null) as CachedEntry
	if entry != null and entry.resource == null:
		entry.ref_count -= 1
		if entry.ref_count <= 0:
			bucket._cache.erase(path)
			var lru_idx: int = bucket._lru_order.find(path)
			if lru_idx >= 0:
				bucket._lru_order.remove_at(lru_idx)


func _is_all_pending_empty() -> bool:
	for type in _buckets:
		if (_buckets[type] as CacheBucket).pending_count() > 0:
			return false
	return true


func _recalc_total() -> void:
	max_cache_size = 0
	for type in _buckets:
		max_cache_size += (_buckets[type] as CacheBucket).max_size
