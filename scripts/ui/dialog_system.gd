class_name DialogSystem extends RefCounted

## Notification toasts and confirm dialogs for the game UI.
##
## Toast: brief message at top-center that fades out after a delay.
## Confirm: modal dialog defined in game_view.tscn (Hud/ConfirmOverlay + Hud/ConfirmPanel).
##
## Usage from NovaScript:
##   <| show_toast("快速存档完成") |>
##   <| var confirmed = await show_confirm("返回标题", "要返回标题界面吗？") |>

signal confirm_result(confirmed: bool)

var _ctx: Node
var _toast_label: Label = null
var _toast_tween: Tween = null
var _confirm_overlay: ColorRect = null
var _confirm_panel: PanelContainer = null
var _confirm_title: Label = null
var _confirm_message: Label = null
var _confirm_ok: Button = null
var _confirm_cancel: Button = null
var _confirm_ready: bool = false


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


# ── Internal UI binding ──────────────────────────────────────────────

func _ensure_toast() -> void:
	if _toast_label != null and is_instance_valid(_toast_label):
		return
	var toast := preload("res://scene/ui/toast.tscn").instantiate()
	_toast_label = toast.get_node("Label")
	var parent := _get_toast_parent()
	if parent:
		parent.add_child(toast)
		if toast is Control:
			toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
			toast.z_index = 1000
			toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
			toast.anchor_top = 0.02
			toast.anchor_bottom = 0.02


func _ensure_confirm() -> void:
	if _confirm_ready:
		return
	_confirm_ready = true
	# Bind to nodes defined in game_view.tscn under Hud.
	var hud := _get_ui_parent()
	if hud == null:
		push_error("DialogSystem: cannot find UI parent for confirm dialog")
		return
	_confirm_overlay = hud.get_node_or_null("ConfirmOverlay")
	_confirm_panel = hud.get_node_or_null("ConfirmPanel")
	if _confirm_panel == null:
		push_error("DialogSystem: ConfirmPanel not found under Hud")
		return
	_confirm_title = _confirm_panel.get_node_or_null("VBox/Title")
	_confirm_message = _confirm_panel.get_node_or_null("VBox/Message")
	_confirm_ok = _confirm_panel.get_node_or_null("VBox/Buttons/OK")
	_confirm_cancel = _confirm_panel.get_node_or_null("VBox/Buttons/Cancel")
	# Apply i18n and connect button signals.
	if _confirm_ok:
		_confirm_ok.text = _t("alert.confirm", "OK")
		_confirm_ok.pressed.connect(func() -> void: answer_confirm(true))
	if _confirm_cancel:
		_confirm_cancel.text = _t("alert.cancel", "Cancel")
		_confirm_cancel.pressed.connect(func() -> void: answer_confirm(false))
	if _confirm_title:
		_confirm_title.add_theme_font_size_override("font_size", 24)
	if _confirm_message:
		_confirm_message.add_theme_font_size_override("font_size", 20)


func _get_ui_parent() -> Node:
	var game_view = _ctx.get_node_or_null("GameView")
	if game_view is Control:
		var hud = game_view.get_node_or_null("Hud")
		if hud is Control:
			return hud
		return game_view
	return _ctx.get_tree().root


func _get_toast_parent() -> Node:
	var global_ui = _ctx.get_node_or_null("GlobalUI")
	if global_ui is Control:
		return global_ui
	return _ctx.get_tree().root


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)
