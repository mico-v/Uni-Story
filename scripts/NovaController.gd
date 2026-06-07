extends Node

## NovaController — the single hub the spec asks for: every subsystem is created
## and owned here, and presentation scripts reach them via `nova.<subsystem>`.
## Also builds the runtime scene graph (world/bg/fg + dialogue UI) and bridges
## the GameState model to the view.

const SCENARIO_FILES := [
	"res://resources/scenarios/plan_demo.txt",
	"res://resources/scenarios/ch1.txt",
	"res://resources/scenarios/ch2.txt",
	"res://resources/scenarios/test_animation.txt",
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
var audio: AudioSystem
var camera: CameraSystem
var transition: TransitionSystem
var dialogue_box: DialogueBoxSystem

# View nodes.
var _world: Node2D
var _bg: Sprite2D
var _fg: Sprite2D
var _overlay: ColorRect

@onready var _hud: Control = $Hud
@onready var _title_label: Label = $Hud/Panel/Title
@onready var _status_label: Label = $Hud/Panel/Status
@onready var _speaker_label: Label = $Hud/Panel/Speaker
@onready var _story_label: RichTextLabel = $Hud/Panel/Story
@onready var _chapter_list: VBoxContainer = $Hud/Panel/ChapterList
@onready var _choice_list: VBoxContainer = $Hud/Panel/Choices
@onready var _start_btn: Button = $Hud/Panel/Controls/StartButton
@onready var _next_btn: Button = $Hud/Panel/Controls/NextButton
@onready var _restart_btn: Button = $Hud/Panel/Controls/RestartButton
@onready var _quit_btn: Button = $Hud/Panel/Controls/QuitButton
@onready var _dialogue_box_node: Control = $Hud/Panel


func _ready() -> void:
	_build_world_nodes()
	_init_subsystems()
	_register_objects()
	_connect_model_signals()

	script_loader.load_all(SCENARIO_FILES)
	game_state.setup(script_loader.graph)

	_connect_ui()
	_show_title()


func _build_world_nodes() -> void:
	# A world container that the camera transforms, holding bg + fg.
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	move_child(_world, 0)  # behind the HUD

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

	# Full-screen transition overlay on top of everything.
	_overlay = ColorRect.new()
	_overlay.name = "TransitionOverlay"
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_overlay)


func _init_subsystems() -> void:
	object_manager = ObjectManager.new()
	runtime = GDRuntime.new(self)
	script_loader = ScriptLoader.new(self)
	game_state = GameState.new(self)
	graphics = Graphics.new(self)
	animation = AnimationSystem.new(self)
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
	object_manager.bind_object("default_box", _dialogue_box_node)


func _connect_model_signals() -> void:
	game_state.dialogue_changed.connect(_on_dialogue_changed)
	game_state.branch_requested.connect(_on_branch_requested)
	game_state.game_ended.connect(_on_game_ended)


# === View ====================================================================

func _connect_ui() -> void:
	_start_btn.pressed.connect(_show_title)
	_next_btn.pressed.connect(func(): game_state.advance())
	_restart_btn.pressed.connect(_show_title)
	_quit_btn.pressed.connect(func(): get_tree().quit())


func _show_title() -> void:
	_title_label.text = "Nova 2"
	_status_label.text = "状态：选择章节开始"
	_speaker_label.text = ""
	_story_label.text = ""
	_bg.visible = false
	_fg.visible = false
	_world.position = Vector2.ZERO
	_world.scale = Vector2.ONE
	_world.rotation_degrees = 0.0
	_choice_list.visible = false
	_clear_children(_choice_list)
	_next_btn.visible = false
	_restart_btn.visible = false
	_start_btn.visible = false
	_chapter_list.visible = true
	_refresh_chapters()


func _refresh_chapters() -> void:
	_clear_children(_chapter_list)
	for node_name in script_loader.graph.unlocked_start_nodes:
		var node = script_loader.graph.get_node_named(node_name)
		var b := Button.new()
		b.text = node.display_name
		b.pressed.connect(_on_chapter_selected.bind(node_name))
		_chapter_list.add_child(b)
	if script_loader.graph.unlocked_start_nodes.is_empty():
		var lbl := Button.new()
		lbl.text = "（无可用章节）"
		lbl.disabled = true
		_chapter_list.add_child(lbl)


func _on_chapter_selected(node_name: StringName) -> void:
	_chapter_list.visible = false
	_next_btn.visible = true
	_restart_btn.visible = false
	_status_label.text = "状态：对话中"
	game_state.start_node(node_name)


func _on_dialogue_changed(speaker: String, text: String) -> void:
	_speaker_label.text = speaker
	_story_label.text = text
	_next_btn.visible = true
	_choice_list.visible = false


func _on_branch_requested(options: Array) -> void:
	_next_btn.visible = false
	_choice_list.visible = true
	_clear_children(_choice_list)
	for opt in options:
		var b := Button.new()
		b.text = str(opt["text"])
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
