extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const PAIRS: Array[Array] = [
	[&"building.farm.t1", &"building.farm.t2"],
	[&"building.logging_camp.t1", &"building.logging_camp.t2"],
	[&"building.warehouse.t1", &"building.warehouse.t2"],
	[&"building.housing.t1", &"building.housing.t2"],
	[&"building.clinic.t1", &"building.clinic.t2"],
]

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city.wood = 1000
	city.food = 1000
	var placement_ids: Array[int] = []
	var origins: Array[Vector2i] = []
	for pair in PAIRS:
		var definition_id: StringName = pair[0]
		var origin := _find_legal_cell(city, definition_id)
		var placement_id: int = city.place_definition_at_cell(definition_id, origin, false, true)
		placement_ids.append(placement_id)
		origins.append(origin)
		_check(placement_id > 0 and bool(city.preview_building_upgrade(placement_id).valid), "%s 具有正式二级升级入口" % String(definition_id))

	var wood_capacity_before: int = city.get_resource_capacity(&"wood")
	var housing_before: int = city.get_city_housing_capacity()
	var medical_before: int = city.get_city_medical_capacity()
	var population_before: int = int(city.get_population_recovery_read_model().total_living)
	for placement_id in placement_ids:
		_check(bool(city.begin_building_upgrade(placement_id).success), "升级一次扣费并建立唯一工程")
		_check(not bool(city.begin_building_upgrade(placement_id).success), "活动升级拒绝重复提交")
	var active_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	_check(int(active_snapshot.schema_version) == 17, "活动升级进入 V17 权威快照")
	_check(city.get_resource_capacity(&"wood") == wood_capacity_before and city.get_city_housing_capacity() == housing_before and city.get_city_medical_capacity() == medical_before, "施工期间继续使用原等级能力")
	city.advance_city_time_for_test(180.0)
	_check(city.get_resource_capacity(&"wood") == wood_capacity_before, "未完工不提前提高仓储")
	city.advance_city_time_for_test(180.0)
	for index in range(PAIRS.size()):
		var record: Dictionary = city.get_building_record(placement_ids[index])
		_check(StringName(record.definition_id) == StringName(PAIRS[index][1]) and Vector2i(record.origin_cell) == origins[index] and int(record.level) == 2, "%s 完工保留身份与位置并切换真实定义" % String(PAIRS[index][0]))
	_check(city.get_resource_capacity(&"wood") == wood_capacity_before + 80 and city.get_city_housing_capacity() == housing_before + 12 and city.get_city_medical_capacity() == medical_before + 4, "仓储、住房和医疗容量读取二级真实能力")
	_check(int(city.get_population_recovery_read_model().total_living) == population_before and city.wood < city.get_resource_capacity(&"wood"), "升级不发库存或居民")
	city.wood = 0
	city.food = 80
	var logging_definition: Resource = city.get_definition(&"building.logging_camp.t2")
	var expected_wood: int = city._get_production_amount(logging_definition, logging_definition.get_capability(&"production"))
	_check(city.advance_one_day_for_test() and city.wood == expected_wood and expected_wood > 18, "连通、在岗与压力共同计算二级伐木场的实际日收益")
	var food_before_training: int = city.food
	var training: Dictionary = city.request_training()
	_check(bool(training.success) and city.food < food_before_training, "升级后城市收益进入既有训练资源事务")

	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	_check(bool(restored.restore_v5_campaign_snapshot(active_snapshot).success), "升级中快照可恢复")
	restored.advance_city_time_for_test(360.0)
	_check(StringName(restored.get_building_record(placement_ids[0]).definition_id) == &"building.farm.t2", "恢复后沿同一施工时钟完工")

	var cancel_cell := _find_legal_cell(restored, &"building.farm.t1")
	var cancel_id: int = restored.place_definition_at_cell(&"building.farm.t1", cancel_cell, false, true)
	var wood_before_cancel: int = restored.wood
	var food_before_cancel: int = restored.food
	_check(bool(restored.begin_building_upgrade(cancel_id).success), "取消夹具建立正式升级")
	_check(bool(restored.cancel_building_upgrade(cancel_id).success) and restored.wood == wood_before_cancel and restored.food == food_before_cancel and StringName(restored.get_building_record(cancel_id).definition_id) == &"building.farm.t1", "取消全额退款并保留原建筑")
	var workforce: Dictionary = restored.get_population_recovery_read_model()
	var construction_workers: int = int(workforce.construction_workers)
	_check(bool(restored.adjust_city_workforce(&"construction", -construction_workers).success) and not bool(restored.preview_building_upgrade(cancel_id).valid), "施工岗位不足时解释并阻止升级提交")
	restored.adjust_city_workforce(&"construction", construction_workers)
	var saved_wood: int = restored.wood
	var saved_food: int = restored.food
	restored.wood = 0
	restored.food = 0
	_check(not bool(restored.preview_building_upgrade(cancel_id).valid), "资源不足时预览给出缺口且不建立工程")
	restored.wood = saved_wood
	restored.food = saved_food
	var disconnected_cell := _find_disconnected_cell(restored, &"building.farm.t1")
	var disconnected_id: int = restored.place_definition_at_cell(&"building.farm.t1", disconnected_cell, false, true)
	var disconnected_preview: Dictionary = restored.preview_building_upgrade(disconnected_id)
	_check(disconnected_id > 0 and bool(disconnected_preview.valid) and str(disconnected_preview.condition_text).contains("未接路"), "道路变化不伪造升级能力，详情明确完工后仍需接路")

	var fault_cell := _find_legal_cell(restored, &"building.logging_camp.t1")
	var fault_id: int = restored.place_definition_at_cell(&"building.logging_camp.t1", fault_cell, false, true)
	var before_fault: Dictionary = restored.export_v5_campaign_snapshot()
	restored.set_building_upgrade_fault_for_test(&"START_CHECKPOINT_SAVE_FAILED")
	_check(not bool(restored.begin_building_upgrade(fault_id).success) and restored.export_v5_campaign_snapshot() == before_fault, "成本保存失败时资源和工程共同回滚")
	_check(bool(restored.begin_building_upgrade(fault_id).success), "保存失败后可安全重试")
	restored.set_building_upgrade_fault_for_test(&"COMPLETION_CHECKPOINT_SAVE_FAILED")
	restored.advance_city_time_for_test(360.0)
	var ready: Dictionary = restored.get_building_record(fault_id)
	_check(StringName(ready.definition_id) == &"building.logging_camp.t1" and StringName(ready.construction_state) == &"READY_TO_COMPLETE", "完工保存失败保留原能力与可恢复终点")
	restored.advance_city_time_for_test(0.0)
	_check(StringName(restored.get_building_record(fault_id).definition_id) == &"building.logging_camp.t2", "完工保存重试只结算一次")
	var fallen_before: int = int(restored.get_population_recovery_read_model().fallen)
	var removed: bool = restored._garrison_state.try_remove_units(restored.INFANTRY_ROLE.role_id, 4)
	var casualties: Dictionary = restored._population_recovery.record_casualties(4, restored.RECOVERY_RULES.wounded_permille)
	var treatment: Dictionary = restored.begin_wounded_treatment()
	restored.advance_city_time_for_test(2.0)
	var treated: Dictionary = restored.get_population_recovery_read_model()
	_check(removed and int(casualties.wounded) > 0 and bool(treatment.success) and int(treated.wounded) == 0 and int(treated.fallen) == fallen_before + int(casualties.fallen), "二级医舍沿共享治疗事务整备伤员且不复活阵亡者")

	var legacy := active_snapshot.duplicate(true)
	legacy.schema_version = 16
	for placement in legacy.placements:
		placement.erase("upgrade_target_definition_id")
		placement.construction_state = &"COMPLETED"
		placement.construction_progress_milliseconds = 0
		placement.construction_required_milliseconds = 0
		placement.construction_total_costs = {}
		placement.construction_paid_costs = {}
	var legacy_result: Dictionary = restored.validate_v5_campaign_snapshot(legacy)
	_check(bool(legacy_result.valid) and int(legacy_result.snapshot.schema_version) == 17 and StringName(legacy_result.snapshot.placements[0].upgrade_target_definition_id) == &"", "V16 旧档只迁移空升级事实，不免费升级")

	var journey_scene := CITY_SCENE.instantiate()
	root.add_child(journey_scene)
	await process_frame
	await process_frame
	var journey: Node = journey_scene.get_node("ConstructionController")
	journey.set_process(false)
	journey.restart_first_map()
	var project: Dictionary = journey.start_build_project(&"building.logging_camp.t1")
	journey.advance_city_time_for_test(180.0)
	var journey_cell := _find_visible_legal_cell(journey, &"building.logging_camp.t1")
	var journey_point: Vector2 = journey.map_local_to_screen(journey.cell_to_map_local(journey_cell) + Vector2(40.0, 40.0))
	var activated: Dictionary = journey.activate_ready_placement(journey_point)
	var committed: Dictionary = journey.commit_building_from_map_click(journey_point)
	var journey_id: int = int(committed.get("placement_id", -1))
	var upgraded: Dictionary = journey.begin_building_upgrade(journey_id)
	journey.advance_city_time_for_test(360.0)
	var before_yield: int = journey.wood
	journey.advance_one_day_for_test()
	var training_after_yield: Dictionary = journey.request_training()
	_check(bool(project.success) and bool(activated.success) and bool(committed.success) and bool(upgraded.success) and StringName(journey.get_building_record(journey_id).definition_id) == &"building.logging_camp.t2" and journey.wood > before_yield and bool(training_after_yield.success), "正常新局资源沿正式建造、放置、升级、日收益和训练完成连续经营链")

	if failures.is_empty():
		print("NORMAL_CITY_BUILDING_GROWTH_R1_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("NORMAL_CITY_BUILDING_GROWTH_R1_SMOKE FAIL: %s" % failure)
	quit(1)


func _find_legal_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if bool(validation.get("valid", false)) and (not definition.requires_road or StringName(validation.get("connection_state", &"")) == &"connected"):
				return cell
	return Vector2i(-1, -1)


func _find_disconnected_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if bool(validation.get("valid", false)) and StringName(validation.get("connection_state", &"")) == &"disconnected":
				return cell
	return Vector2i(-1, -1)


func _find_visible_legal_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	var viewport_size: Vector2 = city.get_viewport().get_visible_rect().size
	var safe_rect := Rect2(Vector2(260.0, 120.0), Vector2(viewport_size.x - 620.0, viewport_size.y - 160.0))
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			var point: Vector2 = city.map_local_to_screen(city.cell_to_map_local(cell) + Vector2(40.0, 40.0))
			if bool(validation.get("valid", false)) and StringName(validation.get("connection_state", &"")) == &"connected" and safe_rect.has_point(point) and not city.is_construction_ui_point(point):
				return cell
	return Vector2i(-1, -1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
