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


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
