extends SceneTree


const WORKER_PATH := "res://tests/war_loop_disk_recovery_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := "%s/txwzs-war-loop-disk-%d-%d" % [
		OS.get_temp_dir(), OS.get_process_id(), Time.get_ticks_usec(),
	]
	_require(DirAccess.make_dir_recursive_absolute(save_directory) == OK, "建立隔离攻城磁盘目录")
	if failures.is_empty():
		var a := _run_worker("A", save_directory)
		var b := _run_worker("B", save_directory)
		var c := _run_worker("C", save_directory)
		_require(int(a.exit_code) == 0 and int(b.exit_code) == 0 and int(c.exit_code) == 0, "三个独立 Godot 进程完成攻城磁盘恢复")
		_require(str(a.output).contains("tick=1") and str(b.output).contains("tick=2") and str(c.output).contains("tick=2"), "跨进程输出证明第二个 tick 只由 B 推进一次")
	_finish()


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", WORKER_PATH, "--",
			"--mode=%s" % mode,
			"--txwzs-v5-save-dir=%s" % save_directory,
		]), output, true
	)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WAR_LOOP_DISK_RECOVERY_FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("WAR_LOOP_DISK_RECOVERY PASS assertions=3")
		quit(0)
		return
	for failure in failures:
		push_error("WAR_LOOP_DISK_RECOVERY FAIL: %s" % failure)
	quit(1)
