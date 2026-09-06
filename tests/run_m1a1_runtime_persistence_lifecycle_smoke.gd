extends SceneTree


const WORKER_PATH := "res://tests/m1a1_runtime_persistence_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_directory := "user://m1a1_runtime_persistence_%d" % OS.get_process_id()
	var absolute_directory := ProjectSettings.globalize_path(root_directory)
	_remove_tree(absolute_directory)
	var process_a := _run_worker("A", absolute_directory)
	var process_b := _run_worker("B", absolute_directory)
	var process_c := _run_worker("C", absolute_directory)
	_check(
		int(process_a.exit_code) == 0
			and int(process_b.exit_code) == 0
			and int(process_c.exit_code) == 0,
		"three independent normal-main-scene processes complete the runtime lifecycle"
	)
	_check(
		str(process_a.output).contains("M1A1_RUNTIME_A PASS")
			and str(process_b.output).contains("M1A1_RUNTIME_B PASS")
			and str(process_c.output).contains("M1A1_RUNTIME_C PASS"),
		"each process reports the normal-entry persistence result"
	)
	_check(
		_process_id(str(process_a.output)) > 0
			and _process_id(str(process_b.output)) > 0
			and _process_id(str(process_c.output)) > 0
			and _process_id(str(process_a.output)) != _process_id(str(process_b.output))
			and _process_id(str(process_b.output)) != _process_id(str(process_c.output)),
		"cold-process verification records three distinct Godot PIDs"
	)
	_remove_tree(absolute_directory)
	if failures.is_empty():
		print("M1A1_RUNTIME_PERSISTENCE_LIFECYCLE_SMOKE PASS")
		quit(0)
	else:
		for failure in failures:
			push_error("M1A1_RUNTIME_PERSISTENCE_LIFECYCLE_SMOKE FAIL: %s" % failure)
		quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", WORKER_PATH,
			"--", "--mode=%s" % mode, "--save-dir=%s" % save_directory,
			"--txwzs-v5-save-dir=%s" % save_directory,
		]),
		output,
		true
	)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _process_id(output: String) -> int:
	for line in output.split("\n"):
		if line.begins_with("M1A1_RUNTIME_PID="):
			return int(line.trim_prefix("M1A1_RUNTIME_PID="))
	return 0


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
