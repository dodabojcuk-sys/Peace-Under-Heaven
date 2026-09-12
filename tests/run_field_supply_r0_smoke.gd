extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	await _check_departure_arrival_and_once_only_credit()
	await _check_no_route_and_capacity_waiting()
	await _check_damaged_route_wait_and_resume()
	await _check_snapshot_compatibility_and_mid_transit_restore()
	await _check_strict_supply_snapshot_rejection()
	await _check_capacity_checkpoint_and_repair_time_boundary()
	await _check_supply_delivery_failure_rollback()
	await _check_repair_contact_precedes_supply_opening()
	if failures.is_empty():
		print("FIELD_SUPPLY_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_SUPPLY_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city._ensure_war_loop_initialized()
	var silverford := Dictionary(city._war_loop_state.cities_by_id.get(&"silverford_city", {}))
	silverford.military_controller_faction_id = &"player"
	city._war_loop_state.cities_by_id[&"silverford_city"] = silverford
	return {"scene": scene, "city": city}


func _field(city: Node) -> Dictionary:
	return city.get_field_tactics_read_model()


func _first_transport(field: Dictionary) -> Dictionary:
	var ids: Array = Dictionary(field.get("supply_transports_by_id", {})).keys()
	ids.sort()
	return Dictionary(Dictionary(field.get("supply_transports_by_id", {})).get(ids.front(), {})) if not ids.is_empty() else {}


func _start_real_siege_for_supply_failure(city: Node) -> Dictionary:
	# Build the same ArmyRegistry + WarLoop siege state used by normal arrival,
	# then let the regular world-time loop hit its existing composition-sync
	# failure branch after the supply credit.  This fixture does not invent a
	# second settlement rollback path.
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	var roster: Array = city.get_formation_roster()
	if roster.is_empty():
		return {}
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"redcliff_city")
	if not bool(route.get("valid", false)):
		return {}
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(Dictionary(roster.front()).get("formation_id", &""))],
		&"redcliff_city", StringName(route.get("route_id", &"")), Array(route.get("points", []))
	)
	var army: Dictionary = Dictionary(issued.get("army", {}))
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	if army.is_empty() or macro.is_empty():
		return {}
	var advanced: Dictionary = city.advance_macro_march_time(
		StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0,
		int(macro.get("total_millis", 0))
	)
	var active_sieges: Array = city._war_loop_state.get_active_sieges()
	return {
		"issued": issued,
		"advanced": advanced,
		"siege": Dictionary(active_sieges.front()) if not active_sieges.is_empty() else {},
	}


func _check_departure_arrival_and_once_only_credit() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var preview: Dictionary = city.preview_field_supply_transport(&"silverford_city")
	var food_before: int = city.food
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var field_after_issue := _field(city)
	var transport := _first_transport(field_after_issue)
	var duplicate_before: Dictionary = city.export_v5_campaign_snapshot()
	var duplicate: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var duration := int(transport.get("total_milliseconds", 0))
	city.advance_war_loop_time(duration)
	var delivered := _first_transport(_field(city))
	var food_after_delivery: int = city.food
	city.advance_war_loop_time(2000)
	_check(
		bool(preview.get("valid", false))
			and bool(issued.get("success", false))
			and int(Dictionary(field_after_issue.get("supply_inventory_by_point_id", {})).get(&"silverford_city", -1)) == 0
			and int(transport.get("amount", 0)) == 20
			and not bool(duplicate.get("success", false))
			and city.export_v5_campaign_snapshot() != duplicate_before
			and bool(delivered.get("deposited", false))
			and city.food == food_after_delivery
			and food_after_delivery == food_before + 20,
		"占领银渡城后运输在出发时扣地点库存、抵达时只通过 NationState 入库一次"
	)
	scene.queue_free()
	await process_frame


