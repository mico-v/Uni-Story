@tool
extends Control

## Bottom panel UI for the Save Viewer.
##
## Lists save slots, displays parsed JSON content with syntax highlighting,
## shows bookmark metadata and checkpoint state summaries.


const DEFAULT_SAVE_DIR := "user://saves/"
const SLOT_COUNT := 100  # Scan up to 100 slots (covers normal + auto + quick)

var _slot_list: ItemList
var _json_display: TextEdit
var _meta_grid: GridContainer
var _refresh_btn: Button
var _export_btn: Button
var _status_label: Label
var _save_dir: String = DEFAULT_SAVE_DIR
var _slot_data: Dictionary = {}  # slot_idx → parsed Dictionary


func _ready() -> void:
	custom_minimum_size = Vector2(0, 400)

	var main := HSplitContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.split_offset = 250
	add_child(main)

	# --- Left panel: slot list ---
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(220, 0)
	main.add_child(left)

	var header := HBoxContainer.new()
	left.add_child(header)

	var title := Label.new()
	title.text = "Save Slots"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_refresh_btn = Button.new()
	_refresh_btn.text = "↻ Refresh"
	_refresh_btn.tooltip_text = "Scan save directory for all slot files"
	_refresh_btn.pressed.connect(_scan_slots)
	header.add_child(_refresh_btn)

	_slot_list = ItemList.new()
	_slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_list.allow_rmb_select = true
	_slot_list.item_selected.connect(_on_slot_selected)
	left.add_child(_slot_list)

	# --- Right panel: details ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(right)

	# Metadata section
	var meta_label := Label.new()
	meta_label.text = "Bookmark Metadata"
	meta_label.add_theme_font_size_override("font_size", 14)
	right.add_child(meta_label)

	var meta_scroll := ScrollContainer.new()
	meta_scroll.custom_minimum_size = Vector2(0, 100)
	meta_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(meta_scroll)

	_meta_grid = GridContainer.new()
	_meta_grid.columns = 2
	_meta_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_scroll.add_child(_meta_grid)

	# JSON content section
	var json_header := HBoxContainer.new()
	right.add_child(json_header)

	var json_label := Label.new()
	json_label.text = "Save Data (JSON)"
	json_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	json_label.add_theme_font_size_override("font_size", 14)
	json_header.add_child(json_label)

	_export_btn = Button.new()
	_export_btn.text = "Export JSON"
	_export_btn.tooltip_text = "Export selected slot as formatted JSON file"
	_export_btn.pressed.connect(_export_current_slot)
	json_header.add_child(_export_btn)

	_json_display = TextEdit.new()
	_json_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_json_display.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json_display.editable = false
	_json_display.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_json_display.syntax_highlighter = _create_json_highlighter()
	right.add_child(_json_display)

	# Status
	_status_label = Label.new()
	_status_label.text = "Click 'Refresh' to scan save files."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_status_label)

	# Initial scan
	_scan_slots.call_deferred()


func _scan_slots() -> void:
	_slot_list.clear()
	_slot_data.clear()

	var save_path := ProjectSettings.globalize_path(_save_dir)
	var dir := DirAccess.open(save_path)
	if dir == null:
		_status_label.text = "Cannot access save directory: %s" % save_path
		return

	var found := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json") and file_name.begins_with("slot_"):
			var full_path := save_path.path_join(file_name)
			var f := FileAccess.open(full_path, FileAccess.READ)
			if f:
				var text := f.get_as_text()
				f.close()
				var parsed: Variant = JSON.parse_string(text)
				if parsed is Dictionary:
					var slot_match := RegEx.new()
					if slot_match.compile("slot_(\\d+)\\.json") == OK:
						var m := slot_match.search(file_name)
						if m:
							var slot_idx := int(m.get_string(1))
							_slot_data[slot_idx] = parsed

							# Build display label
							var bookmark: Variant = parsed.get("bookmark", {})
							var chapter := ""
							var display := ""
							if bookmark is Dictionary:
								chapter = str(bookmark.get("chapter", ""))
								display = str(bookmark.get("display_name", chapter))
							if display.is_empty():
								chapter = str(parsed.get("chapter", ""))
								display = chapter

							var created := ""
							if bookmark is Dictionary:
								var ts := float(bookmark.get("created_at_unix", 0.0))
								if ts > 0:
									var dt := Time.get_datetime_dict_from_unix_time(int(ts))
									created = "%04d-%02d-%02d %02d:%02d" % [
										dt["year"], dt["month"], dt["day"],
										dt["hour"], dt["minute"],
									]

							var label := "Slot %d" % slot_idx
							if not display.is_empty():
								label += "  —  %s" % display
							if not created.is_empty():
								label += "  [%s]" % created

							_slot_list.add_item(label)
							_slot_list.set_item_metadata(_slot_list.item_count - 1, slot_idx)
							found += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	_status_label.text = "Found %d save slot(s) in %s" % [found, save_path]


