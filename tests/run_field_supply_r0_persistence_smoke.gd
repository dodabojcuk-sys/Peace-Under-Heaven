extends SceneTree


const WORKER_PATH := "res://tests/field_supply_r0_persistence_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := ProjectSettings.globalize_path("user://field_supply_r0_persistence_%d" % OS.get_process_id())
	_remove_tree(save_directory)
	var a := _run_worker("A", save_directory)
	var b := _run_worker("B", save_directory)
	var c := _run_worker("C", save_directory)
	# Keep child output visible: a green exit code alone must not hide a missing
	# phase assertion or an early worker return.
	for worker in [a, b, c]:
		print("FIELD_SUPPLY_R0_WORKER_%s_OUTPUT\n%s" % [worker.mode, worker.output])
	_check(_workers_passed([a, b, c]), "三个独立进程覆盖运输前、在途、入库后恢复")
	_check(
		str(a.output).contains("SUPPLY_PRE=20")
			and str(a.output).contains("SUPPLY_MID phase=MOVING")
			and str(b.output).contains("SUPPLY_RESTORED_MID")
			and str(b.output).contains("SUPPLY_DELIVERED deposited=true")
			and str(c.output).contains("SUPPLY_RESTORED_DONE")
			and str(c.output).contains("duplicate_credit=false"),
		"跨进程恢复核对库存、在途进度、一次性入库和完成态不重记"
	)
	_remove_tree(save_directory)
	if failures.is_empty():
		print("FIELD_SUPPLY_R0_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_SUPPLY_R0_PERSISTENCE_SMOKE FAIL: %s" % failure)
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var marker_path := save_directory.path_join("field_supply_worker_%s.result" % mode.to_lower())
	if FileAccess.file_exists(marker_path):
		DirAccess.remove_absolute(marker_path)
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", WORKER_PATH, "--", "--mode=%s" % mode,
			"--txwzs-v5-save-dir=%s" % save_directory,
		]),
		output, true
	)
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	var expected_marker := "FIELD_SUPPLY_R0_WORKER_%s PASS" % mode
	var result := {
		"mode": mode,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"marker": marker,
		"passed": exit_code == 0 and marker == expected_marker,
	}
	if not bool(result.passed):
		push_error("FIELD_SUPPLY_R0_WORKER_%s failed: exit=%d marker=%s\n%s" % [mode, exit_code, marker, String(result.output)])
	return result


func _workers_passed(workers: Array) -> bool:
	for worker in workers:
		if not bool(Dictionary(worker).get("passed", false)):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var child := path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(path)