func _check_no_route_and_capacity_waiting() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var field_state: FieldTacticsState = city._war_loop_state.field_tactics
	# Explicit test fault injection: isolate the no-route outcome without
	# weakening normal main-road rules or assuming the planner has one route.
	for road_id_value in field_state.roads_by_id.keys():
		var road_id := StringName(road_id_value)
		var road := Dictionary(field_state.roads_by_id.get(road_id, {}))
		road.state = FieldTacticsState.ROAD_DAMAGED
		field_state.roads_by_id[road_id] = road
	var no_route_food_before: int = city.food
	var no_route_field_before: Dictionary = _field(city)
	var no_route: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	_check(
		not bool(no_route.get("success", false))
			and city.food == no_route_food_before
			and Dictionary(_field(city).get("supply_inventory_by_point_id", {})) == Dictionary(no_route_field_before.get("supply_inventory_by_point_id", {}))
			and Dictionary(_field(city).get("supply_transports_by_id", {})) == Dictionary(no_route_field_before.get("supply_transports_by_id", {})),
		"没有可通行道路时不扣地点库存、不创建运输且不产生部分写入"
	)
	scene.queue_free()
	await process_frame

	fixture = await _new_city()
	scene = fixture.scene
	city = fixture.city
	city.food = city.get_resource_capacity(&"food")
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var transport := _first_transport(_field(city))
	city.advance_war_loop_time(int(transport.get("total_milliseconds", 0)))
	var waiting := _first_transport(_field(city))
	var full_food: int = city.food
	city.food = city.get_resource_capacity(&"food") - int(waiting.get("amount", 0))
	city.advance_war_loop_time(1)
	var unloaded := _first_transport(_field(city))
	_check(
		bool(issued.get("success", false))
			and StringName(waiting.get("phase", &"")) == FieldTacticsState.SUPPLY_WAITING_CAPACITY
			and full_food == city.get_resource_capacity(&"food")
			and bool(unloaded.get("deposited", false))
			and city.food == city.get_resource_capacity(&"food"),
		"黑石仓满时货物在城外待卸，腾出完整容量后才一次入库"
	)
	scene.queue_free()
	await process_frame


func _check_damaged_route_wait_and_resume() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var transport := _first_transport(_field(city))
	var segments: Array = Array(transport.get("route_segments", []))
	var road_id := StringName(Dictionary(segments.front()).get("road_id", &""))
	city.advance_war_loop_time(500)
	var elapsed_before_damage := int(_first_transport(_field(city)).get("elapsed_milliseconds", 0))
	# Explicit test fault injection: authored supply lanes are main roads and
	# remain indestructible in normal play; this isolates the convoy's required
	# behavior when a future engineered segment in its stored route is damaged.
	var damaged_road := Dictionary(city._war_loop_state.field_tactics.roads_by_id.get(road_id, {}))
	damaged_road.state = FieldTacticsState.ROAD_DAMAGED
	city._war_loop_state.field_tactics.roads_by_id[road_id] = damaged_road
	city.advance_war_loop_time(1000)
	var blocked := _first_transport(_field(city))
	damaged_road.state = FieldTacticsState.ROAD_OPEN
	city._war_loop_state.field_tactics.roads_by_id[road_id] = damaged_road
	city.advance_war_loop_time(int(blocked.get("total_milliseconds", 0)) - int(blocked.get("elapsed_milliseconds", 0)))
	var resumed := _first_transport(_field(city))
	_check(
		bool(issued.get("success", false))
			and int(blocked.get("elapsed_milliseconds", -1)) == elapsed_before_damage
			and StringName(blocked.get("phase", &"")) == FieldTacticsState.SUPPLY_WAITING_ROUTE
			and bool(resumed.get("deposited", false)),
		"运输途中道路受损会在真实位置等待，修复后沿同一有向道路继续"
	)
	scene.queue_free()
	await process_frame


func _check_snapshot_compatibility_and_mid_transit_restore() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var transport := _first_transport(_field(city))
	city.advance_war_loop_time(1200)
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var mid_transit := _first_transport(_field(city))
	var restored: Dictionary = city.restore_v5_campaign_snapshot(snapshot)
	var after_restore := _first_transport(_field(city))
	var legacy: Dictionary = snapshot.duplicate(true)
	var legacy_field: Dictionary = Dictionary(Dictionary(legacy.get("war_loop", {})).get("field_tactics", {})).duplicate(true)
	legacy_field.erase("supply_inventory_by_point_id")
	legacy_field.erase("supply_transports_by_id")
	legacy_field.erase("next_supply_transport_sequence")
	legacy_field.erase("stationed_reinforcements_by_point_id")
	legacy.war_loop.field_tactics = legacy_field
	var legacy_restored: Dictionary = city.restore_v5_campaign_snapshot(legacy)
	_check(
		bool(issued.get("success", false))
			and bool(restored.get("success", false))
			and int(after_restore.get("elapsed_milliseconds", -1)) == int(mid_transit.get("elapsed_milliseconds", -2))
			and Array(after_restore.get("route_segments", [])) == Array(mid_transit.get("route_segments", []))
			and bool(legacy_restored.get("success", false))
			and Dictionary(_field(city).get("supply_inventory_by_point_id", {})).is_empty(),
		"运输中 V5 快照恢复保留剩余路程；旧快照升级不凭空补发银渡库存"
	)
	scene.queue_free()
	await process_frame


