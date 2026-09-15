extends SceneTree

## R1C 冷恢复验证：用已完成战役的隔离存档目录恢复，
## 断言 phase/建筑/资源恢复一致且不重复发放（不再扣除或再奖励）。

const CITY_SCENE := preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_dir := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save-dir="):
			save_dir = arg.trim_prefix("--save-dir=")
	if save_dir.is_empty():
		push_error("冷恢复验证需要 --save-dir=<隔离存档目录>")
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
	var buildings: int = runtime.data.buildings.size()
	var wood_used: int = int(runtime.data.totals.wood_used)
	var wood_stock: int = int(city.wood)
	await _hold_seconds(2.0)
	_expect(String(runtime.data.phase) == "COMPLETED", "cold restore recovers COMPLETED campaign")
	_expect(runtime.data.buildings.size() == buildings, "cold restore keeps buildings without duplication")
	_expect(int(runtime.data.totals.wood_used) == wood_used, "cold restore does not double-count wood usage")
	_expect(int(city.wood) == wood_stock, "cold restore keeps resource stock stable over idle time")
	var present: bool = city.is_regular_campaign_city_active()
	_expect(not present, "completed campaign presents the permanent main city, not the wartime inner city")
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
