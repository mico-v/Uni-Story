class_name GalleryCoordinator extends RefCounted

## Coordinates gallery config loading, auto-unlock signals, and view refreshes.

var _engine: EngineContext
var _cg_view: CgGalleryController
var _music_view: MusicGalleryController
var _cg_config_path := ""
var _music_config_path := ""
var _cg_entries: Array[Dictionary] = []
var _music_entries: Array[Dictionary] = []


func _init(ctx: Node) -> void:
	if ctx:
		_engine = ctx.get("engine_context") as EngineContext


func setup(cg_view: CgGalleryController, music_view: MusicGalleryController, cg_config_path: String, music_config_path: String) -> void:
	_cg_view = cg_view
	_music_view = music_view
	_cg_config_path = cg_config_path
	_music_config_path = music_config_path


func load_configs() -> void:
	if FileAccess.file_exists(_cg_config_path):
		_cg_entries = GalleryConfigLoader.load_cg(_cg_config_path)
		_apply_gallery_unlocks("cg")
		if _cg_view:
			_cg_view.set_gallery(_cg_entries)

	if FileAccess.file_exists(_music_config_path):
		_music_entries = GalleryConfigLoader.load_music(_music_config_path)
		_apply_gallery_unlocks("music")
		if _music_view:
			_music_view.set_tracks(_music_entries)

	_connect_unlock_signals()


func unlock_cg_by_path(tex_path: String) -> void:
	if _engine == null or _engine.read_tracker == null:
		return
	for entry in _cg_entries:
		var entry_path := str(entry.get("texture_path", ""))
		if entry_path == tex_path or entry_path.get_file() == tex_path.get_file():
			_engine.read_tracker.mark_cg(str(entry.get("name", "")))
			return


func cg_entries() -> Array[Dictionary]:
	return _cg_entries.duplicate(true)


func music_entries() -> Array[Dictionary]:
	return _music_entries.duplicate(true)


func _connect_unlock_signals() -> void:
	if _engine == null:
		return
	if _engine.audio:
		var bgm_callable := Callable(self, "_on_bgm_started")
		if not _engine.audio.bgm_started.is_connected(bgm_callable):
			_engine.audio.bgm_started.connect(bgm_callable)
	if _engine.read_tracker:
		var gallery_callable := Callable(self, "_on_gallery_unlocked")
		if not _engine.read_tracker.gallery_unlocked.is_connected(gallery_callable):
			_engine.read_tracker.gallery_unlocked.connect(gallery_callable)


func _apply_gallery_unlocks(entry_type: String) -> void:
	if _engine == null or _engine.read_tracker == null:
		return
	var entries: Array = _cg_entries if entry_type == "cg" else _music_entries
	for entry in entries:
		if not entry is Dictionary:
			continue
		var entry_name := str(entry.get("name", ""))
		if entry_type == "cg" and _engine.read_tracker.is_cg_unlocked(entry_name):
			entry["unlocked"] = true
		elif entry_type == "music" and _engine.read_tracker.is_music_unlocked(entry_name):
			entry["unlocked"] = true


func _on_bgm_started(path: String) -> void:
	if _engine == null or _engine.read_tracker == null:
		return
	for entry in _music_entries:
		var entry_path := str(entry.get("path", ""))
		if entry_path == path or entry_path.get_file() == path.get_file():
			_engine.read_tracker.mark_music(str(entry.get("name", "")))
			return


func _on_gallery_unlocked(entry_type: String, entry_name: String) -> void:
	match entry_type:
		"cg":
			for entry in _cg_entries:
				if str(entry.get("name", "")) == entry_name:
					entry["unlocked"] = true
			if _cg_view:
				_cg_view.set_gallery(_cg_entries)
		"music":
			for entry in _music_entries:
				if str(entry.get("name", "")) == entry_name:
					entry["unlocked"] = true
			if _music_view:
				_music_view.set_tracks(_music_entries)
