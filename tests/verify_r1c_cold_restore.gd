extends SceneTree

## R1C 冷恢复验证（落盘前 vs 恢复后）：
## 进程 A（可玩链驱动）在 PENDING/COMPLETED/回城时导出 facts JSON；
## 本脚本用正式参数 --txwzs-v5-save-dir 从同一隔离目录恢复，
## 与 facts-completed.json 逐项比较（阶段、结算身份、损益、资源、军队、建筑），
## 再空转两秒二次比对，证明恢复不重复发放、不重复扣减。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var facts_path := ""
var save_dir := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--facts="):
			facts_path = arg.trim_prefix("--facts=")
		elif arg.begins_with("--txwzs-v5-save-dir="):
			save_dir = arg.trim_prefix("--txwzs-v5-save-dir=")
	if facts_path.is_empty() or save_dir.is_empty():
		push_error("冷恢复验证需要 --facts= 与 --txwzs-v5-save-dir=")
		quit(2)
		return
	var facts_file := FileAccess.open(facts_path, FileAccess.READ)
	if facts_file == null:
		push_error("无法读取事实文件：" + facts_path)
		quit(2)
		return
	var expected: Dictionary = JSON.parse_string(facts_file.get_as_text())
	facts_file.close()
	if expected.is_empty():
		push_error("事实文件为空或不是 JSON")
		quit(2)
		return

	root.size = Vector2i(1280, 720)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var runtime: RegularCampaignRuntime = city._regular_campaign
	await _hold_seconds(2.0)

	_expect(String(runtime.data.phase) == str(expected.get("phase", "")), "phase 恢复一致（%s）" % str(expected.get("phase", "")))
	_expect(String(runtime.data.settlement_id) == str(expected.get("settlement_id", "")), "结算身份恢复一致（防重复结算）")
	_expect(int(city.wood) == int(expected.get("home_wood", -1)), "永久主城木材恢复一致")
	_expect(int(city.food) == int(expected.get("home_food", -1)), "永久主城粮食恢复一致")

	var expected_totals: Dictionary = Dictionary(expected.get("totals", {}))
	for key in expected_totals.keys():
		_expect(int(runtime.data.totals.get(key, -1)) == int(expected_totals[key]), "totals.%s 恢复一致" % key)

	var expected_summary: Dictionary = Dictionary(expected.get("summary", {}))
	for key in expected_summary.keys():
		if key == "totals":
			continue
		_expect(str(runtime.data.summary.get(key, "")) == str(expected_summary[key]), "summary.%s 恢复一致" % key)

	_expect(runtime.data.army_ids.size() == (expected.get("army_ids", []) as Array).size(), "归队军队数量恢复一致")
	_expect(runtime.data.buildings.size() == (expected.get("buildings", []) as Array).size(), "建筑记录数量恢复一致")

	# 空转两秒后二次比对：恢复结果在空闲期间保持稳定。
	await _hold_seconds(2.0)
	_expect(String(runtime.data.phase) == str(expected.get("phase", "")), "二次比对：phase 稳定")
	_expect(int(city.wood) == int(expected.get("home_wood", -1)), "二次比对：木材稳定")
	_expect(runtime.data.buildings.size() == (expected.get("buildings", []) as Array).size(), "二次比对：建筑数量稳定")

	print("R1C_COLD ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failures.append(message)
		push_error(message)


func _hold_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
