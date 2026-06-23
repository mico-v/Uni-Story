class_name HotReload extends RefCounted

## Scenario hot-reload subsystem.
##
## Polls scenario files for modification and triggers a full reload when changes
## are detected.  Only active in debug builds (OS.is_debug_build()).
##
## The reload process:
##   1. Reset game state (return to title)
##   2. Clear runtime compile cache
##   3. Re-parse all scenario files
##   4. Re-wire graph to GameState
##   5. Refresh chapter list and switch to title view
##
## Also exposes reload() for manual triggering (e.g. keyboard shortcut).

var _ctx: Node

## Scenario file paths to watch (resolved, post-localization).
var _files: Array[String] = []

## Stored modification times for change detection.
var _file_times: Dictionary = {}

## Polling timer (child of _ctx).
var _timer: Timer = null

## Debounce: number of consecutive polls that detected a change.
var _change_count: int = 0

## Whether polling is active.
var _enabled: bool = false


func _init(ctx: Node) -> void:
	_ctx = ctx


# ── Public API ────────────────────────────────────────────────────────

## Start polling.  `files` should be the resolved scenario paths (after
## _localized_scenario_files).  `interval` is the poll period in seconds.
func start(files: Array, interval: float = 2.0) -> void:
	if not OS.is_debug_build():
		return
	_files = files.duplicate()
	_snapshot_times()
	_change_count = 0

	if _timer != null:
		_timer.queue_free()
	_timer = Timer.new()
	_timer.name = "HotReloadTimer"
	_timer.wait_time = interval
	_timer.one_shot = false
	_timer.autostart = true
	_timer.timeout.connect(_poll)
	_ctx.add_child(_timer)
	_enabled = true
	print("[HotReload] watching %d scenario files (every %.1fs)" % [_files.size(), interval])


## Stop polling.
func stop() -> void:
	_enabled = false
	if _timer != null:
		_timer.stop()
		_timer.queue_free()
		_timer = null


## Manually trigger a full scenario reload.  Returns true on success.
func reload() -> bool:
	if _ctx == null:
		return false

	print("[HotReload] reloading scenarios...")

	# 1. End any in-progress game, clean up presentation.
	if _ctx.has_method("_on_game_title_requested"):
		_ctx._on_game_title_requested()

	# 2. Clear runtime compile cache so changed blocks recompile.
	if _ctx.runtime:
		_ctx.runtime.clear_cache()

	# 3. Reset GameState to parse-mode so eager blocks route correctly.
	if _ctx.game_state:
		_ctx.game_state.current_node = null
		_ctx.game_state.is_ended = false
		_ctx.game_state.is_processing = false
		_ctx.game_state.is_waiting_input = false
		_ctx.game_state.is_waiting_branch = false
		_ctx.game_state.pending_jump = &""

	# 4. Clear variables and backlog.
	if _ctx.variables:
		_ctx.variables.clear()
	if _ctx.backlog:
		_ctx.backlog.clear()

	# 5. Destroy all runtime-loaded prefabs.
	if _ctx.prefab_loader:
		_ctx.prefab_loader.destroy_all()

	# 6. Re-resolve localized paths and reload.
	var scenario_files := _files.duplicate()
	if _ctx.has_method("_localized_scenario_files"):
		scenario_files = _ctx._localized_scenario_files(_ctx.SCENARIO_FILES.duplicate())

	_ctx.script_loader.load_all(scenario_files)
	if not _ctx.script_loader.load_ok:
		push_error("[HotReload] script_loader.load_all() failed")
		return false

	# 7. Re-wire graph.
	_ctx.game_state.setup(_ctx.script_loader.graph)

	# 8. Refresh UI.
	if _ctx.view_manager:
		_ctx.view_manager.switch_to("title")

	# 9. Update stored file times.
	_snapshot_times()
	_change_count = 0

	print("[HotReload] reload complete — %d nodes loaded" % _ctx.script_loader.graph.nodes.size())
	return true


# ── Internal ──────────────────────────────────────────────────────────

func _poll() -> void:
	if not _enabled:
		return
	if _has_changes():
		_change_count += 1
		if _change_count >= 2:
			reload()
	else:
		_change_count = 0


func _has_changes() -> bool:
	for path in _files:
		var p := str(path)
		if not FileAccess.file_exists(p):
			continue
		var mtime := FileAccess.get_modified_time(p)
		if not _file_times.has(p):
			return true
		if mtime != _file_times[p]:
			return true
	return false


func _snapshot_times() -> void:
	_file_times.clear()
	for path in _files:
		var p := str(path)
		if FileAccess.file_exists(p):
			_file_times[p] = FileAccess.get_modified_time(p)
