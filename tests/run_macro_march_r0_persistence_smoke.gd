extends SceneTree


const WORKER_PATH := "res://tests/macro_march_r0_persistence_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_directory := "user://macro_march_r0_%d" % OS.get_process_id()
	var absolute_directory := ProjectSettings.globalize_path(root_directory)
	_remove_tree(absolute_directory)
	var a := _run_worker("A", absolute_directory)
	var b := _run_worker("B", absolute_directory)
	var c := _run_worker("C", absolute_directory)
	_check(
		int(a.exit_code) == 0 and int(b.exit_code) == 0 and int(c.exit_code) == 0,
		"三个独立进程完成受阻、恢复、抵达的隔离磁盘冷恢复链"
	)
	_check(
		str(a.output).contains("MACRO_MARCH_WORKER_A PASS")
			and str(b.output).contains("MACRO_MARCH_WORKER_B PASS")
			and str(c.output).contains("MACRO_MARCH_WORKER_C PASS"),
		"跨进程实盘验证未伪造军令，状态依次为 BLOCKED、恢复、STATIONED"
	)
	if not failures.is_empty():
		print("MACRO_MARCH_WORKER_A_OUTPUT\n%s" % str(a.output))
		print("MACRO_MARCH_WORKER_B_OUTPUT\n%s" % str(b.output))
		print("MACRO_MARCH_WORKER_C_OUTPUT\n%s" % str(c.output))
	_remove_tree(absolute_directory)
	if failures.is_empty():
		print("MACRO_MARCH_R0_PERSISTENCE_SMOKE PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("MACRO_MARCH_R0_PERSISTENCE_SMOKE FAIL: %s" % failure)
		quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", WORKER_PATH, "--", "--mode=%s" % mode,
			"--txwzs-v5-save-dir=%s" % save_directory,
		]),
		output, true
	)
	return {"exit_code": exit_code, "output": "\n".join(output)}


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
