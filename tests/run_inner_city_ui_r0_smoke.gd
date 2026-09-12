extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "Inner City UI-R0 主场景可加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	var shell: Control = scene.get_node("UI/Shell")
	var city_rail: Panel = shell.get_node("CityBar")
	var resource_summary: Label = shell.get_node("TopStatusBar/ResourceSummary")
	var construction_menu: Panel = shell.get_node("ConstructionMenu")
	var build_entry: Button = shell.get_node("ConstructionEntryPanel/BuildEntryButton")
	var detail: Panel = shell.get_node("BuildingDetailPanel")
	var macro_march: Node = scene.get_node_or_null("UI/MacroMarchR0")
	var governance: Control = shell.get_node("GovernanceWorkspace")
	var population_summary: Label = governance.get_node("GovernanceMargin/GovernanceContent/PopulationRecoverySummary")

	_check(city.get_nation_state() != null, "资源行只读取现有国家权威")
	_check(not city_rail.visible,
		"R1 默认不常驻左侧城市序列，避免与右侧城建栏争夺地图")
	_check(macro_march == null or not (macro_march as Control).visible,
		"正常启动链默认进入正式内城，外部战区按需打开")
	_check(
		governance.visible
			and population_summary.text.contains("人口")
			and population_summary.text.contains("伤员")
			and governance.get_global_rect().end.y <= root.size.y,
		"常态内城正式入口显示人口与战后恢复，并保持在 1280×720 可操作区域内"
	)
	root.size = Vector2i(1152, 648)
	await process_frame
	await process_frame
	_check(
		governance.get_global_rect().end.y <= root.size.y,
		"常态内城恢复操作在 1152×648 验证窗口内不越出底边"
	)
	root.size = Vector2i(1280, 720)
	await process_frame
	_check(
		resource_summary.text.contains("国家共享资源")
			and resource_summary.text.contains("木材"),
		"资源行显示权威国家共享资源"
	)
	_check(
		detail.size.x >= 278.0
			and detail.get_global_rect().position.x > root.size.x * 0.5,
		"1280 宽度下详情复用右侧安全栏，不挤压城市为多面板"
	)

	build_entry.emit_signal("pressed")
	_check(
		construction_menu.visible and city.is_choosing_template(),
		"建造目录经原有 authority 进入蓝图选择"
	)
	city.cancel_build_interaction()
	_check(
		not construction_menu.visible and not city.is_placing(),
		"建造目录取消不会留下 placing 状态"
	)

	var academy_id := _placement_id_for_template(city, &"academy")
	_check(academy_id > 0, "固定学院存在于唯一建筑 authority")
	if academy_id > 0:
		selection.select_placement(academy_id)
		var data_before: Dictionary = city.get_building_data(academy_id)
		var wood_before: int = city.wood
		(detail.get_node("UpgradeButton") as Button).emit_signal("pressed")
		_check(
			detail.get_node("UpgradeConfirmation").visible
				and selection.is_awaiting_upgrade_confirmation(),
			"升级门禁可达并明确呈现确认/返回"
		)
		(detail.get_node("UpgradeConfirmation/ConfirmUpgradeButton") as Button).emit_signal(
			"pressed"
		)
		_check(
			city.get_building_data(academy_id) == data_before
				and city.wood == wood_before,
			"无升级 writer 时确认不会伪造建筑或资源写入"
		)

	scene.queue_free()
	await process_frame
	_finish()


func _placement_id_for_template(city: Node, template_id: StringName) -> int:
	for placement_id in city.get_placement_ids():
		var record: Dictionary = city.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == template_id:
			return placement_id
	return -1


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failures.append(label)
	push_error("FAIL: %s" % label)


func _finish() -> void:
	if failures.is_empty():
		print("INNER_CITY_UI_R0_SMOKE PASS")
		quit(0)
		return
	print("INNER_CITY_UI_R0_SMOKE FAIL (%d)" % failures.size())
	for failure in failures:
		print(" - %s" % failure)
	quit(1)
