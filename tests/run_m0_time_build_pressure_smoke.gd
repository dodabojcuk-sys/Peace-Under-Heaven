extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const BATTLE_ATTEMPT_STATE = preload("res://scripts/battle/battle_attempt_state.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1440, 900)
	await _check_unified_clock_and_pause()
	await _check_incremental_payment()
	await _check_missing_resource_resume()
	await _check_priority_order()
	await _check_five_pressure_stages()
	await _check_security_and_essential_floor()
	await _check_battle_retry_boundary()
	await _check_v5_roundtrip_and_v3_migration()
	_finish()


func _check_unified_clock_and_pause() -> void:
	var context := await _new_city()
	var city: Node = context.city
	var initial_elapsed: int = city.get_day_elapsed_milliseconds()
	_check(city.set_city_time_speed(1.0), "场景1：统一时钟接受 1x")
	city.advance_city_frame_for_test(1.0)
	_check(city.get_day_elapsed_milliseconds() == initial_elapsed + 1000, "场景1：1x 推进 1000ms")
	_check(city.set_city_time_speed(2.0), "场景1：统一时钟接受 2x")
	city.advance_city_frame_for_test(1.0)
	_check(city.get_day_elapsed_milliseconds() == initial_elapsed + 3000, "场景1：2x 累计推进到 3000ms")
	_check(city.set_city_time_speed(4.0), "场景1：统一时钟接受 4x")
	city.advance_city_frame_for_test(1.0)
	_check(city.get_day_elapsed_milliseconds() == initial_elapsed + 7000, "场景1：4x 累计推进到 7000ms")
	city.set_city_time_paused(true)
	city.advance_city_frame_for_test(10.0)
	_check(city.get_day_elapsed_milliseconds() == initial_elapsed + 7000, "场景1：暂停时所有城市时间停止")
	await _drop_city(context.scene)


func _check_incremental_payment() -> void:
	var context := await _new_city()
	var city: Node = context.city
	_seed_road(city)
	var before: int = city.wood
	var placement_id: int = city.place_definition_at_cell(
		&"building.logging_camp.t1", Vector2i(10, 7), true
	)
	_check(placement_id > 0 and city.wood == before, "场景2：下达施工单不预扣全部资源")
	city.advance_city_time_for_test(45.0)
	var record: Dictionary = city.get_building_record(placement_id)
	_check(
		int(record.construction_progress_milliseconds) == 45000
			and int(record.construction_paid_costs.wood) == 10
			and city.wood == before - 10,
		"场景2：施工进度按固定 tick 累计并只扣累计应付 10 木"
	)
	city.set_city_time_paused(true)
	city.advance_city_time_for_test(30.0)
	_check(
		int(city.get_building_record(placement_id).construction_progress_milliseconds) == 45000,
		"场景2：暂停后施工与扣料同步停止"
	)
	await _drop_city(context.scene)


func _check_missing_resource_resume() -> void:
	var context := await _new_city()
	var city: Node = context.city
	_seed_road(city)
	city.wood = 0
	var placement_id: int = city.place_definition_at_cell(
		&"building.logging_camp.t1", Vector2i(10, 7), true
	)
	_check(placement_id > 0, "场景3：缺料仍可建立合法施工订单")
	city.advance_city_time_for_test(5.0)
	var blocked: Dictionary = city.get_building_record(placement_id)
	_check(
		StringName(blocked.construction_state) == &"BLOCKED_RESOURCES"
			and int(blocked.construction_progress_milliseconds) == 4000,
		"场景3：到首个应付阈值时明确缺料暂停"
	)
	city.wood = 10
	city.advance_city_time_for_test(2.0)
	var resumed: Dictionary = city.get_building_record(placement_id)
	_check(
		StringName(resumed.construction_state) == &"ACTIVE"
			and int(resumed.construction_progress_milliseconds) > 4000,
		"场景3：补料后同一订单自动恢复且不丢进度"
	)
	await _drop_city(context.scene)


func _check_priority_order() -> void:
	var context := await _new_city()
	var city: Node = context.city
	_seed_road(city)
	city.wood = 0
	var low_id: int = city.place_definition_at_cell(
		&"building.logging_camp.t1", Vector2i(10, 7), true
	)
	var high_id: int = city.place_definition_at_cell(
		&"building.farm.t1", Vector2i(12, 7), true
	)
	_check(
		city.set_construction_priority(low_id, city.CONSTRUCTION_PRIORITY_LOW)
			and city.set_construction_priority(high_id, city.CONSTRUCTION_PRIORITY_HIGH),
		"场景4：施工优先级只接受低／普通／高三级"
	)
	city.wood = 1
	city.advance_city_time_for_test(5.0)
	_check(
		int(city.get_building_record(high_id).construction_paid_costs.get(&"wood", 0)) == 1
			and StringName(city.get_building_record(low_id).construction_state) == &"BLOCKED_RESOURCES",
		"场景4：资源竞争时高优先级先扣料，稳定 ID 只作同级次序"
	)
	await _drop_city(context.scene)


func _check_five_pressure_stages() -> void:
	var context := await _new_city()
	var city: Node = context.city
	var expected := {1: &"PRESSURE_0", 8: &"PRESSURE_1", 10: &"PRESSURE_2", 12: &"PRESSURE_3", 14: &"PRESSURE_4"}
	for target_day in expected:
		while city.current_day < target_day:
			_check(city.advance_one_day_for_test(), "场景5：可持续推进到第 %d 日" % target_day)
		_check(city.get_mainline_pressure_state().stage_id == expected[target_day], "场景5：第 %d 日进入 %s" % [target_day, expected[target_day]])
	_check(not city.city_fallen, "场景5：压力只增加困难，不造成主城自动失败或死档")
	await _drop_city(context.scene)


func _check_security_and_essential_floor() -> void:
	var low_context := await _new_city()
	var high_context := await _new_city()
	var low: Node = low_context.city
	var high: Node = high_context.city
	low.set_city_security_for_test(0)
	high.set_city_security_for_test(100)
	while low.current_day < 14:
		low.advance_one_day_for_test()
		high.advance_one_day_for_test()
	var low_losses: Dictionary = low.get_mainline_pressure_state().permanent_losses
	var high_losses: Dictionary = high.get_mainline_pressure_state().permanent_losses
	_check(int(high_losses.wood) < int(low_losses.wood), "场景6：高治安真实缓冲逾期永久损失")
	_check(
		low.get_pressure_modifier_permille(&"food_minimum") >= 250
			and low.get_pressure_modifier_permille(&"basic_repair") >= 250
			and low.get_pressure_modifier_permille(&"medical_care") >= 250
			and low.get_pressure_modifier_permille(&"basic_training") >= 250
			and low.get_pressure_modifier_permille(&"war_supply") >= 250,
		"场景6：五类生存通道始终高于防死档下限"
	)
	await _drop_city(low_context.scene)
	await _drop_city(high_context.scene)


func _check_battle_retry_boundary() -> void:
	var context := await _new_city()
	var city: Node = context.city
	while city.current_day < 10:
		city.advance_one_day_for_test()
	var before: Dictionary = city.get_mainline_pressure_state()
	var attempt: RefCounted = BATTLE_ATTEMPT_STATE.new()
	_check(attempt.restore_attempt({"attempt_id": &"attempt.retry.2", "elapsed_ticks": 0, "issued_order_ids": []}), "场景7：战斗重试只恢复 attempt-local 状态")
	_check(city.get_mainline_pressure_state() == before, "场景7：战斗重试不回滚日期、压力、治安或永久损失")
	await _drop_city(context.scene)


func _check_v5_roundtrip_and_v3_migration() -> void:
	var source_context := await _new_city()
	var source: Node = source_context.city
	_seed_road(source)
	var placement_id: int = source.place_definition_at_cell(&"building.logging_camp.t1", Vector2i(10, 7), true)
	source.advance_city_time_for_test(45.0)
	source.set_construction_priority(placement_id, source.CONSTRUCTION_PRIORITY_HIGH)
	var snapshot: Dictionary = source.export_v5_campaign_snapshot()
	var target_context := await _new_city()
	var target: Node = target_context.city
	var restored: Dictionary = target.restore_v5_campaign_snapshot(snapshot)
	_check(restored.success and target.export_v5_campaign_snapshot() == snapshot, "场景8：schema 5 精确恢复 legacy 施工、扣料、优先级、治安与主线压力")
	var legacy := _to_v3(snapshot)
	var migrated: Dictionary = target.validate_v5_campaign_snapshot(legacy)
	_check(
		migrated.valid
			and int(migrated.snapshot.schema_version) == 5
			and migrated.snapshot.mainline_level.has("pressure_stage_id")
			and migrated.snapshot.placements[0].construction_total_costs.is_empty(),
		"场景8：旧 V3 显式迁移且已付款施工不会重复扣料"
	)
	await _drop_city(source_context.scene)
	await _drop_city(target_context.scene)


func _to_v3(snapshot: Dictionary) -> Dictionary:
	var legacy := snapshot.duplicate(true)
	legacy.schema_version = 3
	legacy.erase("mainline_level")
	legacy.erase("build_slot")
	legacy.city.erase("security")
	for placement in legacy.placements:
		for key in ["construction_state", "construction_progress_milliseconds", "construction_required_milliseconds", "construction_total_costs", "construction_paid_costs", "construction_priority", "construction_missing_resource_ids"]:
			placement.erase(key)
	return legacy


func _seed_road(city: Node) -> void:
	for cell in [Vector2i(7, 4), Vector2i(7, 5), Vector2i(7, 6), Vector2i(8, 6), Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6), Vector2i(12, 6), Vector2i(13, 6), Vector2i(14, 6)]:
		city.place_definition_at_cell(&"building.road.t1", cell, false)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	return {"scene": scene, "city": city}


func _drop_city(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("M0_TIME_BUILD_PRESSURE_SMOKE PASS")
		quit(0)
	else:
		print("M0_TIME_BUILD_PRESSURE_SMOKE FAIL: %s" % str(failures))
		quit(1)
