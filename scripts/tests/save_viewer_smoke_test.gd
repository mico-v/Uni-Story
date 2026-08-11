extends SceneTree

## Headless smoke coverage for the Save Viewer editor panel
## (scripts/editor/save_viewer_panel.gd): verifies it scans a user:// save
## directory, parses >= 3 bookmark-format save files, keys them by slot index,
## and renders metadata/JSON without crashing. A malformed slot file must be
## skipped rather than abort the scan.

const FIXTURE_DIR := "user://tests/save_viewer_smoke"
const SAVE_VERSION := 2
const SaveViewerPanelScript := preload("res://scripts/editor/save_viewer_panel.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_clean_fixture_dir()
	_write_fixture("slot_0.json", _make_save(0, "ch1", "第一章", 12))
	_write_fixture("slot_1.json", _make_save(1, "ch2", "第二章", 34))
	_write_fixture("slot_2.json", _make_save(2, "ch4", "终章·多结局", 56))
	# Malformed JSON: must be skipped, not crash the scan.
	var bad := FileAccess.open(FIXTURE_DIR.path_join("slot_9.json"), FileAccess.WRITE)
	if bad:
		bad.store_string("{ this is not valid json ")
		bad.close()

	var panel := SaveViewerPanelScript.new()
	panel._save_dir = FIXTURE_DIR
	root.add_child(panel)
	# Let _ready() build the UI and its deferred _scan_slots() settle.
	await process_frame
	await process_frame

	var slot_data: Dictionary = panel._slot_data
	var slot_list: ItemList = panel._slot_list
	_expect(slot_data.size() == 3, "SaveViewer should parse 3 valid slots, got %d" % slot_data.size())
	_expect(slot_list.item_count == 3, "SaveViewer slot list should show 3 entries, got %d" % slot_list.item_count)
	_expect(not slot_data.has(9), "malformed slot_9.json should be skipped")

	for slot_idx in [0, 1, 2]:
		_expect(slot_data.has(slot_idx), "parsed data should be keyed by slot index %d" % slot_idx)
		var data: Dictionary = slot_data.get(slot_idx, {})
		_expect(str(data.get("format", "")) == "bookmark", "slot %d should be bookmark format" % slot_idx)
		_expect(int(data.get("version", 0)) == SAVE_VERSION, "slot %d should carry save version %d" % [slot_idx, SAVE_VERSION])
		var bookmark: Variant = data.get("bookmark", {})
		_expect(bookmark is Dictionary and not (bookmark as Dictionary).is_empty(), "slot %d should include bookmark metadata" % slot_idx)

	# Metadata / JSON render paths must tolerate parsed data without crashing.
	var first: Dictionary = slot_data.get(0, {})
	panel._display_metadata(first)
	_expect(panel._meta_grid.get_child_count() > 0, "metadata grid should be populated after display")
	panel._display_json(first)
	_expect(not panel._json_display.text.is_empty(), "JSON display should render formatted save data")

	panel.queue_free()
	if _failures.is_empty():
		print("SaveViewerSmokeTest: OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		push_error("SaveViewerSmokeTest: FAILED")
		quit(1)


## Build a realistic bookmark-format save envelope. Checkpoint uses the real
## snapshot shape (dialogues/endings dictionaries) so the panel's defensive
## reads exercise the same keys SaveSystem writes.
func _make_save(slot: int, chapter: String, display_name: String, entry_index: int) -> Dictionary:
	var state := {
		"dialogues": {("%s:%d" % [chapter, entry_index]): true},
		"endings": {"true_end_good": true} if slot == 2 else {},
	}
	return {
		"format": "bookmark",
		"version": SAVE_VERSION,
		"bookmark": {
			"slot": slot,
			"chapter": chapter,
			"display_name": display_name,
			"entry_index": entry_index,
			"created_at_unix": 1700000000.0 + slot,
			"screenshot_path": "user://saves/thumbnails/slot_%d.png" % slot,
			"checkpoint": {"state": state},
		},
		"checkpoint": {"state": state},
	}


func _write_fixture(file_name: String, data: Dictionary) -> void:
	var f := FileAccess.open(FIXTURE_DIR.path_join(file_name), FileAccess.WRITE)
	if f == null:
		_failures.append("failed to write fixture %s (error %d)" % [file_name, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _clean_fixture_dir() -> void:
	var abs := ProjectSettings.globalize_path(FIXTURE_DIR)
	DirAccess.make_dir_recursive_absolute(abs)
	var dir := DirAccess.open(abs)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			DirAccess.remove_absolute(abs.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
