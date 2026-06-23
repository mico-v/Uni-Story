class_name Timeline extends RefCounted

## A track-based scheduler for orchestrating cinematic sequences.
## Each "track" is a callable that fires after a specified delay.
## All tracks run in parallel (each has its own Tween), so you can
## coordinate animations, camera moves, audio, VFX etc. with precise timing.
##
## Usage from NovaScript:
##   @<|
##       var tl = timeline()
##       tl.at(0.0, func(): show("bg", "sunset.png"))
##       tl.at(0.5, func(): cam([200, 0, 1.2], 1.0))
##       tl.at(1.0, func(): o.anim.PropertyVector3("char1", "position", [400, 300, 0], 0.8))
##       tl.at(1.5, func(): play_se("chime.wav"))
##       tl.play()
##   |>
##
## GDRuntime detects the returned Timeline and awaits its finished signal.

signal finished()

var _ctx: Node
var _tracks: Array[Dictionary] = []
var _tweens: Array[Tween] = []
var _completed_count: int = 0
var _total_count: int = 0
var _is_playing := false


func _init(ctx: Node) -> void:
	_ctx = ctx


## Schedule a callable to fire after `time` seconds.
## Returns self for fluent chaining: tl.at(0, f1).at(0.5, f2).at(1.0, f3)
func at(time: float, callable: Callable) -> Timeline:
	_tracks.append({"time": time, "callable": callable})
	return self


## Convenience: schedule a show() call.
func show_at(time: float, obj_name: String, image: String, coord = null) -> Timeline:
	var c = _ctx
	return at(time, func() -> void:
		if c.graphics:
			c.graphics.show(obj_name, image, coord)
	)


## Convenience: schedule a hide() call.
func hide_at(time: float, obj_name: String) -> Timeline:
	var c = _ctx
	return at(time, func() -> void:
		if c.graphics:
			c.graphics.hide(obj_name)
	)


## Convenience: schedule a camera move.
func cam_at(time: float, coord, duration: float = 0.5) -> Timeline:
	var c = _ctx
	return at(time, func() -> void:
		if c.camera:
			c.camera.move_camera(coord, null, null, duration)
	)


## Convenience: schedule a transition.
func trans_at(time: float, name: String, duration: float = 0.5) -> Timeline:
	var c = _ctx
	return at(time, func() -> void:
		if c.transition:
			c.transition.play(name, duration)
	)


## Convenience: schedule a sound effect.
func se_at(time: float, file: String) -> Timeline:
	var c = _ctx
	return at(time, func() -> void:
		if c.audio:
			c.audio.play_se(file)
	)


## Convenience: schedule a wait (just a delay marker).
func wait_at(time: float) -> Timeline:
	return at(time, func() -> void: pass)


## Start all scheduled tracks. Each track fires after its delay.
## Returns self so GDRuntime can detect and await it.
func play() -> Timeline:
	if _tracks.is_empty():
		# Nothing to play — signal immediately.
		_is_playing = true
		finished.emit()
		return self
	_is_playing = true
	_total_count = _tracks.size()
	_completed_count = 0
	for track in _tracks:
		var delay: float = float(track["time"])
		var callable: Callable = track["callable"]
		var t := _ctx.get_tree().create_tween()
		_tweens.append(t)
		if delay > 0.0:
			t.tween_interval(delay)
		t.tween_callback(_on_track_fire.bind(callable))
	return self


## Stop all running tweens.
func stop() -> void:
	for t in _tweens:
		if t is Tween and t.is_valid():
			t.kill()
	_tweens.clear()
	_is_playing = false


## Awaitable: pauses the scenario until all tracks have fired and completed.
func await_finished() -> void:
	if not _is_playing or _completed_count >= _total_count:
		return
	await finished


func _on_track_fire(callable: Callable) -> void:
	callable.call()
	_completed_count += 1
	if _completed_count >= _total_count:
		_is_playing = false
		finished.emit()
