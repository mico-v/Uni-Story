extends Node

## NovaController — slim coordinator.
## Creates subsystems, initializes ViewManager, and routes signals between
## view controllers.  All game UI logic lives in GameViewController.

const SCENARIO_FILES := [
	"res://resources/scenarios/main.txt",
	"res://resources/scenarios/plan_demo.txt",
	"res://resources/scenarios/test_all.txt",
]

const RESOURCE_ROOT := "res://resources/"

# ── Subsystems (public, BaseBlock reaches them as nova.<name>) ───────
var object_manager: ObjectManager
var runtime: GDRuntime
var script_loader: ScriptLoader
var game_state: GameState
var variables: Variables
var i18n: I18n
var save_system: SaveSystem
var backlog: Backlog
var graphics: Graphics
var animation: AnimationSystem
var composer: SpriteComposer
var avatar: AvatarSystem
var audio: AudioSystem
var camera: CameraSystem
var transition: TransitionSystem
var dialogue_box: DialogueBoxSystem
var vfx: VFXSystem
var read_tracker: ReadTracker
var prefab_loader: PrefabLoader
var hot_reload: HotReload
var shortcut_manager: ShortcutManager
var video_system: VideoSystem
var dialog_system: DialogSystem
var preload_system: PreloadSystem

# ── View management ─────────────────────────────────────────────────
var view_manager: ViewManager

# ── View controllers (private) ───────────────────────────────────────
var _title_vc: TitleViewController
var _game_vc: GameViewController
var _settings_vc: SettingsViewController
var _cg_vc: CgGalleryController
var _music_vc: MusicGalleryController
var _save_load_vc: SaveLoadController

# ── Settings return tracking ──────────────────────────────────────────
var _settings_return_to := "title"


# ── Ready ────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_subsystems()
	_setup_locale()

	var scenario_files := SCENARIO_FILES.duplicate()

	_bind_view_controllers()
	_init_view_manager()
	_setup_game_view()
	_connect_model_signals()
	_load_gallery_configs()
	_apply_i18n()
	_load_settings()

	scenario_files = _localized_scenario_files(scenario_files)
	script_loader.load_all(scenario_files)
	if not script_loader.load_ok:
		push_error("NovaController: script load failed")
		return

	game_state.setup(script_loader.graph)
	view_manager.switch_to("title")
	if _title_vc and save_system:
		_title_vc.set_continue_enabled(save_system.has_auto_save())

	# Start file watching for hot reload (debug builds only).
	hot_reload.start(scenario_files)


# ── Subsystem creation ──────────────────────────────────────────────

func _init_subsystems() -> void:
	object_manager = ObjectManager.new()
	runtime = GDRuntime.new(self)
	script_loader = ScriptLoader.new(self)
	game_state = GameState.new(self)
	variables = Variables.new()
	i18n = I18n.new()
	save_system = SaveSystem.new(self)
	backlog = Backlog.new()
	graphics = Graphics.new(self)
	animation = AnimationSystem.new(self)
	composer = SpriteComposer.new(self)
	avatar = AvatarSystem.new(self)
	audio = AudioSystem.new(self)
	camera = CameraSystem.new(self)
	transition = TransitionSystem.new(self)
	dialogue_box = DialogueBoxSystem.new(self)
	vfx = VFXSystem.new(self)
	read_tracker = ReadTracker.new(self)
	prefab_loader = PrefabLoader.new(self)
	hot_reload = HotReload.new(self)
	shortcut_manager = ShortcutManager.new(self)
	video_system = VideoSystem.new(self)
	dialog_system = DialogSystem.new(self)
	preload_system = PreloadSystem.new(self)


# ── Locale ───────────────────────────────────────────────────────────

func _setup_locale() -> void:
	var os_locale := ""
	if OS.has_method("get_locale"):
		os_locale = str(OS.get_locale())
	i18n.setup(["zh", "en"], "res://resources/localized_resources/localized_strings", os_locale, "en")


func _localized_scenario_files(paths: Array) -> Array:
	var out: Array = []
	for path in paths:
		var src := str(path)
		if src.is_empty():
			continue
		out.append(i18n.load_scenario(i18n.locale, src))
	return out


# ── View controller binding ─────────────────────────────────────────

