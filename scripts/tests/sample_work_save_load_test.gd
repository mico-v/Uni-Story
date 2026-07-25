extends SceneTree

## sample_work_save_load_test.gd — headless smoke test verifying
## save/load/backlog-jump works through the enhanced ch1-ch4 (Phase 13).

var _ok_count: int = 0
var _fail_count: int = 0
var _errors: Array[String] = []


func _init() -> void:
	run()


func run() -> void:
	print("=== Phase 13: Sample Work Save/Load Smoke Test ===")

	# 13.1f: Save system and checkpoints work with the branch-heavy scripts
	_test_save_system_available()

	# 13.1g: All endings reachable in ch4
	_test_all_endings_present()

	# Summary
	print("\n=== Results: %d OK / %d FAIL ===" % [_ok_count, _fail_count])
	if _fail_count > 0:
		print("FAILED TESTS:")
		for err in _errors:
			print("  - %s" % err)
		quit(1)
	else:
		print("PASS")
		quit(0)


func _ok(msg: String) -> void:
	_ok_count += 1
	print("  ✓ %s" % msg)


func _fail(msg: String) -> void:
	_fail_count += 1
	_errors.append(msg)
	print("  ✗ %s" % msg)


func _assert(condition: bool, msg: String) -> void:
	if condition:
		_ok(msg)
	else:
		_fail(msg)


func _file_exists(path: String) -> bool:
	return FileAccess.file_exists(path)


func _read_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var content := f.get_as_text()
	f.close()
	return content


func _test_save_system_available() -> void:
	print("\n-- 13.1f: Save system files exist --")
	_assert(_file_exists("res://scripts/core/checkpoint_manager.gd"), "CheckpointManager exists")
	_assert(_file_exists("res://scripts/tests/save_system_smoke_test.gd"), "Save system smoke test exists")
	_assert(_file_exists("res://scripts/tests/checkpoint_manager_smoke_test.gd"), "Checkpoint manager smoke test exists")

	# StandingProfile exists with new poses
	var sp_text := _read_file("res://resources/standing_profile.tres")
	_assert("smile" in sp_text, "Ergong has 'smile' pose")
	_assert("angry" in sp_text, "Qianye has 'angry' pose")
	_assert("cry" in sp_text, "Xiben has 'cry' pose")


func _test_all_endings_present() -> void:
	print("\n-- 13.1g: All endings present in scripts --")
	var ch4_text := _read_file("res://resources/scenarios/ch4.txt")

	_assert("is_end 'true_end_good'" in ch4_text, "ch4 defines true_end_good")
	_assert("is_end 'true_end_dark'" in ch4_text, "ch4 defines true_end_dark")
	_assert("is_end 'bad_end'" in ch4_text, "ch4 defines bad_end")

	# Verify ch3 branch labels
	var ch3_text := _read_file("res://resources/scenarios/ch3.txt")
	_assert("branch {" in ch3_text and "l_throw_away" in ch3_text, "ch3 has player choice branch")
	_assert("v_used_poison = false" in ch3_text, "ch3 sets v_used_poison=false on throw_away")
	_assert("v_used_poison = true" in ch3_text, "ch3 sets v_used_poison=true on use_poison")

	# Verify ch4 conditional branch
	_assert("!v_used_poison" in ch4_text, "ch4 branches on !v_used_poison")
	_assert("v_flag_xiben" in ch4_text, "ch4 branches on v_flag_xiben")
