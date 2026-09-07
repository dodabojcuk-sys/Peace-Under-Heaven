extends SceneTree


const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")
const FIELD_TACTICS_STATE = preload("res://scripts/war/field_tactics_state.gd")
const WAR_LOOP_STATE = preload("res://scripts/war/war_loop_state.gd")
const ARMY_REGISTRY = preload("res://scripts/army/army_registry.gd")
const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const WAR_LOOP_RULES: WarLoopRules = preload("res://resources/war/war_loop_r1_rules.tres")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_run_parallel_army_contract()
	_run_field_tactics_contract()
	_run_r1_war_snapshot_migration()
	await _run_formal_controller_contract()
	await _run_damaged_road_resume_contract()
	_finish()


func _run_parallel_army_contract() -> void:
	var registry: ArmyRegistry = ARMY_REGISTRY.new()
	var left: Array = [{"formation_id": &"left", "definition_id": &"infantry", "display_name": "左队", "member_count": 6, "max_members": 6}]
	var right: Array = [{"formation_id": &"right", "definition_id": &"infantry", "display_name": "右队", "member_count": 7, "max_members": 7}]
	var first := registry.create_macro_march(&"player", &"blackstone_city", &"blackstone_city", &"northwatch_garrison", &"road.a", [Vector2i.ZERO, Vector2i.ONE], {&"infantry": 6}, left, 1, 100)
	var second := registry.create_macro_march(&"player", &"blackstone_city", &"blackstone_city", &"reedbank_garrison", &"road.b", [Vector2i.ZERO, Vector2i(2, 1)], {&"infantry": 7}, right, 1, 100)
	_check(not first.is_empty() and not second.is_empty() and registry.get_active_macro_armies().size() == 2, "两支不同编队可并行持有独立军令")
	var duplicate_snapshot := registry.get_snapshot()
	var duplicate_army: Dictionary = Dictionary(duplicate_snapshot.armies_by_id[second.army_id]).duplicate(true)
	duplicate_army.macro_march.formation_snapshots = left.duplicate(true)
	duplicate_army.units_by_definition_id = {&"infantry": 6}
	duplicate_snapshot.armies_by_id[second.army_id] = duplicate_army
	var duplicate_validation := ArmyRegistry.validate_snapshot(duplicate_snapshot, [&"infantry"], false)
	_check(not bool(duplicate_validation.valid) and StringName(duplicate_validation.error_id) == &"DUPLICATE_MACRO_FORMATION", "快照拒绝同一编队同时属于两支军队")


