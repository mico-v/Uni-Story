class_name DialogSystem extends RefCounted

## Notification toasts and confirm dialogs for the game UI.
##
## Toast: brief message at top-center that fades out after a delay.
## Confirm: modal dialog with title, message, OK/Cancel, returns a signal.
##
## Usage from NovaScript:
##   <| show_toast("快速存档完成") |>
##   <| var confirmed = await show_confirm("返回标题", "要返回标题界面吗？") |>

signal confirm_result(confirmed: bool)

var _ctx: Node
var _toast_label: Label = null
var _toast_tween: Tween = null
var _confirm_panel: PanelContainer = null
var _confirm_title: Label = null
var _confirm_message: Label = null
var _confirm_ok: Button = null
var _confirm_cancel: Button = null
var _confirm_overlay: ColorRect = null


func _init(ctx: Node) -> void:
	_ctx = ctx


## Show a brief notification toast at the top of the screen.
## Auto-fades out after `duration` seconds.
func show_toast(message: String, duration: float = 2.0) -> void:
	_ensure_toast()
	if _toast_label == null:
		return
	# Kill any running toast fade.
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = message
	_toast_label.modulate.a = 1.0
	_toast_label.visible = true
	_toast_tween = _ctx.get_tree().create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void:
		_toast_label.visible = false
	)


## Show a confirm dialog. Returns a signal that emits `confirm_result(true/false)`.
## The caller should `await` the signal.
func show_confirm(title: String, message: String) -> Signal:
	_ensure_confirm()
	if _confirm_panel == null:
		confirm_result.emit(false)
		return confirm_result
	if _confirm_title:
		_confirm_title.text = title
	if _confirm_message:
		_confirm_message.text = message
	if _confirm_overlay:
		_confirm_overlay.visible = true
	_confirm_panel.visible = true
	return confirm_result


## Programmatically answer the current confirm dialog.
func answer_confirm(confirmed: bool) -> void:
	if _confirm_panel and _confirm_panel.visible:
		_hide_confirm()
		confirm_result.emit(confirmed)


func _hide_confirm() -> void:
	if _confirm_panel:
		_confirm_panel.visible = false
	if _confirm_overlay:
		_confirm_overlay.visible = false


# ── Internal UI creation ──────────────────────────────────────────────

func _ensure_toast() -> void:
	if _toast_label != null:
		return
	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.position.y = 20
	_toast_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add a background panel for readability.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_ui_parent().add_child(bg)
	bg.add_child(_toast_label)
	# Size the background.
	bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg.custom_minimum_size = Vector2(300, 40)
	bg.position.y = 16
	bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _ensure_confirm() -> void:
	if _confirm_panel != null:
		return
	var parent := _get_ui_parent()
	# Overlay (blocks input to the rest of the UI).
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.color = Color(0, 0, 0, 0.4)
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.visible = false
	parent.add_child(_confirm_overlay)
	# Panel.
	_confirm_panel = PanelContainer.new()
	_confirm_panel.visible = false
	_confirm_panel.custom_minimum_size = Vector2(400, 200)
	_confirm_panel.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_confirm_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(_confirm_panel)
	# Layout.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_confirm_panel.add_child(vbox)
	_confirm_title = Label.new()
	_confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_confirm_title)
	_confirm_message = Label.new()
	_confirm_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_message.add_theme_font_size_override("font_size", 20)
	_confirm_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_confirm_message)
	# Buttons.
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	_confirm_ok = Button.new()
	_confirm_ok.text = "OK"
	_confirm_ok.custom_minimum_size = Vector2(120, 40)
	_confirm_ok.pressed.connect(func() -> void: answer_confirm(true))
	hbox.add_child(_confirm_ok)
	_confirm_cancel = Button.new()
	_confirm_cancel.text = "Cancel"
	_confirm_cancel.custom_minimum_size = Vector2(120, 40)
	_confirm_cancel.pressed.connect(func() -> void: answer_confirm(false))
	hbox.add_child(_confirm_cancel)


func _get_ui_parent() -> Control:
	var game_view = _ctx.get_node_or_null("GameView")
	if game_view is Control:
		var hud = game_view.get_node_or_null("Hud")
		if hud is Control:
			return hud
		return game_view
	return _ctx.get_tree().root
