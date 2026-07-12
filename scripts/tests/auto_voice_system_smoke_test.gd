extends SceneTree

## Headless AutoVoice profile, scheduling, dialogue, and restore smoke test.

const CheckpointManagerScript := preload("res://scripts/core/checkpoint_manager.gd")
const AutoVoiceSystemScript := preload("res://scripts/runtime/auto_voice_system.gd")
const GameViewControllerScript := preload("res://scripts/ui/game_view_controller.gd")
const PROFILE := preload("res://resources/auto_voice_profile.tres")
const SCENARIO_PATH := "user://tests/auto_voice_system_smoke.txt"
const SCENARIO_SOURCE := """
@<|
label("auto_voice_start", "Auto Voice")
is_start()
|>
<|
auto_voice_on("王二宫", 001001)
set_auto_voice_delay(0.05)
|>
王二宫：：第一句
王二宫：：第二句
<|
auto_voice_on("孙西本", 003001)
say(xiben, "003007")
|>
孙西本：：显式语音
孙西本：：自动语音
"""


class FakeAudio:
	extends RefCounted

	signal voice_finished()

	var played: Array[String] = []
	var playing := false
	var stop_count := 0

	func play_voice(path: String) -> bool:
		played.append(path)
		playing = true
		return true

	func stop_voice() -> void:
		var was_playing := playing
		playing = false
		stop_count += 1
		if was_playing:
			voice_finished.emit()

	func is_voice_playing() -> bool:
		return playing

	func finish_voice() -> void:
		if not playing:
			return
		playing = false
		voice_finished.emit()


class NoopReadTracker:
	extends RefCounted

	func mark_read(_node_name: StringName, _index: int) -> void:
		pass

	func snapshot() -> Dictionary:
		return {}

	func restore(_data: Dictionary) -> void:
		pass


class TestContext:
	extends Node

	var object_manager: ObjectManager
	var variables: Variables
	var runtime: GDRuntime
	var script_loader: ScriptLoader
	var game_state: GameState
	var checkpoint_manager: RefCounted
	var restorables: RestorableRegistry
	var backlog: Backlog
	var audio: FakeAudio
	var auto_voice
	var read_tracker: NoopReadTracker

	func setup() -> void:
		object_manager = ObjectManager.new()
		object_manager.set_constant("resource_root", "res://resources/")
		variables = Variables.new()
		restorables = RestorableRegistry.new()
		backlog = Backlog.new()
		audio = FakeAudio.new()
		auto_voice = AutoVoiceSystemScript.new(self)
		auto_voice.configure(PROFILE)
		read_tracker = NoopReadTracker.new()
		checkpoint_manager = CheckpointManagerScript.new(self)
		runtime = GDRuntime.new(self)
		script_loader = ScriptLoader.new(self)
		game_state = GameState.new(self)
		restorables.register("game_state", game_state)
		restorables.register("backlog", backlog)
		restorables.register("auto_voice", auto_voice)


class FakeWaitingGameState:
	extends RefCounted

	var is_waiting_input := true
	var advance_count := 0

	func continue_after_input() -> void:
		advance_count += 1
		is_waiting_input = false


class AutoModeContext:
	extends Node

	var object_manager: ObjectManager
	var backlog: Backlog
	var audio: FakeAudio
	var auto_voice
	var game_state: FakeWaitingGameState

	func setup() -> void:
		object_manager = ObjectManager.new()
		object_manager.set_constant("resource_root", "res://resources/")
		backlog = Backlog.new()
		audio = FakeAudio.new()
		auto_voice = AutoVoiceSystemScript.new(self)
		auto_voice.configure(PROFILE)
		game_state = FakeWaitingGameState.new()


var _failures: Array[String] = []
var _dialogues: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_profile_and_state_machine()
	await _test_auto_mode_waits_for_delay_and_voice()
	await _test_game_state_and_restore()

	if _failures.is_empty():
		print("AutoVoiceSystemSmokeTest: OK, dialogues=%d" % _dialogues.size())
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("AutoVoiceSystemSmokeTest: FAILED")
		quit(1)


