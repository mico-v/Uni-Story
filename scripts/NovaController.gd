class_name NovaController extends Node

## NovaController — slim coordinator.
## Creates subsystems, initializes ViewManager, and routes signals between
## view controllers.  All game UI logic lives in GameViewController.

const GalleryCoordinatorScript := preload("res://scripts/core/gallery_coordinator.gd")
const SettingsCoordinatorScript := preload("res://scripts/core/settings_coordinator.gd")
const EngineLogScript := preload("res://scripts/core/engine_log.gd")

@export var scenario_files: Array[String] = [
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/ch3.txt",
	"res://resources/scenarios/ch4.txt",
	"res://resources/scenarios/test_anim_hold.txt",
	"res://resources/scenarios/test_avatar.txt",
	"res://resources/scenarios/test_box.txt",
	"res://resources/scenarios/test_box_anim.txt",
	"res://resources/scenarios/test_branch.txt",
	"res://resources/scenarios/test_branch_image.txt",
	"res://resources/scenarios/test_dialogue_length.txt",
	"res://resources/scenarios/test_empty_node.txt",
	"res://resources/scenarios/test_fade.txt",
	"res://resources/scenarios/test_global_variable.txt",
	"res://resources/scenarios/test_immediate_step.txt",
	"res://resources/scenarios/test_input.txt",
	"res://resources/scenarios/test_many_chara.txt",
	"res://resources/scenarios/test_minigame.txt",
	"res://resources/scenarios/test_transition.txt",
	"res://resources/scenarios/test_upgrade.txt",
	"res://resources/scenarios/test_variables.txt",
	"res://resources/scenarios/test_video.txt",
	"res://resources/scenarios/tut01.txt",
	"res://resources/scenarios/tut02.txt",
	"res://resources/scenarios/tut03.txt",
	"res://resources/scenarios/tut04.txt",
	"res://resources/scenarios/tut05.txt",
	"res://resources/scenarios/tut06.txt",
]

@export var resource_root: String = "res://resources/"
@export_group("Save")
@export var save_dir: String = "user://saves/"
@export_range(1, 100, 1) var save_slot_count: int = 6
@export var auto_save_slot: int = 99
@export var auto_save_enabled: bool = true
@export var settings_path: String = "user://config/settings.cfg"
@export_group("Preload")
@export_range(1, 1024, 1) var preload_cache_size: int = 128
@export_group("Gallery")
@export var cg_gallery_config: String = "res://resources/gallery/cg_gallery.txt"
@export var music_gallery_config: String = "res://resources/gallery/music_gallery.txt"
@export_group("")

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
var engine_context: EngineContext
var restorables: RestorableRegistry
var gallery_coordinator: RefCounted
var settings_coordinator: RefCounted

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

	var sf := scenario_files.duplicate()

	_bind_view_controllers()
	_init_view_manager()
	_setup_game_view()
	_setup_settings()
	_connect_model_signals()
	_setup_gallery()
	_apply_i18n()
	_load_settings()

	sf = _localized_scenario_files(sf)
	script_loader.load_all(sf)
	if not script_loader.load_ok:
		EngineLogScript.error(EngineLogScript.Category.PARSE, "NovaController", "script load failed")
		return

	game_state.setup(script_loader.graph)
	view_manager.switch_to("title")
	if _title_vc and save_system:
		_title_vc.set_continue_enabled(save_system.has_auto_save())

	# Start file watching for hot reload (debug builds only).
	hot_reload.start(scenario_files)


func _exit_tree() -> void:
	if hot_reload:
		hot_reload.stop()
	if audio:
		audio.dispose()
	if vfx:
		vfx.clear_all()
	if composer:
		composer.clear_all()
	if video_system:
		video_system.stop()
	if read_tracker:
		read_tracker.save_to_disk()


# ── Subsystem creation ──────────────────────────────────────────────

func _init_subsystems() -> void:
	engine_context = EngineContext.new(self)
	restorables = RestorableRegistry.new()
	object_manager = ObjectManager.new()
	runtime = GDRuntime.new(self)
	script_loader = ScriptLoader.new(self)
	game_state = GameState.new(self)
	variables = Variables.new()
	i18n = I18n.new()
	save_system = SaveSystem.new(self)
	save_system.configure(save_dir, save_slot_count, auto_save_slot, auto_save_enabled)
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
	preload_system.configure(preload_cache_size)
	gallery_coordinator = GalleryCoordinatorScript.new(self)
	settings_coordinator = SettingsCoordinatorScript.new(self)
	_register_restorables()


func _register_restorables() -> void:
	restorables.register("game_state", game_state)
	restorables.register("graphics", graphics)
	restorables.register("audio", audio)
	restorables.register("camera", camera)
	restorables.register("animation", animation)
	restorables.register("dialogue_box", dialogue_box)
	restorables.register("vfx", vfx)
	restorables.register("composer", composer)
	restorables.register("prefab_loader", prefab_loader)
	restorables.register("read_tracker", read_tracker)
	restorables.register("backlog", backlog)


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
		object_manager.bind_object("cg", _game_vc.get_fg())
	if _game_vc.get_overlay():
		object_manager.bind_object("transition_overlay", _game_vc.get_overlay())
	if _game_vc.get_dbox():
		object_manager.bind_object("default_box", _game_vc.get_dbox())
	if _game_vc.get_avatar_rect():
		object_manager.bind_object("avatar", _game_vc.get_avatar_rect())
	object_manager.bind_object("anim", animation)
	object_manager.set_constant("resource_root", resource_root)
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
		EngineLogScript.error(EngineLogScript.Category.RUNTIME, "NovaController", "no start node found")
		return
	view_manager.switch_to("game")
	if _game_vc:
		_game_vc.enter_game(first_node)


func _on_title_continue() -> void:
	if save_system and save_system.has_auto_save():
		if _game_vc:
			_game_vc.reset_world()
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
	if _game_vc:
		_game_vc.reset_world()
	view_manager.switch_to("game")
	if _game_vc:
		_game_vc.load_game()


func _on_quit() -> void:
	if read_tracker:
		read_tracker.save_to_disk()
	get_tree().quit()


func _setup_gallery() -> void:
	if gallery_coordinator == null:
		return
	gallery_coordinator.setup(_cg_vc, _music_vc, cg_gallery_config, music_gallery_config)
	gallery_coordinator.load_configs()


## Called by the scenario engine when a CG is displayed in-game.
func unlock_cg_by_path(tex_path: String) -> void:
	if gallery_coordinator:
		gallery_coordinator.unlock_cg_by_path(tex_path)


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

func _setup_settings() -> void:
	if settings_coordinator == null:
		return
	settings_coordinator.setup(_settings_vc, _game_vc, settings_path, Callable(self, "_apply_i18n"))

func _on_setting_changed(key: String, value: Variant) -> void:
	if settings_coordinator:
		settings_coordinator.apply_setting(key, value)


func _load_settings() -> void:
	if settings_coordinator:
		settings_coordinator.load_settings()


# ── I18n helper ─────────────────────────────────────────────────────

func _t(key: String, fallback: String = "") -> String:
	if i18n == null:
		return fallback
	return i18n.t(key, fallback)
