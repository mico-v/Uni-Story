class_name AudioSystem extends RefCounted

## BGM / SE / Voice playback. BGM uses Godot's built-in loop support on the
## imported stream (loop begin point is configured on the .ogg/.wav import, so
## we don't reimplement looping). SE and Voice are one-shot.

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
	ctx.add_child(_voice_player)

	for i in SE_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SEPlayer%d" % i
		ctx.add_child(p)
		_se_players.append(p)


func _load_stream(path: String) -> AudioStream:
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var full := path if path.begins_with("res://") else root + path
	if ResourceLoader.exists(full):
		return load(full)
	push_warning("AudioSystem: stream not found '%s'" % full)
	return null


func play_bgm(path: String, fade: float = 0.0) -> void:
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


func stop_bgm(fade: float = 0.0) -> void:
	if not _bgm_player.playing:
		return
	if fade > 0.0:
		var t := _ctx.get_tree().create_tween()
		t.tween_property(_bgm_player, "volume_db", -40.0, fade)
		await t.finished
	_bgm_player.stop()


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


func play_voice(path: String) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()
