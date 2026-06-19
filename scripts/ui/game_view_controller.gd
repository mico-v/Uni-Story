class_name GameViewController extends Control

## GameViewController — owns all gameplay UI logic that was previously inside
## NovaController: typewriter, dialogue display, choices, auto/skip modes,
## save/load panel, backlog panel, and HUD state management.
##
## Attached to the GameView root node in game_view.tscn.
## Receives a reference to NovaController (_ctx) for subsystem access.

signal title_requested()
signal settings_requested()

const ButtonRingScene: PackedScene = preload("res://scene/ui/button_ring.tscn")

# ── Context ──────────────────────────────────────────────────────────
var _ctx: Node  # NovaController

# ── World layer ──────────────────────────────────────────────────────
var _world: Node2D
var _bg: Sprite2D
var _fg: Sprite2D

# ── HUD nodes ────────────────────────────────────────────────────────
var _hud: Control
var _status_label: Label
var _dbox: Panel
var _speaker_label: Label
var _story_label: RichTextLabel
var _choice_list: VBoxContainer
var _choice_list_controller: ChoiceListController
var _controls: HBoxContainer
var _restart_btn: Button
var _quit_btn: Button
var _save_btn: Button
var _load_btn: Button
var _backlog_btn: Button
var _auto_btn: Button
var _skip_btn: Button
var _overlay: ColorRect
var _post_fx_rect: ColorRect
var _continue_icon: Label
var _avatar_rect: TextureRect

# ── Save/load panel ──────────────────────────────────────────────────
var _save_panel: Panel
var _save_panel_title: Label
var _save_slots: VBoxContainer
var _save_close_btn: Button
var _save_mode := true

# ── Backlog panel ────────────────────────────────────────────────────
var _backlog_panel: Panel
var _backlog_list: VBoxContainer
var _backlog_scroll: ScrollContainer
var _backlog_close_btn: Button

# ── Mouse menu (right-click context menu) ────────────────────────────
var _mouse_menu: PanelContainer
var _mouse_menu_items: VBoxContainer

# ── Typewriter state ─────────────────────────────────────────────────
var type_cps := 30.0
var _type_tween: Tween = null
var _is_typing := false

# ── Auto/Skip mode state ─────────────────────────────────────────────
var auto_delay := 2.0
const SKIP_DELAY := 0.05
var _is_auto := false
var _is_skip := false
var _auto_gen := 0
var _skip_gen := 0


# ── Lifecycle ────────────────────────────────────────────────────────

func setup(ctx: Node) -> void:
	_ctx = ctx
	_bind_nodes()
	_apply_ui_defaults()
	_connect_signals()
	_create_mouse_menu()


func _bind_nodes() -> void:
	_world = get_node_or_null("World") as Node2D
	_bg = get_node_or_null("World/Background") as Sprite2D
	_fg = get_node_or_null("World/Foreground") as Sprite2D
	_hud = get_node_or_null("Hud") as Control
	if _hud:
		_status_label = _hud.get_node_or_null("Status") as Label
		_dbox = _hud.get_node_or_null("DialogueBox") as Panel
		_speaker_label = _hud.get_node_or_null("DialogueBox/Speaker") as Label
		_story_label = _hud.get_node_or_null("DialogueBox/Story") as RichTextLabel
		_continue_icon = _hud.get_node_or_null("DialogueBox/ContinueIcon") as Label
		_avatar_rect = _hud.get_node_or_null("DialogueBox/Avatar") as TextureRect
		_choice_list = _hud.get_node_or_null("ChoiceList") as VBoxContainer
		if _choice_list is ChoiceListController:
			_choice_list_controller = _choice_list as ChoiceListController
		_controls = _hud.get_node_or_null("Controls") as HBoxContainer
		_restart_btn = _hud.get_node_or_null("Controls/Restart") as Button
		_save_btn = _hud.get_node_or_null("Controls/Save") as Button
		_load_btn = _hud.get_node_or_null("Controls/Load") as Button
		_backlog_btn = _hud.get_node_or_null("Controls/Backlog") as Button
		_auto_btn = _hud.get_node_or_null("Controls/Auto") as Button
		_skip_btn = _hud.get_node_or_null("Controls/Skip") as Button
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
	_post_fx_rect = get_node_or_null("PostFXRect") as ColorRect

	# Initial visibility.
	visible = false
	if _save_panel:
		_save_panel.visible = false
	if _backlog_panel:
		_backlog_panel.visible = false
	if _choice_list:
		_choice_list.visible = false
	if _dbox:
		_dbox.visible = false
	if _overlay:
		_overlay.visible = false
	if _dbox:
		_dbox.gui_input.connect(_on_dbox_click)
	# Let clicks on dbox children pass through to the Panel (which has gui_input signal).
	# Without this, children's default MOUSE_FILTER_STOP swallows events and
	# _on_dbox_click never fires — the root cause of "click sometimes doesn't work".
	for child in [_speaker_label, _story_label, _continue_icon, _avatar_rect]:
		if child is Control:
			child.mouse_filter = MOUSE_FILTER_IGNORE
	if _restart_btn:
		_restart_btn.visible = false
	if _save_btn:
		_save_btn.visible = false
	if _backlog_btn:
		_backlog_btn.visible = false
	if _backlog_scroll:
		_backlog_scroll.mouse_filter = Control.MOUSE_FILTER_STOP


