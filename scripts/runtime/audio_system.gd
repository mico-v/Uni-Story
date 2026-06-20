class_name AudioSystem extends RefCounted

## BGM / SE / Voice playback. BGM uses Godot's built-in loop support on the
## imported stream (loop begin point is configured on the .ogg/.wav import, so
## we don't reimplement looping). SE and Voice are one-shot.

signal voice_finished()

var _ctx: Node
var _bgm_player: AudioStreamPlayer
var _voice_player: AudioStreamPlayer
var _se_players: Array = []  # small pool for overlapping SE

const SE_POOL_SIZE := 4


func _init(ctx: Node) -> void:
	_ctx = ctx
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "Master"
	ctx.add_child(_bgm_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.finished.connect(_on_voice_finished)
	ctx.add_child(_voice_player)

	for i in SE_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SEPlayer%d" % i
		ctx.add_child(p)
		_se_players.append(p)


func _on_voice_finished() -> void:
	voice_finished.emit()


func is_voice_playing() -> bool:
	return _voice_player.playing


func _load_stream(path: String) -> AudioStream:
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var full := path if path.begins_with("res://") else root + path
	if ResourceLoader.exists(full):
		return load(full)
	push_warning("AudioSystem: stream not found '%s'" % full)
	return null


func play_bgm(path: String, fade: float = 0.0):
	var stream := _load_stream(path)
	if stream == null:
		return
	if fade > 0.0 and _bgm_player.playing:
		var t := _ctx.get_tree().create_tween()
		t.tween_property(_bgm_player, "volume_db", -40.0, fade)
		await t.finished
	_bgm_player.stream = stream
	_bgm_player.volume_db = 0.0
	_bgm_player.play()
	if fade > 0.0:
		_bgm_player.volume_db = -40.0
		var t2 := _ctx.get_tree().create_tween()
		t2.tween_property(_bgm_player, "volume_db", 0.0, fade)
		await t2.finished
	return


func snapshot() -> Dictionary:
	var stream_path := ""
	if _bgm_player.stream:
		stream_path = _bgm_player.stream.resource_path
	return {
		"bgm": {
			"stream": stream_path,
			"volume_db": _bgm_player.volume_db,
			"playing": _bgm_player.playing,
			"position": _bgm_player.get_playback_position() if _bgm_player.stream else 0.0,
		},
		"voice": {
			"stream": (_voice_player.stream.resource_path if _voice_player.stream else ""),
			"playing": _voice_player.playing,
			"volume_db": _voice_player.volume_db,
		},
	}


func restore(state: Dictionary) -> void:
	if not (state is Dictionary):
		return

	var bgm_state: Dictionary = state.get("bgm", {})
	if bgm_state is Dictionary:
		var stream_path := str(bgm_state.get("stream", ""))
		if stream_path != "":
			var stream := _load_stream(stream_path)
			if stream != null:
				_bgm_player.stream = stream
				_bgm_player.volume_db = float(bgm_state.get("volume_db", 0.0))
				var pos := float(bgm_state.get("position", 0.0))
				var play := bool(bgm_state.get("playing", false))
				if play:
					# Keep deterministic: use saved playback position as seek seed.
					_bgm_player.play(pos)


	var voice_state: Dictionary = state.get("voice", {})
	if voice_state is Dictionary:
		var vs := str(voice_state.get("stream", ""))
		if vs != "":
			var stream := _load_stream(vs)
			if stream != null:
				_voice_player.stream = stream
				_voice_player.volume_db = float(voice_state.get("volume_db", 0.0))
				if bool(voice_state.get("playing", false)):
					_voice_player.play()


func stop_all() -> void:
	_bgm_player.stop()
	_voice_player.stop()
	for p in _se_players:
		p.stop()


func stop_bgm(fade: float = 0.0):
	if not _bgm_player.playing:
		return
	if fade > 0.0:
		var t := _ctx.get_tree().create_tween()
		t.tween_property(_bgm_player, "volume_db", -40.0, fade)
		await t.finished
	_bgm_player.stop()
	return


## Set volume for all audio players (0.0 to 1.0, converted to dB).
func set_master_volume(linear: float) -> void:
	var db := _linear_to_db(linear)
	_bgm_player.volume_db = db
	_voice_player.volume_db = db


## Set BGM volume only (0.0 to 1.0).
func set_bgm_volume(linear: float) -> void:
	_bgm_player.volume_db = _linear_to_db(linear)


## Set SE volume (0.0 to 1.0).
func set_se_volume(linear: float) -> void:
	var db := _linear_to_db(linear)
	for p in _se_players:
		p.volume_db = db


## Set voice volume (0.0 to 1.0).
func set_voice_volume(linear: float) -> void:
	_voice_player.volume_db = _linear_to_db(linear)


static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


func play_se(path: String, volume_db: float = 0.0) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	for p in _se_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	# All busy: reuse the first.
	_se_players[0].stream = stream
	_se_players[0].volume_db = volume_db
	_se_players[0].play()


func play_voice(path: String):
	var stream := _load_stream(path)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()
	# Keep async compatibility with lazy call sites; return when dispatch done.
	return
