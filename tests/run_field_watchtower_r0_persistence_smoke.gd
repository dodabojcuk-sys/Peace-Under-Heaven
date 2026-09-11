extends SceneTree


const WORKER_PATH := "res://tests/field_watchtower_r0_persistence_worker.gd"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := ProjectSettings.globalize_path("user://field_watchtower_r0_persistence_%d" % OS.get_process_id())
	_remove_tree(save_directory)
	var workers: Array[Dictionary] = []
	for mode in ["A", "B", "C"]:
		workers.append(_run_worker(mode, save_directory))
	for worker in workers:
		print("FIELD_WATCHTOWER_R0_WORKER_%s_OUTPUT\n%s" % [worker.mode, worker.output])
	_check(_all_passed(workers), "独立进程覆盖瞭望塔在途、完工和完成态恢复")
	_check(str(workers[0].output).contains("WATCHTOWER_MID phase=TRAVELING") and str(workers[1].output).contains("WATCHTOWER_COMPLETE count=1") and str(workers[2].output).contains("WATCHTOWER_RESTORED_COMPLETE count=1 stable=true"), "跨进程恢复保留工程进度和完成塔，不重复生成")
	_remove_tree(save_directory)
	if failures.is_empty():
		print("FIELD_WATCHTOWER_R0_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_WATCHTOWER_R0_PERSISTENCE_SMOKE FAIL: %s" % failure)
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var marker_path := save_directory.path_join("watchtower_worker_%s.result" % mode.to_lower())
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER_PATH, "--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory]), output, true)
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {"mode": mode, "output": "\n".join(output), "passed": exit_code == 0 and marker == "FIELD_WATCHTOWER_R0_WORKER_%s PASS" % mode}


func _all_passed(workers: Array[Dictionary]) -> bool:
	for worker in workers:
		if not bool(worker.get("passed", false)):
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