func _bind_view_controllers() -> void:
	var title_node := get_node_or_null("TitleView")
	if title_node is TitleViewController:
		_title_vc = title_node as TitleViewController
	var game_node := get_node_or_null("GameView")
	if game_node is GameViewController:
		_game_vc = game_node as GameViewController
	var settings_node := get_node_or_null("SettingsView")
	if settings_node is SettingsViewController:
		_settings_vc = settings_node as SettingsViewController
		if _settings_vc:
			_settings_vc.setup(self)
	var cg_node := get_node_or_null("CgGalleryView")
	if cg_node is CgGalleryController:
		_cg_vc = cg_node as CgGalleryController
	var music_node := get_node_or_null("MusicGalleryView")
	if music_node is MusicGalleryController:
		_music_vc = music_node as MusicGalleryController
		if _music_vc:
			_music_vc.setup(self)
	var save_load_node := get_node_or_null("SaveLoadView")
	if save_load_node is SaveLoadController:
		_save_load_vc = save_load_node as SaveLoadController
		if _save_load_vc:
			_save_load_vc.setup(self)


# ── ViewManager initialization ──────────────────────────────────────

func _init_view_manager() -> void:
	view_manager = ViewManager.new(self)
	var T := ViewManager.Transition
	if _title_vc:
		view_manager.register("title", _title_vc, T.FADE)
	if _game_vc:
		view_manager.register("game", _game_vc, T.FADE)
	if _settings_vc:
		view_manager.register("settings", _settings_vc, T.SLIDE_LEFT)
	if _cg_vc:
		view_manager.register("cg_gallery", _cg_vc, T.SLIDE_LEFT)
	if _music_vc:
		view_manager.register("music_gallery", _music_vc, T.SLIDE_LEFT)
	if _save_load_vc:
		view_manager.register("save_load", _save_load_vc, T.SLIDE_LEFT)


# ── Signal wiring ───────────────────────────────────────────────────

func _setup_game_view() -> void:
	if _game_vc == null:
		return
	_game_vc.setup(self)
	# Register world/bg/fg with object_manager from GameViewController.
	if _game_vc.get_world():
		object_manager.bind_object("world", _game_vc.get_world())
	if _game_vc.get_bg():
		object_manager.bind_object("bg", _game_vc.get_bg())
	if _game_vc.get_fg():
		object_manager.bind_object("fg", _game_vc.get_fg())
	if _game_vc.get_overlay():
		object_manager.bind_object("transition_overlay", _game_vc.get_overlay())
	if _game_vc.get_dbox():
		object_manager.bind_object("default_box", _game_vc.get_dbox())
	if _game_vc.get_avatar_rect():
		object_manager.bind_object("avatar", _game_vc.get_avatar_rect())
	object_manager.bind_object("anim", animation)
	object_manager.set_constant("resource_root", RESOURCE_ROOT)
	object_manager.freeze_constants()
	object_manager.freeze_objects()
	# VFX post-fx rect.
	if vfx and _game_vc.get_post_fx_rect():
		vfx.set_post_fx_rect(_game_vc.get_post_fx_rect())


func _connect_model_signals() -> void:
	if _game_vc == null:
		return
	game_state.dialogue_changed.connect(_game_vc.on_dialogue_changed)
	game_state.branch_requested.connect(_game_vc.on_branch_requested)
	game_state.game_ended.connect(_game_vc.on_game_ended)
	game_state.chapter_started.connect(_game_vc.on_chapter_started)
	game_state.ending_reached.connect(_game_vc.on_ending_reached)
	game_state.dialogue_advanced.connect(_auto_save)
	avatar.avatar_changed.connect(_game_vc.on_avatar_changed)
	# GameVC → NovaController routing.
	_game_vc.title_requested.connect(_on_game_title_requested)
	_game_vc.settings_requested.connect(func() -> void:
		_settings_return_to = view_manager.current()
		view_manager.switch_to("settings")
	)
	# TitleVC → navigation.
	if _title_vc:
		_title_vc.new_game_requested.connect(_on_title_new_game)
		_title_vc.continue_requested.connect(_on_title_continue)
		_title_vc.load_requested.connect(_on_title_load)
		_title_vc.settings_requested.connect(func() -> void:
			_settings_return_to = view_manager.current()
			view_manager.switch_to("settings")
		)
		_title_vc.gallery_requested.connect(func() -> void: view_manager.switch_to("cg_gallery"))
		_title_vc.music_requested.connect(func() -> void: view_manager.switch_to("music_gallery"))
		_title_vc.quit_requested.connect(_on_quit)
	# SettingsVC → back.
	if _settings_vc:
		_settings_vc.back_requested.connect(func() -> void: view_manager.switch_to(_settings_return_to))
		_settings_vc.setting_changed.connect(_on_setting_changed)
	# GalleryVCs → back.
	if _cg_vc:
		_cg_vc.back_requested.connect(func() -> void: view_manager.switch_to("title"))
	if _music_vc:
		_music_vc.back_requested.connect(func() -> void: view_manager.switch_to("title"))
	if _save_load_vc:
		_save_load_vc.back_requested.connect(func() -> void: view_manager.switch_to("title"))
		_save_load_vc.load_completed.connect(_on_save_load_completed)


