extends SceneTree


const WORKER_PATH := "res://tests/wartime_defense_persistence_worker.gd"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := "%s/txwzs-spatial-defense-%d-%d" % [OS.get_temp_dir(), OS.get_process_id(), Time.get_ticks_usec()]
	_require(DirAccess.make_dir_recursive_absolute(save_directory) == OK, "建立隔离宏观围城存档目录")
	var outputs: Array[Dictionary] = []
	if failures.is_empty():
		for mode in ["A", "B", "C", "D"]:
			outputs.append(_run_worker(mode, save_directory))
	for index in outputs.size():
		var result: Dictionary = outputs[index]
		var mode: String = ["A", "B", "C", "D"][index]
		_require(int(result.get("exit_code", -1)) == 0, "独立进程 %s 成功退出：%s" % [mode, str(result.get("output", ""))])
		_require(str(result.get("output", "")).contains("WARTIME_DEFENSE_DISK_WORKER_%s PASS" % mode), "独立进程 %s 输出完整成功标记" % mode)
	_finish()


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER_PATH,
		"--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory,
	]), output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WARTIME_DEFENSE_PERSISTENCE_FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("WARTIME_DEFENSE_PERSISTENCE PASS assertions=9")
		quit(0)
		return
	quit(1)
