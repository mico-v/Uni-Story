class_name DialogSystem extends RefCounted

## Notification toasts and confirm dialogs for the game UI.
##
## Toast: brief message at top-center that fades out after a delay.
## Uses scene/ui/notification_view.tscn in GlobalUI.
##
## Confirm: modal dialog with title, message, OK and Cancel buttons.
## Binds to ConfirmOverlay/ConfirmPanel nodes defined in game_view.tscn
## under Hud/ModalLayer — these are editor-created nodes with correct
## sizing and theming that work reliably.

signal confirm_result(confirmed: bool)

var _ctx: Node
var _active_toast: Control = null
var _toast_tween: Tween = null

# Confirm dialog nodes (bound from game_view.tscn).
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
func show_toast(message: String, duration: float = 2.0) -> void:
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = null
	if _active_toast and is_instance_valid(_active_toast):
		_active_toast.queue_free()
	_active_toast = null

	var toast: Control = preload("res://scene/ui/notification_view.tscn").instantiate()
	if toast == null:
		return
	var label: Label = toast.get_node_or_null("Margin/Label") as Label
	if label == null:
		toast.queue_free()
		return

	toast.z_index = 1000
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.anchor_top = 0.02
	toast.anchor_bottom = 0.02

	var parent := _get_global_ui_parent()
	if parent:
		parent.add_child(toast)

	label.text = message
	toast.visible = true
	toast.modulate.a = 0.0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.75)
	panel_style.set_corner_radius_all(8)
	toast.add_theme_stylebox_override("panel", panel_style)

	_toast_tween = _ctx.get_tree().create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
		if _active_toast == toast:
			_active_toast = null
	)
	_active_toast = toast


## Show a confirm dialog. Returns a signal that emits confirm_result(true/false).
func show_confirm(title: String, message: String) -> Signal:
	_ensure_confirm()
	if _confirm_panel == null:
		confirm_result.emit(false)
		return confirm_result

	_begin_alert_state()
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
	_end_alert_state()


# ── UI binding ──────────────────────────────────────────────────────────

func _ensure_confirm() -> void:
	if _confirm_ready:
		return
	_confirm_ready = true

	var modal_parent := _get_modal_parent()
	if modal_parent == null:
		return

	_confirm_overlay = modal_parent.get_node_or_null("ConfirmOverlay") as ColorRect
	_confirm_panel = modal_parent.get_node_or_null("ConfirmPanel") as PanelContainer
	if _confirm_panel == null:
		return

	_confirm_title = _confirm_panel.get_node_or_null("VBox/Title") as Label
	_confirm_message = _confirm_panel.get_node_or_null("VBox/Message") as Label
	_confirm_ok = _confirm_panel.get_node_or_null("VBox/Buttons/OK") as Button
	_confirm_cancel = _confirm_panel.get_node_or_null("VBox/Buttons/Cancel") as Button

	if _confirm_ok:
		_confirm_ok.text = _t("alert.confirm", "OK")
		_confirm_ok.pressed.connect(func() -> void: answer_confirm(true))
	if _confirm_cancel:
		_confirm_cancel.text = _t("alert.cancel", "Cancel")
		_confirm_cancel.pressed.connect(func() -> void: answer_confirm(false))

	if _confirm_title:
		_confirm_title.add_theme_font_size_override("font_size", ThemeManager.SIZE_SECTION)
	if _confirm_message:
		_confirm_message.add_theme_font_size_override("font_size", ThemeManager.SIZE_MODE_LABEL)


func _get_modal_parent() -> Node:
	# Bind to game_view.tscn / Hud / ModalLayer where ConfirmOverlay/ConfirmPanel live.
	var game_view = _ctx.get_node_or_null("GameView")
	if game_view is Control:
		var hud = game_view.get_node_or_null("Hud")
		if hud is Control:
			var modal_layer = hud.get_node_or_null("ModalLayer")
			if modal_layer is Control:
				return modal_layer
			return hud
		return game_view
	return null


# ── State management ────────────────────────────────────────────────────

func _begin_alert_state() -> void:
	if _ctx and _ctx.view_manager and _ctx.view_manager.has_method("begin_alert"):
		_ctx.view_manager.begin_alert()


func _end_alert_state() -> void:
	if _ctx and _ctx.view_manager and _ctx.view_manager.has_method("end_alert"):
		_ctx.view_manager.end_alert()


func _get_global_ui_parent() -> Node:
	var global_ui = _ctx.get_node_or_null("GlobalUI")
	if global_ui is Control:
		return global_ui
	var tree := _ctx.get_tree()
	if tree:
		return tree.root
	return null


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)
