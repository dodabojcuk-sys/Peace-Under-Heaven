extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _run_main_road_route()
	await _run_engineering_route()
	_finish()


func _run_main_road_route() -> void:
	var context := await _new_city()
	var city: Node = context.city
	var route_start_world := int(city._war_loop_state.field_tactics.world_milliseconds)
	var initial_food: int = city.food
	var roster: Array[Dictionary] = city.get_formation_roster()
	var formation_ids: Array[StringName] = []
	for formation in roster:
		formation_ids.append(StringName(formation.formation_id))
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var north_plan: Dictionary = city.plan_field_path(&"blackstone_city", &"northwatch_garrison", Array(ridge.points))
	var issue: Dictionary = city.commit_macro_march_from_city(formation_ids, &"northwatch_garrison", StringName(north_plan.route_id), Array(north_plan.points))
	var army_id := StringName(Dictionary(issue.get("army", {})).get("army_id", &""))
	_advance_until_phase(city, army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	var patrol := Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
	var patrol_wait := 0
	while army_id not in Array(patrol.get("resolved_army_ids", [])) and patrol_wait < 30000:
		city._process(0.1)
		patrol_wait += 100
		patrol = Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
	var after_patrol: Dictionary = city._army_registry.get_army(army_id)
	var count_after_patrol: int = city._macro_army_member_count(after_patrol)
	var red_route: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	var red_issue: Dictionary = city.commit_macro_march_from_station(army_id, &"redcliff_city", StringName(red_route.route_id), Array(red_route.points))
	_advance_until_city_owned(city, &"redcliff_city", 30000)
	var silver_route: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
	var silver_issue: Dictionary = city.commit_macro_march_from_station(army_id, &"silverford_city", StringName(silver_route.route_id), Array(silver_route.points))
	_advance_until_city_owned(city, &"silverford_city", 30000)
	var final_army: Dictionary = city._army_registry.get_army(army_id)
	var elapsed := int(city._war_loop_state.field_tactics.world_milliseconds) - route_start_world
	var food_spent: int = initial_food - int(city.food)
	var casualties: int = 20 - city._macro_army_member_count(final_army)
	_check(
		initial_food == 80 and bool(issue.get("success", false))
			and army_id in Array(patrol.get("resolved_army_ids", []))
			and count_after_patrol < 20 and count_after_patrol > 0
			and bool(red_issue.get("success", false)) and bool(silver_issue.get("success", false))
			and bool(city.get_macro_march_read_model().get("level_cleared", false))
			and food_spent > 0 and city.food >= 0 and casualties > 0
			and StringName(final_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"主路正式路线从默认资源出征，经历有限巡逻伤亡后连续占领两座必占城"
	)
	print("R2_PLAYTHROUGH_ROUTE_A elapsed_ms=%d food_remaining=%d food_spent=%d army_casualties=%d specialist_losses=0" % [elapsed, city.food, food_spent, casualties])
	await _drop(context.scene)


func _run_engineering_route() -> void:
	var context := await _new_city()
	var city: Node = context.city
	var route_start_world := int(city._war_loop_state.field_tactics.world_milliseconds)
	var scene: Node = context.scene
	var macro_screen: MacroMarchR0 = scene.get_node("UI/MacroMarchR0")
	scene.open_macro_march_r0()
	var initial_food: int = city.food
	var roster: Array[Dictionary] = city.get_formation_roster()
	var ridge: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var engineer_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var engineer_id := StringName(Dictionary(engineer_dispatch.get("specialist", {})).get("specialist_id", &""))
	var camp_site := &"camp.site.route_b_forest"
	var feeder_points: Array = [
		Vector2i(790, 170), Vector2i(770, 250), Vector2i(735, 330), Vector2i(710, 400),
	]
	var feeder_project: Dictionary = city.begin_field_road_project(
		engineer_id, &"northwatch_garrison", camp_site, feeder_points,
		FieldTacticsState.ROAD_NORMAL, true
	)
	var feeder_project_id := StringName(Dictionary(feeder_project.get("project", {})).get("project_id", &""))
	var interrupted := false
	for _step in range(50):
		city._process(0.1)
		var project := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(feeder_project_id, {}))
		if StringName(project.get("phase", &"")) == &"INTERRUPTED":
			interrupted = true
			break
	var first_guard_issue: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[0].formation_id)], &"northwatch_garrison", StringName(ridge.route_id), Array(ridge.points)
	)
	var guard_army_id := StringName(Dictionary(first_guard_issue.get("army", {})).get("army_id", &""))
	var guard_initial_count: int = city._macro_army_member_count(Dictionary(first_guard_issue.get("army", {})))
	_advance_until_phase(city, guard_army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	var replacement_dispatch: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	var replacement_id := StringName(Dictionary(replacement_dispatch.get("specialist", {})).get("specialist_id", &""))
	var resume: Dictionary = city.resume_interrupted_field_project(replacement_id, feeder_project_id)
	_advance_until_project_phase(city, feeder_project_id, &"COMPLETE", 30000)
	var completed_feeder := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(feeder_project_id, {}))
	var guard_plan: Dictionary = city.plan_field_path(&"northwatch_garrison", camp_site, feeder_points)
	var guard_escort: Dictionary = city.commit_macro_march_from_station(
		guard_army_id, camp_site, StringName(guard_plan.get("route_id", &"")), Array(guard_plan.get("points", []))
	)
	_advance_until_phase(city, guard_army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	_repair_damaged_engineered_roads(city)
	_advance_until_phase(city, guard_army_id, ArmyRegistry.PHASE_STATIONED, 30000)

	macro_screen._scout_button.emit_signal("pressed")
	var scout_id := macro_screen._selected_scout_id
	var scout_dispatch := {"success": scout_id != &""}
	var scout_target_click := InputEventMouseButton.new()
	scout_target_click.button_index = MOUSE_BUTTON_LEFT
	scout_target_click.pressed = true
	scout_target_click.position = macro_screen._world_to_screen(Vector2(THEATER.get_point(&"northwatch_garrison").world_position))
	macro_screen._on_gui_input(scout_target_click)
	var scout_order := {
		"success": StringName(Dictionary(city._war_loop_state.field_tactics.specialists_by_id.get(scout_id, {})).get("phase", &"")) == FieldTacticsState.SPECIALIST_MOVING,
	}
	var scouting_elapsed := 0
	while scouting_elapsed < 30000:
		city._process(0.1)
		scouting_elapsed += 100
		var intel: Dictionary = city._war_loop_state.field_tactics.observe_subject(&"patrol.ridge.001")
		if StringName(intel.get("fog_state", &"")) != FieldTacticsState.FOG_UNOBSERVED:
			break

	var ridge_to_camp := Array(ridge.points).duplicate(true)
	ridge_to_camp.pop_back()
	ridge_to_camp.append_array(feeder_points)
	var forest_plan: Dictionary = city.plan_field_path(&"blackstone_city", camp_site, ridge_to_camp)
	var field_issue: Dictionary = city.commit_macro_march_from_city(
		[StringName(roster[1].formation_id), StringName(roster[2].formation_id)], camp_site,
		StringName(forest_plan.get("route_id", &"")), Array(forest_plan.get("points", []))
	)
	var field_army_id := StringName(Dictionary(field_issue.get("army", {})).get("army_id", &""))
	var field_initial_count: int = city._macro_army_member_count(Dictionary(field_issue.get("army", {})))
	_advance_until_phase(city, field_army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	_repair_damaged_engineered_roads(city)
	_advance_until_phase(city, field_army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	var ambush_wait := 0
	while ambush_wait < 30000:
		var patrol := Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])
		if field_army_id in Array(patrol.get("ambush_consumed_army_ids", [])):
			break
		city._process(0.1)
		ambush_wait += 100
	var patrol_after_ambush := Dictionary(city._war_loop_state.field_tactics.patrols_by_id[&"patrol.ridge.001"])

	var bridge_points: Array = [
		Vector2i(150, 430), Vector2i(360, 430), Vector2i(500, 430),
		Vector2i(650, 430), Vector2i(710, 400),
	]
	var bridge_project: Dictionary = city.begin_field_road_project(
		_active_engineer_id(city), &"blackstone_city", camp_site, bridge_points,
		FieldTacticsState.ROAD_NORMAL, false
	)
	var bridge_project_id := StringName(Dictionary(bridge_project.get("project", {})).get("project_id", &""))
	_advance_until_project_phase(city, bridge_project_id, &"COMPLETE", 40000)
	var completed_project := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(bridge_project_id, {}))
	var bridge_segment_ids: Array[StringName] = []
	for segment_value in Array(completed_project.get("segment_plans", [])):
		var segment: Dictionary = Dictionary(segment_value)
		if StringName(segment.get("road_kind", &"")) == FieldTacticsState.ROAD_BRIDGE:
			bridge_segment_ids.append(StringName(segment.get("road_id", &"")))
	var bridge_return_points := bridge_points.duplicate(true)
	bridge_return_points.reverse()
	var bridge_return_plan: Dictionary = city.plan_field_path(camp_site, &"blackstone_city", bridge_return_points)
	var bridge_return: Dictionary = city.commit_macro_march_from_station(
		field_army_id, &"blackstone_city", StringName(bridge_return_plan.get("route_id", &"")), Array(bridge_return_plan.get("points", []))
	)
	_advance_until_phase(city, field_army_id, ArmyRegistry.PHASE_STATIONED, 30000)
	var bridge_forward_plan: Dictionary = city.plan_field_path(&"blackstone_city", camp_site, bridge_points)
	var bridge_forward: Dictionary = city.commit_macro_march_from_station(
		field_army_id, camp_site, StringName(bridge_forward_plan.get("route_id", &"")), Array(bridge_forward_plan.get("points", []))
	)
	_advance_until_phase(city, field_army_id, ArmyRegistry.PHASE_STATIONED, 30000)

	var mid_one := &"camp.site.route_b_mid_one"
	var mid_two := &"camp.site.route_b_mid_two"
	var connector_one: Dictionary = city.begin_field_road_project(_active_engineer_id(city), camp_site, mid_one, [Vector2i(710, 400), Vector2i(730, 410)], FieldTacticsState.ROAD_NORMAL, true)
	var connector_one_id := StringName(Dictionary(connector_one.get("project", {})).get("project_id", &""))
	_advance_until_project_phase(city, connector_one_id, &"COMPLETE", 20000)
	var connector_two: Dictionary = city.begin_field_road_project(_active_engineer_id(city), mid_one, mid_two, [Vector2i(730, 410), Vector2i(755, 430)], FieldTacticsState.ROAD_NORMAL, true)
	var connector_two_record := Dictionary(connector_two.get("project", {}))
	var connector_two_id := StringName(connector_two_record.get("project_id", &""))
	_advance_until_project_phase(city, connector_two_id, &"COMPLETE", 20000)
	connector_two_record = Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(connector_two_id, {}))
	var connector_two_road_id := StringName(connector_two_record.get("road_id", &""))
	var connector_three: Dictionary = city.begin_field_road_project(_active_engineer_id(city), mid_two, &"reedbank_garrison", [Vector2i(755, 430), Vector2i(850, 505)], FieldTacticsState.ROAD_NORMAL, false)
	var connector_three_id := StringName(Dictionary(connector_three.get("project", {})).get("project_id", &""))
	_advance_until_project_phase(city, connector_three_id, &"COMPLETE", 20000)
	# Enemy road damage is not yet a player-authored command. This explicit test
	# event drives the formal blocked-transfer and repair flow without bypassing
	# its movement, resource, or persistence owners.
	var connector_points: Array = [Vector2i(710, 400), Vector2i(730, 410), Vector2i(755, 430), Vector2i(850, 505)]
	var connector_plan: Dictionary = city.plan_field_path(camp_site, &"reedbank_garrison", connector_points)
	var reedbank_issue: Dictionary = city.commit_macro_march_from_station(
		field_army_id, &"reedbank_garrison", StringName(connector_plan.get("route_id", &"")), Array(connector_plan.get("points", []))
	)
	_advance_world_milliseconds(city, maxi(int(connector_plan.get("duration_milliseconds", 0)) / 10, 1))
	var before_damage: Dictionary = city._army_registry.get_army(field_army_id)
	city._war_loop_state.field_tactics.damage_road(connector_two_road_id, 999999)
	city._process(0.1)
	var blocked: Dictionary = city._army_registry.get_army(field_army_id)
	var blocked_transfer := Dictionary(Dictionary(blocked.get("macro_march", {})).get("blocked_transfer", {}))
	_advance_until_blocked_waiting(city, field_army_id, 30000)
	var waiting_army: Dictionary = city._army_registry.get_army(field_army_id)
	var waiting_transfer := Dictionary(Dictionary(waiting_army.get("macro_march", {})).get("blocked_transfer", {}))
	var combined_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored_city: Node = restored_scene.get_node("ConstructionController")
	restored_city.set_process(false)
	var combined_restore: Dictionary = restored_city.restore_v5_campaign_snapshot(combined_snapshot)
	var restored_waiting_army: Dictionary = restored_city._army_registry.get_army(field_army_id)
	var restored_waiting_transfer := Dictionary(Dictionary(restored_waiting_army.get("macro_march", {})).get("blocked_transfer", {}))
	var combined_restored: bool = (
		bool(combined_restore.get("success", false))
		and StringName(restored_waiting_transfer.get("phase", &"")) == &"WAITING"
		and restored_waiting_army == waiting_army
		and restored_city._war_loop_state.field_tactics.get_snapshot()
			== Dictionary(combined_snapshot.get("war_loop", {})).get("field_tactics", {})
	)
	context.scene.queue_free()
	await process_frame
	context = {"scene": restored_scene, "city": restored_city}
	city = restored_city
	var repair: Dictionary = city.begin_field_road_repair(_active_engineer_id(city), connector_two_road_id)
	var repair_project_id := StringName(Dictionary(repair.get("project", {})).get("project_id", &""))
	_advance_until_project_phase(city, repair_project_id, &"COMPLETE", 30000)
	_advance_until_phase(city, field_army_id, ArmyRegistry.PHASE_STATIONED, 40000)
	var silver_route: Dictionary = THEATER.get_route(&"road.reedbank.silverford")
	var silver_issue: Dictionary = city.commit_macro_march_from_station(field_army_id, &"silverford_city", StringName(silver_route.route_id), Array(silver_route.points))
	_advance_until_city_owned(city, &"silverford_city", 30000)
	var red_reverse_points := Array(THEATER.get_route(&"road.redcliff.silverford").points).duplicate(true)
	red_reverse_points.reverse()
	var red_plan: Dictionary = city.plan_field_path(&"silverford_city", &"redcliff_city", red_reverse_points)
	var red_issue: Dictionary = city.commit_macro_march_from_station(field_army_id, &"redcliff_city", StringName(red_plan.get("route_id", &"")), Array(red_plan.get("points", [])))
	_advance_until_city_owned(city, &"redcliff_city", 40000)
	var final_army: Dictionary = city._army_registry.get_army(field_army_id)
	var final_guard: Dictionary = city._army_registry.get_army(guard_army_id)
	var army_casualties: int = guard_initial_count + field_initial_count - city._macro_army_member_count(final_guard) - city._macro_army_member_count(final_army)
	var specialist_losses := 0
	for specialist_value in city._war_loop_state.field_tactics.specialists_by_id.values():
		if not bool(Dictionary(specialist_value).get("alive", false)):
			specialist_losses += 1
	var elapsed := int(city._war_loop_state.field_tactics.world_milliseconds) - route_start_world
	var food_spent: int = initial_food - int(city.food)
	var patrol_resolved := int(patrol_after_ambush.get("strength", -1)) == 0
	var ambush_count := Array(patrol_after_ambush.get("ambush_consumed_army_ids", [])).size()
	_check(
		initial_food == 80 and bool(first_guard_issue.get("success", false))
			and bool(scout_dispatch.get("success", false)) and bool(scout_order.get("success", false))
			and bool(feeder_project.get("success", false)) and interrupted
			and bool(replacement_dispatch.get("success", false)) and bool(resume.get("success", false)) and bool(guard_escort.get("success", false))
			and StringName(completed_feeder.get("phase", &"")) == &"COMPLETE"
			and bool(bridge_project.get("success", false)) and StringName(completed_project.get("phase", &"")) == &"COMPLETE" and not bridge_segment_ids.is_empty()
			and bool(bridge_return.get("success", false)) and bool(bridge_forward.get("success", false))
			and bool(connector_one.get("success", false)) and bool(connector_two.get("success", false)) and bool(connector_three.get("success", false))
			and bool(field_issue.get("success", false))
			and patrol_resolved
			and bool(reedbank_issue.get("success", false))
			and not before_damage.is_empty()
			and StringName(blocked_transfer.get("phase", &"")) == &"TO_CAMP"
			and StringName(waiting_transfer.get("phase", &"")) == &"WAITING"
			and combined_restored
			and bool(repair.get("success", false))
			and bool(silver_issue.get("success", false)) and bool(red_issue.get("success", false))
			and bool(city.get_macro_march_read_model().get("level_cleared", false))
			and elapsed > 0 and food_spent > 0 and city.food >= 0
			and army_casualties >= 0 and specialist_losses >= 1
			and StringName(final_army.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED,
		"工程正式路线从默认资源完成侦察、桥路施工、损失补派、林地部署与巡逻结算、断路驻扎维修续行及双城结算"
	)
	print("R2_PLAYTHROUGH_ROUTE_B elapsed_ms=%d food_remaining=%d food_spent=%d army_casualties=%d specialist_losses=%d ambushes=%d interrupted=%s" % [
		elapsed, city.food, food_spent, army_casualties, specialist_losses, ambush_count, interrupted,
	])
	await _drop(context.scene)


func _advance_until_phase(city: Node, army_id: StringName, phase: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		if StringName(city._army_registry.get_army(army_id).get("phase", &"")) == phase:
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_city_owned(city: Node, city_id: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var cities: Dictionary = Dictionary(city.get_macro_march_read_model().war_loop).get("cities_by_id", {})
		if StringName(Dictionary(cities.get(city_id, {})).get("military_controller_faction_id", &"")) == &"player":
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_project_phase(city: Node, project_id: StringName, phase: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var project := Dictionary(city._war_loop_state.field_tactics.projects_by_id.get(project_id, {}))
		if StringName(project.get("phase", &"")) == phase:
			return
		city._process(0.1)
		elapsed += 100


func _advance_until_blocked_waiting(city: Node, army_id: StringName, budget_milliseconds: int) -> void:
	var elapsed := 0
	while elapsed < budget_milliseconds:
		var army: Dictionary = city._army_registry.get_army(army_id)
		var transfer := Dictionary(Dictionary(army.get("macro_march", {})).get("blocked_transfer", {}))
		if StringName(transfer.get("phase", &"")) == &"WAITING":
			return
		city._process(0.1)
		elapsed += 100


func _advance_world_milliseconds(city: Node, requested_milliseconds: int) -> void:
	var remaining := requested_milliseconds
	while remaining > 0:
		var step := mini(remaining, 100)
		city._process(float(step) / 1000.0)
		remaining -= step


func _repair_damaged_engineered_roads(city: Node) -> void:
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	var road_ids: Array = field.roads_by_id.keys()
	road_ids.sort()
	for road_id_value in road_ids:
		var road_id := StringName(road_id_value)
		var road: Dictionary = Dictionary(field.roads_by_id[road_id])
		if StringName(road.get("state", &"")) != FieldTacticsState.ROAD_DAMAGED or StringName(road.get("road_kind", &"")) == FieldTacticsState.ROAD_MAIN:
			continue
		var engineer_id := _active_engineer_id(city)
		if engineer_id == &"":
			return
		var repair: Dictionary = city.begin_field_road_repair(engineer_id, road_id)
		var project_id := StringName(Dictionary(repair.get("project", {})).get("project_id", &""))
		if bool(repair.get("success", false)) and project_id != &"":
			_advance_until_project_phase(city, project_id, &"COMPLETE", 30000)


func _active_engineer_id(city: Node) -> StringName:
	var ids: Array = city._war_loop_state.field_tactics.specialists_by_id.keys()
	ids.sort()
	for specialist_id_value in ids:
		var specialist: Dictionary = Dictionary(city._war_loop_state.field_tactics.specialists_by_id[specialist_id_value])
		if bool(specialist.get("alive", false)) and StringName(specialist.get("role", &"")) == FieldTacticsState.SPECIALIST_ENGINEER and StringName(specialist.get("project_id", &"")) == &"":
			return StringName(specialist_id_value)
	return &""


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	return {"scene": scene, "city": city}


func _drop(scene: Node) -> void:
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
		print("FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_TACTICS_R2_PLAYTHROUGH_SMOKE FAIL: %s" % failure)
	quit(1)
