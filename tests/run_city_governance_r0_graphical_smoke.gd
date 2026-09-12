extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var evidence_directory := ""
var save_directory := ""
var failures: Array[String] = []


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CITY_GOVERNANCE_R0_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-city-governance-evidence-dir=")
	save_directory = _argument_value("--txwzs-v5-save-dir=")
	if save_directory.is_empty():
		push_error("CITY_GOVERNANCE_R0_GRAPHICAL_SMOKE requires --txwzs-v5-save-dir=<empty isolated directory>")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	for size in [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var data := await _new_city(size)
		_check(data.workspace.is_visible_in_tree() and data.workspace.get_global_rect().end.y <= Vector2(size).y, "治理区在 %s 内完整可见" % size)
		_capture("city-governance-default-%dx%d.png" % [size.x, size.y])
		await _drop_city(data.scene)

	var pressure := await _new_city(Vector2i(1280, 720))
	var population_before: Dictionary = pressure.city.get_population_recovery_read_model()
	pressure.medical_minus.pressed.emit()
	await process_frame
	var population_after: Dictionary = pressure.city.get_population_recovery_read_model()
	_check(int(population_after.medical_workers) == int(population_before.medical_workers) - 1 and int(population_after.available) == int(population_before.available) + 1, "可见岗位按钮通过正式 UI 信号调整唯一人口状态")
	pressure.city.food = 0
	for _day in range(3):
		pressure.city._advance_day_boundary(true)
	pressure.city._refresh_city_ui()
	await _frames(2)
	var stressed: Dictionary = pressure.city.get_city_governance_read_model()
	_check(int(stressed.diseased_count) > 0 and StringName(Dictionary(stressed.active_event).phase) == &"ACTIVE" and pressure.event_button.is_visible_in_tree() and not pressure.event_button.disabled, "持续短缺在现有治理区显示疾病、原因与可用治理行动")
	_capture("city-governance-pressure-action-1280x720.png")
	pressure.city.food = 5
	var food_before: int = pressure.city.food
	pressure.event_button.pressed.emit()
	await _frames(2)
	var resolved: Dictionary = pressure.city.get_city_governance_read_model()
	_check(StringName(Dictionary(resolved.active_event).phase) == &"IDLE" and pressure.city.food == food_before - 2, "可见治理按钮只提交一次正式资源与事件事务")
	_capture("city-governance-resolved-1280x720.png")
	await _drop_city(pressure.scene)

	if failures.is_empty():
		print("CITY_GOVERNANCE_R0_GRAPHICAL_SMOKE PASS assertions=6")
		quit(0)
		return
	for failure in failures:
		push_error("CITY_GOVERNANCE_R0_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city(size: Vector2i) -> Dictionary:
	root.size = size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(4)
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	var shell: Control = scene.get_node("UI/Shell")
	await _frames(2)
	return {
		"scene": scene,
		"city": city,
		"shell": shell,
		"workspace": shell.get_node("GovernanceWorkspace"),
		"medical_minus": shell.governance_medical_minus,
		"event_button": shell.governance_event_button,
	}


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	var image := root.get_texture().get_image()
	if image == null or image.save_png(evidence_directory.path_join(filename)) != OK:
		failures.append("无法写入图形证据 %s" % filename)


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _frames(count: int) -> void:
	for _frame in range(count):
		await process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
