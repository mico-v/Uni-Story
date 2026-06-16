extends Node

## NovaController — slim coordinator.
## Creates subsystems, initializes ViewManager, and routes signals between
## view controllers.  All game UI logic lives in GameViewController.

const SCENARIO_FILES := [
	"res://resources/scenarios/plan_demo.txt",
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/demo_full.txt",
	"res://resources/scenarios/test_all.txt",
]

const REVIEW_REGRESSION_FILES := [
	"res://resources/scenarios/review_regression_branch.txt",
	"res://resources/scenarios/review_regression_branch_attr.txt",
	"res://resources/scenarios/review_regression_resume.txt",
]

const REVIEW_SANITY_FILES := [
	"res://resources/scenarios/review_regression_sanity.txt",
]

@export var include_review_scenarios := false
@export var include_review_sanity := false
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

# ── View management ─────────────────────────────────────────────────
var view_manager: ViewManager

# ── View controllers (private) ───────────────────────────────────────
var _title_vc: TitleViewController
var _chapter_vc: ChapterSelectViewController
var _game_vc: GameViewController
var _settings_vc: SettingsViewController
var _cg_vc: CgGalleryController
var _music_vc: MusicGalleryController
var _save_load_vc: SaveLoadController


# ── Ready ────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_subsystems()
	_setup_locale()

	var scenario_files := SCENARIO_FILES.duplicate()
	if include_review_scenarios:
		scenario_files.append_array(REVIEW_REGRESSION_FILES)
	if include_review_sanity:
		scenario_files.append_array(REVIEW_SANITY_FILES)

	_bind_view_controllers()
	_init_view_manager()
	_setup_game_view()
	_register_objects()
	_connect_model_signals()
	_apply_i18n()

	scenario_files = _localized_scenario_files(scenario_files)
	script_loader.load_all(scenario_files)
	if not script_loader.load_ok:
		push_error("NovaController: script load failed")
		return

	game_state.setup(script_loader.graph)
	_refresh_chapters()
	view_manager.switch_to("title")


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
	var chapter_node := get_node_or_null("ChapterSelectView")
	if chapter_node is ChapterSelectViewController:
		_chapter_vc = chapter_node as ChapterSelectViewController
	var game_node := get_node_or_null("GameView")
	if game_node is GameViewController:
		_game_vc = game_node as GameViewController
	var settings_node := get_node_or_null("SettingsView")
	if settings_node is SettingsViewController:
		_settings_vc = settings_node as SettingsViewController
	var cg_node := get_node_or_null("CgGalleryView")
	if cg_node is CgGalleryController:
		_cg_vc = cg_node as CgGalleryController
	var music_node := get_node_or_null("MusicGalleryView")
	if music_node is MusicGalleryController:
		_music_vc = music_node as MusicGalleryController
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
	if _chapter_vc:
		view_manager.register("chapter_select", _chapter_vc, T.SLIDE_LEFT)
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


func _register_objects() -> void:
	# Objects already registered in _setup_game_view().
	pass


func _connect_model_signals() -> void:
	if _game_vc == null:
		return
	game_state.dialogue_changed.connect(_game_vc.on_dialogue_changed)
	game_state.branch_requested.connect(_game_vc.on_branch_requested)
	game_state.game_ended.connect(_game_vc.on_game_ended)
	avatar.avatar_changed.connect(_game_vc.on_avatar_changed)
	# GameVC → NovaController routing.
	_game_vc.title_requested.connect(_on_game_title_requested)
	# TitleVC → navigation.
	if _title_vc:
		_title_vc.new_game_requested.connect(_on_title_new_game)
		_title_vc.load_requested.connect(_on_title_load)
		_title_vc.settings_requested.connect(func() -> void: view_manager.switch_to("settings"))
		_title_vc.gallery_requested.connect(func() -> void: view_manager.switch_to("cg_gallery"))
		_title_vc.music_requested.connect(func() -> void: view_manager.switch_to("music_gallery"))
		_title_vc.quit_requested.connect(_on_quit)
	# ChapterVC → navigation.
	if _chapter_vc:
		if not _chapter_vc.chapter_selected.is_connected(_on_chapter_selected):
			_chapter_vc.chapter_selected.connect(_on_chapter_selected)
		if not _chapter_vc.back_requested.is_connected(_on_chapter_back):
			_chapter_vc.back_requested.connect(_on_chapter_back)
	# SettingsVC → back.
	if _settings_vc:
		_settings_vc.back_requested.connect(func() -> void: view_manager.switch_to("title"))
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
	if _chapter_vc:
		_chapter_vc.set_title(_t("title.first.selectchapter", "章节选择"))
		_chapter_vc.set_back_text(_t("title.selectchapter.return", "返回"))
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
	_refresh_chapters()
	view_manager.switch_to("chapter_select")


func _on_title_load() -> void:
	if _save_load_vc:
		_save_load_vc.show_in_mode(false)
	view_manager.switch_to("save_load")


func _on_chapter_selected(node_name: StringName) -> void:
	view_manager.switch_to("game")
	if _game_vc:
		_game_vc.enter_game(node_name)


func _on_chapter_back() -> void:
	view_manager.switch_to("title")


func _on_game_title_requested() -> void:
	if _game_vc:
		_game_vc.reset_world()
	view_manager.switch_to("title")
	_refresh_chapters()


func _on_save_load_completed() -> void:
	view_manager.switch_to("game")
	if _game_vc:
		_game_vc.load_game()


func _on_quit() -> void:
	if read_tracker:
		read_tracker.save_to_disk()
	get_tree().quit()


# ── Chapter refresh ─────────────────────────────────────────────────

func _refresh_chapters() -> void:
	if _chapter_vc == null:
		return
	_chapter_vc.clear()
	var entries: Array = []
	for node_name in script_loader.graph.unlocked_start_nodes:
		var node = script_loader.graph.get_node_named(node_name)
		if node == null:
			continue
		entries.append({"name": node_name, "text": str(node.display_name)})
	_chapter_vc.set_chapters(entries, _t("ui.chapter.empty", "（无可用章节）"))


# ── Settings handler ────────────────────────────────────────────────

func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"text_speed":
			pass  # Future: adjust GameViewController.TYPE_CPS
		"auto_speed":
			pass  # Future: adjust GameViewController.AUTO_DELAY
		"vol_global", "vol_bgm", "vol_se", "vol_voice":
			pass  # Future: adjust AudioSystem volumes
		"language":
			if str(value) != i18n.locale:
				i18n.locale = str(value)
				_apply_i18n()
		"fullscreen":
			if bool(value):
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


# ── I18n helper ─────────────────────────────────────────────────────

func _t(key: String, fallback: String = "") -> String:
	if i18n == null:
		return fallback
	return i18n.t(key, fallback)