func _apply_i18n() -> void:
	if _title_vc:
		_title_vc.apply_i18n(i18n)
	if _game_vc:
		_game_vc.apply_i18n()
	if _settings_vc:
		_settings_vc.apply_i18n(i18n)
	if _cg_vc:
		_cg_vc.apply_i18n(i18n)
	if _music_vc:
		_music_vc.apply_i18n(i18n)
	if _save_load_vc:
		_save_load_vc.apply_i18n(i18n)


# ── Navigation handlers ─────────────────────────────────────────────

func _on_title_new_game() -> void:
	var first_node: StringName = &""
	if script_loader.graph.start_nodes.size() > 0:
		first_node = script_loader.graph.start_nodes[0]
	elif script_loader.graph.unlocked_start_nodes.size() > 0:
		first_node = script_loader.graph.unlocked_start_nodes[0]
	if first_node == &"":
		push_error("NovaController: no start node found")
		return
	view_manager.switch_to("game")
	if _game_vc:
		_game_vc.enter_game(first_node)


func _on_title_continue() -> void:
	if save_system and save_system.has_auto_save():
		if save_system.load_auto_save():
			view_manager.switch_to("game")
			if _game_vc:
				_game_vc.load_game()


func _auto_save() -> void:
	if save_system:
		save_system.auto_save()


func _on_title_load() -> void:
	if _save_load_vc:
		_save_load_vc.show_in_mode(false)
	view_manager.switch_to("save_load")


func _on_game_title_requested() -> void:
	if _game_vc:
		_game_vc.reset_world()
	view_manager.switch_to("title")
	if _title_vc and save_system:
		_title_vc.set_continue_enabled(save_system.has_auto_save())


func _on_save_load_completed() -> void:
	view_manager.switch_to("game")
	if _game_vc:
		_game_vc.load_game()


func _on_quit() -> void:
	if read_tracker:
		read_tracker.save_to_disk()
	get_tree().quit()


# ── Gallery configuration ─────────────────────────────────────────────

const CG_GALLERY_CONFIG := "res://resources/gallery/cg_gallery.txt"
const MUSIC_GALLERY_CONFIG := "res://resources/gallery/music_gallery.txt"

var _cg_entries: Array = []
var _music_entries: Array = []

func _load_gallery_configs() -> void:
	if FileAccess.file_exists(CG_GALLERY_CONFIG):
		_cg_entries = GalleryConfigLoader.load_cg(CG_GALLERY_CONFIG)
		_apply_gallery_unlocks("cg")
		if _cg_vc:
			_cg_vc.set_gallery(_cg_entries)
	if FileAccess.file_exists(MUSIC_GALLERY_CONFIG):
		_music_entries = GalleryConfigLoader.load_music(MUSIC_GALLERY_CONFIG)
		_apply_gallery_unlocks("music")
		if _music_vc:
			_music_vc.set_tracks(_music_entries)
	# Hook auto-unlock signals.
	if audio and not audio.bgm_started.is_connected(_on_bgm_started):
		audio.bgm_started.connect(_on_bgm_started)
	if read_tracker and not read_tracker.gallery_unlocked.is_connected(_on_gallery_unlocked):
		read_tracker.gallery_unlocked.connect(_on_gallery_unlocked)


func _apply_gallery_unlocks(entry_type: String) -> void:
	if read_tracker == null:
		return
	var entries: Array = _cg_entries if entry_type == "cg" else _music_entries
	for entry in entries:
		if entry is Dictionary:
			var entry_name := str(entry.get("name", ""))
			if entry_type == "cg" and read_tracker.is_cg_unlocked(entry_name):
				entry["unlocked"] = true
			elif entry_type == "music" and read_tracker.is_music_unlocked(entry_name):
				entry["unlocked"] = true


func _on_bgm_started(path: String) -> void:
	if read_tracker == null:
		return
	for entry in _music_entries:
		if entry is Dictionary:
			var entry_path := str(entry.get("path", ""))
			if entry_path == path or entry_path.get_file() == path.get_file():
				read_tracker.mark_music(str(entry.get("name", "")))
				return