func _apply_ui_defaults() -> void:
	if _status_label:
		_status_label.add_theme_font_size_override("font_size", 18)
	if _speaker_label:
		_speaker_label.add_theme_font_size_override("font_size", 22)
		_speaker_label.position = Vector2(24, 10)
	if _story_label:
		_story_label.add_theme_font_size_override("normal_font_size", 26)
		_story_label.bbcode_enabled = true
		_story_label.visible_ratio = 0.0
	if _choice_list:
		_choice_list.alignment = BoxContainer.ALIGNMENT_CENTER
		_choice_list.add_theme_constant_override("separation", 10)
	if _controls:
		_controls.add_theme_constant_override("separation", 10)
	if _save_panel_title:
		_save_panel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_save_panel_title.add_theme_font_size_override("font_size", 26)
	if _save_slots:
		_save_slots.add_theme_constant_override("separation", 6)
	if _backlog_list:
		_backlog_list.add_theme_constant_override("separation", 10)
	if _backlog_panel:
		var bt := _backlog_panel.get_node_or_null("BacklogPanelContainer/Title")
		if bt is Label:
			bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bt.add_theme_font_size_override("font_size", 26)


func _connect_signals() -> void:
	if _restart_btn:
		_restart_btn.pressed.connect(func() -> void: title_requested.emit())
	if _save_btn:
		_save_btn.pressed.connect(func() -> void: _open_save_panel(true))
	if _load_btn:
		_load_btn.pressed.connect(func() -> void: _open_save_panel(false))
	if _backlog_btn:
		_backlog_btn.pressed.connect(_open_backlog)
	if _auto_btn:
		_auto_btn.pressed.connect(_on_auto_toggled)
	if _skip_btn:
		_skip_btn.pressed.connect(_on_skip_toggled)
	if _quit_btn:
		_quit_btn.pressed.connect(_request_quit)
	if _save_close_btn:
		_save_close_btn.pressed.connect(_close_save_panel)
	if _backlog_close_btn:
		_backlog_close_btn.pressed.connect(func() -> void:
			_backlog_panel.visible = false
		)
	if _choice_list_controller:
		if not _choice_list_controller.choice_chosen.is_connected(_on_choice):
			_choice_list_controller.choice_chosen.connect(_on_choice)


