extends Node

## NovaController — scene-composed view host.
## All presentation nodes are now defined in scene files.

const SCENARIO_FILES := [
	"res://resources/scenarios/plan_demo.txt",
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/test_animation.txt",
	"res://resources/scenarios/test_runtime.txt",
	"res://resources/scenarios/test_char.txt",
	"res://resources/scenarios/test_var.txt",
	"res://resources/scenarios/demo_full.txt",
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

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

# Subsystems (public so BaseBlock / scripts can reach them as nova.<name>).
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

# Scene structure nodes.
var _title_view: Control
var _chapter_view: Control
var _game_view: Control

# Dedicated view controllers for event dispatch (task8 step1).
var _chapter_view_controller: ChapterSelectViewController
var _choice_list_controller: ChoiceListController

# World layer.
var _world: Node2D
var _bg: Sprite2D
var _fg: Sprite2D

# Hud/UI.
var _hud: Control
var _status_label: Label
var _menu: VBoxContainer
var _title_label: Label
var _chapter_list: VBoxContainer
var _start_btn: Button
var _dbox: Panel
var _speaker_label: Label
var _story_label: RichTextLabel
var _choice_list: VBoxContainer
var _controls: HBoxContainer
var _next_btn: Button
var _restart_btn: Button
var _quit_btn: Button
var _save_btn: Button
var _load_btn: Button
var _backlog_btn: Button
var _overlay: ColorRect
var _continue_icon: Label
var _avatar_rect: TextureRect

# Save/load panel.
var _save_panel: Panel
var _save_panel_title: Label
var _save_slots: VBoxContainer
var _save_mode := true  # true = saving, false = loading

# Backlog (text review) panel.
var _backlog_panel: Panel
var _backlog_list: VBoxContainer
var _backlog_scroll: ScrollContainer

# Navigation/back buttons.
var _chapter_back_btn: Button
var _save_close_btn: Button
var _backlog_close_btn: Button

# Typewriter state.
const TYPE_CPS := 30.0
var _type_tween: Tween = null
var _is_typing := false


func _ready() -> void:
	_init_subsystems()
	_setup_locale()

	var scenario_files := SCENARIO_FILES.duplicate()
	if include_review_scenarios:
		scenario_files.append_array(REVIEW_REGRESSION_FILES)
	if include_review_sanity:
		scenario_files.append_array(REVIEW_SANITY_FILES)

	if not _bind_nodes():
		return

	_apply_ui_defaults()
	_apply_localized_texts()
	_connect_view_signals()
	_register_objects()
	_connect_model_signals()

	scenario_files = _localized_scenario_files(scenario_files)
	script_loader.load_all(scenario_files)
	if not script_loader.load_ok:
		push_error("NovaController: script load failed, enter safe state")
		if _title_view:
			_title_view.visible = false
		if _chapter_view:
			_chapter_view.visible = false
		if _game_view:
			_game_view.visible = false
		if _status_label:
			_status_label.text = _t("ui.status.load_failed", "状态：脚本加载失败")
		return

	game_state.setup(script_loader.graph)

	_show_title()


func _bind_nodes() -> bool:
	var ok := true

	_title_view = get_node_or_null("TitleView") as Control
	_chapter_view = get_node_or_null("ChapterSelectView") as Control
	_game_view = get_node_or_null("GameView") as Control
	if _title_view == null:
		push_error("NovaController: missing TitleView")
		ok = false
	if _chapter_view == null:
		push_error("NovaController: missing ChapterSelectView")
		ok = false
	if _game_view == null:
		push_error("NovaController: missing GameView")
		ok = false

	if _title_view:
		_menu = _title_view.get_node_or_null("Menu") as VBoxContainer
		_title_label = _title_view.get_node_or_null("Menu/Title") as Label
		_start_btn = _title_view.get_node_or_null("Menu/Start") as Button
	if _menu == null or _title_label == null or _start_btn == null:
		push_error("NovaController: TitleView requires Menu, Menu/Title, Menu/Start")
		ok = false

	if _chapter_view:
		if _chapter_view is ChapterSelectViewController:
			_chapter_view_controller = _chapter_view as ChapterSelectViewController
		else:
			_chapter_list = _chapter_view.get_node_or_null("VBox/ChapterList") as VBoxContainer
			_chapter_back_btn = _chapter_view.get_node_or_null("VBox/Back") as Button
	if _chapter_view_controller == null and _chapter_list == null:
		push_error("NovaController: ChapterSelectView requires VBox/ChapterList")
		ok = false

	if _game_view:
		_world = _game_view.get_node_or_null("World") as Node2D
		_bg = _game_view.get_node_or_null("World/Background") as Sprite2D
		_fg = _game_view.get_node_or_null("World/Foreground") as Sprite2D
		_hud = _game_view.get_node_or_null("Hud") as Control
		_status_label = _hud.get_node_or_null("Status") as Label
		_dbox = _hud.get_node_or_null("DialogueBox") as Panel
		_speaker_label = _hud.get_node_or_null("DialogueBox/Speaker") as Label
		_story_label = _hud.get_node_or_null("DialogueBox/Story") as RichTextLabel
		_continue_icon = _hud.get_node_or_null("DialogueBox/ContinueIcon") as Label
		_avatar_rect = _hud.get_node_or_null("DialogueBox/Avatar") as TextureRect
		_choice_list = _hud.get_node_or_null("ChoiceList") as VBoxContainer
		if _choice_list != null:
			_choice_list_controller = _choice_list as ChoiceListController
		_controls = _hud.get_node_or_null("Controls") as HBoxContainer
		_next_btn = _hud.get_node_or_null("Controls/Next") as Button
		_restart_btn = _hud.get_node_or_null("Controls/Restart") as Button
		_save_btn = _hud.get_node_or_null("Controls/Save") as Button
		_load_btn = _hud.get_node_or_null("Controls/Load") as Button
		_backlog_btn = _hud.get_node_or_null("Controls/Backlog") as Button
		_quit_btn = _hud.get_node_or_null("Controls/Quit") as Button
		_overlay = _hud.get_node_or_null("TransitionOverlay") as ColorRect
		_save_panel = _hud.get_node_or_null("SavePanel") as Panel
		_save_panel_title = _hud.get_node_or_null("SavePanel/SavePanelContainer/Title") as Label
		_save_slots = _hud.get_node_or_null("SavePanel/SavePanelContainer/Slots") as VBoxContainer
		_save_close_btn = _hud.get_node_or_null("SavePanel/SavePanelContainer/CloseButton") as Button
		_backlog_panel = _hud.get_node_or_null("BacklogPanel") as Panel
		_backlog_list = _hud.get_node_or_null("BacklogPanel/BacklogPanelContainer/BacklogScroll/BacklogList") as VBoxContainer
		_backlog_scroll = _hud.get_node_or_null("BacklogPanel/BacklogPanelContainer/BacklogScroll") as ScrollContainer
		_backlog_close_btn = _hud.get_node_or_null("BacklogPanel/BacklogPanelContainer/CloseButton") as Button

	if _world == null or _bg == null or _fg == null or _hud == null or _status_label == null or _dbox == null or _speaker_label == null or _story_label == null or _choice_list == null or _controls == null or _next_btn == null or _restart_btn == null or _save_btn == null or _load_btn == null or _backlog_btn == null or _quit_btn == null or _overlay == null or _continue_icon == null or _avatar_rect == null or _save_panel == null or _save_panel_title == null or _save_slots == null or _save_close_btn == null or _backlog_panel == null or _backlog_list == null or _backlog_scroll == null or _backlog_close_btn == null:
		push_error("NovaController: GameView is missing required hud nodes")
		ok = false

	if not ok:
		return false

	_bg.set_meta("folder", "")
	_title_view.visible = false
	_chapter_view.visible = false
	_game_view.visible = false
	_save_panel.visible = false
	_backlog_panel.visible = false
	_choice_list.visible = false
	_dbox.visible = false
	_overlay.visible = false
	_next_btn.visible = false
	_restart_btn.visible = false
	_save_btn.visible = false
	_backlog_btn.visible = false
	_backlog_scroll.mouse_filter = Control.MOUSE_FILTER_STOP

	return true


func _apply_ui_defaults() -> void:
	_status_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_font_size_override("font_size", 40)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 12)
	if _chapter_list:
		_chapter_list.alignment = BoxContainer.ALIGNMENT_CENTER
		_chapter_list.add_theme_constant_override("separation", 8)
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_speaker_label.position = Vector2(24, 10)
	_story_label.add_theme_font_size_override("normal_font_size", 26)
	_story_label.bbcode_enabled = true
	_choice_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_list.add_theme_constant_override("separation", 10)
	_controls.add_theme_constant_override("separation", 10)
	_story_label.visible_ratio = 0.0
	_save_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_save_panel_title.add_theme_font_size_override("font_size", 26)
	_save_slots.add_theme_constant_override("separation", 6)
	_backlog_list.add_theme_constant_override("separation", 10)
	if _backlog_panel.get_node_or_null("BacklogPanelContainer/Title"):
		(_backlog_panel.get_node("BacklogPanelContainer/Title") as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(_backlog_panel.get_node("BacklogPanelContainer/Title") as Label).add_theme_font_size_override("font_size", 26)
	if _chapter_view_controller:
		_chapter_view_controller.clear()

func _connect_view_signals() -> void:
	if _chapter_view_controller:
		if not _chapter_view_controller.chapter_selected.is_connected(_on_chapter_selected):
			_chapter_view_controller.chapter_selected.connect(_on_chapter_selected)
		if not _chapter_view_controller.back_requested.is_connected(_show_title):
			_chapter_view_controller.back_requested.connect(_show_title)
	else:
		if _chapter_back_btn:
			_chapter_back_btn.pressed.connect(_show_title)

	_start_btn.pressed.connect(_show_chapter_select)
	_next_btn.pressed.connect(_on_next)
	_restart_btn.pressed.connect(_show_title)
	_save_btn.pressed.connect(func(): _open_save_panel(true))
	_load_btn.pressed.connect(func(): _open_save_panel(false))
	_backlog_btn.pressed.connect(_open_backlog)
	_quit_btn.pressed.connect(func(): get_tree().quit())
	_save_close_btn.pressed.connect(_close_save_panel)
	_backlog_close_btn.pressed.connect(func(): _backlog_panel.visible = false)
	if _choice_list_controller:
		if not _choice_list_controller.choice_chosen.is_connected(_on_choice):
			_choice_list_controller.choice_chosen.connect(_on_choice)


func _make_button(text: String) -> Button:
	var b := ButtonRingScene.instantiate() as Button
	if b == null:
		b = Button.new()
	b.text = text
	return b


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


func _register_objects() -> void:
	object_manager.set_constant("resource_root", RESOURCE_ROOT)
	object_manager.bind_object("world", _world)
	object_manager.bind_object("bg", _bg)
	object_manager.bind_object("fg", _fg)
	object_manager.bind_object("anim", animation)
	object_manager.bind_object("transition_overlay", _overlay)
	object_manager.bind_object("default_box", _dbox)
	object_manager.bind_object("avatar", _avatar_rect)
	object_manager.freeze_constants()
	object_manager.freeze_objects()


func _connect_model_signals() -> void:
	game_state.dialogue_changed.connect(_on_dialogue_changed)
	game_state.branch_requested.connect(_on_branch_requested)
	game_state.game_ended.connect(_on_game_ended)
	avatar.avatar_changed.connect(_on_avatar_changed)


func _show_title() -> void:
	_kill_typewriter()
	_title_view.visible = true
	_chapter_view.visible = false
	_game_view.visible = false
	_continue_icon.visible = false
	_status_label.text = _t("ui.status.ready", "状态：选择章节开始")
	_speaker_label.text = ""
	_story_label.text = ""
	_bg.visible = false
	_fg.visible = false
	_world.position = Vector2.ZERO
	_world.scale = Vector2.ONE
	_world.rotation_degrees = 0.0
	_dbox.visible = false
	_choice_list.visible = false
	_clear_children(_choice_list)
	_save_panel.visible = false
	_backlog_panel.visible = false
	_next_btn.visible = false
	_restart_btn.visible = false
	_save_btn.visible = false
	_backlog_btn.visible = false
	_start_btn.visible = true
	_refresh_chapters()


func _show_chapter_select() -> void:
	_title_view.visible = false
	_chapter_view.visible = true
	_game_view.visible = false
	_refresh_chapters()


func _refresh_chapters() -> void:
	if _chapter_view_controller == null and _chapter_list == null:
		return

	var entries: Array = []

	if _chapter_view_controller:
		_chapter_view_controller.clear()
	else:
		_clear_children(_chapter_list)

	for node_name in script_loader.graph.unlocked_start_nodes:
		var node = script_loader.graph.get_node_named(node_name)
		if node == null:
			continue
		var display_name := str(node.display_name)
		if _chapter_view_controller:
			entries.append({"name": node_name, "text": display_name})
		else:
			var b := _make_button(display_name)
			b.pressed.connect(_on_chapter_selected.bind(node_name))
			_chapter_list.add_child(b)

	if _chapter_view_controller:
		_chapter_view_controller.set_chapters(entries, _t("ui.chapter.empty", "（无可用章节）"))
		return
	if _chapter_list.get_child_count() == 0:
		var lbl := _make_button(_t("ui.chapter.empty", "（无可用章节）"))
		lbl.disabled = true
		_chapter_list.add_child(lbl)


func _on_chapter_selected(node_name: StringName) -> void:
	_title_view.visible = false
	_chapter_view.visible = false
	_game_view.visible = true
	_dbox.visible = true
	_next_btn.visible = true
	_restart_btn.visible = false
	_save_btn.visible = true
	_backlog_btn.visible = true
	_status_label.text = _t("ui.status.playing", "状态：对话中")
	variables.clear()
	backlog.clear()
	game_state.start_node(node_name)


func _on_dialogue_changed(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_dbox.visible = true
	_next_btn.visible = true
	_choice_list.visible = false
	backlog.record(speaker, text)
	_start_typewriter(text)


func _start_typewriter(text: String) -> void:
	_kill_typewriter()
	_story_label.text = text
	_continue_icon.visible = false
	var n := text.length()
	if n <= 0:
		_finish_typewriter()
		return
	_story_label.visible_ratio = 0.0
	_is_typing = true
	var duration := float(n) / TYPE_CPS
	_type_tween = create_tween()
	_type_tween.tween_method(_set_reveal, 0.0, 1.0, duration)
	_type_tween.finished.connect(_on_typewriter_done)


func _set_reveal(ratio: float) -> void:
	_story_label.visible_ratio = ratio


func _on_typewriter_done() -> void:
	_is_typing = false
	_story_label.visible_ratio = 1.0
	_continue_icon.visible = true


func _on_avatar_changed(shown: bool) -> void:
	var left := 124.0 if shown else 24.0
	_speaker_label.position.x = left
	_story_label.offset_left = left


func _kill_typewriter() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null
	_is_typing = false


func _finish_typewriter() -> void:
	_kill_typewriter()
	_story_label.visible_ratio = 1.0
	_continue_icon.visible = true


func _on_next() -> void:
	if _is_typing:
		_finish_typewriter()
		return
	if game_state.is_waiting_input:
		game_state.continue_after_input()
	else:
		game_state.advance()


func _on_branch_requested(options: Array) -> void:
	_finish_typewriter()
	_continue_icon.visible = false
	_next_btn.visible = false
	if _choice_list_controller:
		_choice_list.visible = true
		_choice_list_controller.set_choices(options)
	else:
		_choice_list.visible = true
		_clear_children(_choice_list)
		for opt in options:
			var enabled := bool(opt.get("enabled", true))
			var b := _make_button(str(opt["text"]))
			b.disabled = not enabled
			b.pressed.connect(_on_choice.bind(opt["dest"]))
			_choice_list.add_child(b)


func _on_choice(dest: StringName) -> void:
	_choice_list.visible = false
	if _choice_list_controller:
		_choice_list_controller.clear()
	else:
		_clear_children(_choice_list)
	_next_btn.visible = true
	game_state.choose_branch(dest)


func _on_game_ended() -> void:
	_finish_typewriter()
	_continue_icon.visible = false
	_status_label.text = _t("ui.status.ended", "状态：章节结束")
	_next_btn.visible = false
	_restart_btn.visible = true


func _open_backlog() -> void:
	var backlog_title := _backlog_panel_title()
	if backlog_title:
		backlog_title.text = _t("ui.label.backlog", "文本回顾")
	_clear_children(_backlog_list)
	for entry in backlog.entries():
		var lbl := RichTextLabel.new()
		lbl.bbcode_enabled = true
		lbl.fit_content = true
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(0, 0)
		var speaker := str(entry["speaker"])
		var text := str(entry["text"])
		if speaker.is_empty():
			lbl.text = text
		else:
			lbl.text = "[b]%s[/b]：%s" % [speaker, text]
		_backlog_list.add_child(lbl)
	_backlog_panel.visible = true
	await get_tree().process_frame
	_backlog_scroll.scroll_vertical = int(_backlog_scroll.get_v_scroll_bar().max_value)


func _open_save_panel(save_mode: bool) -> void:
	_save_mode = save_mode
	_save_panel_title.text = _t("ingame.save.button", "存档") if save_mode else _t("ingame.load.button", "读档")
	_clear_children(_save_slots)
	for slot in SaveSystem.SLOT_COUNT:
		var label := _t("ui.save.slot_format", "存档位 %d：%s") % [slot + 1, save_system.slot_label(slot)]
		var b := _make_button(label)
		b.custom_minimum_size = Vector2(360, 40)
		if not save_mode and not save_system.has_save(slot):
			b.disabled = true
		b.pressed.connect(_on_slot_pressed.bind(slot))
		_save_slots.add_child(b)
	_save_panel.visible = true


func _close_save_panel() -> void:
	_save_panel.visible = false


func _on_slot_pressed(slot: int) -> void:
	if _save_mode:
		if save_system.save(slot):
			_status_label.text = _t("ui.status.saved", "状态：已存档到位 %d") % (slot + 1)
		_close_save_panel()
	else:
		_close_save_panel()
		if save_system.load_slot(slot):
			_title_view.visible = false
			_chapter_view.visible = false
			_game_view.visible = true
			_dbox.visible = true
			_next_btn.visible = true
			_restart_btn.visible = false
			_save_btn.visible = true
			_backlog_btn.visible = true
			_status_label.text = _t("ui.status.loaded", "状态：已读档")


func _localized_scenario_files(paths: Array) -> Array:
	var out: Array = []
	for path in paths:
		var src := str(path)
		if src.is_empty():
			continue
		out.append(i18n.load_scenario(i18n.locale, src))
	return out


func _setup_locale() -> void:
	var os_locale := ""
	if OS.has_method("get_locale"):
		os_locale = str(OS.get_locale())
		i18n.setup(["zh", "en"], "res://resources/localized_resources/localized_strings", os_locale, "en")
	else:
		i18n.setup(["zh", "en"], "res://resources/localized_resources/localized_strings", "en", "en")


func _apply_localized_texts() -> void:
	if _title_label:
		_title_label.text = _t("title.subtitle", "Nova2")
	if _start_btn:
		_start_btn.text = _t("title.menu.start", "开始")
	if _chapter_view_controller:
		_chapter_view_controller.set_title(_t("title.first.selectchapter", "章节选择"))
		_chapter_view_controller.set_back_text(_t("title.selectchapter.return", "返回"))

	if _next_btn:
		_next_btn.text = _t("ui.button.next", "下一句")
	if _restart_btn:
		_restart_btn.text = _t("ui.button.restart", "重开")
	if _save_btn:
		_save_btn.text = _t("ingame.save.button", "存档")
	if _load_btn:
		_load_btn.text = _t("ingame.load.button", "读档")
	if _backlog_btn:
		_backlog_btn.text = _t("ingame.log.button", "回顾")
	if _quit_btn:
		_quit_btn.text = _t("config.quitgame", "退出")
	if _chapter_back_btn:
		_chapter_back_btn.text = _t("title.selectchapter.return", "返回")
	if _save_panel_title:
		_save_panel_title.text = _t("ingame.save.button", "存档")
	if _save_close_btn:
		_save_close_btn.text = _t("help.close", "关闭")
	if _backlog_close_btn:
		_backlog_close_btn.text = _t("help.close", "关闭")
	if _status_label:
		# Keep default runtime statuses empty until state transitions.
		pass


func _t(key: String, fallback: String = "") -> String:
	if i18n == null:
		return fallback
	return i18n.t(key, fallback)


func _backlog_panel_title() -> Label:
	if not _backlog_panel:
		return null
	var node := _backlog_panel.get_node_or_null("BacklogPanelContainer/Title")
	if node is Label:
		return node
	return null


func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
