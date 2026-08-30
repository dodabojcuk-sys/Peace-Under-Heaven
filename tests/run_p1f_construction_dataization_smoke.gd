extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	city.set_process(false)

	_check_definition_data(city)
	var defense_before: Dictionary = (
		city.get_first_war_preparation_assessment()
	)
	_check(
		int(defense_before.city_defense) == 10
			and int(defense_before.defense_target) == 20
			and "建造瞭望塔" in str(defense_before.suggestion),
		"首战准备评估从真实城防阈值指出防御短板"
	)

	city.wood = 200
	for cell in [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
	]:
		_check(
			city.place_definition_at_cell(
				&"building.road.t1",
				cell,
				false
			) > 0,
			"道路 fixture %s 即时接入城市路网" % cell
		)

	var logging_id: int = city.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7),
		true
	)
	var warehouse_id: int = city.place_definition_at_cell(
		&"building.warehouse.t1",
		Vector2i(20, 20),
		true
	)
	var watchtower_id: int = city.place_definition_at_cell(
		&"building.watchtower.t1",
		Vector2i(23, 20),
		true
	)
	_check(
		logging_id > 0 and warehouse_id > 0 and watchtower_id > 0,
		"资源、容量和防御三种现有建筑进入同一 placement 权威记录"
	)
	_check(
		city.wood == 200,
		"下达三项施工单时不再原子预扣 40、60、50 木材"
	)
	_check(
		city.get_construction_in_progress_count() == 3
			and not city.is_building_operational(logging_id)
			and city.get_resource_capacity(&"wood") == 160
			and city.get_city_defense() == 10,
		"施工完成前不提前获得生产、容量或城防效果"
	)

	var logging_record: Dictionary = city.get_building_record(logging_id)
	_check(
		StringName(logging_record.lifecycle_state) == &"constructing"
			and int(logging_record.level) == 1
			and int(logging_record.build_days) == 1
			and int(logging_record.construction_complete_day) == 2,
		"建筑记录持有等级、施工状态、工期和预计完成日"
	)
	selection.select_placement(logging_id)
	var detail_panel: Control = scene.get_node("UI/Shell/BuildingDetailPanel")
	_check(
		detail_panel.get_node("TargetType").text
			== "当前等级：L1\n下一等级：当前切片未开放"
		and detail_panel.get_node("GridPosition").text
				== "朝向：北｜投入：木材 40｜工期：1 日"
			and detail_panel.get_node("Footprint").text
				== "当前效果：木材 +18/日"
			and detail_panel.get_node("PrototypeStatus").text.contains(
				"预计第 2 日完成"
			),
		"选中施工建筑可见等级、投入、工期、效果和预计完成日"
	)
	_check(
		city.get_building_node(logging_id).get_node("Label").text.contains(
			"施工中"
		),
		"地图中的施工建筑有可见施工状态"
	)

	var wood_before_settlement: int = city.wood
	_check(city.advance_one_day_for_test(), "施工可通过受控日界线完成")
	_check(
		city.get_construction_in_progress_count() == 0
			and city.is_building_operational(logging_id)
			and city.get_resource_capacity(&"wood") == 280
			and city.get_city_defense() == 20,
		"第 2 日统一完成施工并启用生产、容量和城防"
	)
	_check(
		city.wood == wood_before_settlement - 150 + 18
			and int(city.get_last_daily_breakdown().construction_completed) == 3,
		"完成日前增量付清 150 木并结算 18 木材，报告三项完工"
	)
	_check(
		city.get_building_node(logging_id).get_node("Label").text == "伐木场",
		"完工后地图节点恢复运行中建筑标签"
	)

	var defense_after: Dictionary = city.get_first_war_preparation_assessment()
	_check(
		int(defense_after.city_defense) == 20
			and str(defense_after.defense_status)
				== "达到首轮骚扰减损线"
			and "建造瞭望塔" not in str(defense_after.suggestion),
		"瞭望塔完工真实改变首战准备评估而非只改说明文字"
	)

	var barracks_id := _find_template(city, &"barracks")
	var barracks_data: Dictionary = city.get_building_data(barracks_id)
	_check(
		str(barracks_data.level_text) == "当前等级：L1"
			and "征募 5 人" in str(barracks_data.effect_text)
			and not bool(barracks_data.upgrade_available),
		"固定兵营显示真实征募数据且不伪造升级入口"
	)

	city.wood = 0
	city._refresh_city_ui()
	var logging_button: Button = scene.get_node(
		"UI/Shell/ConstructionMenu/LoggingCampButton"
	)
	var logging_definition_data: Dictionary = city.get_definition_build_data(
		&"building.logging_camp.t1"
	)
	_check(
		not logging_button.disabled
			and bool(logging_definition_data.can_build)
			and str(logging_definition_data.unavailable_reason).is_empty(),
		"资源不足时建造目录仍允许下单，缺料在施工 tick 暂停"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _check_definition_data(city: Node) -> void:
	var expected := {
		&"building.road.t1": [2, 0, "接通城市路网"],
		&"building.logging_camp.t1": [40, 1, "木材 +18/日"],
		&"building.farm.t1": [45, 1, "粮食 +22/日"],
		&"building.warehouse.t1": [60, 1, "木材／粮食容量各 +120"],
		&"building.watchtower.t1": [50, 1, "城防 +10"],
	}
	for definition_id in expected:
		var data: Dictionary = city.get_definition_build_data(definition_id)
		var definition: BuildingDefinition = city.get_definition(definition_id)
		_check(
			definition != null
				and definition.level == 1
				and definition.wood_cost == int(expected[definition_id][0])
				and definition.build_days == int(expected[definition_id][1])
				and str(data.effect_text) == str(expected[definition_id][2])
				and str(data.next_level_label)
					== "下一等级：当前切片未开放",
			"%s 复用仓库既有成本效果并补齐诚实等级工期"
				% definition_id
		)


func _find_template(city: Node, template_id: StringName) -> int:
	for placement_id in city.get_placement_ids():
		var record: Dictionary = city.get_building_record(placement_id)
		if StringName(record.get("template_id", &"")) == template_id:
			return placement_id
	return -1


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("P1F_CONSTRUCTION_DATAIZATION_SMOKE PASS")
		quit(0)
	else:
		print(
			"P1F_CONSTRUCTION_DATAIZATION_SMOKE FAIL (%d)"
			% failures.size()
		)
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
