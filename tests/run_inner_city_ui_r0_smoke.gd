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

	_check(city.get_nation_state() != null, "资源行只读取现有国家权威")
	_check(city_rail.visible and city_rail.get_node("Title").text == "城市序列",
		"一城经营视图默认显示城市序列")
	_check(
		resource_summary.text.contains("国家共享资源")
			and resource_summary.text.contains("木材"),
		"资源行显示权威国家共享资源"
	)
	_check(
		detail.size.x >= 290.0
			and not detail.get_global_rect().intersects(
				city_rail.get_global_rect()
			),
		"1280 宽度下详情与城市序列保持安全分区"
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
