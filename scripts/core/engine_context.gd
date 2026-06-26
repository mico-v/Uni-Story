class_name EngineContext extends RefCounted

## Typed facade for the engine composition root.
##
## Existing systems still receive NovaController as `_ctx` for compatibility.
## New code should prefer this facade when it only needs subsystem access; it
## makes dependencies visible without forcing a large migration in one pass.

var _owner: Node


func _init(owner: Node) -> void:
	_owner = owner


var object_manager: ObjectManager:
	get:
		return _owner.object_manager if _owner else null

var runtime: GDRuntime:
	get:
		return _owner.runtime if _owner else null

var script_loader: ScriptLoader:
	get:
		return _owner.script_loader if _owner else null

var game_state: GameState:
	get:
		return _owner.game_state if _owner else null

var variables: Variables:
	get:
		return _owner.variables if _owner else null

var i18n: I18n:
	get:
		return _owner.i18n if _owner else null

var save_system: SaveSystem:
	get:
		return _owner.save_system if _owner else null

var backlog: Backlog:
	get:
		return _owner.backlog if _owner else null

var graphics: Graphics:
	get:
		return _owner.graphics if _owner else null

var animation: AnimationSystem:
	get:
		return _owner.animation if _owner else null

var composer: SpriteComposer:
	get:
		return _owner.composer if _owner else null

var avatar: AvatarSystem:
	get:
		return _owner.avatar if _owner else null

var audio: AudioSystem:
	get:
		return _owner.audio if _owner else null

var camera: CameraSystem:
	get:
		return _owner.camera if _owner else null

var transition: TransitionSystem:
	get:
		return _owner.transition if _owner else null

var dialogue_box: DialogueBoxSystem:
	get:
		return _owner.dialogue_box if _owner else null

var vfx: VFXSystem:
	get:
		return _owner.vfx if _owner else null

var read_tracker: ReadTracker:
	get:
		return _owner.read_tracker if _owner else null

var prefab_loader: PrefabLoader:
	get:
		return _owner.prefab_loader if _owner else null

var hot_reload: HotReload:
	get:
		return _owner.hot_reload if _owner else null

var shortcut_manager: ShortcutManager:
	get:
		return _owner.shortcut_manager if _owner else null

var video_system: VideoSystem:
	get:
		return _owner.video_system if _owner else null

var dialog_system: DialogSystem:
	get:
		return _owner.dialog_system if _owner else null

var preload_system: PreloadSystem:
	get:
		return _owner.preload_system if _owner else null

var restorables: RestorableRegistry:
	get:
		return _owner.restorables if _owner else null

var checkpoint_manager: RefCounted:
	get:
		return _owner.checkpoint_manager if _owner else null

var view_manager: ViewManager:
	get:
		return _owner.view_manager if _owner else null

var gallery_coordinator: RefCounted:
	get:
		return _owner.gallery_coordinator if _owner else null

var settings_coordinator: RefCounted:
	get:
		return _owner.settings_coordinator if _owner else null


func validate_core() -> Array[String]:
	var errors: Array[String] = []
	for name in [
		"object_manager",
		"runtime",
		"script_loader",
		"game_state",
		"variables",
		"i18n",
		"save_system",
		"restorables",
		"checkpoint_manager",
	]:
		if _owner == null or _owner.get(name) == null:
			errors.append("EngineContext: missing required subsystem '%s'" % name)
	return errors
