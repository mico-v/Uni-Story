class_name VideoSystem extends RefCounted

## Video playback subsystem. Creates a VideoStreamPlayer on demand,
## overlays it on the game view, and supports skip (click / Space / Enter).
##
## Supported formats: .ogv (Theora), .webm (VP8/VP9).
## The video file must be importable by Godot (present in project or user://).
##
## Usage from NovaScript:
##   <| play_video("intro.ogv") |>

signal video_finished()

var _ctx: Node
var _player: VideoStreamPlayer = null
var _overlay: ColorRect = null  # background behind the video
var _is_playing := false
var _skippable := true


func _init(ctx: Node) -> void:
	_ctx = ctx


## Play a video file. `path` is relative to resource_root or an absolute res:// path.
## If `skippable` is true, clicking or pressing Space/Enter skips the video.
## Returns a signal that GDRuntime can await.
func play_video(path: String, skippable: bool = true) -> Signal:
	var full_path := _resolve_path(path)
	if not ResourceLoader.exists(full_path):
		push_warning("VideoSystem: video not found '%s'" % full_path)
		video_finished.emit()
		return video_finished

	stop()  # cleanup any previous

	_skippable = skippable
	_is_playing = true

	# Create background overlay.
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 1)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(_on_gui_input)
	_get_video_parent().add_child(_overlay)

	# Create video player.
	_player = VideoStreamPlayer.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.autoplay = false
	_player.finished.connect(_on_finished)
	_player.mouse_filter = Control.MOUSE_FILTER_STOP
	_player.gui_input.connect(_on_gui_input)
	_get_video_parent().add_child(_player)

	# Load and play.
	var stream = ResourceLoader.load(full_path)
	if stream == null:
		push_error("VideoSystem: failed to load '%s'" % full_path)
		stop()
		video_finished.emit()
		return video_finished

	_player.stream = stream
	_player.play()
	return video_finished


## Stop the current video and clean up nodes.
func stop() -> void:
	if _player and is_instance_valid(_player):
		_player.stop()
		_player.queue_free()
	_player = null
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_is_playing = false


## Whether a video is currently playing.
func is_playing() -> bool:
	return _is_playing


func _resolve_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return path
	var root: String = ""
	if _ctx.object_manager:
		var r = _ctx.object_manager.constants.get("resource_root", "")
		root = str(r)
	return root + path


func _get_video_parent() -> Control:
	# Attach to the GameView if available, otherwise to the root viewport.
	var game_view = _ctx.get_node_or_null("GameView")
	if game_view is Control:
		return game_view
	return _ctx.get_tree().root


func _on_gui_input(event: InputEvent) -> void:
	if not _is_playing or not _skippable:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			skip()
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_ESCAPE:
				skip()


func _on_finished() -> void:
	stop()
	video_finished.emit()


## Skip the current video (jump to end).
func skip() -> void:
	if _is_playing:
		stop()
		video_finished.emit()
