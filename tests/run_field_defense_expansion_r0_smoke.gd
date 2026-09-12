extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	var blackstone_capability: Dictionary = MacroMarchTheater.get_location_capability(&"blackstone_city")
	var silverford_capability: Dictionary = MacroMarchTheater.get_location_capability(&"silverford_city")
	var redcliff_capability: Dictionary = MacroMarchTheater.get_location_capability(&"redcliff_city")
	_check(
		bool(blackstone_capability.get("allows_long_term_construction", false))
		and not bool(silverford_capability.get("allows_long_term_construction", true))
		and bool(silverford_capability.get("allows_supply_transfer", false))
		and not bool(redcliff_capability.get("allows_inner_city_actions", true))
		and not bool(redcliff_capability.get("allows_long_term_construction", true)),
		"主城、资源城和占领驻点从同一地点能力表获得建设、补给与内城权限"
	)
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	var initial_day := int(city.current_day)
	var initial_wood := int(city.wood)
	var initial_food := int(city.food)
	var defense_anchor := Vector2i(MacroMarchTheater.get_point(&"northwatch_garrison").get("world_position", Vector2i.ZERO))
	field.camps_by_id[&"camp.defense.expansion"] = {
		"camp_id": &"camp.defense.expansion",
		"point_id": &"northwatch_garrison",
		"road_id": &"road.blackstone.northwatch.ridge",
		"display_name": "防线工程驻点",
		"world_position": defense_anchor,
		"durability": 80,
		"connected": true,
	}
	var engineer_result: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_result.get("specialist", {})).get("specialist_id", &""))

	var fortress_id := await _build_facility(city, field, engineer_id, FieldTacticsState.FACILITY_FORTRESS, defense_anchor + Vector2i(50, 0))
	var mine_id := await _build_facility(city, field, engineer_id, FieldTacticsState.FACILITY_MINEFIELD, defense_anchor + Vector2i(85, 0))
	var arrow_id := await _build_facility(city, field, engineer_id, FieldTacticsState.FACILITY_ARROW_TOWER, defense_anchor + Vector2i(120, 0))
	_check(fortress_id != &"" and mine_id != &"" and arrow_id != &"" and initial_day == 1 and int(city.current_day) <= 4 and int(city.wood) == initial_wood and int(city.food) < initial_food and int(city.wood) >= 0 and int(city.food) >= 0, "正常开局不补资源即可在第 4 日预警前，以真实工程师、配置粮食成本和施工进度完成有意义的基础防线")

	var fortress := Dictionary(field.watchtowers_by_id.get(fortress_id, {}))
	var formation_id := StringName(Dictionary(city.get_garrison_snapshot()).get("formations", [])[0].formation_id)
	var route: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison")
	var march: Dictionary = city.commit_macro_march_from_city([formation_id], &"northwatch_garrison", StringName(route.get("route_id", &"")), Array(route.get("points", [])))
	var army := Dictionary(march.get("army", {}))
	var macro := Dictionary(army.get("macro_march", {}))
	city.advance_macro_march_time(StringName(army.get("army_id", &"")), StringName(macro.get("order_id", &"")), 0, int(macro.get("total_millis", 0)))
	var stationed_army: Dictionary = city._army_registry.get_army(StringName(army.get("army_id", &"")))
	var assignment: Dictionary = city.assign_field_fortress_garrison(fortress_id, StringName(army.get("army_id", &"")))
	var assigned := bool(assignment.get("success", false))
	var duplicate_assignment := field.assign_fortress_garrison(fortress_id, &"army.test.other", Vector2(fortress.world_position))
	var absorbed := field.absorb_fortress_casualties(fortress_id, 2)
	fortress = Dictionary(field.watchtowers_by_id.get(fortress_id, {}))
	_check(StringName(stationed_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED and assigned and not duplicate_assignment and absorbed and int(fortress.durability) == int(fortress.max_durability) - 20 and StringName(fortress.state) == FieldTacticsState.FACILITY_DAMAGED, "堡垒只绑定同一 ArmyRegistry 的真实驻扎军队，并把避免的伤亡转成自身耐久损失")

	field.patrols_by_id[&"patrol.mine.target"] = {
		"patrol_id": &"patrol.mine.target", "current_point_id": &"", "world_position": defense_anchor + Vector2i(150, 0),
		"strength": 8, "phase": &"PATROL", "route_point_ids": [], "last_engagement": {},
	}
	var mine_events := field._apply_field_facility_effects(1000, [{"patrol_id": &"patrol.mine.target", "from": defense_anchor, "to": defense_anchor + Vector2i(150, 0)}])
	var mine_after_first := Dictionary(field.watchtowers_by_id.get(mine_id, {}))
	var repeat_events := field._apply_field_facility_effects(1000, [{"patrol_id": &"patrol.mine.target", "from": defense_anchor, "to": defense_anchor + Vector2i(150, 0)}])
	_check(mine_events.any(func(event: Dictionary) -> bool: return StringName(event.get("effect", &"")) == &"MINE_TRIGGER") and int(mine_after_first.mine_charges) == 1 and not repeat_events.any(func(event: Dictionary) -> bool: return StringName(event.get("effect", &"")) == &"MINE_TRIGGER") and int(Dictionary(field.patrols_by_id[&"patrol.mine.target"]).strength) == 5, "地雷只在真实路线穿越时触发一次；消耗与伤害不会因重复推进重播")

	var player_mine_record := Dictionary(field.watchtowers_by_id[mine_id]).duplicate(true)
	var hostile_mine_record := player_mine_record.duplicate(true)
	hostile_mine_record.owner_faction_id = &"redcliff"
	hostile_mine_record.discovered_by_faction_ids = []
	field.watchtowers_by_id[mine_id] = hostile_mine_record
	var hidden_before_discovery := not Dictionary(city.get_field_tactics_read_model().get("watchtowers_by_id", {})).has(mine_id)
	var discovered := field.discover_minefield(mine_id, &"player", engineer_id)
	var visible_after_discovery := Dictionary(city.get_field_tactics_read_model().get("watchtowers_by_id", {})).has(mine_id)
	var mine_clear_snapshot := field.get_snapshot()
	var mine_clear_probe := FieldTacticsState.new()
	var mine_clear_restored := mine_clear_probe.restore_snapshot(mine_clear_snapshot)
	mine_clear_probe.scout_visibility_range = field.scout_visibility_range
	var cleared := mine_clear_restored and mine_clear_probe.clear_discovered_minefield(mine_id, &"player", engineer_id)
	var cleared_snapshot := mine_clear_probe.get_snapshot() if cleared else {}
	var cleared_cold_probe := FieldTacticsState.new()
	var cleared_cold_ok := not cleared_snapshot.is_empty() and cleared_cold_probe.restore_snapshot(cleared_snapshot)
	var cleared_mine := Dictionary(cleared_cold_probe.watchtowers_by_id.get(mine_id, {}))
	print("MINE_DISCOVERY_TRACE hidden=%s discovered=%s visible=%s cleared=%s cold=%s" % [str(hidden_before_discovery), str(discovered), str(visible_after_discovery), str(cleared), str(cleared_cold_ok)])
	_check(hidden_before_discovery and discovered and visible_after_discovery and cleared and cleared_cold_ok and int(cleared_mine.get("mine_charges", -1)) == 0 and StringName(cleared_mine.get("state", &"")) == FieldTacticsState.FACILITY_DESTROYED, "敌方地雷在侦察前不进入玩家读模型；现场发现、排除与消耗态均可恢复")
	field.watchtowers_by_id[mine_id] = player_mine_record

	var arrow := Dictionary(field.watchtowers_by_id[arrow_id])
	arrow.durability = int(arrow.max_durability) / 2
	field.watchtowers_by_id[arrow_id] = arrow
	var food_before_upgrade := int(city.food)
	var upgrade_preview: Dictionary = city.preview_field_facility_upgrade(engineer_id, arrow_id)
	var upgrade_result: Dictionary = city.begin_field_facility_upgrade(engineer_id, arrow_id)
	var upgrade_project := Dictionary(upgrade_result.get("project", {}))
	var upgrade_total := int(upgrade_project.get("travel_milliseconds", 0)) + int(upgrade_project.get("required_milliseconds", 0))
	var upgrade_first_step := maxi(upgrade_total / 2, 1)
	city.advance_war_loop_time(upgrade_first_step)
	var mid_upgrade := Dictionary(field.watchtowers_by_id[arrow_id])
	var mid_snapshot := field.get_snapshot()
	var restored := FieldTacticsState.new()
	var restored_ok := restored.restore_snapshot(mid_snapshot)
	if restored_ok:
		restored.advance_world(upgrade_total - upgrade_first_step + 1)
	var upgraded := Dictionary(restored.watchtowers_by_id.get(arrow_id, {}))
	_check(
		bool(upgrade_preview.get("valid", false)) and bool(upgrade_result.get("success", false))
		and int(city.food) == food_before_upgrade - int(upgrade_preview.get("food_cost", 0))
		and int(mid_upgrade.level) == 1 and int(mid_upgrade.damage) == 1
		and int(upgraded.level) == 2 and int(upgraded.damage) == 2
		and int(upgraded.durability) * 2 == int(upgraded.max_durability),
		"升级进行中保留旧能力；读档续建只结算一次，并按旧耐久比例提升真实参数"
	)

	var snapshot := restored.get_snapshot()
	var cold_restored := FieldTacticsState.new()
	var cold_restored_ok := cold_restored.restore_snapshot(snapshot)
	_check(cold_restored_ok and cold_restored.get_snapshot() == snapshot and int(Dictionary(cold_restored.watchtowers_by_id[mine_id]).mine_charges) == 1 and StringName(Dictionary(cold_restored.watchtowers_by_id[fortress_id]).garrison_army_id) == StringName(army.get("army_id", &"")) and int(Dictionary(cold_restored.watchtowers_by_id[arrow_id]).level) == 2, "地雷消耗、真实堡垒驻军、设施等级与在场状态精确恢复")

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("FIELD_DEFENSE_EXPANSION_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_DEFENSE_EXPANSION_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _build_facility(city: Node, field: FieldTacticsState, engineer_id: StringName, kind: StringName, position: Vector2i) -> StringName:
	var issued: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.defense.expansion", position, kind)
	var project := Dictionary(issued.get("project", {}))
	if not bool(issued.get("success", false)):
		return &""
	city.advance_war_loop_time(int(project.get("travel_milliseconds", 0)) + int(project.get("required_milliseconds", 0)))
	return StringName(project.get("tower_id", &"")) if field.watchtowers_by_id.has(StringName(project.get("tower_id", &""))) else &""


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