func _run_field_tactics_contract() -> void:
	var state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	state.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	var bridge_state: FieldTacticsState = FIELD_TACTICS_STATE.new()
	bridge_state.initialize_from_theater(THEATER.get_points(), THEATER.get_routes(), [Rect2i(515, 350, 120, 145)])
	var bridge_engineer := bridge_state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var bridge_project := bridge_state.begin_road_project(
		StringName(bridge_engineer.specialist_id), &"blackstone_city", &"camp.site.bridge",
		[Vector2i(150, 430), Vector2i(475, 420), Vector2i(710, 410)], FieldTacticsState.ROAD_NORMAL, true
	)
	_check(
		StringName(bridge_project.get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE
			and int(bridge_project.get("required_milliseconds", 0)) == 11000,
		"战区 Resource 水域命中的工程线自动成为桥梁项目，而非普通道路"
	)
	_check(state.is_route_open(&"road.blackstone.northwatch.ridge"), "主路进入运行时路网且默认可通行")
	var hidden := state.observe_subject(&"patrol.ridge.001")
	_check(StringName(hidden.get("fog_state", &"")) == FieldTacticsState.FOG_UNOBSERVED and int(hidden.get("known_strength", 0)) == 0, "未侦察巡逻不泄露实时兵力")
	var scout := state.dispatch_specialist(FieldTacticsState.SPECIALIST_SCOUT, &"blackstone_city")
	state.order_specialist_move(StringName(scout.specialist_id), &"northwatch_garrison")
	state.advance_world(450)
	var scout_midway := Dictionary(state.specialists_by_id[scout.specialist_id])
	_check(Vector2(scout_midway.get("world_position", Vector2.ZERO)).distance_to(Vector2(150, 430)) > 1.0 and StringName(state.observe_subject(&"patrol.ridge.001").get("fog_state", &"")) == FieldTacticsState.FOG_UNOBSERVED, "侦察兵按实际坐标连续移动，远离视野时不泄露巡逻")
	state.advance_world(1349)
	_check(StringName(Dictionary(state.specialists_by_id[scout.specialist_id]).get("current_point_id", &"")) == &"blackstone_city", "侦察兵在途期间不提前到达或揭示敌情")
	state.advance_world(1)
	var observed := state.observe_subject(&"patrol.ridge.001")
	_check(StringName(observed.get("fog_state", &"")) == FieldTacticsState.FOG_OBSERVED and int(observed.get("known_strength", 0)) == 5 and not bool(Dictionary(state.specialists_by_id[scout.specialist_id]).get("alive", true)), "侦察兵到达实际位置后获得最后情报，并会在同一节点被巡逻击杀")
	state.advance_world(1000)
	var patrol_after_departure := Dictionary(state.patrols_by_id[&"patrol.ridge.001"])
	var historical_intel := state.observe_subject(&"patrol.ridge.001")
	_check(
		Vector2(patrol_after_departure.get("world_position", Vector2.ZERO)).distance_to(Vector2(790, 170)) > 1.0
			and StringName(historical_intel.get("fog_state", &"")) == FieldTacticsState.FOG_OBSERVED
			and Vector2i(historical_intel.get("last_known_world_position", Vector2i.ZERO)) == Vector2i(790, 170),
		"巡逻在等待后沿路线实际移动；失去观察后情报保留最后观察坐标而不追踪当前位置"
	)
	var engineer := state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var project := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"reedbank_garrison", [Vector2i(150, 430), Vector2i(440, 570), Vector2i(850, 505)], FieldTacticsState.ROAD_NORMAL, true)
	_check(not project.is_empty() and not state.is_route_open(StringName(project.road_id)), "工程确认后保留施工事务，未完成道路不能提前通军")
	state.advance_world(int(project.required_milliseconds) - 1)
	_check(not state.is_route_open(StringName(project.road_id)), "施工进度未满时动态道路仍不可通行")
	state.advance_world(1)
	var completed_road := Dictionary(state.roads_by_id.get(StringName(project.road_id), {}))
	_check(state.is_route_open(StringName(project.road_id)) and not state.camps_by_id.is_empty(), "工程完成后道路与道路相连驻扎点同时成为正式运行时节点")
	var runtime_route := state.validate_runtime_route(&"blackstone_city", &"reedbank_garrison", StringName(project.road_id), Array(project.route_world_points))
	_check(bool(runtime_route.get("valid", false)) and state.runtime_route_duration_milliseconds(StringName(project.road_id)) >= 6000, "完工工程道路进入正式军令校验与行军时长计算")
	_check(state.damage_road(StringName(project.road_id), 999) and not state.is_route_open(StringName(project.road_id)), "敌方造成的真实路损会改变通行状态")
	var repair := state.begin_road_repair(StringName(engineer.specialist_id), StringName(project.road_id))
	var repair_travel := int(Dictionary(state.specialists_by_id[StringName(engineer.specialist_id)]).get("move_total_milliseconds", 0))
	_check(not repair.is_empty() and not state.is_route_open(StringName(project.road_id)) and repair_travel > 0, "远处受损道路先建立工程师到场维修事务，不能隔空立即修好")
	var repair_start_snapshot := state.get_snapshot()
	var one_step_repair: FieldTacticsState = FIELD_TACTICS_STATE.new()
	var split_step_repair: FieldTacticsState = FIELD_TACTICS_STATE.new()
	one_step_repair.restore_snapshot(repair_start_snapshot)
	split_step_repair.restore_snapshot(repair_start_snapshot)
	one_step_repair.advance_world(repair_travel + int(repair.required_milliseconds))
	split_step_repair.advance_world(repair_travel)
	split_step_repair.advance_world(int(repair.required_milliseconds))
	_check(
		Dictionary(one_step_repair.get_snapshot().roads_by_id) == Dictionary(split_step_repair.get_snapshot().roads_by_id)
			and Dictionary(one_step_repair.get_snapshot().projects_by_id) == Dictionary(split_step_repair.get_snapshot().projects_by_id)
			and Dictionary(one_step_repair.get_snapshot().specialists_by_id) == Dictionary(split_step_repair.get_snapshot().specialists_by_id)
			and one_step_repair.is_route_open(StringName(project.road_id)),
		"维修到场帧余量计入施工：一次推进与拆分推进得到相同道路和项目状态"
	)
	state.advance_world(repair_travel)
	_check(not state.is_route_open(StringName(project.road_id)), "工程师到达维修点的同一时间步不跳过维修工期")
	state.advance_world(int(repair.required_milliseconds) - 1)
	_check(not state.is_route_open(StringName(project.road_id)), "维修进度未完成时道路继续阻断军队通行")
	state.advance_world(1)
	var reverse_points := Array(project.route_world_points).duplicate(true)
	reverse_points.reverse()
	_check(
		state.is_route_open(StringName(project.road_id))
			and bool(state.validate_runtime_route(&"reedbank_garrison", &"blackstone_city", StringName(project.road_id), reverse_points).get("valid", false)),
		"工程师到场完成后恢复原道路身份，并允许同一路段反向往返"
	)
	state.order_specialist_move(StringName(engineer.specialist_id), &"blackstone_city")
	state.advance_world(int(Dictionary(state.specialists_by_id[StringName(engineer.specialist_id)]).get("move_total_milliseconds", 0)))
	var camp_project := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"camp.site.000001", [Vector2i(150, 430), Vector2i(355, 410), Vector2i(470, 355)], FieldTacticsState.ROAD_NORMAL, true)
	state.advance_world(int(camp_project.get("required_milliseconds", 0)))
	var runtime_points := state.get_runtime_points()
	_check(not camp_project.is_empty() and runtime_points.has(&"camp.site.000001") and state.validate_runtime_route(&"blackstone_city", &"camp.site.000001", StringName(camp_project.get("road_id", &"")), Array(camp_project.get("route_world_points", []))).get("valid", false), "玩家指定的新工程驻点以运行时坐标进入可通军路网")
	var concurrent_engineer := state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var first_concurrent := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"", [Vector2i(150, 430), Vector2i(275, 360)], FieldTacticsState.ROAD_NORMAL, true)
	var second_concurrent := state.begin_road_project(StringName(concurrent_engineer.specialist_id), &"blackstone_city", &"", [Vector2i(150, 430), Vector2i(285, 510)], FieldTacticsState.ROAD_NORMAL, true)
	_check(
		not first_concurrent.is_empty() and not second_concurrent.is_empty()
			and StringName(first_concurrent.target_point_id) != StringName(second_concurrent.target_point_id)
			and StringName(first_concurrent.camp_id) != StringName(second_concurrent.camp_id)
			and state.next_camp_sequence == 5,
		"两名工程师在首项完工前确认工程时分别保留不同驻点编号"
	)
	var snapshot := state.get_snapshot()
	var restored: FieldTacticsState = FIELD_TACTICS_STATE.new()
	_check(restored.restore_snapshot(snapshot) and restored.is_route_open(StringName(project.road_id)), "施工、驻点、道路与探索记录可随战役快照冷恢复")
	var invalid := snapshot.duplicate(true)
	invalid.next_project_sequence = 0
	_check(not FieldTacticsState.new().restore_snapshot(invalid), "无效战术快照在写入前被拒绝")


