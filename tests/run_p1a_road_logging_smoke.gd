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
	var initial_count: int = construction.get_building_count()
	var road_definition = construction.get_definition(&"building.road.t1")
	var logging_definition = construction.get_definition(
		&"building.logging_camp.t1"
	)
	_check(road_definition is BuildingDefinition, "道路使用类型化 BuildingDefinition")
	_check(logging_definition is BuildingDefinition, "伐木场使用类型化 BuildingDefinition")
	_check(
		logging_definition.get_capability(&"production") is BuildingCapability,
		"伐木场产量使用类型化 BuildingCapability"
	)
	_check(
		construction.get_definition_ids().has(&"building.road.t1")
			and construction.get_definition_ids().has(
				&"building.logging_camp.t1"
			),
		"P1-A 道路与伐木场定义仍存在"
	)

	var isolated_road_id: int = construction.place_definition_at_cell(
		&"building.road.t1",
		Vector2i(20, 20)
	)
	_check(isolated_road_id > 0, "孤立道路可以放置")
	_check(
		construction.get_operational_status(isolated_road_id).state
			== &"isolated",
		"孤立道路明确显示未接入城市路网"
	)

	var logging_id: int = construction.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7)
	)
	_check(logging_id > 0, "伐木场可以放置")
	_check(
		not construction.is_building_operational(logging_id),
		"刚放置的伐木场在施工完成前不运行"
	)
	_check(
		construction.get_operational_status(logging_id).state
			== &"constructing",
		"伐木场明确显示施工状态和预计完成日"
	)

	var road_cells := [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
	]
	var road_ids: Array[int] = []
	for cell in road_cells:
		var road_id: int = construction.place_definition_at_cell(
			&"building.road.t1",
			cell
		)
		road_ids.append(road_id)
		_check(road_id > 0, "道路格 %s 放置成功" % cell)

	var connected_roads: Dictionary = construction.get_connected_road_cells()
	var all_runtime_roads_connected := true
	for road_cell in road_cells:
		if not connected_roads.has(road_cell):
			all_runtime_roads_connected = false
	_check(
		all_runtime_roads_connected
			and connected_roads.size()
				>= construction.get_formal_road_cells().size() + road_cells.size(),
		"从正式道路与城主府根格共同派生完整四向路网"
	)
	_check(
		not construction.is_building_operational(logging_id),
		"道路接通不会绕过尚未完成的施工"
	)

	var wood_before_day: int = construction.wood
	_check(construction.advance_one_day_for_test(), "可以推进到下一日")
	_check(
		construction.is_building_operational(logging_id)
			and construction.wood == wood_before_day + 18,
		"第 2 日完工后，接通的伐木场产生 18 木材"
	)
	_check(construction.current_day == 2, "日期从第 1 日推进到第 2 日")

	var broken_road_id: int = road_ids[3]
	_check(construction.remove_placed_building(broken_road_id), "道路可以安全拆除")
	_check(
		not construction.is_building_operational(logging_id),
		"断路后伐木场派生为停用"
	)
	var wood_before_disconnected_day: int = construction.wood
	construction.advance_one_day_for_test()
	_check(
		construction.wood == wood_before_disconnected_day,
		"断路期间不生产且不补发"
	)
	var replacement_id: int = construction.place_definition_at_cell(
		&"building.road.t1",
		road_cells[3]
	)
	_check(replacement_id > broken_road_id, "恢复道路获得新的单调 placement ID")
	var wood_before_recovery_day: int = construction.wood
	construction.advance_one_day_for_test()
	_check(
		construction.wood == wood_before_recovery_day + 18,
		"恢复连接后从下一次结算恢复生产"
	)

	var count_before_insufficient: int = construction.get_building_count()
	construction.wood = 1
	var rejected_id: int = construction.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(20, 24)
	)
	_check(rejected_id < 0, "木材不足时原子拒绝建造")
	_check(
		construction.get_building_count() == count_before_insufficient,
		"资源不足不创建节点或权威记录"
	)
	_check(
		construction.get_building_count()
			== initial_count + 1 + 1 + road_cells.size(),
		"最终记录只包含固定建筑、孤立道路、伐木场和当前路网"
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
		print("P1A_ROAD_LOGGING_SMOKE PASS")
		quit(0)
	else:
		print("P1A_ROAD_LOGGING_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