func _test_profile_and_state_machine() -> void:
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()

	_expect(PROFILE.resolve_character("Ergong") == "王二宫", "English alias should resolve to canonical speaker")
	_expect(PROFILE.voice_path("王二宫", 1001) == "Voices/Ergong/001001.ogg", "profile should pad automatic voice ids to six digits")
	_expect(ctx.auto_voice.manual_voice_path("xiben", "003007") == "Voices/Xiben/003007.ogg", "manual say should resolve the character directory")

	ctx.auto_voice.enable("王二宫", 1001)
	ctx.auto_voice.set_next_delay(0.05)
	_expect(ctx.auto_voice.prepare_dialogue("", true).is_empty(), "narration should not consume automatic voice state")
	var delayed: Dictionary = ctx.auto_voice.prepare_dialogue("王二宫", true)
	_expect(str(delayed.get("path", "")) == "Voices/Ergong/001001.ogg", "first automatic cue should use the configured index")
	_expect(is_equal_approx(float(delayed.get("delay", 0.0)), 0.05), "narration should not consume the pending delay")
	_expect(ctx.auto_voice.next_index("王二宫") == 1002, "matching dialogue should advance the next index")
	ctx.auto_voice.start_prepared_cue(delayed)
	_expect(ctx.auto_voice.has_pending_voice(), "positive delay should create a pending cue")
	ctx.auto_voice.cancel_pending(false, true)

	var settle_order: Array[String] = []
	ctx.auto_voice.enable("王二宫", 1001)
	ctx.auto_voice.set_next_delay(0.01)
	var ordered_cue: Dictionary = ctx.auto_voice.prepare_dialogue("王二宫", true)
	ctx.auto_voice.cue_started.connect(func(_path: String) -> void: settle_order.append("started"))
	ctx.auto_voice.pending_changed.connect(func() -> void:
		if not ctx.auto_voice.has_pending_voice():
			settle_order.append("settled")
	)
	ctx.auto_voice.start_prepared_cue(ordered_cue)
	await create_timer(0.03).timeout
	_expect(settle_order.size() >= 2 and settle_order[0] == "started" and settle_order[1] == "settled", "delay completion should publish cue start before waking Auto-mode waiters")

	ctx.auto_voice.disable("王二宫")
	ctx.auto_voice.prepare_dialogue("王二宫", true)
	_expect(ctx.auto_voice.next_index("王二宫") == 1002, "disabled speaker should not consume an index")
	ctx.auto_voice.enable("王二宫")
	_expect(ctx.auto_voice.next_index("王二宫") == 1002, "re-enabling without an index should preserve the counter")
	ctx.auto_voice.enable("王二宫", ["alt_", 7])
	_expect(ctx.auto_voice.prefix_for("Ergong") == "alt_" and ctx.auto_voice.next_index("王二宫") == 7, "tuple form should override prefix and index")
	ctx.auto_voice.enable("孙西本", 3001)
	ctx.auto_voice.disable_all()
	_expect(not ctx.auto_voice.is_enabled("王二宫") and not ctx.auto_voice.is_enabled("孙西本"), "off_all should disable every initialized speaker")
	_expect(ctx.auto_voice.next_index("孙西本") == 3001, "off_all should preserve speaker indices")

	ctx.auto_voice.enable("张浅野", 2001)
	ctx.auto_voice.set_next_delay(0.25)
	ctx.auto_voice.skip_next()
	_expect(ctx.auto_voice.prepare_dialogue("张浅野", true).is_empty(), "explicit override should suppress one automatic cue")
	_expect(ctx.auto_voice.next_index("张浅野") == 2001, "explicit override should not advance the index")
	var after_override: Dictionary = ctx.auto_voice.prepare_dialogue("张浅野", true)
	_expect(ctx.auto_voice.next_index("张浅野") == 2002, "the following automatic cue should advance normally")
	_expect(is_equal_approx(float(after_override.get("delay", 0.0)), 0.25), "explicit override should not consume the pending delay")
	ctx.auto_voice.prepare_manual("qianye", "002010", 0.0, false)
	var coexist_cue: Dictionary = ctx.auto_voice.prepare_dialogue("张浅野", true)
	_expect(str(coexist_cue.get("path", "")) == "Voices/Qianye/002010.ogg", "say override=false should still play its explicit cue")
	_expect(ctx.auto_voice.next_index("张浅野") == 2003, "say override=false should consume automatic state to keep numbering aligned")
	ctx.auto_voice.skip_next()
	_expect(ctx.auto_voice.prepare_dialogue("张浅野", true).is_empty(), "a later skip should not replay a stale override=false cue")
	_expect(ctx.auto_voice.next_index("张浅野") == 2003, "later skip should preserve the aligned automatic index")

	ctx.auto_voice.enable("孙西本", 3001)
	var backlog_cue: Dictionary = ctx.auto_voice.prepare_dialogue("孙西本", true)
	ctx.backlog.record("孙西本", "测试", "node", 0)
	_expect(str(ctx.backlog.entries()[0].get("voice", "")) == str(backlog_cue.get("path", "")), "automatic cue should attach to the same backlog entry")
	ctx.backlog.note_voice("Voices/stale.ogg")
	ctx.backlog.clear()
	ctx.backlog.record("", "fresh", "node", 1)
	_expect(str(ctx.backlog.entries()[0].get("voice", "")).is_empty(), "backlog clear should discard stale pending voice")
	ctx.queue_free()


