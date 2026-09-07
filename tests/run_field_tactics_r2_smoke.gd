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
	_check(state.is_route_open(&"road.blackstone.northwatch.ridge"), "主路进入运行时路网且默认可通行")
	var hidden := state.observe_subject(&"patrol.ridge.001")
	_check(StringName(hidden.get("fog_state", &"")) == FieldTacticsState.FOG_UNOBSERVED and int(hidden.get("known_strength", 0)) == 0, "未侦察巡逻不泄露实时兵力")
	var scout := state.dispatch_specialist(FieldTacticsState.SPECIALIST_SCOUT, &"blackstone_city")
	state.order_specialist_move(StringName(scout.specialist_id), &"northwatch_garrison")
	state.advance_world(1)
	var observed := state.observe_subject(&"patrol.ridge.001")
	_check(StringName(observed.get("fog_state", &"")) == FieldTacticsState.FOG_VISIBLE and int(observed.get("known_strength", 0)) == 5, "侦察兵到达实际位置后才获得敌情")
	var engineer := state.dispatch_specialist(FieldTacticsState.SPECIALIST_ENGINEER, &"blackstone_city")
	var project := state.begin_road_project(StringName(engineer.specialist_id), &"blackstone_city", &"reedbank_garrison", [Vector2i(150, 430), Vector2i(440, 570), Vector2i(850, 505)], FieldTacticsState.ROAD_NORMAL, true)
	_check(not project.is_empty() and not state.is_route_open(StringName(project.road_id)), "工程确认后保留施工事务，未完成道路不能提前通军")
	state.advance_world(int(project.required_milliseconds) - 1)
	_check(not state.is_route_open(StringName(project.road_id)), "施工进度未满时动态道路仍不可通行")
	state.advance_world(1)
	var completed_road := Dictionary(state.roads_by_id.get(StringName(project.road_id), {}))
	_check(state.is_route_open(StringName(project.road_id)) and not state.camps_by_id.is_empty(), "工程完成后道路与道路相连驻扎点同时成为正式运行时节点")
	_check(state.damage_road(StringName(project.road_id), 999) and not state.is_route_open(StringName(project.road_id)), "敌方造成的真实路损会改变通行状态")
	_check(state.repair_road(StringName(engineer.specialist_id), StringName(project.road_id)) and state.is_route_open(StringName(project.road_id)), "工程师维修后恢复原道路身份而不重写已发军令")
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
