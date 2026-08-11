@tool
extends EditorScript

## One-shot maintenance tool: re-save every .tscn/.tres under res:// in EDITOR
## mode so Godot regenerates base31-valid UIDs (in-file + sidecar) and keeps
## cross-references consistent.
##
## HOW TO RUN (important):
##   This is an EditorScript. It MUST be executed from inside the Godot editor:
##   open the script and choose Editor > Run Script (or the "Run" button in the
##   script editor). That runs _run() in the editor context, where ResourceSaver
##   PINs valid UIDs.
##
##   It CANNOT be run via `godot --script ...`: that flag requires the script to
##   extend SceneTree/MainLoop, and a SceneTree script runs in GAME mode where
##   ResourceSaver STRIPS UIDs instead of generating them. So the headless CLI
##   cannot pin UIDs -- use the editor for that step.
##
##   The source .tscn/.tres files currently resolve by path (no uid= header),
##   which is valid and loads fine. Run this tool only if you want Godot to pin
##   explicit UIDs for move/rename robustness.

func _run() -> void:
	var roots := PackedStringArray(["res://scene", "res://resources"])
	var saved := 0
	var failed := 0
	for root in roots:
		saved += _resave_dir(root, failed)
	print("RESAVE_EDITOR_DONE saved=%d failed=%d" % [saved, failed])


func _resave_dir(root: String, failed: int) -> int:
	var count := 0
	var da := DirAccess.open(root)
	if da == null:
		push_error("cannot open " + root)
		return 0
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name == "." or name == "..":
			name = da.get_next()
			continue
		var full := root.path_join(name)
		if da.current_is_dir():
			count += _resave_dir(full, failed)
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			if _resave_one(full) == OK:
				count += 1
			else:
				failed += 1
		name = da.get_next()
	da.list_dir_end()
	return count


func _resave_one(path: String) -> int:
	var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		push_error("load failed: " + path)
		return ERR_CANT_OPEN
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("save failed (%d): %s" % [err, path])
	return err
