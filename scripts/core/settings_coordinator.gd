class_name SettingsCoordinator extends RefCounted

## Loads, saves, and applies settings outside NovaController.

var _engine: EngineContext
var _settings_vc: Object
var _game_vc: Object
var _settings_path := "user://config/settings.cfg"
var _apply_i18n_callback: Callable


func _init(ctx: Node) -> void:
	if ctx:
		_engine = ctx.get("engine_context") as EngineContext


func setup(settings_vc: Object, game_vc: Object, settings_path: String, apply_i18n_callback: Callable) -> void:
	_settings_vc = settings_vc
	_game_vc = game_vc
	_settings_path = settings_path
	_apply_i18n_callback = apply_i18n_callback


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path) != OK:
		return
	var data: Dictionary = {}
	for key in cfg.get_section_keys("settings"):
		data[key] = cfg.get_value("settings", key)
	if _settings_vc and _settings_vc.has_method("apply_settings"):
		_settings_vc.call("apply_settings", data)
	for key in data:
		apply_setting(str(key), data[key], false)


func apply_setting(key: String, value: Variant, persist: bool = true) -> void:
	match key:
		"text_speed":
			if _game_vc:
				_game_vc.set("type_cps", clampf(float(value) * 2.0, 1.0, 200.0))
		"auto_speed":
			if _game_vc:
				_game_vc.set("auto_delay", clampf(float(101 - value) * 0.002, 0.02, 0.2))
		"vol_global":
			if _engine and _engine.audio:
				_engine.audio.set_master_volume(float(value) / 100.0)
		"vol_bgm":
			if _engine and _engine.audio:
				_engine.audio.set_bgm_volume(float(value) / 100.0)
		"vol_se":
			if _engine and _engine.audio:
				_engine.audio.set_se_volume(float(value) / 100.0)
		"vol_voice":
			if _engine and _engine.audio:
				_engine.audio.set_voice_volume(float(value) / 100.0)
		"font_size":
			_apply_font_size(int(value))
		"language":
			if _engine and _engine.i18n and str(value) != _engine.i18n.locale:
				_engine.i18n.locale = str(value)
				if _apply_i18n_callback.is_valid():
					_apply_i18n_callback.call()
		"fullscreen":
			if bool(value):
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"dialogue_opacity":
			if _engine and _engine.dialogue_box:
				_engine.dialogue_box.set_opacity(float(value) / 100.0)
		"click_stop_anim":
			if _game_vc:
				_game_vc.set("click_stop_anim", bool(value))
		"click_stop_voice":
			if _game_vc:
				_game_vc.set("click_stop_voice", bool(value))
		"skip_unread":
			if _game_vc:
				_game_vc.set("skip_unread", bool(value))

	if persist:
		save_settings()


func save_settings() -> void:
	if _settings_vc == null or not _settings_vc.has_method("snapshot"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_settings_path.get_base_dir()))
	var cfg := ConfigFile.new()
	var data: Dictionary = _settings_vc.call("snapshot")
	for key in data:
		cfg.set_value("settings", key, data[key])
	cfg.save(_settings_path)


func _apply_font_size(font_size: int) -> void:
	if _game_vc == null or not _game_vc.has_method("get_dbox"):
		return
	var dbox = _game_vc.call("get_dbox")
	if dbox == null:
		return
	var story = dbox.get_node_or_null("Story")
	if story is RichTextLabel:
		story.add_theme_font_size_override("normal_font_size", font_size)
