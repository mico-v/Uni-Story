@tool
extends Control

## Bottom panel for managing Music Entries.
##
## Features:
##   - Load/Create MusicEntryList resources
##   - List all entries with metadata
##   - Sequential preview playback
##   - Validate resource references


var plugin: EditorPlugin

var _file_list: ItemList
var _entry_list: ItemList
var _load_btn: Button
var _create_btn: Button
var _preview_btn: Button
var _validate_btn: Button
var _stop_btn: Button
var _status_label: Label
var _current_list: Resource
var _preview_player: AudioStreamPlayer
var _preview_index: int = 0


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
	left_title.text = "MusicEntryList Files"
	left_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_header.add_child(left_title)

	_load_btn = Button.new()
	_load_btn.text = "Load"
	_load_btn.pressed.connect(_load_selected)
	left_header.add_child(_load_btn)

	_create_btn = Button.new()
	_create_btn.text = "Create"
	_create_btn.pressed.connect(_create_new)
	left_header.add_child(_create_btn)

	_file_list = ItemList.new()
	_file_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_file_list)

	# Right: entry details
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)

	var toolbar := HBoxContainer.new()
	right.add_child(toolbar)

	var right_title := Label.new()
	right_title.text = "Music Entries"
	right_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(right_title)

	_preview_btn = Button.new()
	_preview_btn.text = "▶ Preview All"
	_preview_btn.tooltip_text = "Sequential preview of all tracks"
	_preview_btn.pressed.connect(_preview_all)
	toolbar.add_child(_preview_btn)

	_validate_btn = Button.new()
	_validate_btn.text = "✓ Validate"
	_validate_btn.tooltip_text = "Check all audio stream references"
	_validate_btn.pressed.connect(_validate_entries)
	toolbar.add_child(_validate_btn)

	_stop_btn = Button.new()
	_stop_btn.text = "⏹ Stop"
	_stop_btn.pressed.connect(_stop_preview)
	toolbar.add_child(_stop_btn)

	_entry_list = ItemList.new()
	_entry_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_entry_list)

	_status_label = Label.new()
	_status_label.text = "Load or create a MusicEntryList to begin."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)

	# Preview player
	_preview_player = AudioStreamPlayer.new()
	_preview_player.bus = "Music"
	_preview_player.finished.connect(_on_preview_finished)
	add_child(_preview_player)

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
			if res and res.get_script() and res.get_script().resource_path == "res://scripts/resources/music_entry_list.gd":
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
	_refresh_entries()


func _create_new() -> void:
	_current_list = ResourceLoader.load("res://scripts/resources/music_entry_list.gd").new()
	_status_label.text = "Created new MusicEntryList (unsaved)."


func _refresh_entries() -> void:
	_entry_list.clear()
	if _current_list == null:
		return
	for i in range(_current_list.entries.size()):
		var entry = _current_list.get_entry(i)
		if entry:
			var composer_str := ""
			if not entry.composer.is_empty():
				composer_str = " — " + entry.composer
			var label := "%s%s  [%s]" % [entry.display_name, composer_str, entry.category]
			_entry_list.add_item(label)
	_status_label.text = "%d tracks loaded" % _current_list.entries.size()


func _preview_all() -> void:
	if _current_list == null or _current_list.entries.is_empty():
		_status_label.text = "No tracks to preview."
		return
	_preview_index = 0
	_play_current()


func _play_current() -> void:
	if _current_list == null or _preview_index >= _current_list.entries.size():
		_status_label.text = "Preview complete: %d tracks played" % _current_list.entries.size()
		return
	var entry = _current_list.get_entry(_preview_index)
	if entry and entry.audio_stream:
		_preview_player.stream = entry.audio_stream
		_preview_player.play()
		_status_label.text = "[%d/%d] ▶ %s" % [_preview_index + 1, _current_list.entries.size(), entry.display_name]
	else:
		_preview_index += 1
		_play_current()


func _on_preview_finished() -> void:
	_preview_index += 1
	_play_current()


func _stop_preview() -> void:
	if _preview_player.playing:
		_preview_player.stop()
		_status_label.text = "Preview stopped."


func _validate_entries() -> void:
	if _current_list == null:
		return
	var valid := 0
	var invalid := 0
	for entry in _current_list.entries:
		if entry and entry.is_valid():
			valid += 1
		else:
			invalid += 1
	_status_label.text = "Tracks: %d valid, %d invalid" % [valid, invalid]
