@tool
extends EditorScript

## Generates the global dark GALGAME theme for Uni-Story.
## Run from Godot Editor: File > Run > This Script

func _run() -> void:
	var theme := Theme.new()

	# ── Colors ───────────────────────────────────────────────────────────
	var bg_dark := Color(0.12, 0.12, 0.14, 0.95)
	var bg_panel := Color(0.15, 0.15, 0.18, 0.92)
	var bg_hover := Color(0.22, 0.22, 0.26, 0.95)
	var bg_pressed := Color(0.08, 0.08, 0.10, 0.95)
	var text_light := Color(0.95, 0.95, 0.97, 1.0)
	var text_dim := Color(0.70, 0.70, 0.75, 1.0)
	var accent := Color(0.85, 0.75, 0.90, 1.0)  # soft lavender
	var border := Color(0.30, 0.30, 0.35, 0.6)

	# ── Button Styles ────────────────────────────────────────────────────
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = bg_panel
	btn_normal.border_color = border
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_right = 12
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = bg_hover
	btn_hover.border_color = accent
	btn_hover.border_width_bottom = 2
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.content_margin_left = 12
	btn_hover.content_margin_right = 12
	btn_hover.content_margin_top = 8
	btn_hover.content_margin_bottom = 8

	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = bg_pressed
	btn_pressed.border_color = accent
	btn_pressed.border_width_bottom = 2
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	btn_pressed.content_margin_left = 12
	btn_pressed.content_margin_right = 12
	btn_pressed.content_margin_top = 8
	btn_pressed.content_margin_bottom = 8

	var btn_disabled := StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.10, 0.10, 0.12, 0.5)
	btn_disabled.border_color = Color(0.20, 0.20, 0.25, 0.3)
	btn_disabled.border_width_bottom = 2
	btn_disabled.corner_radius_top_left = 6
	btn_disabled.corner_radius_top_right = 6
	btn_disabled.corner_radius_bottom_left = 6
	btn_disabled.corner_radius_bottom_right = 6
	btn_disabled.content_margin_left = 12
	btn_disabled.content_margin_right = 12
	btn_disabled.content_margin_top = 8
	btn_disabled.content_margin_bottom = 8

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color", "Button", text_light)
	theme.set_color("font_hover_color", "Button", text_light)
	theme.set_color("font_pressed_color", "Button", text_light)
	theme.set_color("font_disabled_color", "Button", text_dim)

	# ── Panel Styles ─────────────────────────────────────────────────────
	var panel := StyleBoxFlat.new()
	panel.bg_color = bg_panel
	panel.border_color = border
	panel.border_width_left = 1
	panel.border_width_top = 1
	panel.border_width_right = 1
	panel.border_width_bottom = 1
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	panel.content_margin_left = 16
	panel.content_margin_top = 16
	panel.content_margin_right = 16
	panel.content_margin_bottom = 16

	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# ── Label Styles ─────────────────────────────────────────────────────
	theme.set_color("font_color", "Label", text_light)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	# ── RichTextLabel ────────────────────────────────────────────────────
	theme.set_color("default_color", "RichTextLabel", text_light)

	# ── LineEdit ─────────────────────────────────────────────────────────
	var line_edit := StyleBoxFlat.new()
	line_edit.bg_color = bg_dark
	line_edit.border_color = border
	line_edit.border_width_bottom = 2
	line_edit.corner_radius_top_left = 4
	line_edit.corner_radius_top_right = 4
	line_edit.corner_radius_bottom_left = 4
	line_edit.corner_radius_bottom_right = 4
	line_edit.content_margin_left = 8
	line_edit.content_margin_right = 8
	line_edit.content_margin_top = 6
	line_edit.content_margin_bottom = 6
	theme.set_stylebox("normal", "LineEdit", line_edit)
	theme.set_color("font_color", "LineEdit", text_light)

	# ── HSlider ──────────────────────────────────────────────────────────
	var slider_grabber := StyleBoxFlat.new()
	slider_grabber.bg_color = accent
	slider_grabber.corner_radius_top_left = 6
	slider_grabber.corner_radius_top_right = 6
	slider_grabber.corner_radius_bottom_left = 6
	slider_grabber.corner_radius_bottom_right = 6
	slider_grabber.content_margin_left = 4
	slider_grabber.content_margin_right = 4
	slider_grabber.content_margin_top = 4
	slider_grabber.content_margin_bottom = 4

	var slider_track := StyleBoxFlat.new()
	slider_track.bg_color = Color(0.25, 0.25, 0.30, 1.0)
	slider_track.corner_radius_top_left = 3
	slider_track.corner_radius_top_right = 3
	slider_track.corner_radius_bottom_left = 3
	slider_track.corner_radius_bottom_right = 3

	theme.set_stylebox("slider", "HSlider", slider_grabber)
	theme.set_stylebox("grabber", "HSlider", slider_grabber)
	theme.set_stylebox("grabber_highlight", "HSlider", slider_grabber)
	theme.set_stylebox("slider", "HSlider", slider_track)

	# ── CheckButton ──────────────────────────────────────────────────────
	theme.set_color("font_color", "CheckButton", text_light)
	theme.set_color("font_hover_color", "CheckButton", text_light)
	theme.set_color("font_pressed_color", "CheckButton", text_light)

	# ── OptionButton ─────────────────────────────────────────────────────
	theme.set_color("font_color", "OptionButton", text_light)
	theme.set_color("font_hover_color", "OptionButton", text_light)
	theme.set_stylebox("normal", "OptionButton", btn_normal)
	theme.set_stylebox("hover", "OptionButton", btn_hover)
	theme.set_stylebox("pressed", "OptionButton", btn_pressed)

	# ── Separator ────────────────────────────────────────────────────────
	var sep := StyleBoxLine.new()
	sep.color = border
	sep.thickness = 1
	sep.vertical = false
	theme.set_stylebox("separator", "HSeparator", sep)

	# ── ScrollContainer ──────────────────────────────────────────────────
	var scroll := StyleBoxFlat.new()
	scroll.bg_color = Color(0, 0, 0, 0)
	theme.set_stylebox("panel", "ScrollContainer", scroll)

	# ── Save ─────────────────────────────────────────────────────────────
	var err := ResourceSaver.save(theme, "res://resources/themes/default_theme.tres")
	if err == OK:
		print("Theme saved to res://resources/themes/default_theme.tres")
	else:
		print("Failed to save theme: ", err)
