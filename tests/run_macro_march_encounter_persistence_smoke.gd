extends SceneTree


const WORKER_PATH := "res://tests/macro_march_encounter_persistence_worker.gd"
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	var root_directory := "user://macro_march_encounter_%d" % OS.get_process_id()
	var save_directory := ProjectSettings.globalize_path(root_directory)
	_remove_tree(save_directory)
	var a := _run_worker("A", save_directory)
	var b := _run_worker("B", save_directory)
	# Keep the complete child output available for review even when the marker and
	# exit status are both green. A process that returns early cannot hide behind
	# the aggregate PASS line.
	print("ENCOUNTER_PERSISTENCE_WORKER_A_OUTPUT\n%s" % str(a.output))
	print("ENCOUNTER_PERSISTENCE_WORKER_B_OUTPUT\n%s" % str(b.output))
	_check(_worker_passed(a) and _worker_passed(b), "两个独立进程完成遭遇结算保存、退出与重开")
	_check(
		str(b.output).contains("ENCOUNTER_PERSISTENCE_RESTORED")
			and str(b.output).contains("replay=false"),
		"重开后保留权威战果，并将历史遭遇初始化为不重播的只读记录"
	)
	_remove_tree(save_directory)
	if failures.is_empty():
		print("MACRO_MARCH_ENCOUNTER_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	for failure in failures:
		push_error("MACRO_MARCH_ENCOUNTER_PERSISTENCE_SMOKE FAIL: %s" % failure)
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var marker_path := save_directory.path_join("encounter_worker_%s.result" % mode.to_lower())
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
	return {
		"mode": mode,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"marker": marker,
	}


func _worker_passed(result: Dictionary) -> bool:
	return int(result.get("exit_code", -1)) == 0 and str(result.get("marker", "")) == "ENCOUNTER_PERSISTENCE_WORKER_%s PASS" % str(result.get("mode", ""))


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
