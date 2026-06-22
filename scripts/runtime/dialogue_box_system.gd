class_name DialogueBoxSystem extends RefCounted

## Handles `set_box(pos_name)` — repositions the dialogue box using anchor
## presets. The box Control is registered in ObjectManager under "default_box".

const PRESETS := {
	"bottom":  [0.1, 0.9, 0.72, 0.96],
	"default": [0.1, 0.9, 0.72, 0.96],
	"top":     [0.1, 0.9, 0.05, 0.32],
	"center":  [0.1, 0.9, 0.40, 0.66],
	"left":    [0.02, 0.46, 0.72, 0.96],
	"right":   [0.54, 0.98, 0.72, 0.96],
	"full":    [0.05, 0.95, 0.10, 0.95],
}

var _ctx: Node
var _current_preset: String = "bottom"
var _gradient_overlay: ColorRect


func _init(ctx: Node) -> void:
	_ctx = ctx


func _box() -> Control:
	var b = _ctx.object_manager.objects.get("default_box")
	return b if b is Control else null


func set_box(pos_name: Variant = "bottom") -> void:
	var box := _box()
	if box == null:
		return
	var key := str(pos_name) if pos_name != null else "hide"
	if key == "hide" or key == "":
		box.visible = false
		_current_preset = "hide"
		return
	box.visible = true
	_current_preset = key
	_ensure_gradient_overlay(box)
	var a: Array = PRESETS.get(key, PRESETS["bottom"])
	box.anchor_left = a[0]
	box.anchor_right = a[1]
	box.anchor_top = a[2]
	box.anchor_bottom = a[3]
	box.offset_left = 0
	box.offset_right = 0
	box.offset_top = 0
	box.offset_bottom = 0


func _ensure_gradient_overlay(box: Control) -> void:
	if _gradient_overlay and is_instance_valid(_gradient_overlay):
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.93, 0.98, 0.82)
	sb.border_width_top = 2
	sb.border_color = Color(0.88, 0.78, 0.92, 0.6)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.content_margin_left = 8.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 8.0
	sb.content_margin_bottom = 8.0
	sb.shadow_color = Color(0, 0, 0, 0.1)
	sb.shadow_size = 6
	if box is Panel:
		box.add_theme_stylebox_override("panel", sb)
	_gradient_overlay = ColorRect.new()
	_gradient_overlay.visible = false
	box.add_child(_gradient_overlay)


func set_opacity(value: float) -> void:
	var box := _box()
	if box == null:
		return
	box.modulate.a = clampf(value, 0.0, 1.0)


func snapshot() -> Dictionary:
	return {"preset": _current_preset}


func restore(data: Dictionary) -> void:
	var preset: String = str(data.get("preset", "bottom"))
	set_box(preset)