# ── Keyboard shortcuts ───────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.is_echo():
		return
	if _ctx == null or _ctx.shortcut_manager == null:
		return
	var sm: ShortcutManager = _ctx.shortcut_manager
	var panels_open := _is_save_panel_visible() or _is_backlog_panel_visible()
	# Step forward works even with panels open (closes them first).
	if sm.is_action_pressed("ui_step_forward"):
		if panels_open:
			_close_save_panel()
			if _backlog_panel:
				_backlog_panel.visible = false
		_on_next()
		get_viewport().set_input_as_handled()
		return
	# Block other shortcuts when panels are open.
	if panels_open:
		if sm.is_action_pressed("ui_leave"):
			_close_save_panel()
			if _backlog_panel:
				_backlog_panel.visible = false
			get_viewport().set_input_as_handled()
		return
	if sm.is_action_pressed("ui_auto"):
		if _auto_btn:
			_auto_btn.button_pressed = not _auto_btn.button_pressed
		_on_auto_toggled()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_skip"):
		if _skip_btn:
			_skip_btn.button_pressed = not _skip_btn.button_pressed
		_on_skip_toggled()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_save"):
		_open_save_panel(true)
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_load"):
		_open_save_panel(false)
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_quick_save"):
		_quick_save()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_quick_load"):
		_quick_load()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_backlog"):
		_open_backlog()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_toggle_dbox"):
		_toggle_dbox()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_fullscreen"):
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_settings"):
		_close_save_panel()
		if _backlog_panel:
			_backlog_panel.visible = false
		get_viewport().set_input_as_handled()
	elif sm.is_action_pressed("ui_leave"):
		if _ctx.dialog_system:
			_deactivate_modes()
			_ctx.dialog_system.show_confirm(
				_t("ingame.title.button", "标题"),
				_t("ingame.title.confirm", "要返回标题界面吗？")
			).connect(func(_confirmed: bool) -> void:
				if _confirmed:
					title_requested.emit()
			, CONNECT_ONE_SHOT)
		else:
			title_requested.emit()
		get_viewport().set_input_as_handled()
	# Debug-only shortcuts.
	if OS.is_debug_build():
		if sm.is_action_pressed("debug_reload"):
			_on_hot_reload()
			get_viewport().set_input_as_handled()


# ── Public API ───────────────────────────────────────────────────────

func enter_game(node_name: StringName) -> void:
	reset_world()
	if _ctx.dialogue_box:
		_ctx.dialogue_box.set_box("bottom")
	if _dbox:
		_dbox.visible = true
	if _restart_btn:
		_restart_btn.visible = false
	if _save_btn:
		_save_btn.visible = true
	if _backlog_btn:
		_backlog_btn.visible = true
	if _status_label:
		_status_label.text = _t("ui.status.playing", "状态：对话中")
	if _ctx.variables:
		_ctx.variables.clear()
	if _ctx.backlog:
		_ctx.backlog.clear()
	if _ctx.game_state:
		_ctx.game_state.start_node(node_name)


func load_game() -> void:
	reset_world()
	if _dbox:
		_dbox.visible = true
	if _restart_btn:
		_restart_btn.visible = false
	if _save_btn:
		_save_btn.visible = true
	if _backlog_btn:
		_backlog_btn.visible = true
	if _status_label:
		_status_label.text = _t("ui.status.loaded", "状态：已读档")


func reset_world() -> void:
	# Clean up runtime-loaded prefabs.
	if _ctx and _ctx.prefab_loader:
		_ctx.prefab_loader.destroy_all()
	# Stop any playing video.
	if _ctx and _ctx.video_system:
		_ctx.video_system.stop()
	_hide_mouse_menu()
	if _bg:
		_bg.visible = false
	if _fg:
		_fg.visible = false
	if _world:
		_world.visible = true
		_world.position = Vector2.ZERO
		_world.scale = Vector2.ONE
		_world.rotation_degrees = 0.0
	if _dbox:
		_dbox.visible = false
	if _choice_list:
		_choice_list.visible = false
		_clear_children(_choice_list)
	if _save_panel:
		_save_panel.visible = false
	if _backlog_panel:
		_backlog_panel.visible = false
	if _restart_btn:
		_restart_btn.visible = false
	if _save_btn:
		_save_btn.visible = false
	if _backlog_btn:
		_backlog_btn.visible = false
	# Reset transition overlay and post-fx.
	if _overlay:
		_overlay.visible = false
		var col := _overlay.color
		col.a = 0.0
		_overlay.color = col
	if _post_fx_rect:
		_post_fx_rect.visible = false
	_continue_icon_visible(false)
	_speaker_label_clear()
	_story_label_clear()
	_kill_typewriter()
	_deactivate_modes()


