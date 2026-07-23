extends SceneTree

## Headless smoke test for ThemeManager and the layered theme architecture.
##
## Usage:
##   godot --headless --path . --script res://scripts/tests/theme_manager_smoke_test.gd

const MAIN_SCENE := "res://scene/game.tscn"
const BASE_THEME_PATH := "res://resources/themes/base_theme.tres"
const MAIN_THEME_PATH := "res://resources/themes/main_theme.tres"
const DARK_THEME_PATH := "res://resources/themes/default_theme.tres"

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_theme_files_load()
	_test_base_theme_structural()
	_test_work_theme_colors()
	_test_theme_manager_constants()
	await _test_theme_manager_in_main_scene()
	_finish()


# ── Theme file loading ──────────────────────────────────────────────

func _test_theme_files_load() -> void:
	_expect(ResourceLoader.exists(BASE_THEME_PATH), "base_theme.tres should exist")
	_expect(ResourceLoader.exists(MAIN_THEME_PATH), "main_theme.tres should exist")
	_expect(ResourceLoader.exists(DARK_THEME_PATH), "default_theme.tres should exist")

	var base: Resource = load(BASE_THEME_PATH)
	var main: Resource = load(MAIN_THEME_PATH)
	var dark: Resource = load(DARK_THEME_PATH)

	_expect(base is Theme, "base_theme.tres should be a Theme resource")
	_expect(main is Theme, "main_theme.tres should be a Theme resource")
	_expect(dark is Theme, "default_theme.tres should be a Theme resource")


# ── Base theme structural verification ─────────────────────────────

func _test_base_theme_structural() -> void:
	var base: Theme = load(BASE_THEME_PATH) as Theme
	if base == null:
		return

	# Base theme should define structural StyleBox types.
	var btn_normal: StyleBox = base.get_stylebox("normal", "Button")
	_expect(btn_normal is StyleBoxFlat, "base_theme should define Button/normal as StyleBoxFlat")
	if btn_normal is StyleBoxFlat:
		var sbf: StyleBoxFlat = btn_normal as StyleBoxFlat
		# Structural properties should be present.
		_expect(sbf.corner_radius_top_left == 6, "base_theme Button/normal corner_radius should be 6")
		_expect(sbf.content_margin_left == 12.0, "base_theme Button/normal content_margin_left should be 12")

	var panel_style: StyleBox = base.get_stylebox("panel", "Panel")
	_expect(panel_style is StyleBoxFlat, "base_theme should define Panel/panel as StyleBoxFlat")
	if panel_style is StyleBoxFlat:
		var psf: StyleBoxFlat = panel_style as StyleBoxFlat
		_expect(psf.corner_radius_top_left == 10, "base_theme Panel/panel corner_radius should be 10")
		_expect(psf.shadow_size >= 6, "base_theme Panel/panel shadow_size should be >= 6")

	# Base theme should NOT define font colors (those belong to work themes).
	_expect(not base.has_color("font_color", "Button"), "base_theme should NOT define Button/font_color")
	_expect(not base.has_color("font_color", "Label"), "base_theme should NOT define Label/font_color")


# ── Work theme colors ──────────────────────────────────────────────

func _test_work_theme_colors() -> void:
	var main: Theme = load(MAIN_THEME_PATH) as Theme
	if main == null:
		return

	# main_theme should define colors (unlike base_theme).
	_expect(main.has_color("font_color", "Button"), "main_theme should define Button/font_color")

	# Work theme should have StyleBoxes with non-default colors.
	var btn_normal: StyleBox = main.get_stylebox("normal", "Button")
	_expect(btn_normal is StyleBoxFlat, "main_theme should define Button/normal")
	if btn_normal is StyleBoxFlat:
		var sbf: StyleBoxFlat = btn_normal as StyleBoxFlat
		# Should have a non-white/non-transparent color.
		var c: Color = sbf.bg_color
		_expect(c.a > 0.01, "main_theme Button/normal bg_color should be non-transparent")

	# Style of inherited type should resolve.
	var sb: StyleBox = main.get_stylebox("grabber", "HScrollBar")
	_expect(sb is StyleBoxFlat, "HScrollBar/grabber should be resolvable through work theme")


# ── ThemeManager constants ──────────────────────────────────────────

func _test_theme_manager_constants() -> void:
	_expect(ThemeManager.SIZE_LOGO == 36, "SIZE_LOGO should be 36")
	_expect(ThemeManager.SIZE_TITLE == 32, "SIZE_TITLE should be 32")
	_expect(ThemeManager.SIZE_SECTION == 24, "SIZE_SECTION should be 24")
	_expect(ThemeManager.SIZE_BODY == 18, "SIZE_BODY should be 18")
	_expect(ThemeManager.SIZE_CAPTION == 14, "SIZE_CAPTION should be 14")
	_expect(ThemeManager.SIZE_SPEAKER == 22, "SIZE_SPEAKER should be 22")
	_expect(ThemeManager.SIZE_STORY == 26, "SIZE_STORY should be 26")
	_expect(ThemeManager.SIZE_HINT == 28, "SIZE_HINT should be 28")
	_expect(ThemeManager.SIZE_CONFIRM_TITLE == 24, "SIZE_CONFIRM_TITLE should be 24")
	_expect(ThemeManager.SIZE_CONFIRM_MESSAGE == 20, "SIZE_CONFIRM_MESSAGE should be 20")
	_expect(ThemeManager.SIZE_MODE_LABEL == 20, "SIZE_MODE_LABEL should be 20")
	_expect(ThemeManager.SIZE_CONFLICT == 20, "SIZE_CONFLICT should be 20")

	_expect(ThemeManager.SEP_CHOICE_LIST == 10, "SEP_CHOICE_LIST should be 10")
	_expect(ThemeManager.SEP_SAVE_SLOTS == 6, "SEP_SAVE_SLOTS should be 6")
	_expect(ThemeManager.SEP_BACKLOG_LIST == 10, "SEP_BACKLOG_LIST should be 10")
	_expect(ThemeManager.SEP_CHAPTER_LIST == 10, "SEP_CHAPTER_LIST should be 10")
	_expect(ThemeManager.SEP_IMAGE_ROWS == 12, "SEP_IMAGE_ROWS should be 12")


# ── Integration: NovaController has theme_manager ───────────────────

func _test_theme_manager_in_main_scene() -> void:
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		return
	root.add_child(scene)
	await process_frame
	await process_frame

	# After instantiation, NovaController should have theme_manager.
	var tm: Variant = scene.get("theme_manager")
	_expect(tm != null, "NovaController should have theme_manager after _ready")

	# ThemeManager should have core methods.
	if tm != null:
		_expect(tm.has_method("apply"), "theme_manager should have apply() method")
		_expect(tm.has_method("configure"), "theme_manager should have configure() method")
		_expect(tm.has_method("snapshot"), "theme_manager should have snapshot() method")
		_expect(tm.has_method("restore"), "theme_manager should have restore() method")

		# Snapshot should contain work_theme_path.
		var snap: Dictionary = tm.snapshot()
		_expect(snap is Dictionary, "snapshot() should return Dictionary")
		_expect(snap.has("work_theme_path"), "snapshot should contain work_theme_path")

		# Restore should work.
		var ok: bool = tm.restore(snap)
		_expect(ok, "restore() with valid snapshot should return true")

	root.remove_child(scene)
	scene.free()
	await process_frame
	await process_frame


# ── Helpers ─────────────────────────────────────────────────────────

func _finish() -> void:
	if _failures.is_empty():
		print("ThemeManagerSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("ThemeManagerSmokeTest: FAILED")
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
