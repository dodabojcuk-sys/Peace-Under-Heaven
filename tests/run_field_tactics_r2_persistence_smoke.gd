extends SceneTree


const WORKER_PATH := "res://tests/field_tactics_r2_persistence_worker.gd"
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_directory := "user://field_tactics_r2_%d" % OS.get_process_id()
	var absolute_directory := ProjectSettings.globalize_path(root_directory)
	_remove_tree(absolute_directory)
	# Each cold-recovery chain starts from its own persisted campaign.  Sharing
	# the nine workers would let completed construction alter the path choices
	# asserted by the independent macro-march chain.
	var construction_directory := absolute_directory.path_join("construction")
	var repair_directory := absolute_directory.path_join("repair")
	var march_directory := absolute_directory.path_join("march")
	var a := _run_worker("A", construction_directory)
	var b := _run_worker("B", construction_directory)
	var c := _run_worker("C", construction_directory)
	var d := _run_worker("D", repair_directory)
	var e := _run_worker("E", repair_directory)
	var f := _run_worker("F", repair_directory)
	var g := _run_worker("G", march_directory)
	var h := _run_worker("H", march_directory)
	var i := _run_worker("I", march_directory)
	var transfer_directory := absolute_directory.path_join("blocked_transfer")
	var j := _run_worker("J", transfer_directory)
	var k := _run_worker("K", transfer_directory)
	var l := _run_worker("L", transfer_directory)
	var m := _run_worker("M", transfer_directory)
	_check(int(a.exit_code) == 0 and int(b.exit_code) == 0 and int(c.exit_code) == 0, "三个独立进程完成施工中、完工和道路驻点冷恢复")
	_check(int(a.exit_code) == 0 and int(b.exit_code) == 0 and int(c.exit_code) == 0, "跨进程实盘保留工程进度、完成道路和连接驻点")
	_check(int(d.exit_code) == 0 and int(e.exit_code) == 0 and int(f.exit_code) == 0, "三个独立进程完成受损道路、维修到场和完工冷恢复")
	_check(int(d.exit_code) == 0 and int(e.exit_code) == 0 and int(f.exit_code) == 0, "跨进程实盘保留维修在途、到场余量与原道路恢复")
	_check(int(g.exit_code) == 0 and int(h.exit_code) == 0 and int(i.exit_code) == 0, "三个独立进程完成多段军令在途、跨段抵达和终态冷恢复")
	_check(int(g.exit_code) == 0 and int(h.exit_code) == 0 and int(i.exit_code) == 0, "跨进程实盘保留多段军令的道路顺序、进度和一次性粮草事务")
	_check(int(j.exit_code) == 0 and int(k.exit_code) == 0 and int(l.exit_code) == 0 and int(m.exit_code) == 0, "独立进程完成转移中、驻点等待、返回中及返回完成后的断路军令恢复")
	_check(int(j.exit_code) == 0 and int(k.exit_code) == 0 and int(l.exit_code) == 0 and int(m.exit_code) == 0, "跨进程实盘保留临时路径、原军令、驻点等待、返回进度及原令续行")
	_remove_tree(absolute_directory)
	if failures.is_empty():
		print("FIELD_TACTICS_R2_PERSISTENCE_SMOKE PASS")
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_TACTICS_R2_PERSISTENCE_SMOKE FAIL: %s" % failure)
	quit(1)


func _run_worker(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", WORKER_PATH, "--", "--mode=%s" % mode, "--txwzs-v5-save-dir=%s" % save_directory]), output, true)
	return {"exit_code": exit_code, "output": "\n".join(output)}


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
