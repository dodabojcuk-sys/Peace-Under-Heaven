extends SceneTree


const WORKER_PATH := "res://tests/wartime_defense_persistence_worker.gd"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var repair_save_directory := "%s/txwzs-wartime-defense-repair-%d-%d" % [OS.get_temp_dir(), OS.get_process_id(), Time.get_ticks_usec()]
	var victory_save_directory := "%s/txwzs-wartime-defense-victory-%d-%d" % [OS.get_temp_dir(), OS.get_process_id(), Time.get_ticks_usec()]
	_require(DirAccess.make_dir_recursive_absolute(repair_save_directory) == OK, "建立维修链隔离守城存档目录")
	_require(DirAccess.make_dir_recursive_absolute(victory_save_directory) == OK, "建立胜利链隔离守城存档目录")
	var workers: Array[Dictionary] = []
	for mode in ["A", "B", "C", "D", "E"]:
		workers.append(_run_worker(mode, repair_save_directory))
	for mode in ["F", "G"]:
		workers.append(_run_worker(mode, victory_save_directory))
	for worker in workers:
		print("WARTIME_DEFENSE_DISK_WORKER_%s_OUTPUT\n%s" % [worker.mode, worker.output])
		_require(bool(worker.passed), "独立进程 %s 退出、完成标记和断言均通过" % worker.mode)
	_remove_tree(repair_save_directory)
	_remove_tree(victory_save_directory)
	if failures.is_empty():
		print("WARTIME_DEFENSE_PERSISTENCE_SMOKE PASS assertions=8")
		quit(0)
		return
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var marker_path := save_directory.path_join("wartime_defense_worker_%s.result" % mode.to_lower())
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER_PATH,
		"--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory,
	]), output, true)
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {
		"mode": mode,
		"output": "\n".join(output),
		"passed": exit_code == 0 and marker == "WARTIME_DEFENSE_DISK_WORKER_%s PASS" % mode,
	}


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WARTIME_DEFENSE_PERSISTENCE_FAIL: %s" % description)


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