func _check_strict_supply_snapshot_rejection() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var state: FieldTacticsState = city._war_loop_state.field_tactics
	var valid_snapshot := state.get_snapshot()
	var current_before := state.get_snapshot()
	var ids: Array = Dictionary(valid_snapshot.get("supply_transports_by_id", {})).keys()
	ids.sort()
	var transport_id := StringName(ids.front())
	var invalid_type := valid_snapshot.duplicate(true)
	Dictionary(invalid_type.supply_transports_by_id[transport_id]).amount = "20"
	var invalid_sequence := valid_snapshot.duplicate(true)
	invalid_sequence.next_supply_transport_sequence = 1
	var invalid_route := valid_snapshot.duplicate(true)
	var route_segments: Array = Array(Dictionary(invalid_route.supply_transports_by_id[transport_id]).get("route_segments", [])).duplicate(true)
	route_segments[1] = {"road_id": &"road.northwatch.forest", "forward": true}
	Dictionary(invalid_route.supply_transports_by_id[transport_id]).route_segments = route_segments
	var invalid_completed := valid_snapshot.duplicate(true)
	Dictionary(invalid_completed.supply_transports_by_id[transport_id]).phase = FieldTacticsState.SUPPLY_COMPLETED
	var duplicate_payload := valid_snapshot.duplicate(true)
	Dictionary(duplicate_payload.supply_inventory_by_point_id)[&"silverford_city"] = 20
	var invalid_middle_type := valid_snapshot.duplicate(true)
	var invalid_middle_points: Array = Array(Dictionary(invalid_middle_type.supply_transports_by_id[transport_id]).get("route_world_points", [])).duplicate(true)
	invalid_middle_points[1] = "not-a-world-point"
	Dictionary(invalid_middle_type.supply_transports_by_id[transport_id]).route_world_points = invalid_middle_points
	var invalid_middle_geometry := valid_snapshot.duplicate(true)
	var shifted_middle_points: Array = Array(Dictionary(invalid_middle_geometry.supply_transports_by_id[transport_id]).get("route_world_points", [])).duplicate(true)
	shifted_middle_points[1] = Vector2i(shifted_middle_points[1]) + Vector2i(31, -17)
	Dictionary(invalid_middle_geometry.supply_transports_by_id[transport_id]).route_world_points = shifted_middle_points
	_check(
		bool(issued.get("success", false))
			and not state.restore_snapshot(invalid_type)
			and not state.restore_snapshot(invalid_sequence)
			and not state.restore_snapshot(invalid_route)
			and not state.restore_snapshot(invalid_completed)
			and not state.restore_snapshot(duplicate_payload)
			and not state.restore_snapshot(invalid_middle_type)
			and not state.restore_snapshot(invalid_middle_geometry)
			and state.get_snapshot() == current_before,
		"补给快照在类型、序号、断路、完成态、库存货物重复或中间折线篡改时拒绝恢复且不污染当前状态"
	)
	scene.queue_free()
	await process_frame


