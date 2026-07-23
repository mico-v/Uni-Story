class_name AutoVoiceSystem extends RefCounted

## Resolves and schedules Nova-style automatic character voice cues.
##
## A dialogue is handled in two phases: prepare_dialogue() consumes the
## one-shot flags and advances the character index before a checkpoint is
## captured; start_prepared_cue() starts playback only after the UI has recorded
## the dialogue in Backlog.

signal pending_changed()
signal cue_started(path: String)

const AutoVoiceProfileScript := preload("res://scripts/runtime/auto_voice_profile.gd")

var _ctx: Node
var _profile
var _states: Dictionary = {}
var _next_delay: float = 0.0
var _override_next: bool = false
var _explicit_cue: Dictionary = {}
var _current_cue: Dictionary = {}
var _generation: int = 0
var _pending: bool = false
var _pending_deadline_msec: int = 0
var _disposed: bool = false


func _init(ctx: Node) -> void:
	_ctx = ctx


func configure(profile: Resource) -> void:
	_profile = profile
	if _profile == null or not _profile.has_method("resolve_character") or not _profile.has_method("voice_path"):
		if _profile != null:
			push_warning("AutoVoiceSystem: invalid profile, using an empty default profile")
		_profile = AutoVoiceProfileScript.new()


func enable(speaker: Variant, start_id: Variant = null) -> bool:
	var canonical: String = _canonical(speaker)
	if canonical.is_empty():
		push_warning("AutoVoiceSystem: unknown speaker '%s'" % str(speaker))
		return false
	var state: Dictionary = _state_for(canonical)
	var index_value: Variant = start_id
	if start_id is Array:
		var tuple: Array = start_id
		if tuple.size() > 0:
			state["prefix"] = str(tuple[0])
		index_value = tuple[1] if tuple.size() > 1 else null
	elif start_id is Dictionary:
		var table: Dictionary = start_id
		if table.has("prefix"):
			state["prefix"] = str(table.get("prefix", ""))
		index_value = table.get("index", null)
	state["enabled"] = true
	if index_value != null and not str(index_value).strip_edges().is_empty():
		state["index"] = int(index_value)
	_states[canonical] = state
	return true


func disable(speaker: Variant) -> void:
	var canonical: String = _canonical(speaker)
	if canonical.is_empty():
		return
	var state: Dictionary = _state_for(canonical)
	state["enabled"] = false
	_states[canonical] = state


func disable_all() -> void:
	for canonical in _states.keys():
		var state: Dictionary = _state_for(str(canonical))
		state["enabled"] = false
		_states[canonical] = state


func set_next_delay(seconds: Variant = 0.0) -> void:
	_next_delay = maxf(float(seconds), 0.0)


func skip_next() -> void:
	_override_next = true


func prepare_manual(speaker: Variant, voice_id: Variant, delay: Variant = 0.0, override_auto_voice: bool = true) -> String:
	var path: String = manual_voice_path(speaker, voice_id)
	if path.is_empty():
		return ""
	cancel_pending(false, true)
	if override_auto_voice:
		skip_next()
	_explicit_cue = _make_cue(path, maxf(float(delay), 0.0), false)
	_explicit_cue["override_auto_voice"] = override_auto_voice
	_note_voice(path)
	return path


## Play an explicit path immediately while still overriding the next automatic
## cue. This preserves the existing play_voice() behaviour for script APIs that
## are not tied to a dialogue line.
func play_explicit_path(path: String, override_auto_voice: bool = true):
	var resolved: String = path.strip_edges()
	if resolved.is_empty():
		return false
	cancel_pending(false, true)
	if override_auto_voice:
		skip_next()
	_explicit_cue = _make_cue(resolved, 0.0, true)
	_explicit_cue["override_auto_voice"] = override_auto_voice
	_note_voice(resolved)
	_current_cue = _explicit_cue.duplicate(true)
	if not bool(_explicit_cue.get("playable", false)):
		return false
	return _play_path(resolved)


