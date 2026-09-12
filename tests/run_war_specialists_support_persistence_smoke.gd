extends SceneTree


const WORKER_PATH := "res://tests/war_specialists_support_persistence_worker.gd"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := "%s/txwzs-war-specialists-support-%d-%d" % [OS.get_temp_dir(), OS.get_process_id(), Time.get_ticks_usec()]
	_require(DirAccess.make_dir_recursive_absolute(save_directory) == OK, "建立隔离存档目录")
	var outputs: Array[Dictionary] = []
	for mode in ["A", "B", "C"]:
		outputs.append(_run_worker(mode, save_directory))
	for index in outputs.size():
		var mode: String = ["A", "B", "C"][index]
		var result := outputs[index]
		print("WAR_SPECIALISTS_SUPPORT_%s_OUTPUT\n%s" % [mode, result.output])
		_require(int(result.exit_code) == 0, "独立进程 %s 成功退出" % mode)
		_require(str(result.output).contains("WAR_SPECIALISTS_SUPPORT_WORKER_%s PASS" % mode), "独立进程 %s 输出完整成功标记" % mode)
		_require(not str(result.output).contains("SCRIPT ERROR") and not str(result.output).contains("Parse Error"), "独立进程 %s 没有脚本错误" % mode)
	_remove_tree(save_directory)
	if failures.is_empty():
		print("WAR_SPECIALISTS_SUPPORT_PERSISTENCE_SMOKE PASS assertions=10")
		quit(0)
		return
	quit(1)


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
	push_error("WAR_SPECIALISTS_SUPPORT_PERSISTENCE_FAIL: %s" % description)


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	for entry in directory.get_files():
		DirAccess.remove_absolute(path.path_join(entry))
	DirAccess.remove_absolute(path)
