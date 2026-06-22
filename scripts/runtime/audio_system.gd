class_name AudioSystem extends RefCounted

## BGM / SE / Voice playback with independent audio buses, BGM crossfade,
## and SE pool preemption. BGM uses two players for seamless crossfade.
## SE and Voice are one-shot.

signal voice_finished()
signal bgm_started(path: String)
signal bgm_finished()

var _ctx: Node
var _bgm_a: AudioStreamPlayer
var _bgm_b: AudioStreamPlayer
var _bgm_active: AudioStreamPlayer  # currently playing BGM player
var _bgm_inactive: AudioStreamPlayer  # the other one, used for crossfade
var _voice_player: AudioStreamPlayer
var _se_players: Array = []  # small pool for overlapping SE
var _se_start_times: Array = []  # track when each SE started (for preemption)

const SE_POOL_SIZE := 4
const BUS_BGM := "BGM"
const BUS_SE := "SE"
const BUS_VOICE := "Voice"


func _init(ctx: Node) -> void:
	_ctx = ctx
	_setup_buses()

	_bgm_a = AudioStreamPlayer.new()
	_bgm_a.name = "BGMPlayerA"
	_bgm_a.bus = BUS_BGM
	_bgm_a.finished.connect(_on_bgm_finished)
	ctx.add_child(_bgm_a)

	_bgm_b = AudioStreamPlayer.new()
	_bgm_b.name = "BGMPlayerB"
	_bgm_b.bus = BUS_BGM
	_bgm_b.finished.connect(_on_bgm_finished)
	ctx.add_child(_bgm_b)

	_bgm_active = _bgm_a
	_bgm_inactive = _bgm_b

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "VoicePlayer"
	_voice_player.bus = BUS_VOICE
	_voice_player.finished.connect(_on_voice_finished)
	ctx.add_child(_voice_player)

	for i in SE_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SEPlayer%d" % i
		p.bus = BUS_SE
		ctx.add_child(p)
		_se_players.append(p)
		_se_start_times.append(0.0)


