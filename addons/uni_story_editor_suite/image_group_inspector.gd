@tool
extends EditorInspectorPlugin

## Inspector plugin for ImageGroup resources.
##
## Adds a "Generate Snapshot" button that renders a preview
## of the first CG entry's full image at the correct aspect ratio.


func _can_handle(object: Object) -> bool:
	if object is Resource:
		var script := object.get_script()
		if script:
			return script.resource_path in [
				"res://scripts/resources/image_group.gd",
				"res://scripts/resources/image_group_list.gd",
			]
	return false


func _parse_begin(object: Object) -> void:
	if not (object is Resource):
		return

	# Generate Snapshot button
	var snap_btn := Button.new()
	snap_btn.text = "📷 Generate Snapshot"
	snap_btn.tooltip_text = "Generate a thumbnail snapshot from this group's first entry"
	snap_btn.pressed.connect(func():
		if object.has_method("get_entry"):
			var entry = object.get_entry(0)
			if entry and entry.full_image:
				var img: Image = entry.full_image.get_image()
				if img:
					# Resize to thumbnail maintaining aspect ratio
					var max_size := 256
					var w: int = img.get_width()
					var h: int = img.get_height()
					var scale_x := float(max_size) / float(w)
					var scale_y := float(max_size) / float(h)
					var scale := min(scale_x, scale_y)
					var new_w := int(w * scale)
					var new_h := int(h * scale)
					img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
					var tex := ImageTexture.create_from_image(img)
					entry.thumbnail = tex
					print("[ImageGroupInspector] Snapshot generated: %dx%d → %dx%d" % [w, h, new_w, new_h])
	)
	add_custom_control(snap_btn)

	# Validate button
	var validate_btn := Button.new()
	validate_btn.text = "✓ Validate Entries"
	validate_btn.tooltip_text = "Check that all entries have valid images"
	validate_btn.pressed.connect(func():
		if object.has_method("entry_count"):
			var count: int = object.entry_count()
			var valid := 0
			var invalid := 0
			for i in range(count):
				var entry = object.get_entry(i)
				if entry and entry.is_valid():
					valid += 1
				else:
					invalid += 1
			print("[ImageGroupInspector] %s: %d valid, %d invalid out of %d entries" % [
				object.resource_name, valid, invalid, count,
			])
	)
	add_custom_control(validate_btn)