func _on_gallery_unlocked(entry_type: String, entry_name: String) -> void:
	if entry_type == "cg" and _cg_vc:
		for entry in _cg_entries:
			if entry is Dictionary and str(entry.get("name", "")) == entry_name:
				entry["unlocked"] = true
		_cg_vc.set_gallery(_cg_entries)
	elif entry_type == "music" and _music_vc:
		for entry in _music_entries:
			if entry is Dictionary and str(entry.get("name", "")) == entry_name:
				entry["unlocked"] = true
		_music_vc.set_tracks(_music_entries)


## Called by the scenario engine when a CG is displayed in-game.
func unlock_cg_by_path(tex_path: String) -> void:
	if read_tracker == null:
		return
	for entry in _cg_entries:
		if entry is Dictionary:
			var entry_path := str(entry.get("texture_path", ""))
			if entry_path == tex_path or entry_path.get_file() == tex_path.get_file():
				read_tracker.mark_cg(str(entry.get("name", "")))
				return


# ── Keyboard shortcuts (non-game views + debug) ──────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.is_echo():
		return
	if shortcut_manager == null:
		return
	# Navigation for non-game views.
	if view_manager and view_manager.current() != "game":
		if shortcut_manager.is_action_pressed("ui_leave"):
			var view := view_manager.current()
			match view:
				"settings":
					view_manager.switch_to(_settings_return_to)
				"cg_gallery", "music_gallery", "save_load":
					view_manager.switch_to("title")
				"title":
					_on_quit()
			get_viewport().set_input_as_handled()
			return
		if shortcut_manager.is_action_pressed("ui_step_forward"):
			if view_manager.current() == "title":
				_on_title_new_game()
				get_viewport().set_input_as_handled()
				return
	# Debug shortcuts (any view).
	if OS.is_debug_build():
		if shortcut_manager.is_action_pressed("debug_reload"):
			if hot_reload:
				hot_reload.reload()
			get_viewport().set_input_as_handled()
			return


# ── Settings handler ────────────────────────────────────────────────

const SETTINGS_PATH := "user://config/settings.cfg"

func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"text_speed":
			if _game_vc:
				_game_vc.type_cps = clampf(float(value) * 2.0, 1.0, 200.0)
		"auto_speed":
			if _game_vc:
				_game_vc.auto_delay = clampf(float(101 - value) * 0.002, 0.02, 0.2)
		"vol_global":
			if audio:
				audio.set_master_volume(float(value) / 100.0)
		"vol_bgm":
			if audio:
				audio.set_bgm_volume(float(value) / 100.0)
		"vol_se":
			if audio:
				audio.set_se_volume(float(value) / 100.0)
		"vol_voice":
			if audio:
				audio.set_voice_volume(float(value) / 100.0)
		"font_size":
			if _game_vc:
				var dbox := _game_vc.get_dbox()
				if dbox:
					var story = dbox.get_node_or_null("Story")
					if story is RichTextLabel:
						story.add_theme_font_size_override("normal_font_size", int(value))
		"language":
			if str(value) != i18n.locale:
				i18n.locale = str(value)
				_apply_i18n()
		"fullscreen":
			if bool(value):
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"dialogue_opacity":
			if dialogue_box:
				dialogue_box.set_opacity(float(value) / 100.0)
		"click_stop_anim":
			if _game_vc:
				_game_vc.click_stop_anim = bool(value)
		"click_stop_voice":
			if _game_vc:
				_game_vc.click_stop_voice = bool(value)
		"skip_unread":
			if _game_vc:
				_game_vc.skip_unread = bool(value)
	_save_settings()


func _save_settings() -> void:
	if _settings_vc == null:
		return
	DirAccess.make_dir_recursive_absolute("user://config")
	var cfg := ConfigFile.new()
	var data := _settings_vc.snapshot()
	for k in data:
		cfg.set_value("settings", k, data[k])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var data: Dictionary = {}
	for k in cfg.get_section_keys("settings"):
		data[k] = cfg.get_value("settings", k)
	if _settings_vc:
		_settings_vc.apply_settings(data)
	# Apply each setting to subsystems.
	for k in data:
		_on_setting_changed(str(k), data[k])


# ── I18n helper ─────────────────────────────────────────────────────

func _t(key: String, fallback: String = "") -> String:
	if i18n == null:
		return fallback
	return i18n.t(key, fallback)
