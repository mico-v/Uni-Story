extends Node

## NovaController — the single hub the spec asks for: every subsystem is created
## and owned here, and presentation scripts reach them via `nova.<subsystem>`.
## Builds the entire runtime scene graph (world layer + HUD) in code so layout is
## deterministic, then bridges the GameState model to the view.

const SCENARIO_FILES := [
	"res://resources/scenarios/plan_demo.txt",
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/test_animation.txt",
	"res://resources/scenarios/test_runtime.txt",
	"res://resources/scenarios/test_char.txt",
	"res://resources/scenarios/demo_full.txt",
]
const RESOURCE_ROOT := "res://resources/"

# Subsystems (public so BaseBlock / scripts can reach them as nova.<name>).
var object_manager: ObjectManager
var runtime: GDRuntime
var script_loader: ScriptLoader
var game_state: GameState
var graphics: Graphics
var animation: AnimationSystem
var composer: SpriteComposer
var audio: AudioSystem
var camera: CameraSystem
var transition: TransitionSystem
var dialogue_box: DialogueBoxSystem

# World layer.
var _world: Node2D
var _bg: Sprite2D
var _fg: Sprite2D

# HUD.
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
var _overlay: ColorRect


func _ready() -> void:
	_build_world()
	_build_hud()
	_init_subsystems()
	_register_objects()
	_connect_model_signals()

	script_loader.load_all(SCENARIO_FILES)
	game_state.setup(script_loader.graph)

	_show_title()


# === Scene construction ======================================================

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)

	_bg = Sprite2D.new()
	_bg.name = "Background"
	_bg.centered = false
	_bg.visible = false
	_bg.set_meta("folder", "")
	_world.add_child(_bg)

	_fg = Sprite2D.new()
	_fg.name = "Foreground"
	_fg.centered = false
	_fg.visible = false
	_world.add_child(_fg)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "Hud"
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.position = Vector2(16, 12)
	_status_label.add_theme_font_size_override("font_size", 18)
	_hud.add_child(_status_label)

	# Centered menu (title + chapters + start).
	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 12)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	_hud.add_child(_menu)

	_title_label = Label.new()
	_title_label.text = "Nova 2"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 40)
	_menu.add_child(_title_label)

	_chapter_list = VBoxContainer.new()
	_chapter_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_chapter_list.add_theme_constant_override("separation", 8)
	_menu.add_child(_chapter_list)

	_start_btn = _make_button("开始")
	_menu.add_child(_start_btn)

	# Dialogue box anchored to the bottom.
	_dbox = Panel.new()
	_dbox.name = "DialogueBox"
	_dbox.anchor_left = 0.08
	_dbox.anchor_right = 0.92
	_dbox.anchor_top = 0.72
	_dbox.anchor_bottom = 0.95
	_dbox.visible = false
	_hud.add_child(_dbox)

	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.position = Vector2(24, 10)
	_speaker_label.add_theme_font_size_override("font_size", 22)
	_dbox.add_child(_speaker_label)

	_story_label = RichTextLabel.new()
	_story_label.name = "Story"
	_story_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story_label.offset_left = 24
	_story_label.offset_top = 44
	_story_label.offset_right = -24
	_story_label.offset_bottom = -16
	_story_label.bbcode_enabled = true
	_story_label.add_theme_font_size_override("normal_font_size", 26)
	_dbox.add_child(_story_label)

	# Choices, centered.
	_choice_list = VBoxContainer.new()
	_choice_list.set_anchors_preset(Control.PRESET_CENTER)
	_choice_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_list.add_theme_constant_override("separation", 10)
	_choice_list.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_choice_list.grow_vertical = Control.GROW_DIRECTION_BOTH
	_choice_list.visible = false
	_hud.add_child(_choice_list)

	# Bottom-right controls.
	_controls = HBoxContainer.new()
	_controls.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_controls.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_controls.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_controls.position = Vector2(-24, -16)
	_controls.add_theme_constant_override("separation", 10)
	_hud.add_child(_controls)

	_next_btn = _make_button("下一句")
	_restart_btn = _make_button("重开")
	_quit_btn = _make_button("退出")
	_controls.add_child(_next_btn)
	_controls.add_child(_restart_btn)
	_controls.add_child(_quit_btn)

	# Full-screen transition overlay on top.
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_overlay)

	_start_btn.pressed.connect(_show_title)
	_next_btn.pressed.connect(func(): game_state.advance())
	_restart_btn.pressed.connect(_show_title)
	_quit_btn.pressed.connect(func(): get_tree().quit())


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 44)
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b


func _init_subsystems() -> void:
	object_manager = ObjectManager.new()
	runtime = GDRuntime.new(self)
	script_loader = ScriptLoader.new(self)
	game_state = GameState.new(self)
	graphics = Graphics.new(self)
	animation = AnimationSystem.new(self)
	composer = SpriteComposer.new(self)
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


func _connect_model_signals() -> void:
	game_state.dialogue_changed.connect(_on_dialogue_changed)
	game_state.branch_requested.connect(_on_branch_requested)
	game_state.game_ended.connect(_on_game_ended)


# === View ====================================================================

func _show_title() -> void:
	_status_label.text = "状态：选择章节开始"
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
	_next_btn.visible = false
	_restart_btn.visible = false
	_start_btn.visible = false
	_menu.visible = true
	_refresh_chapters()


func _refresh_chapters() -> void:
	_clear_children(_chapter_list)
	for node_name in script_loader.graph.unlocked_start_nodes:
		var node = script_loader.graph.get_node_named(node_name)
		var b := _make_button(node.display_name)
		b.pressed.connect(_on_chapter_selected.bind(node_name))
		_chapter_list.add_child(b)
	if script_loader.graph.unlocked_start_nodes.is_empty():
		var lbl := _make_button("（无可用章节）")
		lbl.disabled = true
		_chapter_list.add_child(lbl)


func _on_chapter_selected(node_name: StringName) -> void:
	_menu.visible = false
	_dbox.visible = true
	_next_btn.visible = true
	_restart_btn.visible = false
	_status_label.text = "状态：对话中"
	game_state.start_node(node_name)


func _on_dialogue_changed(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_story_label.text = text
	_dbox.visible = true
	_next_btn.visible = true
	_choice_list.visible = false


func _on_branch_requested(options: Array) -> void:
	_next_btn.visible = false
	_choice_list.visible = true
	_clear_children(_choice_list)
	for opt in options:
		var b := _make_button(str(opt["text"]))
		b.pressed.connect(_on_choice.bind(opt["dest"]))
		_choice_list.add_child(b)


func _on_choice(dest: StringName) -> void:
	_choice_list.visible = false
	_clear_children(_choice_list)
	_next_btn.visible = true
	game_state.choose_branch(dest)


func _on_game_ended() -> void:
	_status_label.text = "状态：章节结束"
	_next_btn.visible = false
	_restart_btn.visible = true


func _clear_children(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()
