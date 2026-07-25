extends SceneTree

## i18n_switch_smoke_test.gd — headless smoke test verifying
## zh↔en locale switching for UI strings and scenario text (Phase 13).

var _ok_count: int = 0
var _fail_count: int = 0
var _errors: Array[String] = []


func _init() -> void:
	run()


func run() -> void:
	print("=== Phase 13: I18n Switch Smoke Test ===")

	# 13.2a: UI localization strings present
	_test_ui_json()

	# 13.2b: English scenario files present with matching structure
	_test_scenario_files()

	# 13.2c: I18n class works correctly
	_test_i18n_class()

	# Summary
	print("\n=== Results: %d OK / %d FAIL ===" % [_ok_count, _fail_count])
	if _fail_count > 0:
		print("FAILED TESTS:")
		for err in _errors:
			print("  - %s" % err)
		quit(1)
	else:
		print("PASS")
		quit(0)


func _ok(msg: String) -> void:
	_ok_count += 1
	print("  ✓ %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	_errors.append(msg)
	print("  ✗ %s" % msg)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_ok(msg)
	else:
		_fail(msg)


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _test_ui_json() -> void:
	print("\n-- 13.2a: UI localization JSON files --")
	var zh := _read_json("res://resources/localized_resources/localized_strings/zh.json")
	var en := _read_json("res://resources/localized_resources/localized_strings/en.json")

	_assert(not zh.is_empty(), "zh.json is non-empty")
	_assert(not en.is_empty(), "en.json is non-empty")

	# Required UI keys
	var required_keys := [
		"title.menu.start", "title.menu.continue", "title.menu.load",
		"title.menu.config", "title.menu.gallery", "title.menu.help",
		"title.menu.quit", "config.quitgame", "config.returntitle",
		"ingame.save.button", "ingame.load.button", "ingame.config.button",
		"ingame.auto.button", "ingame.title.button", "config.item.language",
		"bookmark.save.button", "bookmark.load.button",
	]
	for key in required_keys:
		_assert(zh.has(key), "zh.json has key: %s" % key)
		_assert(en.has(key), "en.json has key: %s" % key)

	# Verify zh and en are actually different languages
	_assert(zh["title.menu.start"] != en["title.menu.start"],
		"zh/en differ on title.menu.start")


func _test_scenario_files() -> void:
	print("\n-- 13.2b: English scenario files --")
	var zh_files := [
		"res://resources/scenarios/ch1.txt",
		"res://resources/scenarios/ch2.txt",
		"res://resources/scenarios/ch3.txt",
		"res://resources/scenarios/ch4.txt",
	]
	var en_files := [
		"res://resources/LocalizedResources/English/Scenarios/ch1.txt",
		"res://resources/LocalizedResources/English/Scenarios/ch2.txt",
		"res://resources/LocalizedResources/English/Scenarios/ch3.txt",
		"res://resources/LocalizedResources/English/Scenarios/ch4.txt",
	]

	for i in range(zh_files.size()):
		var zh_path := zh_files[i]
		var en_path := en_files[i]
		var zh_exists := _file_exists(zh_path)
		var en_exists := _file_exists(en_path)
		_assert(zh_exists, "ZH scenario exists: %s" % zh_path.get_file())
		_assert(en_exists, "EN scenario exists: %s" % en_path.get_file())

		if zh_exists and en_exists:
			# Both should have labels
			var zh_content := _read_file(zh_path)
			var en_content := _read_file(en_path)
			_assert("label(" in zh_content, "ZH %s has labels" % zh_path.get_file())
			_assert("label(" in en_content, "EN %s has labels" % en_path.get_file())


func _test_i18n_class() -> void:
	print("\n-- 13.2c: I18n class functional --")
	var i18n := load("res://scripts/core/i18n.gd").new()

	# Default locale
	_assert(i18n.locale == "zh", "Default locale is zh")

	# Switch to en
	i18n.set_locale("en")
	_assert(i18n.locale == "en", "Can switch locale to en")

	# Switch back to zh
	i18n.set_locale("zh")
	_assert(i18n.locale == "zh", "Can switch locale back to zh")

	# t() method works
	i18n._load_locale("en")
	var key := "title.menu.start"
	var result := i18n.t(key)
	_assert(result != "" and result != key, "t('%s') returns a translated string" % key)

	# Fallback
	i18n.set_locale("fr")
	var fallback := i18n.t("title.menu.start")
	_assert(fallback != "", "Fallback locale works for unknown locale")

	i18n.free()


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var content := f.get_as_text()
	f.close()
	return content
