class_name DialogSystem extends RefCounted

## Notification toasts and confirm dialogs for the game UI.
##
## Toast: brief message at top-center that fades out after a delay.
## Confirm: modal dialog loaded from scene/ui/confirm_dialog.tscn.
##
## Usage from NovaScript:
##   <| show_toast("快速存档完成") |>
##   <| var confirmed = await show_confirm("返回标题", "要返回标题界面吗？") |>

signal confirm_result(confirmed: bool)

const CONFIRM_SCENE_PATH := "res://scene/ui/confirm_dialog.tscn"

var _ctx: Node
var _toast_label: Label = null
var _toast_tween: Tween = null
var _confirm_root: Control = null
var _confirm_overlay: ColorRect = null
var _confirm_panel: PanelContainer = null
var _confirm_title: Label = null
var _confirm_message: Label = null
var _confirm_ok: Button = null
var _confirm_cancel: Button = null


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
	if _confirm_root:
		_confirm_root.visible = false


# ── Internal UI creation ──────────────────────────────────────────────

func _ensure_toast() -> void:
	if _toast_label != null:
		return
	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Add a background panel for readability.
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_get_ui_parent().add_child(bg)
	bg.add_child(_toast_label)
	# Use anchors for viewport-adaptive positioning (top center, 2% from top).
	bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bg.anchor_top = 0.02
	bg.anchor_bottom = 0.02
	bg.custom_minimum_size = Vector2(300, 40)
	bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _ensure_confirm() -> void:
	if _confirm_root != null:
		return
	var scene := load(CONFIRM_SCENE_PATH) as PackedScene
	if scene == null:
		push_error("DialogSystem: cannot load confirm scene: %s" % CONFIRM_SCENE_PATH)
		return
	_confirm_root = scene.instantiate()
	_get_ui_parent().add_child(_confirm_root)
	_confirm_root.visible = false
	# Bind node references.
	_confirm_overlay = _confirm_root.get_node("Overlay")
	_confirm_panel = _confirm_root.get_node("Panel")
	_confirm_title = _confirm_root.get_node("Panel/VBox/Title")
	_confirm_message = _confirm_root.get_node("Panel/VBox/Message")
	_confirm_ok = _confirm_root.get_node("Panel/VBox/Buttons/OK")
	_confirm_cancel = _confirm_root.get_node("Panel/VBox/Buttons/Cancel")
	# Set i18n text and connect signals.
	_confirm_ok.text = _t("alert.confirm", "OK")
	_confirm_cancel.text = _t("alert.cancel", "Cancel")
	_confirm_title.add_theme_font_size_override("font_size", 24)
	_confirm_message.add_theme_font_size_override("font_size", 20)
	_confirm_ok.pressed.connect(func() -> void: answer_confirm(true))
	_confirm_cancel.pressed.connect(func() -> void: answer_confirm(false))


func _get_ui_parent() -> Node:
	var game_view = _ctx.get_node_or_null("GameView")
	if game_view is Control:
		var hud = game_view.get_node_or_null("Hud")
		if hud is Control:
			return hud
		return game_view
	return _ctx.get_tree().root


func _t(key: String, fallback: String = "") -> String:
	if _ctx == null or _ctx.i18n == null:
		return fallback
	return _ctx.i18n.t(key, fallback)
