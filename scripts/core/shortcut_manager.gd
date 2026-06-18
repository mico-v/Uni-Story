class_name ShortcutManager extends RefCounted

## Manages customizable keyboard shortcuts for all game actions.
## Loads default bindings, applies user overrides from user://config/keybinds.cfg,
## and provides remap/save/load/reset APIs for a future settings UI tab.

const CONFIG_PATH := "user://config/keybinds.cfg"

var _ctx: Node
var _custom: Dictionary = {}  # action_name -> int (Key enum)


func _init(ctx: Node) -> void:
	_ctx = ctx
	_apply_defaults()
	load_bindings()


## Check if an action was just triggered this frame.
func is_action_pressed(action: String) -> bool:
	if not InputMap.has_action(action):
		return false
	return Input.is_action_just_pressed(action)


## Get the primary keycode for an action (custom or default).
func get_keycode(action: String) -> int:
	if _custom.has(action):
		var val = _custom[action]
		return int(val)
	var defaults := _get_defaults()
	if defaults.has(action):
		var val = defaults[action]
		return int(val)
	return KEY_NONE


## Check whether an action has a user-customized binding.
func is_customized(action: String) -> bool:
	return _custom.has(action)


## Remap an action to a new key. Saves automatically.
func remap(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		push_warning("ShortcutManager: unknown action '%s'" % action)
		return
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	InputMap.action_add_event(action, ev)
	_custom[action] = keycode
	save_bindings()


## Reset one action to its default key.
func reset_action(action: String) -> void:
	_custom.erase(action)
	var defaults := _get_defaults()
	if defaults.has(action):
		_apply_single(action, int(defaults[action]))
	save_bindings()


## Reset all actions to defaults.
func reset_all() -> void:
	_custom.clear()
	_apply_defaults()
	save_bindings()


## Human-readable label for the key bound to an action.
func get_key_label(action: String) -> String:
	var code := get_keycode(action)
	if code == KEY_NONE:
		return ""
	return OS.get_keycode_string(code)


## Return all action names (default + custom).
func get_all_actions() -> Array:
	var actions: Array = []
	var defaults := _get_defaults()
	for key in defaults.keys():
		if not actions.has(key):
			actions.append(key)
	for key in _custom.keys():
		if not actions.has(key):
			actions.append(key)
	return actions


# ── Persistence ─────────────────────────────────────────────────────────

func save_bindings() -> void:
	if _custom.is_empty():
		DirAccess.remove_absolute(CONFIG_PATH)
		return
	DirAccess.make_dir_recursive_absolute("user://config")
	var cfg := ConfigFile.new()
	for action in _custom:
		cfg.set_value("keys", action, int(_custom[action]))
	cfg.save(CONFIG_PATH)


func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		_apply_defaults()
		return
	if not cfg.has_section("keys"):
		_apply_defaults()
		return
	for action in cfg.get_section_keys("keys"):
		var val = cfg.get_value("keys", action)
		if val is int:
			_custom[action] = int(val)
			_apply_single(action, int(val))
	# Apply defaults for any actions not in the config.
	var defaults := _get_defaults()
	for action in defaults:
		if not _custom.has(action):
			_apply_single(action, int(defaults[action]))


# ── Internals ───────────────────────────────────────────────────────────

func _get_defaults() -> Dictionary:
	var d := {}
	d["ui_step_forward"] = KEY_SPACE
	d["ui_auto"] = KEY_A
	d["ui_skip"] = KEY_S
	d["ui_save"] = KEY_F5
	d["ui_load"] = KEY_F7
	d["ui_quick_save"] = KEY_F6
	d["ui_quick_load"] = KEY_F8
	d["ui_backlog"] = KEY_L
	d["ui_toggle_dbox"] = KEY_H
	d["ui_fullscreen"] = KEY_F11
	d["ui_settings"] = KEY_F1
	d["ui_leave"] = KEY_ESCAPE
	d["debug_reload"] = KEY_F5
	d["debug_unlock"] = KEY_U
	return d


func _apply_defaults() -> void:
	var defaults := _get_defaults()
	for action in defaults:
		_apply_single(action, int(defaults[action]))


func _apply_single(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	InputMap.action_add_event(action, ev)
