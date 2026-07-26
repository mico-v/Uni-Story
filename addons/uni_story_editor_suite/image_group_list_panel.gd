@tool
extends Control

## Bottom panel for managing Image Groups.
##
## Features:
##   - Load/Create ImageGroupList resources
##   - List all groups with entry counts
##   - Validate all entries
##   - Generate snapshots for all groups


var _file_list: ItemList
var _group_list: ItemList
var _load_btn: Button
var _create_btn: Button
var _refresh_btn: Button
var _validate_btn: Button
var _snapshot_all_btn: Button
var _status_label: Label
var _current_list: Resource


func _ready() -> void:
	custom_minimum_size = Vector2(0, 250)

	var main := HSplitContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.split_offset = 300
	add_child(main)

	# Left: file list
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	main.add_child(left)

	var left_header := HBoxContainer.new()
	left.add_child(left_header)

	var left_title := Label.new()
	left_title.text = "ImageGroupList Files"
	left_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_header.add_child(left_title)

	_load_btn = Button.new()
	_load_btn.text = "Load"
	_load_btn.tooltip_text = "Load selected ImageGroupList resource"
	_load_btn.pressed.connect(_load_selected)
	left_header.add_child(_load_btn)

	_create_btn = Button.new()
	_create_btn.text = "Create"
	_create_btn.tooltip_text = "Create a new ImageGroupList resource"
	_create_btn.pressed.connect(_create_new)
	left_header.add_child(_create_btn)

	_file_list = ItemList.new()
	_file_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_file_list)

	# Right: group details
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)

	var toolbar := HBoxContainer.new()
	right.add_child(toolbar)

	var right_title := Label.new()
	right_title.text = "Groups"
	right_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(right_title)

	_refresh_btn = Button.new()
	_refresh_btn.text = "🔄 Refresh"
	_refresh_btn.pressed.connect(_refresh_groups)
	toolbar.add_child(_refresh_btn)

	_validate_btn = Button.new()
	_validate_btn.text = "✓ Validate"
	_validate_btn.pressed.connect(_validate_groups)
	toolbar.add_child(_validate_btn)

	_snapshot_all_btn = Button.new()
	_snapshot_all_btn.text = "📷 Snapshot All"
	_snapshot_all_btn.pressed.connect(_snapshot_all)
	toolbar.add_child(_snapshot_all_btn)

	_group_list = ItemList.new()
	_group_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_group_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_group_list)

	_status_label = Label.new()
	_status_label.text = "Load or create an ImageGroupList to begin."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)

	_scan_files()


func _scan_files() -> void:
	_file_list.clear()
	var dir := DirAccess.open("res://")
	if dir == null:
		return
	_scan_dir_recursive(dir, "res://")


func _scan_dir_recursive(dir: DirAccess, path: String) -> void:
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir() and not file_name.begins_with("."):
			var sub_dir := DirAccess.open(path + file_name + "/")
			if sub_dir:
				_scan_dir_recursive(sub_dir, path + file_name + "/")
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var res := load(path + file_name)
			if res and res.get_script() and res.get_script().resource_path == "res://scripts/resources/image_group_list.gd":
				var idx := _file_list.add_item(file_name)
				_file_list.set_item_metadata(idx, path + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_selected() -> void:
	var selected := _file_list.get_selected_items()
	if selected.is_empty():
		return
	var path: String = _file_list.get_item_metadata(selected[0])
	_current_list = load(path)
	_status_label.text = "Loaded: %s" % path
	_refresh_groups()


func _create_new() -> void:
	_current_list = ResourceLoader.load("res://scripts/resources/image_group_list.gd").new()
	_status_label.text = "Created new ImageGroupList (unsaved)."


func _refresh_groups() -> void:
	_group_list.clear()
	if _current_list == null:
		return
	for i in range(_current_list.groups.size()):
		var group = _current_list.get_group(i)
		if group:
			var label := "%s  (%d entries)" % [group.group_name, group.entry_count()]
			_group_list.add_item(label)
	_status_label.text = "%d groups loaded" % _current_list.groups.size()


func _validate_groups() -> void:
	if _current_list == null:
		return
	var valid := 0
	var invalid := 0
	for group in _current_list.groups:
		if group and group.is_valid():
			valid += 1
		else:
			invalid += 1
	_status_label.text = "Groups: %d valid, %d invalid" % [valid, invalid]


func _snapshot_all() -> void:
	if _current_list == null:
		return
	var count := 0
	for group in _current_list.groups:
		if group and group.entry_count() > 0:
			var entry = group.get_entry(0)
			if entry and entry.full_image:
				var img: Image = entry.full_image.get_image()
				if img:
					var w: int = img.get_width()
					var h: int = img.get_height()
					var max_size := 256
					var scale := min(float(max_size) / w, float(max_size) / h)
					img.resize(int(w * scale), int(h * scale), Image.INTERPOLATE_LANCZOS)
					entry.thumbnail = ImageTexture.create_from_image(img)
					count += 1
	_status_label.text = "Snapshots generated for %d groups" % count