func _on_slot_selected(idx: int) -> void:
	var slot_idx: int = _slot_list.get_item_metadata(idx)
	if not _slot_data.has(slot_idx):
		return

	var data: Dictionary = _slot_data[slot_idx]
	_display_metadata(data)
	_display_json(data)


func _display_metadata(data: Dictionary) -> void:
	# Clear
	for child in _meta_grid.get_children():
		child.queue_free()

	var _add_row = func(key: String, value: String):
		var kl := Label.new()
		kl.text = key + ":"
		kl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_meta_grid.add_child(kl)

		var vl := Label.new()
		vl.text = value
		vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_meta_grid.add_child(vl)

	var bookmark: Variant = data.get("bookmark", {})
	if bookmark is Dictionary:
		_add_row.call("Format", str(data.get("format", "bookmark")))
		_add_row.call("Version", str(data.get("version", "?")))
		_add_row.call("Chapter", str(bookmark.get("chapter", "")))
		_add_row.call("Display Name", str(bookmark.get("display_name", "")))
		_add_row.call("Entry Index", str(bookmark.get("entry_index", "")))
		var ts := float(bookmark.get("created_at_unix", 0.0))
		if ts > 0:
			var dt := Time.get_datetime_dict_from_unix_time(int(ts))
			_add_row.call("Created", "%04d-%02d-%02d %02d:%02d:%02d" % [
				dt["year"], dt["month"], dt["day"],
				dt["hour"], dt["minute"], dt["second"],
			])
		_add_row.call("Screenshot", str(bookmark.get("screenshot_path", "(none)")).replace("user:/", "user://"))

		# Checkpoint summary
		var checkpoint: Variant = bookmark.get("checkpoint", {})
		if not (checkpoint is Dictionary):
			checkpoint = data.get("checkpoint", {})
		if checkpoint is Dictionary:
			var state: Variant = checkpoint.get("state", {})
			if state is Dictionary:
				_add_row.call("---", "")
				_add_row.call("Checkpoint state keys", str(state.keys()))
				var dial_count := 0
				if state.has("reached_dialogues"):
					var rd = state["reached_dialogues"]
					if rd is Array:
						dial_count = rd.size()
				var end_count := 0
				if state.has("reached_endings"):
					var re = state["reached_endings"]
					if re is Array:
						end_count = re.size()
				_add_row.call("Reached Dialogues", str(dial_count))
				_add_row.call("Reached Endings", str(end_count))
	else:
		_add_row.call("Format", str(data.get("format", "snapshot")))
		_add_row.call("Version", str(data.get("version", "?")))
		_add_row.call("Chapter", str(data.get("chapter", "")))
		var state: Variant = data.get("state", {})
		if state is Dictionary:
			_add_row.call("State Index", str(state.get("index", "?")))


func _display_json(data: Dictionary) -> void:
	var formatted := JSON.stringify(data, "\t")
	_json_display.text = formatted


func _create_json_highlighter() -> CodeHighlighter:
	var hl := CodeHighlighter.new()

	# JSON keywords (true/false/null) → purple
	hl.add_keyword_color("true", Color(0.8, 0.4, 0.8))
	hl.add_keyword_color("false", Color(0.8, 0.4, 0.8))
	hl.add_keyword_color("null", Color(0.8, 0.4, 0.8))

	# Numbers → light blue
	hl.number_color = Color(0.4, 0.8, 0.9)

	# Strings → yellow-green
	hl.add_color_region('"', '"', Color(0.6, 0.9, 0.4))

	return hl


func _export_current_slot() -> void:
	var selected := _slot_list.get_selected_items()
	if selected.is_empty():
		_status_label.text = "Select a slot to export."
		return

	var slot_idx: int = _slot_list.get_item_metadata(selected[0])
	if not _slot_data.has(slot_idx):
		return

	var data: Variant = _slot_data[slot_idx]
	var formatted := JSON.stringify(data, "\t")

	var dialog := EditorFileDialog.new()
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.title = "Export Slot %d JSON" % slot_idx
	dialog.current_file = "slot_%d_export.json" % slot_idx
	dialog.add_filter("*.json", "JSON File")
	dialog.file_selected.connect(func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(formatted)
			f.close()
			_status_label.text = "Exported slot %d to %s" % [slot_idx, path]
		else:
			_status_label.text = "Failed to write: %s" % path
	)
	dialog.size = Vector2(800, 600)
	dialog.popup_centered_clamped(dialog.size)


func _exit_tree() -> void:
	# Cleanup
	_slot_data.clear()
