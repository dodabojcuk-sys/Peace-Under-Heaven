extends SceneTree


const WORKER := "res://tests/city_population_pressure_r0_persistence_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := ProjectSettings.globalize_path("user://city_population_pressure_r0_%d" % OS.get_process_id())
	_remove_tree(save_directory)
	var workers: Array[Dictionary] = []
	for mode in ["A", "B", "C"]:
		workers.append(_run_worker(mode, save_directory))
	for worker in workers:
		print("POPULATION_PRESSURE_WORKER_%s_OUTPUT\n%s" % [worker.mode, worker.output])
	_check(_workers_passed(workers), "三个独立进程保存并恢复人口增长、待安置难民、治安事件、治疗与冬季压力")
	var a := str(workers[0].output)
	var b := str(workers[1].output)
	var c := str(workers[2].output)
	_check(a.contains("unsettled=9") and a.contains("growth=750") and b.contains("treatment=500") and c.contains("winter_shortfall=1"), "重复加载保持同一人数、进度、事件身份、治疗进度与冬季缺口")
	var event_a := _field(a, "event=")
	_check(not event_a.is_empty() and _field(b, "event=") == event_a and _field(c, "event=") == event_a, "活动治安事件身份不因独立进程恢复而重抽")
	_remove_tree(save_directory)
	if failures.is_empty():
		print("CITY_POPULATION_PRESSURE_R0_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	for failure in failures:
		push_error("CITY_POPULATION_PRESSURE_R0_PERSISTENCE_SMOKE FAIL: %s" % failure)
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var marker_path := save_directory.path_join("population_pressure_%s.result" % mode.to_lower())
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER, "--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory]), output, true)
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {"mode": mode, "exit_code": exit_code, "output": "\n".join(output), "passed": exit_code == 0 and marker == "POPULATION_PRESSURE_%s PASS" % mode}


func _workers_passed(workers: Array[Dictionary]) -> bool:
	for worker in workers:
		if not bool(worker.passed):
			return false
	return true


func _field(line: String, prefix: String) -> String:
	var start := line.find(prefix)
	if start < 0:
		return ""
	var tail := line.substr(start + prefix.length())
	return tail.get_slice(" ", 0).strip_edges()


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
