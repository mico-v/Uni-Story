class_name TransitionSystem extends RefCounted

## Full-screen transitions (fade to/from black, etc.) via a ColorRect overlay
## registered in ObjectManager under "transition_overlay".

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx


func _overlay() -> ColorRect:
	var o = _ctx.object_manager.objects.get("transition_overlay")
	return o if o is ColorRect else null


func play(kind: String = "fade", duration: float = 0.5) -> void:
	var overlay := _overlay()
	if overlay == null:
		return
	match kind:
		"fade", "fade_out":
			await _fade(overlay, 0.0, 1.0, duration)
		"fade_in":
			await _fade(overlay, 1.0, 0.0, duration)
		"flash":
			await _fade(overlay, 0.0, 1.0, duration * 0.5)
			await _fade(overlay, 1.0, 0.0, duration * 0.5)
		_:
			await _fade(overlay, 0.0, 1.0, duration)


func _fade(overlay: ColorRect, from_a: float, to_a: float, duration: float) -> void:
	overlay.visible = true
	var col := overlay.color
	col.a = from_a
	overlay.color = col
	var t := _ctx.get_tree().create_tween()
	t.tween_property(overlay, "color:a", to_a, max(0.01, duration))
	await t.finished
	if to_a <= 0.0:
		overlay.visible = false
