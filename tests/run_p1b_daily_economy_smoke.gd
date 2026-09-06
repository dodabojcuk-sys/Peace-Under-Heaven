extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "主场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var construction: Node = scene.get_node("ConstructionController")

	var farm_definition = construction.get_definition(&"building.farm.t1")
	var warehouse_definition = construction.get_definition(
		&"building.warehouse.t1"
	)
	_check(farm_definition is BuildingDefinition, "农田使用类型化定义")
	_check(warehouse_definition is BuildingDefinition, "仓库使用类型化定义")
	_check(
		farm_definition.get_capability(&"production").resource_id == &"food",
		"农田定义产出粮食"
	)
	_check(
		warehouse_definition.get_capability(&"storage").amount == 120,
		"仓库定义容量增量为 120"
	)
	var initial_state: Dictionary = construction.get_city_state()
	_check(
		initial_state.wood == 100
			and initial_state.food == 80
			and initial_state.wood_capacity == 160
			and initial_state.food_capacity == 160,
		"初始木材、粮食和容量符合 V0"
	)

	var road_cells := [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
		Vector2i(11, 6),
		Vector2i(12, 6),
	]
	for cell in road_cells:
		_check(
			construction.place_definition_at_cell(
				&"building.road.t1",
				cell,
				false
			) > 0,
			"测试路网格 %s 放置成功" % cell
		)
	var logging_id: int = construction.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7),
		false,
		true
	)
	var farm_id: int = construction.place_definition_at_cell(
		&"building.farm.t1",
		Vector2i(12, 7),
		false,
		true
	)
	_check(
		construction.is_building_operational(logging_id)
			and construction.is_building_operational(farm_id),
		"伐木场和农田都从同一路网派生运行状态"
	)

	var wood_before: int = construction.wood
	var food_before: int = construction.food
	construction.advance_one_day_for_test()
	var first_breakdown: Dictionary = construction.get_last_daily_breakdown()
	_check(construction.wood == wood_before + 18, "次日结算 18 木材")
	_check(
		construction.food == food_before - 4 + 22,
		"次日先扣 4 粮维护，再结算 22 粮食"
	)
	_check(construction.tech_points == 1, "学院每日增加 1 科技点")
	for required_key in [
		"maintenance_food",
		"training_completed",
		"wood_income",
		"food_income",
		"research_income",
		"event_wood_loss",
		"event_food_loss",
	]:
		_check(
			first_breakdown.has(required_key),
			"每日明细包含固定字段 %s" % required_key
		)
	_check(
		first_breakdown.maintenance_food == 4
			and first_breakdown.training_completed == 0
			and first_breakdown.wood_income == 18
			and first_breakdown.food_income == 22
			and first_breakdown.research_income == 1,
		"P1-B 结算顺序保留维护、训练、生产、研究槽位"
	)

	for cell in [Vector2i(13, 6), Vector2i(14, 6)]:
		_check(
			construction.place_definition_at_cell(
				&"building.road.t1",
				cell,
				false
			) > 0,
			"第二农田延伸道路格 %s 放置成功" % cell
		)
	var second_farm_id: int = construction.place_definition_at_cell(
		&"building.farm.t1",
		Vector2i(14, 7),
		false,
		true
	)
	_check(second_farm_id > 0, "本日可立即完成第二座农田")
	var food_after_build: int = construction.food
	_check(
		construction.food == food_after_build,
		"建筑完成当日不会立即发放产量"
	)
	construction.advance_one_day_for_test()
	_check(
		construction.get_last_daily_breakdown().food_income == 44,
		"下一日两座联网农田合计生产 44 粮食"
	)

	construction.wood = 155
	construction.food = 155
	construction.advance_one_day_for_test()
	var capped: Dictionary = construction.get_last_daily_breakdown()
	_check(
		construction.wood == 160
			and construction.food == 160
			and capped.wood_income == 5
			and capped.food_income == 9,
		"维护先扣除后，生产只接收容量可容纳部分"
	)
	_check(
		construction.last_daily_report.contains("容量封顶"),
		"容量封顶在日结算摘要中可见"
	)

	var warehouse_id: int = construction.place_definition_at_cell(
		&"building.warehouse.t1",
		Vector2i(20, 20),
		false,
		true
	)
	_check(warehouse_id > 0, "仓库可以进入统一 placement 记录")
	_check(
		construction.get_resource_capacity(&"wood") == 280
			and construction.get_resource_capacity(&"food") == 280,
		"仓库从权威 placement 派生两种资源容量"
	)
	construction.wood = 270
	construction.food = 270
	construction.advance_one_day_for_test()
	_check(
		construction.wood == 280
			and construction.food == 268
			and construction.get_last_daily_breakdown().event_food_loss == 12,
		"扩容先封顶生产，再按固定顺序结算第 5 日骚扰"
	)
	_check(construction.remove_placed_building(warehouse_id), "仓库沿用安全移除")
	_check(
		construction.wood == 160 and construction.food == 160,
		"移除容量来源后资源确定性收敛到当前容量"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("P1B_DAILY_ECONOMY_SMOKE PASS")
		quit(0)
	else:
		print("P1B_DAILY_ECONOMY_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
