class_name MusicGalleryController extends Control

## Music appreciation view.  Displays a scrollable list of BGM tracks
## with play/stop controls and three playback modes (sequential, loop,
## random).  Reuses AudioSystem for actual playback when available.

signal back_requested()

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

enum PlayMode { SEQUENTIAL, LOOP_SINGLE, RANDOM }

@onready var title_label: Label = $HBox/Sidebar/VBox/Title
@onready var btn_back: Button = $HBox/Sidebar/VBox/BtnBack
@onready var track_list: VBoxContainer = $HBox/Content/VBox/Scroll/TrackList
@onready var lbl_now_playing: Label = $HBox/Content/VBox/PlayerBar/TrackLabel
@onready var btn_play: Button = $HBox/Content/VBox/PlayerBar/BtnPlay
@onready var btn_stop: Button = $HBox/Content/VBox/PlayerBar/BtnStop
@onready var btn_mode: Button = $HBox/Content/VBox/PlayerBar/BtnMode
@onready var empty_label: Label = $HBox/Content/VBox/Scroll/TrackList/EmptyLabel

var _tracks: Array = []  # [{name, display_name, path, unlocked}]
var _current_index := -1
var _play_mode: int = PlayMode.SEQUENTIAL
var _audio: AudioSystem = null  # optional reference for playback
var _ctx: Node = null


func setup(ctx: Node) -> void:
	_ctx = ctx
	if ctx and ctx.audio:
		_audio = ctx.audio as AudioSystem
	# Connect BGM finished signal for auto-advance.
	if _audio:
		_audio.bgm_finished.connect(_on_bgm_finished)


func _ready() -> void:
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	btn_play.pressed.connect(_play_current)
	btn_stop.pressed.connect(_stop_current)
	btn_mode.pressed.connect(_cycle_mode)
	if title_label:
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func set_audio_system(audio_sys: AudioSystem) -> void:
	_audio = audio_sys


func set_tracks(entries: Array) -> void:
	_tracks = entries
	_clear_list()
	if entries.is_empty():
		if empty_label:
			empty_label.visible = true
		return
	if empty_label:
		empty_label.visible = false
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var unlocked := bool(entry.get("unlocked", false))
		var display := str(entry.get("display_name", entry.get("name", "???")))
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		if unlocked:
			btn.text = display
			btn.pressed.connect(_play_track.bind(i))
		else:
			btn.text = "???"
			btn.disabled = true
		track_list.add_child(btn)


func _play_track(index: int) -> void:
	if index < 0 or index >= _tracks.size():
		return
	_current_index = index
	var entry: Dictionary = _tracks[index]
	var path := str(entry.get("path", ""))
	var display := str(entry.get("display_name", entry.get("name", "")))
	if _audio and not path.is_empty():
		_audio.play_bgm(path)
	if lbl_now_playing:
		lbl_now_playing.text = display


func _play_current() -> void:
	if _current_index >= 0:
		_play_track(_current_index)


func _stop_current() -> void:
	if _audio:
		_audio.stop_bgm()
	_current_index = -1
	if lbl_now_playing:
		lbl_now_playing.text = ""


func _cycle_mode() -> void:
	_play_mode = (_play_mode + 1) % 3
	_update_mode_label()


func _on_bgm_finished() -> void:
	if _current_index < 0 or _tracks.is_empty():
		return
	match _play_mode:
		PlayMode.SEQUENTIAL:
			# Advance to next track.
			var next := _current_index + 1
			if next >= _tracks.size():
				next = 0
			_play_track(next)
		PlayMode.LOOP_SINGLE:
			# Replay current track.
			_play_track(_current_index)
		PlayMode.RANDOM:
			# Pick a random track (different from current if possible).
			if _tracks.size() <= 1:
				_play_track(0)
			else:
				var r := randi() % _tracks.size()
				while r == _current_index:
					r = randi() % _tracks.size()
				_play_track(r)


func _update_mode_label() -> void:
	if btn_mode == null:
		return
	var i: I18n = null
	if _ctx and _ctx.i18n:
		i = _ctx.i18n
	match _play_mode:
		PlayMode.SEQUENTIAL:
			btn_mode.text = i.t("musicgallery.mode.seq", "列表循环") if i else "列表循环"
		PlayMode.LOOP_SINGLE:
			btn_mode.text = i.t("musicgallery.mode.loop", "单曲循环") if i else "单曲循环"
		PlayMode.RANDOM:
			btn_mode.text = i.t("musicgallery.mode.rand", "随机播放") if i else "随机播放"


func _clear_list() -> void:
	for c in track_list.get_children():
		if c == empty_label:
			continue
		c.queue_free()


func apply_i18n(i18n: I18n) -> void:
	if i18n == null:
		return
	if title_label:
		title_label.text = i18n.t("musicgallery.title", "音乐鉴赏")
	if btn_back:
		btn_back.text = i18n.t("title.selectchapter.return", "返回")
	if btn_play:
		btn_play.text = i18n.t("music.play", "播放")
	if btn_stop:
		btn_stop.text = i18n.t("music.stop", "停止")
	if empty_label:
		empty_label.text = i18n.t("music.no_tracks", "（暂无曲目）")
	# Mode button text
	match _play_mode:
		PlayMode.SEQUENTIAL:
			if btn_mode:
				btn_mode.text = i18n.t("musicgallery.mode.seq", "列表循环")
		PlayMode.LOOP_SINGLE:
			if btn_mode:
				btn_mode.text = i18n.t("musicgallery.mode.loop", "单曲循环")
		PlayMode.RANDOM:
			if btn_mode:
				btn_mode.text = i18n.t("musicgallery.mode.rand", "随机播放")