func get_world() -> Node2D:
	return _world


func get_hud() -> Control:
	return _hud


func get_bg() -> Sprite2D:
	return _bg


func get_fg() -> Sprite2D:
	return _fg


func get_overlay() -> ColorRect:
	return _overlay


func get_post_fx_rect() -> ColorRect:
	return _post_fx_rect


func get_dbox() -> Panel:
	return _dbox


func get_avatar_rect() -> TextureRect:
	return _avatar_rect


func apply_i18n() -> void:
	if _ctx == null or _ctx.i18n == null:
		return
	var i: I18n = _ctx.i18n
	if _restart_btn:
		_restart_btn.text = i.t("ui.button.restart", "重开")
	if _save_btn:
		_save_btn.text = i.t("ingame.save.button", "存档")
	if _load_btn:
		_load_btn.text = i.t("ingame.load.button", "读档")
	if _backlog_btn:
		_backlog_btn.text = i.t("ingame.log.button", "回顾")
	if _auto_btn:
		_auto_btn.text = i.t("ingame.auto.button", "自动")
	if _skip_btn:
		_skip_btn.text = i.t("ingame.fastforward.button", "快进")
	if _quit_btn:
		_quit_btn.text = i.t("config.quitgame", "退出")
	if _save_close_btn:
		_save_close_btn.text = i.t("help.close", "关闭")
	if _backlog_close_btn:
		_backlog_close_btn.text = i.t("help.close", "关闭")


# ── Model signal handlers (connected by NovaController) ─────────────

func on_dialogue_changed(speaker: String, text: String) -> void:
	if _speaker_label:
		_speaker_label.text = speaker
	if _dbox:
		_dbox.visible = true
	if _choice_list:
		_choice_list.visible = false
	if _ctx.backlog:
		_ctx.backlog.record(speaker, text)
	_start_typewriter(text)
	# Skip mode: fast-forward read entries, stop at unread.
	if _is_skip and _ctx.game_state and _ctx.game_state.current_node:
		if _ctx.read_tracker and _ctx.read_tracker.is_read(_ctx.game_state.current_node.name, _ctx.game_state.current_index):
			_finish_typewriter()
			var gen := _skip_gen
			get_tree().create_timer(SKIP_DELAY).timeout.connect(_on_skip_advance.bind(gen))
		else:
			_deactivate_modes()


func on_branch_requested(options: Array) -> void:
	_deactivate_modes()
	_finish_typewriter()
	_continue_icon_visible(false)
	if _choice_list_controller:
		if _choice_list:
			_choice_list.visible = true
		_choice_list_controller.set_choices(options)
	else:
		if _choice_list:
			_choice_list.visible = true
			_clear_children(_choice_list)
		for opt in options:
			var enabled := bool(opt.get("enabled", true))
			var b := _make_button(str(opt["text"]))
			b.disabled = not enabled
			b.pressed.connect(_on_choice.bind(opt["dest"]))
			if _choice_list:
				_choice_list.add_child(b)


func on_game_ended() -> void:
	_deactivate_modes()
	_finish_typewriter()
	_continue_icon_visible(false)
	# Reset transition overlay — trans("fade") may have left it opaque.
	if _overlay:
		_overlay.visible = false
		var col := _overlay.color
		col.a = 0.0
		_overlay.color = col
	if _status_label:
		_status_label.text = _t("ui.status.ended", "状态：章节结束")
	if _restart_btn:
		_restart_btn.visible = true


func on_avatar_changed(shown: bool) -> void:
	var left := 124.0 if shown else 24.0
	if _speaker_label:
		_speaker_label.position.x = left
	if _story_label:
		_story_label.offset_left = left


# ── Typewriter ───────────────────────────────────────────────────────

func _start_typewriter(text: String) -> void:
	_kill_typewriter()
	if _story_label == null:
		return
	_story_label.text = text
	_continue_icon_visible(false)
	var n := text.length()
	if n <= 0:
		_finish_typewriter()
		return
	_story_label.visible_ratio = 0.0
	_is_typing = true
	var duration := float(n) / type_cps
	_type_tween = create_tween()
	_type_tween.tween_method(_set_reveal, 0.0, 1.0, duration)
	_type_tween.finished.connect(_on_typewriter_done)


