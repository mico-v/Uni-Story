class_name ThemeManager extends RefCounted

## Subsystem that loads, applies, and manages work-specific themes.
##
## The project uses a layered theme architecture:
##   base_theme.tres  — structural skeleton (margins, radii, border widths)
##   main_theme.tres  — default warm palette (pink/purple) with base_theme set
##
## ThemeManager loads the configured work theme and applies it as the
## project-wide theme via ThemeDB, replacing project.godot's static reference.
##
## Font-size tiers are exposed as constants so controllers reference them
## instead of scattered magic numbers.

signal theme_changed(work_theme_path: String)

# ── Font-size tier constants ────────────────────────────────────────

const SIZE_LOGO := 36
const SIZE_TITLE := 32
const SIZE_SECTION := 24
const SIZE_BODY := 18
const SIZE_CAPTION := 14
const SIZE_SPEAKER := 22
const SIZE_STORY := 26
const SIZE_HINT := 28
const SIZE_CONFIRM_TITLE := 24
const SIZE_CONFIRM_MESSAGE := 20
const SIZE_MODE_LABEL := 20
const SIZE_CONFLICT := 20

# ── Separation constants ────────────────────────────────────────────

const SEP_CHOICE_LIST := 10
const SEP_CONTROLS := 10
const SEP_SAVE_SLOTS := 6
const SEP_BACKLOG_LIST := 10
const SEP_CHAPTER_LIST := 10
const SEP_IMAGE_ROWS := 12

var _ctx: Node

var base_theme: Theme
var current_work_theme: Theme
var _base_theme_path: String = "res://resources/themes/base_theme.tres"
var _work_theme_path: String = "res://resources/themes/main_theme.tres"


func _init(ctx: Node) -> void:
	_ctx = ctx


## Configure theme paths. Call before apply().
func configure(base_theme_path: String, work_theme_path: String) -> void:
	_base_theme_path = base_theme_path
	_work_theme_path = work_theme_path


## Load and apply the current work theme as the project-wide theme.
## Must be called after the scene tree is ready (ThemeDB is available).
func apply() -> void:
	base_theme = _load_theme(_base_theme_path)
	current_work_theme = _load_theme(_work_theme_path)
	if current_work_theme == null:
		push_error("ThemeManager: failed to load work theme '%s'" % _work_theme_path)
		return

	# Ensure the work theme inherits from base for structural fallback.
	if base_theme != null:
		# Check if work theme already has base_theme set from the .tres file.
		# If not, set it programmatically.
		var existing_base: Theme = null
		if current_work_theme.has_method("get_base_theme"):
			existing_base = current_work_theme.get_base_theme()
		elif current_work_theme.get("base_theme") != null:
			existing_base = current_work_theme.get("base_theme") as Theme
		if existing_base == null:
			current_work_theme.set("base_theme", base_theme)

	# Apply as project-wide theme via the scene tree root.
	# ThemeDB.project_theme is not directly accessible from GDScript in some Godot 4.x builds.
	if _ctx and _ctx.get_tree() and _ctx.get_tree().root:
		_ctx.get_tree().root.theme = current_work_theme
	theme_changed.emit(_work_theme_path)


## Switch to a different work theme at runtime.
func set_work_theme(path: String) -> void:
	_work_theme_path = path
	apply()


## Apply a font-size override to a specific control using a named tier.
## This replaces the scattered `control.add_theme_font_size_override("font_size", N)` pattern.
## Pass the override name (e.g. "font_size", "normal_font_size") and point size.
func apply_font_size(control: Control, override_name: String, size: int) -> void:
	if control == null:
		return
	control.add_theme_font_size_override(StringName(override_name), size)


## Apply a constant override (separation, margin, etc.) to a control.
func apply_constant(control: Control, constant_name: String, value: int) -> void:
	if control == null:
		return
	control.add_theme_constant_override(StringName(constant_name), value)


## Apply a stylebox override to a control.
func apply_stylebox(control: Control, style_name: String, stylebox: StyleBox) -> void:
	if control == null:
		return
	control.add_theme_stylebox_override(StringName(style_name), stylebox)


## Set the dialogue font size (called from SettingsCoordinator).
## This is a per-control user preference, not a theme property.
func set_dialogue_font_size(story_label: RichTextLabel, size: int) -> void:
	if story_label == null:
		return
	story_label.add_theme_font_size_override("normal_font_size", size)


# ── Save / Restore ──────────────────────────────────────────────────

func snapshot() -> Dictionary:
	return {
		"work_theme_path": _work_theme_path,
	}


func restore(data: Dictionary) -> bool:
	var path: String = str(data.get("work_theme_path", ""))
	if path.is_empty():
		return false
	if path != _work_theme_path:
		set_work_theme(path)
	return true


# ── Helpers ─────────────────────────────────────────────────────────

func _load_theme(path: String) -> Theme:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		push_warning("ThemeManager: theme not found '%s'" % path)
		return null
	var res := load(path)
	if res is Theme:
		return res as Theme
	push_error("ThemeManager: '%s' is not a Theme resource" % path)
	return null
