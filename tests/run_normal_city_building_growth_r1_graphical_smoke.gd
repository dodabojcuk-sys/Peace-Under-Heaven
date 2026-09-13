extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const VIEWPORTS: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1920, 1080)]

var evidence_directory := ""
var failures: Array[String] = []


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("NORMAL_CITY_BUILDING_GROWTH_R1_GRAPHICAL_SMOKE requires a graphical Godot process")
		quit(2)
		return
	evidence_directory = _argument_value("--txwzs-building-growth-evidence-dir=")
	call_deferred("_run")


func _run() -> void:
	for viewport_size in VIEWPORTS:
		await _check_viewport(viewport_size)
	if failures.is_empty():
		print("NORMAL_CITY_BUILDING_GROWTH_R1_GRAPHICAL_SMOKE PASS viewports=%d" % VIEWPORTS.size())
		quit(0)
		return
	for failure in failures:
		push_error("NORMAL_CITY_BUILDING_GROWTH_R1_GRAPHICAL_SMOKE FAIL: %s" % failure)
	quit(1)


func _check_viewport(viewport_size: Vector2i) -> void:
	root.size = viewport_size
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await _frames(4)
	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	city.set_process(false)
	city.restart_first_map()
	# Layout fixture: enough resources to expose the confirmation without
	# exceeding the normal 160-capacity warehouse projection.
	city.wood = 150
	city.food = 100
	var cell := _find_legal_cell(city, &"building.farm.t1")
	var placement_id: int = city.place_definition_at_cell(&"building.farm.t1", cell, false, true)
	selection.select_placement(placement_id)
	await _frames(2)
	var panel: Control = scene.get_node("UI/Shell/BuildingDetailPanel")
	var primary: Button = selection.governance_primary_action
	primary.emit_signal("pressed")
	await _frames(2)
	var confirmation: Control = panel.get_node("UpgradeConfirmation")
	var confirmation_text: Label = confirmation.get_node("ConfirmationText")
	var panel_rect := panel.get_global_rect()
	var valid_confirmation: bool = (
		placement_id > 0
		and confirmation.visible
		and selection.panel_title.text == "农田 Lv.1 → Lv.2"
		and confirmation_text.text.contains("建筑产能")
		and confirmation_text.text.contains("成本")
		and panel_rect.position.x >= 0.0
		and panel_rect.position.y >= 0.0
		and panel_rect.end.x <= viewport_size.x
		and panel_rect.end.y <= viewport_size.y
	)
	if not valid_confirmation:
		failures.append("%s 升级确认未完整显示真实成本、能力或边界" % str(viewport_size))
	_capture("building-growth-final-confirm-%dx%d.png" % [viewport_size.x, viewport_size.y])
	(panel.get_node("UpgradeConfirmation/ConfirmUpgradeButton") as Button).emit_signal("pressed")
	await _frames(2)
	var progress: ProgressBar = selection.upgrade_progress_bar
	var status: Label = selection.upgrade_progress_label
	var action_group: Control = selection.governance_action_group
	var progress_scroll: Control = selection.upgrade_progress_scroll
	if (
		not progress.visible
		or not status.visible
		or not status.text.contains("已投入")
		or not progress_scroll.visible
		or progress_scroll.get_global_rect().intersects(action_group.get_global_rect())
	):
		failures.append("%s 升级提交后未显示工程进度与投入" % str(viewport_size))
	_capture("building-growth-final-progress-%dx%d.png" % [viewport_size.x, viewport_size.y])
	primary.emit_signal("pressed")
	await _frames(2)
	if selection.panel_title.text != "农田 Lv.1 → Lv.2" or not confirmation_text.text.contains("取消后返还"):
		failures.append("%s 活动升级取消确认未显示对象、等级或退款规则" % str(viewport_size))
	(selection.cancel_upgrade_button as Button).emit_signal("pressed")
	await _frames(2)
	var workers: int = int(city.get_population_recovery_read_model().construction_workers)
	city.adjust_city_workforce(&"construction", -workers)
	await _frames(2)
	if not selection.status_badge.text.contains("等待施工人员") or not progress_scroll.visible:
		failures.append("%s 人员不足状态未保留滚动进度并解释等待条件" % str(viewport_size))
	city.adjust_city_workforce(&"construction", workers)
	city.set_building_upgrade_fault_for_test(&"COMPLETION_CHECKPOINT_SAVE_FAILED")
	city.advance_city_time_for_test(360.0)
	await _frames(2)
	if not selection.status_badge.text.contains("等待保存重试") or not progress_scroll.visible:
		failures.append("%s 完工保存失败未显示可重试状态" % str(viewport_size))
	city.advance_city_time_for_test(0.0)
	await _frames(2)
	if progress_scroll.visible or not selection.target_type.text.contains("粮食 +36/日"):
		failures.append("%s 完工后未退出进度布局或未显示二级真实能力" % str(viewport_size))
	print("BUILDING_GROWTH_GUI_TRACE viewport=%s confirmation=%s progress=%s panel=%s" % [str(viewport_size), confirmation_text.text.replace("\n", " / "), status.text.replace("\n", " / "), str(panel_rect)])
	scene.queue_free()
	await process_frame


func _find_legal_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if bool(validation.get("valid", false)) and StringName(validation.get("connection_state", &"")) == &"connected":
				return cell
	return Vector2i(-1, -1)


func _capture(filename: String) -> void:
	if evidence_directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(evidence_directory)
	root.get_texture().get_image().save_png(evidence_directory.path_join(filename))


func _frames(count: int) -> void:
	for _frame in range(maxi(count, 0)):
		await process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""
