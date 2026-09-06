extends SceneTree


const WORKER_PATH := "res://tests/war_loop_arrival_persistence_worker.gd"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := "%s/txwzs-war-loop-arrival-%d-%d" % [OS.get_temp_dir(), OS.get_process_id(), Time.get_ticks_usec()]
	_require(DirAccess.make_dir_recursive_absolute(save_directory) == OK, "建立隔离敌城抵达存档目录")
	if failures.is_empty():
		var a := _run_worker("A", save_directory)
		var b := _run_worker("B", save_directory)
		var c := _run_worker("C", save_directory)
		_require(int(a.exit_code) == 0 and int(b.exit_code) == 0 and int(c.exit_code) == 0, "敌城抵达、首城占领、即时招降均在独立进程立即恢复")
		_require(str(a.output).contains("WAR_LOOP_ARRIVAL_A") and str(b.output).contains("WAR_LOOP_ARRIVAL_B") and str(c.output).contains("WAR_LOOP_ARRIVAL_C"), "跨进程输出记录每个关键发布阶段")
	_finish()


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER_PATH, "--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory]), output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


func _require(condition: bool, description: String) -> void:
	if condition:
		return
	failures.append(description)
	push_error("WAR_LOOP_ARRIVAL_PERSISTENCE_FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("WAR_LOOP_ARRIVAL_PERSISTENCE PASS assertions=3")
		quit(0)
		return
	quit(1)
