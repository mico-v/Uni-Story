extends SceneTree


func _init() -> void:
	var paths := [
		"res://scripts/runtime/nova_animation_compat.gd",
		"res://scripts/runtime/base_block.gd",
	]
	var ok := true
	for path in paths:
		var res := load(path)
		if res == null:
			push_error("LoadRuntimeScriptsTest: failed to load %s" % path)
			ok = false
		else:
			print("LoadRuntimeScriptsTest: loaded %s" % path)
	quit(0 if ok else 1)