func _run_r1_war_snapshot_migration() -> void:
	var legacy := {
		"schema_version": 1,
		"cities_by_id": {},
		"required_city_ids": {},
		"active_siege": {},
		"completed_resolution_ids": {},
		"next_siege_sequence": 1,
	}
	var state: WarLoopState = WAR_LOOP_STATE.new()
	_check(state.restore_snapshot(legacy) and state.get_snapshot().has("field_tactics"), "R1 单攻城快照迁移为带战区状态的 R2 快照")
	var parallel: WarLoopState = WAR_LOOP_STATE.new()
	parallel.initialize_from_theater(THEATER.get_points(), THEATER.get_routes())
	var silverford := parallel.get_city(&"silverford_city")
	silverford.surrender_allowed = false
	parallel.cities_by_id[&"silverford_city"] = silverford
	var red_siege := parallel.begin_siege(&"army.red", &"macro.order.000101", &"redcliff_city", 12, 100, 8, 1, 10000, WAR_LOOP_RULES)
	var silver_siege := parallel.begin_siege(&"army.silver", &"macro.order.000102", &"silverford_city", 12, 100, 8, 1, 10000, WAR_LOOP_RULES)
	var parallel_ticks := parallel.advance_parallel_sieges(WAR_LOOP_RULES)
	var parallel_snapshot := parallel.get_snapshot()
	var parallel_restored: WarLoopState = WAR_LOOP_STATE.new()
	_check(not red_siege.is_empty() and not silver_siege.is_empty() and parallel.get_active_sieges().size() == 2 and parallel_ticks.size() == 2 and parallel_restored.restore_snapshot(parallel_snapshot) and parallel_restored.get_active_sieges().size() == 2, "不同敌城可保留并推进独立攻城记录并冷恢复")