func _setup_buses() -> void:
	# Create BGM, SE, Voice buses routing to Master. Skip if already present.
	var layout := AudioServer.get_bus_layout()
	for bus_name in [BUS_BGM, BUS_SE, BUS_VOICE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _on_voice_finished() -> void:
	voice_finished.emit()


func _on_bgm_finished() -> void:
	bgm_finished.emit()


func is_voice_playing() -> bool:
	return _voice_player.playing


func stop_voice() -> void:
	_voice_player.stop()


func _load_stream(path: String) -> AudioStream:
	var root: String = _ctx.object_manager.constants.get("resource_root", "res://resources/")
	var full := path if path.begins_with("res://") else root + path
	if ResourceLoader.exists(full):
		return load(full)
	push_warning("AudioSystem: stream not found '%s'" % full)
	return null


## Play BGM with crossfade. If a BGM is already playing, simultaneously fade
## out the old one and fade in the new one — no silence gap.
func play_bgm(path: String, fade: float = 0.0):
	var stream := _load_stream(path)
	if stream == null:
		return
	# If same stream is already playing, do nothing.
	if _bgm_active.playing and _bgm_active.stream and _bgm_active.stream.resource_path == stream.resource_path:
		return
	if fade > 0.0 and _bgm_active.playing:
		# Crossfade: start new on inactive player, fade it in while fading old out.
		_bgm_inactive.stream = stream
		_bgm_inactive.volume_db = -40.0
		_bgm_inactive.play()
		var t := _ctx.get_tree().create_tween()
		t.set_parallel(true)
		t.tween_property(_bgm_active, "volume_db", -80.0, fade)
		t.tween_property(_bgm_inactive, "volume_db", 0.0, fade)
		t.set_parallel(false)
		t.tween_callback(func() -> void:
			_bgm_active.stop()
			_swap_bgm()
		)
		await t.finished
	else:
		# No fade or nothing playing: just start on active player.
		_bgm_active.stream = stream
		_bgm_active.volume_db = 0.0
		_bgm_active.play()
	bgm_started.emit(path)
	return


func _swap_bgm() -> void:
	var tmp := _bgm_active
	_bgm_active = _bgm_inactive
	_bgm_inactive = tmp


func snapshot() -> Dictionary:
	var stream_path := ""
	if _bgm_active.stream:
		stream_path = _bgm_active.stream.resource_path
	return {
		"bgm": {
			"stream": stream_path,
			"volume_db": _bgm_active.volume_db,
			"playing": _bgm_active.playing,
			"position": _bgm_active.get_playback_position() if _bgm_active.stream else 0.0,
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
				_bgm_active.stream = stream
				_bgm_active.volume_db = float(bgm_state.get("volume_db", 0.0))
				var pos := float(bgm_state.get("position", 0.0))
				var play := bool(bgm_state.get("playing", false))
				if play:
					_bgm_active.play(pos)

	var voice_state: Dictionary = state.get("voice", {})
	if voice_state is Dictionary:
		var vs := str(voice_state.get("stream", ""))
		if vs != "":
			var stream := _load_stream(vs)
			if stream != null:
				_voice_player.stream = stream
				_voice_player.volume_db = float(voice_state.get("volume_db", 0.0))
				# NOTE: voice is one-shot; do NOT replay on restore.


func stop_all() -> void:
	_bgm_a.stop()
	_bgm_b.stop()
	_voice_player.stop()
	for p in _se_players:
		p.stop()


## Public accessor for the BGM player, used by MusicGalleryController.
func get_bgm_player() -> AudioStreamPlayer:
	return _bgm_active


func stop_bgm(fade: float = 0.0):
	if not _bgm_active.playing:
		return
	if fade > 0.0:
		var t := _ctx.get_tree().create_tween()
		t.tween_property(_bgm_active, "volume_db", -80.0, fade)
		await t.finished
	_bgm_active.stop()
	return


## Set volume for all audio players (0.0 to 1.0, converted to dB).
## Routes through bus volume for independent control.
func set_master_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _linear_to_db(linear))
	else:
		var db := _linear_to_db(linear)
		_bgm_active.volume_db = db
		_voice_player.volume_db = db


## Set BGM volume only (0.0 to 1.0).
func set_bgm_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_BGM)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _linear_to_db(linear))
	else:
		_bgm_active.volume_db = _linear_to_db(linear)
		_bgm_inactive.volume_db = _linear_to_db(linear)


## Set SE volume (0.0 to 1.0).
func set_se_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_SE)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _linear_to_db(linear))
	else:
		var db := _linear_to_db(linear)
		for p in _se_players:
			p.volume_db = db


## Set voice volume (0.0 to 1.0).
func set_voice_volume(linear: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_VOICE)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, _linear_to_db(linear))
	else:
		_voice_player.volume_db = _linear_to_db(linear)


static func _linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


## Play a sound effect. If all SE players are busy, preempt the oldest one.
func play_se(path: String, volume_db: float = 0.0) -> void:
	var stream := _load_stream(path)
	if stream == null:
		return
	# Find a free player.
	for i in _se_players.size():
		var p: AudioStreamPlayer = _se_players[i]
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			_se_start_times[i] = Time.get_ticks_msec()
			return
	# All busy: preempt the oldest (earliest start time).
	var oldest_idx := 0
	var oldest_time: float = _se_start_times[0]
	for i in range(1, _se_players.size()):
		if _se_start_times[i] < oldest_time:
			oldest_time = _se_start_times[i]
			oldest_idx = i
	var p: AudioStreamPlayer = _se_players[oldest_idx]
	p.stop()
	p.stream = stream
	p.volume_db = volume_db
	p.play()
	_se_start_times[oldest_idx] = Time.get_ticks_msec()


func play_voice(path: String):
	var stream := _load_stream(path)
	if stream == null:
		return
	_voice_player.stream = stream
	_voice_player.play()
	return
