class_name CameraSystem extends RefCounted

## A logical 2D camera implemented by transforming a "world" container that
## holds the display objects. move_camera shifts/zooms/rotates that container.
## The world node is registered in ObjectManager under "world".

var _ctx: Node


func _init(ctx: Node) -> void:
	_ctx = ctx


func _world() -> Node2D:
	var objects: Dictionary = _ctx.object_manager.objects
	var w = objects.get("world")
	return w if w is Node2D else null


func move_camera(coord: Variant, scale = null, angle = null, duration: float = 0.0) -> void:
	var world := _world()
	if world == null:
		return

	var target_pos := world.position
	var target_scale := world.scale
	var target_rot := world.rotation_degrees

	if coord is Array:
		var arr := coord as Array
		if arr.size() >= 2:
			# Camera position moves the world the opposite way.
			target_pos = -Vector2(float(arr[0]), float(arr[1]))
		if scale == null and arr.size() > 2 and (arr[2] is int or arr[2] is float):
			scale = float(arr[2])
		if angle == null and arr.size() > 4:
			angle = arr[4]
	elif coord is Vector2:
		target_pos = -coord

	if scale != null and (scale is int or scale is float):
		target_scale = Vector2(float(scale), float(scale))
	if angle != null:
		if angle is int or angle is float:
			target_rot = float(angle)
		elif angle is Vector3:
			target_rot = angle.z

	if duration > 0.0:
		var t := _ctx.get_tree().create_tween().set_parallel(true)
		t.tween_property(world, "position", target_pos, duration)
		t.tween_property(world, "scale", target_scale, duration)
		t.tween_property(world, "rotation_degrees", target_rot, duration)
	else:
		world.position = target_pos
		world.scale = target_scale
		world.rotation_degrees = target_rot