func _run_formal_controller_contract() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 120
	var roster: Array[Dictionary] = city.get_formation_roster()
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var lowland: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.lowland")
	var first: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(ridge.route_id), Array(ridge.points))
	var second: Dictionary = city.commit_macro_march_from_city([StringName(roster[1].formation_id)], &"northwatch_garrison", StringName(lowland.route_id), Array(lowland.points))
	_check(bool(first.get("success", false)) and bool(second.get("success", false)) and Array(city.get_macro_march_read_model().armies).size() == 2, "正式城市入口可对不同编队提交两支并行军令")
	var duplicate: Dictionary = city.commit_macro_march_from_city([StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(ridge.route_id), Array(ridge.points))
	_check(not bool(duplicate.get("success", false)), "正式入口拒绝已经由第一支军队占用的编队")
	var scout: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_SCOUT)
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	_check(bool(scout.get("success", false)) and bool(engineer.get("success", false)), "侦察兵和工程师通过正式城市资源事务派遣")
	var project: Dictionary = city.begin_field_road_project(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), &"blackstone_city", &"reedbank_garrison", [Vector2i(150, 430), Vector2i(440, 570), Vector2i(850, 505)], FieldTacticsState.ROAD_NORMAL, true)
	city.advance_war_loop_time(5000)
	var field_model: Dictionary = city.get_field_tactics_read_model()
	_check(bool(project.get("success", false)) and not Dictionary(field_model.projects_by_id).is_empty() and not Dictionary(field_model.camps_by_id).is_empty(), "正式世界时间推进工程，并将道路和驻点投影给地图")
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restored_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(bool(restored_result.get("success", false)) and Array(restored.get_macro_march_read_model().armies).size() == 2 and not Dictionary(restored.get_field_tactics_read_model().camps_by_id).is_empty(), "两支军令与工程战区状态可在同一正式快照冷恢复")
	scene.queue_free()
	restored_scene.queue_free()
	await process_frame


func _run_damaged_road_resume_contract() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.food = 140
	var engineer: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var route_points := [Vector2i(150, 430), Vector2i(340, 470), Vector2i(480, 440)]
	var project: Dictionary = city.begin_field_road_project(
		StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")),
		&"blackstone_city", &"camp.site.resume", route_points, FieldTacticsState.ROAD_NORMAL, true
	)
	city.advance_war_loop_time(int(Dictionary(project.get("project", {})).get("required_milliseconds", 0)))
	var road_id := StringName(Dictionary(project.get("project", {})).get("road_id", &""))
	var roster: Array[Dictionary] = city.get_formation_roster()
	var issued: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"camp.site.resume", road_id, route_points
	)
	var army_before_damage: Dictionary = Dictionary(issued.get("army", {}))
	var food_after_issue := int(city.food)
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.damage_road(road_id, 999)
	city._advance_all_macro_marches_seconds(1.0)
	var blocked: Dictionary = city._army_registry.get_army(StringName(army_before_damage.get("army_id", &"")))
	var repair: Dictionary = city.begin_field_road_repair(StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &"")), road_id)
	var repair_engineer := Dictionary(field.specialists_by_id[StringName(Dictionary(engineer.get("specialist", {})).get("specialist_id", &""))])
	city.advance_war_loop_time(int(repair_engineer.get("move_remaining_milliseconds", 0)) + int(Dictionary(repair.get("project", {})).get("required_milliseconds", 0)))
	var resumed: Dictionary = city._army_registry.get_army(StringName(army_before_damage.get("army_id", &"")))
	city._advance_all_macro_marches_seconds(1.0)
	var advancing: Dictionary = city._army_registry.get_army(StringName(army_before_damage.get("army_id", &"")))
	_check(
		bool(project.get("success", false)) and bool(issued.get("success", false)) and bool(repair.get("success", false))
			and StringName(blocked.get("phase", &"")) == ArmyRegistry.PHASE_BLOCKED
			and StringName(resumed.get("phase", &"")) == ArmyRegistry.PHASE_MARCHING
			and StringName(Dictionary(resumed.get("macro_march", {})).get("order_id", &"")) == StringName(Dictionary(army_before_damage.get("macro_march", {})).get("order_id", &""))
			and int(city.food) == food_after_issue - int(repair.get("food_cost", 0))
			and int(Dictionary(advancing.get("macro_march", {})).get("progress_millis", 0)) > int(Dictionary(resumed.get("macro_march", {})).get("progress_millis", 0)),
		"真实受损道路使军令就近受阻；到场维修后原 order 自动恢复且不重复扣行军粮"
	)
	scene.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)


func _finish() -> void:
	if failures.is_empty():
		print("FIELD_TACTICS_R2_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_TACTICS_R2_SMOKE FAIL: %s" % failure)
	quit(1)
