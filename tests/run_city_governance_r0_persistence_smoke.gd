extends SceneTree


const WORKER := "res://tests/city_governance_r0_persistence_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := ProjectSettings.globalize_path("user://city_governance_r0_persistence_%d" % OS.get_process_id())
	_remove_tree(save_directory)
	var workers: Array[Dictionary] = []
	for mode in ["A", "B", "C"]:
		workers.append(_run_worker(mode, save_directory))
	for worker in workers:
		print("CITY_GOVERNANCE_WORKER_%s_OUTPUT\n%s" % [worker.mode, worker.output])
	_check(_workers_passed(workers), "独立进程恢复持续短缺、患病、待治理事件与已解决结果")
	_check(str(workers[0].output).contains("diseased=4") and str(workers[1].output).contains("resolved=true") and str(workers[2].output).contains("resolved=1"), "每个进程先读到上一步事实，再推进且不重复扣粮或重抽事件")
	_remove_tree(save_directory)
	if failures.is_empty():
		print("CITY_GOVERNANCE_R0_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	for failure in failures:
		push_error("CITY_GOVERNANCE_R0_PERSISTENCE_SMOKE FAIL: %s" % failure)
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var marker_path := save_directory.path_join("city_governance_worker_%s.result" % mode.to_lower())
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER, "--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory]), output, true)
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {"mode": mode, "exit_code": exit_code, "output": "\n".join(output), "passed": exit_code == 0 and marker == "CITY_GOVERNANCE_WORKER_%s PASS" % mode}


func _workers_passed(workers: Array[Dictionary]) -> bool:
	for worker in workers:
		if not bool(worker.passed):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	for entry in directory.get_files():
		DirAccess.remove_absolute(path.path_join(entry))
	DirAccess.remove_absolute(path)
