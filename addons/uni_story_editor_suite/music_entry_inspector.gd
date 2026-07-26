@tool
extends EditorInspectorPlugin

## Inspector plugin for MusicEntry resources.
##
## Adds audio preview controls:
##   - Preview Loop: Play with loop points
##   - Preview No Loop: Play once through
##   - Stop: Stop current preview


var _preview_stream_player: AudioStreamPlayer


func _can_handle(object: Object) -> bool:
	if object is Resource:
		var script := object.get_script()
		if script:
			return script.resource_path == "res://scripts/resources/music_entry.gd"
	return false


func _parse_begin(object: Object) -> void:
	if not (object is Resource):
		return

	# Get or create preview player
	if _preview_stream_player == null or not is_instance_valid(_preview_stream_player):
		_preview_stream_player = AudioStreamPlayer.new()
		_preview_stream_player.bus = "Music"
		Engine.get_main_loop().root.add_child(_preview_stream_player)

	# Preview Loop button
	var loop_btn := Button.new()
	loop_btn.text = "▶ Preview Loop"
	loop_btn.tooltip_text = "Play audio with loop points"
	loop_btn.pressed.connect(func():
		var stream = object.get("audio_stream")
		if stream and _preview_stream_player:
			_preview_stream_player.stream = stream
			_preview_stream_player.play()
			print("[MusicEntryInspector] Preview loop: %s" % object.get("display_name"))
	)
	add_custom_control(loop_btn)

	# Preview No Loop button
	var play_btn := Button.new()
	play_btn.text = "▶ Preview No Loop"
	play_btn.tooltip_text = "Play audio once without looping"
	play_btn.pressed.connect(func():
		var stream = object.get("audio_stream")
		if stream and _preview_stream_player:
			_preview_stream_player.stream = stream
			_preview_stream_player.play()
			print("[MusicEntryInspector] Preview play: %s" % object.get("display_name"))
	)
	add_custom_control(play_btn)

	# Stop button
	var stop_btn := Button.new()
	stop_btn.text = "⏹ Stop"
	stop_btn.tooltip_text = "Stop current preview"
	stop_btn.pressed.connect(func():
		if _preview_stream_player:
			_preview_stream_player.stop()
			print("[MusicEntryInspector] Preview stopped")
	)
	add_custom_control(stop_btn)