func _set_reveal(ratio: float) -> void:
	if _story_label:
		_story_label.visible_ratio = ratio


func _on_typewriter_done() -> void:
	_is_typing = false
	if _story_label:
		_story_label.visible_ratio = 1.0
	_continue_icon_visible(true)
	if _is_auto and _ctx.game_state and _ctx.game_state.is_waiting_input:
		var gen := _auto_gen
		get_tree().create_timer(auto_delay).timeout.connect(_on_auto_advance.bind(gen))


func _kill_typewriter() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null
	_is_typing = false


func _finish_typewriter() -> void:
	_kill_typewriter()
	if _story_label:
		_story_label.visible_ratio = 1.0
	_continue_icon_visible(true)


# ── Next / Choice ────────────────────────────────────────────────────

func _on_dbox_click(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.is_echo():
			_on_next()
			accept_event()


func _on_next() -> void:
	if _is_typing:
		_finish_typewriter()
		_deactivate_modes()
		return
	if _ctx.game_state and _ctx.game_state.is_waiting_input:
		_deactivate_modes()
		_ctx.game_state.continue_after_input()
	else:
		if _ctx.game_state:
			_ctx.game_state.advance()


func _on_choice(dest: StringName) -> void:
	if _choice_list:
		_choice_list.visible = false
	if _choice_list_controller:
		_choice_list_controller.clear()
	else:
		if _choice_list:
			_clear_children(_choice_list)
	if _ctx.game_state:
		_ctx.game_state.choose_branch(dest)


# ── Auto / Skip mode ────────────────────────────────────────────────

func _on_auto_toggled() -> void:
	_is_auto = _auto_btn.button_pressed
	if _is_auto:
		_is_skip = false
		if _skip_btn:
			_skip_btn.button_pressed = false
	if not _is_auto:
		_auto_gen += 1


func _on_skip_toggled() -> void:
	_is_skip = _skip_btn.button_pressed
	if _is_skip:
		_is_auto = false
		if _auto_btn:
			_auto_btn.button_pressed = false
		if _ctx.game_state and _ctx.game_state.is_waiting_input and _ctx.game_state.current_node and _ctx.read_tracker:
			if _ctx.read_tracker.is_read(_ctx.game_state.current_node.name, _ctx.game_state.current_index):
				_finish_typewriter()
				var gen := _skip_gen
				get_tree().create_timer(SKIP_DELAY).timeout.connect(_on_skip_advance.bind(gen))
			else:
				_deactivate_modes()
				return
	if not _is_skip:
		_skip_gen += 1


func _deactivate_modes() -> void:
	if _is_auto:
		_is_auto = false
		if _auto_btn:
			_auto_btn.button_pressed = false
		_auto_gen += 1
	if _is_skip:
		_is_skip = false
		if _skip_btn:
			_skip_btn.button_pressed = false
		_skip_gen += 1


@warning_ignore("unused_parameter")
func _on_auto_advance(gen: int) -> void:
	if gen != _auto_gen or not _is_auto:
		return
	if _ctx.game_state and _ctx.game_state.is_waiting_input:
		_ctx.game_state.continue_after_input()


@warning_ignore("unused_parameter")
func _on_skip_advance(gen: int) -> void:
	if gen != _skip_gen or not _is_skip:
		return
	if _ctx.game_state and _ctx.game_state.is_waiting_input:
		_ctx.game_state.continue_after_input()


# ── Backlog panel ────────────────────────────────────────────────────

func _open_backlog() -> void:
	_deactivate_modes()
	var backlog_title := _backlog_panel_title_node()
	if backlog_title:
		backlog_title.text = _t("ui.label.backlog", "文本回顾")
	_clear_children(_backlog_list)
	if _ctx.backlog:
		for entry in _ctx.backlog.entries():
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
	if _backlog_panel:
		_backlog_panel.visible = true
	await get_tree().process_frame
	if _backlog_scroll:
		_backlog_scroll.scroll_vertical = int(_backlog_scroll.get_v_scroll_bar().max_value)


# ── Save/load panel ──────────────────────────────────────────────────

func _open_save_panel(save_mode: bool) -> void:
	_deactivate_modes()
	_save_mode = save_mode
	if _save_panel_title:
		_save_panel_title.text = _t("ingame.save.button", "存档") if save_mode else _t("ingame.load.button", "读档")
	_clear_children(_save_slots)
	if _ctx.save_system == null:
		return
	for slot in _ctx.save_system.SLOT_COUNT:
		var label := _t("ui.save.slot_format", "存档位 %d：%s") % [slot + 1, _ctx.save_system.slot_label(slot)]
		var b := _make_button(label)
		b.custom_minimum_size = Vector2(360, 40)
		if not save_mode and not _ctx.save_system.has_save(slot):
			b.disabled = true
		b.pressed.connect(_on_slot_pressed.bind(slot))
		_save_slots.add_child(b)
	if _save_panel:
		_save_panel.visible = true


func _close_save_panel() -> void:
	if _save_panel:
		_save_panel.visible = false


func _on_slot_pressed(slot: int) -> void:
	if _ctx.save_system == null:
		return
	if _save_mode:
		if _ctx.save_system.save(slot):
			if _status_label:
				_status_label.text = _t("ui.status.saved", "状态：已存档到位 %d") % (slot + 1)
		_close_save_panel()
	else:
		_close_save_panel()
		if _ctx.save_system.load_slot(slot):
			load_game()


# ── Mouse menu (right-click context menu) ────────────────────────────

func _create_mouse_menu() -> void:
	_mouse_menu = PanelContainer.new()
	_mouse_menu.visible = false
	_mouse_menu.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_mouse_menu.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_mouse_menu_items = VBoxContainer.new()
	_mouse_menu_items.add_theme_constant_override("separation", 2)
	_mouse_menu.add_child(_mouse_menu_items)
	if _hud:
		_hud.add_child(_mouse_menu)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			if _mouse_menu and _mouse_menu.visible:
				_hide_mouse_menu()
			else:
				_show_mouse_menu(mb.position)
			accept_event()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not mb.is_echo():
			if _mouse_menu and _mouse_menu.visible:
				_hide_mouse_menu()
			elif _dbox == null or not _dbox.visible:
				_on_next()
				accept_event()


func _show_mouse_menu(at_pos: Vector2) -> void:
	if _mouse_menu == null:
		return
	_deactivate_modes()
	_clear_children(_mouse_menu_items)
	var items := [
		[_t("ingame.save.button", "存档"), _on_mouse_save],
		[_t("ingame.load.button", "读档"), _on_mouse_load],
		[_t("ingame.log.button", "回顾"), _on_mouse_backlog],
		[_t("ingame.config.button", "设置"), _on_mouse_settings],
		[_t("ingame.auto.button", "自动"), _on_mouse_auto],
		[_t("ingame.fastforward.button", "快进"), _on_mouse_skip],
		[_t("ingame.title.button", "标题"), _on_mouse_title],
		[_t("config.quitgame", "退出"), _on_mouse_quit],
	]
	for item in items:
		var b := _make_button(str(item[0]))
		b.custom_minimum_size = Vector2(160, 32)
		b.pressed.connect(item[1])
		_mouse_menu_items.add_child(b)
	# Clamp to viewport.
	var vp_size := get_viewport().get_visible_rect().size
	var menu_size := Vector2(180, items.size() * 36.0)
	var pos := at_pos
	if pos.x + menu_size.x > vp_size.x:
		pos.x = vp_size.x - menu_size.x
	if pos.y + menu_size.y > vp_size.y:
		pos.y = vp_size.y - menu_size.y
	_mouse_menu.position = pos
	_mouse_menu.visible = true


func _hide_mouse_menu() -> void:
	if _mouse_menu:
		_mouse_menu.visible = false


func _on_mouse_save() -> void:
	_hide_mouse_menu()
	_open_save_panel(true)


func _on_mouse_load() -> void:
	_hide_mouse_menu()
	_open_save_panel(false)


func _on_mouse_backlog() -> void:
	_hide_mouse_menu()
	_open_backlog()


func _on_mouse_settings() -> void:
	_hide_mouse_menu()
	settings_requested.emit()


func _on_mouse_auto() -> void:
	_hide_mouse_menu()
	if _auto_btn:
		_auto_btn.button_pressed = not _auto_btn.button_pressed
	_on_auto_toggled()


func _on_mouse_skip() -> void:
	_hide_mouse_menu()
	if _skip_btn:
		_skip_btn.button_pressed = not _skip_btn.button_pressed
	_on_skip_toggled()


func _on_mouse_title() -> void:
	_hide_mouse_menu()
	if _ctx.dialog_system:
		_deactivate_modes()
		_ctx.dialog_system.show_confirm(
			_t("ingame.title.button", "标题"),
			_t("ingame.title.confirm", "要返回标题界面吗？")
		).connect(func(_confirmed: bool) -> void:
			if _confirmed:
				title_requested.emit()
		, CONNECT_ONE_SHOT)
	else:
		title_requested.emit()


func _on_mouse_quit() -> void:
	_hide_mouse_menu()
	if _ctx and _ctx.dialog_system:
		_deactivate_modes()
		_ctx.dialog_system.show_confirm(
			_t("config.quitgame", "退出"),
			_t("ingame.quit.confirm", "要退出游戏吗？")
		).connect(func(_confirmed: bool) -> void:
			if _confirmed:
				_do_quit()
		, CONNECT_ONE_SHOT)
	else:
		_do_quit()


# ── Helpers ──────────────────────────────────────────────────────────

func _continue_icon_visible(v: bool) -> void:
	if _continue_icon:
		_continue_icon.visible = v


func _speaker_label_clear() -> void:
	if _speaker_label:
		_speaker_label.text = ""


func _story_label_clear() -> void:
	if _story_label:
		_story_label.text = ""


func _backlog_panel_title_node() -> Label:
	if not _backlog_panel:
		return null
	var node := _backlog_panel.get_node_or_null("BacklogPanelContainer/Title")
	if node is Label:
		return node
	return null


func _make_button(text: String) -> Button:
	var b := ButtonRingScene.instantiate() as Button
	if b == null:
		b = Button.new()
	b.text = text
	return b


func _clear_children(node: Node) -> void:
	if node == null:
		return
	for c in node.get_children():
		c.queue_free()


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)