func _check_capacity_checkpoint_and_repair_time_boundary() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	city.food = city.get_resource_capacity(&"food")
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var transport := _first_transport(_field(city))
	city.advance_war_loop_time(int(transport.get("total_milliseconds", 0)))
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.consume_supply_checkpoint_required()
	city.advance_war_loop_time(500)
	var second_wait_checkpoint := field.consume_supply_checkpoint_required()
	_check(
		bool(issued.get("success", false))
			and StringName(_first_transport(_field(city)).get("phase", &"")) == FieldTacticsState.SUPPLY_WAITING_CAPACITY
			and not second_wait_checkpoint,
		"仓满等待在首次状态转换保存后不随后续世界帧重复请求补给检查点"
	)
	scene.queue_free()
	await process_frame

	fixture = await _new_city()
	scene = fixture.scene
	city = fixture.city
	field = city._war_loop_state.field_tactics
	issued = city.begin_field_supply_transport(&"silverford_city")
	transport = _first_transport(_field(city))
	var route_segments: Array = Array(transport.get("route_segments", []))
	var repair_road_id := StringName(Dictionary(route_segments.back()).get("road_id", &""))
	var damaged := Dictionary(field.roads_by_id.get(repair_road_id, {}))
	damaged.state = FieldTacticsState.ROAD_DAMAGED
	# The authored trunk road is intentionally indestructible in play. This
	# isolated timing fixture makes the same physical route repairable so the
	# convoy observes a real REPAIR project rather than a direct ROAD_OPEN edit.
	damaged.road_kind = FieldTacticsState.ROAD_NORMAL
	field.roads_by_id[repair_road_id] = damaged
	var engineer := field.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var repair := field.begin_road_repair(StringName(engineer.get("specialist_id", &"")), repair_road_id)
	var repair_travel := int(Dictionary(field.specialists_by_id[StringName(engineer.get("specialist_id", &""))]).get("move_total_milliseconds", 0))
	var repair_work := int(repair.get("required_milliseconds", 0))
	var start_snapshot := field.get_snapshot()
	var one_step := FieldTacticsState.new()
	var split_step := FieldTacticsState.new()
	var thirty_fps := FieldTacticsState.new()
	var sixty_fps := FieldTacticsState.new()
	var irregular := FieldTacticsState.new()
	one_step.restore_snapshot(start_snapshot)
	split_step.restore_snapshot(start_snapshot)
	thirty_fps.restore_snapshot(start_snapshot)
	sixty_fps.restore_snapshot(start_snapshot)
	irregular.restore_snapshot(start_snapshot)
	one_step.advance_world(repair_travel + repair_work + 1000)
	split_step.advance_world(repair_travel + repair_work)
	split_step.advance_world(1000)
	var boundary_delta := repair_travel + repair_work + 1000
	_advance_field_in_steps(thirty_fps, boundary_delta, [33])
	_advance_field_in_steps(sixty_fps, boundary_delta, [17])
	_advance_field_in_steps(irregular, boundary_delta, [11, 47, 23, 61, 19])
	var one_transport := Dictionary(one_step.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	var split_transport := Dictionary(split_step.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	var thirty_transport := Dictionary(thirty_fps.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	var sixty_transport := Dictionary(sixty_fps.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	var irregular_transport := Dictionary(irregular.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	_check(
		bool(issued.get("success", false)) and not repair.is_empty()
			and one_step.is_route_open(repair_road_id)
			and int(one_transport.get("elapsed_milliseconds", -1)) == 1000
			and one_transport == split_transport
			and one_transport == thirty_transport
			and one_transport == sixty_transport
			and one_transport == irregular_transport,
		"真实维修在同一世界步完成时，运输只消费维修后可用的 1000 毫秒，且与 30/60 FPS、不规则拆分推进一致"
	)
	scene.queue_free()
	await process_frame


func _advance_field_in_steps(field: FieldTacticsState, total_milliseconds: int, steps: Array) -> void:
	var remaining := total_milliseconds
	var index := 0
	while remaining > 0:
		var step := mini(maxi(int(steps[index % steps.size()]), 1), remaining)
		field.advance_world(step)
		remaining -= step
		index += 1


func _check_supply_delivery_failure_rollback() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var siege_setup := _start_real_siege_for_supply_failure(city)
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var transport := _first_transport(_field(city))
	var before: Dictionary = city.export_v5_campaign_snapshot()
	var food_before := int(city.food)
	city.set_field_supply_fault_for_test(&"SIEGE_ARMY_REPLACE_FAIL")
	var injected: Dictionary = city.advance_war_loop_time(int(transport.get("total_milliseconds", 0)))
	var after_credit_failure: Dictionary = city.export_v5_campaign_snapshot()
	var retry: Dictionary = city.advance_war_loop_time(int(transport.get("total_milliseconds", 0)))
	var delivered := _first_transport(_field(city))
	_check(
		not Dictionary(siege_setup.get("siege", {})).is_empty()
			and bool(issued.get("success", false))
			and StringName(injected.get("error_id", &"")) == &"SIEGE_ARMY_SYNC_FAILED"
			and city.food == food_before + 20
			and before == after_credit_failure
			and bool(delivered.get("deposited", false))
			and bool(retry.get("success", false)),
		"入库后的真实攻城编队同步失败走既有回滚分支；恢复正常后重试只入库一次"
	)
	scene.queue_free()
	await process_frame

	fixture = await _new_city()
	scene = fixture.scene
	city = fixture.city
	issued = city.begin_field_supply_transport(&"silverford_city")
	transport = _first_transport(_field(city))
	before = city.export_v5_campaign_snapshot()
	food_before = int(city.food)
	city.set_field_supply_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	injected = city.advance_war_loop_time(int(transport.get("total_milliseconds", 0)))
	_check(
		bool(issued.get("success", false))
			and StringName(injected.get("error_id", &"")) == &"SAVE_FAILED"
			and city.food == food_before
			and city.export_v5_campaign_snapshot() == before,
		"关键保存失败会回滚已入库粮草和运输完成态，不留下半笔事务"
	)
	scene.queue_free()
	await process_frame


func _check_repair_contact_precedes_supply_opening() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	var issued: Dictionary = city.begin_field_supply_transport(&"silverford_city")
	var transport := _first_transport(_field(city))
	var route_segments: Array = Array(transport.get("route_segments", []))
	var repair_road_id := StringName(Dictionary(route_segments.back()).get("road_id", &""))
	var damaged_road := Dictionary(field.roads_by_id.get(repair_road_id, {}))
	damaged_road.state = FieldTacticsState.ROAD_DAMAGED
	damaged_road.road_kind = FieldTacticsState.ROAD_NORMAL
	field.roads_by_id[repair_road_id] = damaged_road
	var engineer := field.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var engineer_id := StringName(engineer.get("specialist_id", &""))
	var repair := field.begin_road_repair(engineer_id, repair_road_id)
	# This patrol is already within timed-contact range at the repair point. It
	# exercises Field's real patrol/specialist contact before any repair work is
	# consumed, making the event-order invariant exact for large and split steps.
	field.patrols_by_id[&"patrol.supply.repair_contact"] = {
		"patrol_id": &"patrol.supply.repair_contact",
		"strength": 1,
		"world_position": Vector2i(160, 650),
		"current_point_id": &"blackstone_city",
		"route_point_ids": [&"blackstone_city", &"northwatch_garrison"],
		"target_route_index": 0,
		"wait_remaining_milliseconds": 3500,
		"move_total_milliseconds": 2500,
		"move_elapsed_milliseconds": 0,
		"move_start_position": Vector2i(160, 650),
		"move_route_world_points": [Vector2i(160, 650), Vector2i(135, 650)],
	}
	var start_snapshot := field.get_snapshot()
	var one_step := FieldTacticsState.new()
	var split_step := FieldTacticsState.new()
	one_step.restore_snapshot(start_snapshot)
	split_step.restore_snapshot(start_snapshot)
	var one_result := one_step.advance_world(3500)
	_advance_field_in_steps(split_step, 3500, [17, 33, 11, 29])
	var one_project := Dictionary(one_step.projects_by_id.get(StringName(repair.get("project_id", &"")), {}))
	var split_project := Dictionary(split_step.projects_by_id.get(StringName(repair.get("project_id", &"")), {}))
	var one_road := Dictionary(one_step.roads_by_id.get(repair_road_id, {}))
	var split_road := Dictionary(split_step.roads_by_id.get(repair_road_id, {}))
	var one_transport := Dictionary(one_step.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	var split_transport := Dictionary(split_step.supply_transports_by_id.get(StringName(transport.get("transport_id", &"")), {}))
	_check(
		bool(issued.get("success", false)) and not repair.is_empty()
			and not bool(Dictionary(one_step.specialists_by_id.get(engineer_id, {})).get("alive", true))
			and StringName(one_project.get("phase", &"")) == &"INTERRUPTED"
			and int(one_project.get("progress_milliseconds", 9999)) < int(one_project.get("required_milliseconds", 0))
			and StringName(one_road.get("state", &"")) == FieldTacticsState.ROAD_DAMAGED
			and int(one_road.get("durability", -1)) == int(damaged_road.get("durability", -2))
			and int(one_transport.get("elapsed_milliseconds", -1)) == 0
			and StringName(one_transport.get("phase", &"")) == FieldTacticsState.SUPPLY_WAITING_ROUTE
			and Array(one_result.get("ready_supply_transport_ids", [])).is_empty()
			and one_project == split_project and one_road == split_road and one_transport == split_transport,
		"工程师在维修完成前遭遇巡逻时中断工程、保持道路受损且运输不提前通车或入库；大步与拆帧一致"
	)
	scene.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