func _test_auto_mode_waits_for_delay_and_voice() -> void:
	var ctx := AutoModeContext.new()
	root.add_child(ctx)
	ctx.setup()
	var view = GameViewControllerScript.new()
	root.add_child(view)
	view.set("_ctx", ctx)
	view.set("_is_auto", true)
	view.set("auto_delay", 0.0)

	ctx.auto_voice.enable("王二宫", 1001)
	ctx.auto_voice.set_next_delay(0.01)
	var cue: Dictionary = ctx.auto_voice.prepare_dialogue("王二宫", true)
	ctx.auto_voice.start_prepared_cue(cue)
	view.call("_check_auto_advance")
	await create_timer(0.04).timeout
	_expect(ctx.audio.playing, "delayed cue should have started before Auto mode continues")
	_expect(ctx.game_state.advance_count == 0, "Auto mode should not schedule an advance while voice is playing")
	ctx.audio.finish_voice()
	await create_timer(0.55).timeout
	_expect(ctx.game_state.advance_count == 1, "Auto mode should advance after delay, playback, and reading wait all finish")

	root.remove_child(view)
	view.free()
	ctx.auto_voice.dispose()
	root.remove_child(ctx)
	ctx.free()


func _test_game_state_and_restore() -> void:
	_write_scenario()
	var ctx := TestContext.new()
	root.add_child(ctx)
	ctx.setup()
	ctx.game_state.dialogue_changed.connect(func(speaker: String, text: String) -> void:
		_dialogues.append({"speaker": speaker, "text": text})
		var node_name := str(ctx.game_state.current_node.name) if ctx.game_state.current_node else ""
		ctx.backlog.record(speaker, text, node_name, ctx.game_state.current_index)
	)

	ctx.script_loader.load_all([SCENARIO_PATH])
	_expect(ctx.script_loader.load_ok, "AutoVoice integration scenario should parse")
	ctx.game_state.setup(ctx.script_loader.graph)
	ctx.game_state.start_node(&"auto_voice_start")
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 0 and ctx.game_state.is_waiting_input)
	_expect(ctx.auto_voice.next_index("王二宫") == 1002, "GameState should consume the first cue before checkpointing")
	_expect(ctx.auto_voice.has_pending_voice(), "first integration cue should be waiting on its scripted delay")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 1 and ctx.game_state.is_waiting_input)
	_expect(ctx.audio.played == ["Voices/Ergong/001002.ogg"], "advancing should cancel the older delayed cue and play only the new line")
	_expect(ctx.auto_voice.next_index("王二宫") == 1003, "second integration dialogue should advance the counter")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 2 and ctx.game_state.is_waiting_input)
	_expect(ctx.audio.played.back() == "Voices/Xiben/003007.ogg", "explicit say(xiben, id) should resolve through the character voice directory")
	_expect(ctx.auto_voice.next_index("孙西本") == 3001, "explicit say should override automatic voice without consuming its index")

	await ctx.game_state.continue_after_input()
	await _wait_until(func() -> bool: return ctx.game_state.current_index == 3 and ctx.game_state.is_waiting_input)
	_expect(ctx.audio.played.back() == "Voices/Xiben/003001.ogg", "automatic voice should resume on the following dialogue")
	_expect(ctx.auto_voice.next_index("孙西本") == 3002, "automatic voice after explicit say should consume exactly one index")

	var restored := bool(ctx.checkpoint_manager.restore_to_position("auto_voice_start", 0))
	_expect(restored, "checkpoint restore to the first dialogue should succeed")
	_expect(ctx.game_state.current_index == 0, "restore should return to the requested dialogue")
	_expect(ctx.auto_voice.next_index("王二宫") == 1002, "restore should recover the saved next index without double consumption")
	_expect(ctx.auto_voice.has_pending_voice(), "restored target cue should be scheduled only after secondary state restore")
	_expect(_dialogues.back().get("text", "") == "第一句", "restore should present the target line once secondary state is ready")
	_expect(ctx.backlog.entries().size() == 1 and str(ctx.backlog.entries()[0].get("voice", "")) == "Voices/Ergong/001001.ogg", "restored backlog target should retain its exact voice path, got %s" % JSON.stringify(ctx.backlog.entries()))

	ctx.auto_voice.cancel_pending(true, true)
	ctx.queue_free()


func _write_scenario() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var file := FileAccess.open(SCENARIO_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("failed to write AutoVoice scenario")
		return
	file.store_string(SCENARIO_SOURCE)
	file.close()


func _wait_until(predicate: Callable, max_frames: int = 60) -> void:
	for _i in range(max_frames):
		if bool(predicate.call()):
			return
		await process_frame
	_failures.append("timed out waiting for AutoVoice condition")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