# ── Shortcut helpers ──────────────────────────────────────────────────

const QUICK_SAVE_SLOT := 98

func _quick_save() -> void:
	if _ctx.save_system and _ctx.save_system.save(QUICK_SAVE_SLOT):
		if _ctx.dialog_system:
			_ctx.dialog_system.show_toast(_t("ui.status.quicksaved", "快速存档完成"))
		if _status_label:
			_status_label.text = _t("ui.status.quicksaved", "状态：快速存档完成")


func _quick_load() -> void:
	if _ctx.save_system and _ctx.save_system.load_slot(QUICK_SAVE_SLOT):
		load_game()


func _toggle_dbox() -> void:
	if _dbox:
		_dbox.visible = not _dbox.visible


func _toggle_fullscreen() -> void:
	var is_full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_hot_reload() -> void:
	if _ctx.hot_reload:
		_ctx.hot_reload.reload()


func _request_quit() -> void:
	if _ctx and _ctx.dialog_system:
		_deactivate_modes()
		_ctx.dialog_system.show_confirm(
			_t("config.quitgame", "退出"),
			_t("ingame.quit.confirm", "要退出游戏吗？")
		).connect(func(_confirmed: bool) -> void:
			if _confirmed:
				_do_quit()
		, CONNECT_ONE_SHOT)
	else:
		_do_quit()


func _do_quit() -> void:
	if _ctx and _ctx.read_tracker:
		_ctx.read_tracker.save_to_disk()
	if _ctx:
		_ctx.get_tree().quit()


func _is_save_panel_visible() -> bool:
	return _save_panel != null and _save_panel.visible


func _is_backlog_panel_visible() -> bool:
	return _backlog_panel != null and _backlog_panel.visible