func prepare_dialogue(speaker: Variant, audible: bool = true) -> Dictionary:
	# A cue delayed for an older line must never leak into the new dialogue.
	cancel_pending(false, true)

	if not _explicit_cue.is_empty():
		var explicit: Dictionary = _explicit_cue.duplicate(true)
		_explicit_cue.clear()
		var skip_auto := _override_next
		_override_next = false
		var overrides_auto := bool(explicit.get("override_auto_voice", true))
		if not overrides_auto and not skip_auto:
			# A single voice player cannot mix both cues. Keep the explicit cue,
			# but consume the eligible automatic state so numbering/delay remain
			# aligned when callers explicitly opt out of auto suppression.
			_consume_automatic_cue(speaker)
		_current_cue = explicit.duplicate(true) if audible else {}
		return explicit if audible else {}

	if _override_next:
		_override_next = false
		_current_cue.clear()
		return {}

	var cue: Dictionary = _consume_automatic_cue(speaker)
	var path: String = str(cue.get("path", ""))
	_current_cue = cue.duplicate(true)
	if audible and not path.is_empty():
		_note_voice(path)
	return cue if audible else {}


func start_prepared_cue(cue: Dictionary) -> void:
	if _disposed or cue.is_empty():
		return
	var path: String = str(cue.get("path", ""))
	if path.is_empty() or not bool(cue.get("playable", false)):
		return
	_current_cue = cue.duplicate(true)
	if bool(cue.get("already_started", false)):
		_current_cue["started"] = true
		return

	_generation += 1
	var token := _generation
	var delay: float = maxf(float(cue.get("delay", 0.0)), 0.0)
	if delay <= 0.0:
		_play_cue(token, cue)
		return

	_pending = true
	_pending_deadline_msec = Time.get_ticks_msec() + int(delay * 1000.0)
	pending_changed.emit()
	_ctx.get_tree().create_timer(delay).timeout.connect(_on_delay_elapsed.bind(token, cue.duplicate(true)), CONNECT_ONE_SHOT)


func current_cue_for_restore() -> Dictionary:
	if _current_cue.is_empty():
		return {}
	var cue: Dictionary = _current_cue.duplicate(true)
	cue["already_started"] = false
	cue["started"] = false
	if _pending:
		cue["delay"] = maxf(float(_pending_deadline_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	elif bool(_current_cue.get("started", false)):
		cue["delay"] = 0.0
	var path: String = str(cue.get("path", ""))
	if not path.is_empty():
		_note_voice(path)
	return cue


func cancel_pending(stop_active_voice: bool = false, clear_current: bool = true) -> void:
	_generation += 1
	_pending = false
	_pending_deadline_msec = 0
	if clear_current:
		_current_cue.clear()
	if stop_active_voice:
		_stop_voice()
	pending_changed.emit()


func reset_transient(stop_active_voice: bool = false) -> void:
	cancel_pending(stop_active_voice, true)
	_override_next = false
	_explicit_cue.clear()


func reset_all(stop_active_voice: bool = false) -> void:
	reset_transient(stop_active_voice)
	_states.clear()
	_next_delay = 0.0


func has_pending_voice() -> bool:
	return _pending


func is_enabled(speaker: Variant) -> bool:
	var canonical: String = _canonical(speaker)
	return not canonical.is_empty() and bool(_state_for(canonical).get("enabled", false))


func next_index(speaker: Variant) -> int:
	var canonical: String = _canonical(speaker)
	return int(_state_for(canonical).get("index", 0)) if not canonical.is_empty() else 0


func prefix_for(speaker: Variant) -> String:
	var canonical: String = _canonical(speaker)
	return str(_state_for(canonical).get("prefix", "")) if not canonical.is_empty() else ""


func manual_voice_path(speaker: Variant, voice_id: Variant) -> String:
	return _profile.manual_voice_path(speaker, voice_id) if _profile else ""


func snapshot() -> Dictionary:
	var states: Dictionary = {}
	for canonical in _states.keys():
		states[str(canonical)] = _state_for(str(canonical)).duplicate(true)
	var cue: Dictionary = _current_cue.duplicate(true)
	if not cue.is_empty():
		if _pending:
			cue["delay"] = maxf(float(_pending_deadline_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
		elif bool(cue.get("started", false)):
			cue["delay"] = 0.0
		cue["already_started"] = false
		cue["started"] = false
	return {
		"states": states,
		"next_delay": _next_delay,
		"override_next": _override_next,
		"current_cue": cue,
	}


func restore(data: Dictionary) -> void:
	cancel_pending(true, true)
	_states.clear()
	if not (data is Dictionary):
		return
	var states = data.get("states", {})
	if states is Dictionary:
		for canonical in states.keys():
			var value = states[canonical]
			if value is Dictionary:
				_states[str(canonical)] = value.duplicate(true)
	_next_delay = maxf(float(data.get("next_delay", 0.0)), 0.0)
	_override_next = bool(data.get("override_next", false))
	_explicit_cue.clear()
	var cue = data.get("current_cue", {})
	_current_cue = cue.duplicate(true) if cue is Dictionary else {}


func dispose() -> void:
	if _disposed:
		return
	cancel_pending(true, true)
	_disposed = true
	_ctx = null


func _on_delay_elapsed(token: int, cue: Dictionary) -> void:
	if token != _generation or _disposed:
		return
	_pending = false
	_pending_deadline_msec = 0
	_play_cue(token, cue)
	# Wake Auto-mode waiters only after AudioSystem has started (or rejected)
	# the cue, so they cannot observe an idle gap between delay and playback.
	pending_changed.emit()


func _play_cue(token: int, cue: Dictionary) -> void:
	if token != _generation or _disposed:
		return
	var path: String = str(cue.get("path", ""))
	if path.is_empty():
		return
	if _play_path(path):
		_current_cue = cue.duplicate(true)
		_current_cue["started"] = true
		cue_started.emit(path)


func _play_path(path: String) -> bool:
	var audio = _subsystem("audio")
	if audio == null or not audio.has_method("play_voice"):
		return false
	var result = audio.call("play_voice", path)
	return true if result == null else bool(result)


func _stop_voice() -> void:
	var audio = _subsystem("audio")
	if audio != null and audio.has_method("stop_voice"):
		audio.call("stop_voice")


func _note_voice(path: String) -> void:
	var backlog = _subsystem("backlog")
	if backlog != null and backlog.has_method("note_voice"):
		backlog.call("note_voice", path)


func _make_cue(path: String, delay: float, already_started: bool) -> Dictionary:
	return {
		"path": path,
		"delay": delay,
		"playable": _resource_exists(path),
		"already_started": already_started,
		"started": already_started,
	}


func _consume_automatic_cue(speaker: Variant) -> Dictionary:
	var canonical: String = _canonical(speaker)
	if canonical.is_empty():
		return {}
	var state: Dictionary = _state_for(canonical)
	if not bool(state.get("enabled", false)):
		return {}
	var index: int = int(state.get("index", 0))
	var prefix: String = str(state.get("prefix", ""))
	var path: String = _profile.voice_path(canonical, index, prefix)
	var delay: float = _next_delay
	_next_delay = 0.0
	state["index"] = index + 1
	_states[canonical] = state
	var cue := _make_cue(path, delay, false)
	cue["speaker"] = canonical
	cue["index"] = index
	return cue


func _resource_exists(path: String) -> bool:
	if path.is_empty():
		return false
	var full: String = path
	if not full.begins_with("res://"):
		var root := "res://resources/"
		var object_manager = _subsystem("object_manager")
		if object_manager != null:
			var constants = object_manager.get("constants")
			if constants is Dictionary:
				root = str(constants.get("resource_root", root))
		full = root.path_join(path)
	var exists := ResourceLoader.exists(full)
	if not exists:
		push_warning("AutoVoiceSystem: voice stream not found '%s'" % full)
	return exists


func _canonical(speaker: Variant) -> String:
	return _profile.resolve_character(speaker) if _profile else ""


func _state_for(canonical: String) -> Dictionary:
	var value = _states.get(canonical, {})
	if value is Dictionary and not value.is_empty():
		return value
	return {
		"enabled": false,
		"index": 0,
		"prefix": _profile.default_prefix(canonical) if _profile else "",
	}


func _subsystem(name: String) -> Object:
	if _ctx == null:
		return null
	return _ctx.get(name) as Object
