extends SceneTree

const CITY := preload("res://scenes/blank_map.tscn")
const THEATER := preload("res://scripts/macro_march/macro_march_theater.gd")
var city: Node
var scene: Node
var fast := false
var route := "A"
var world_speed := 1.0
var evidence := "/tmp/blackstone-r1-journey"
var started := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []

func _initialize() -> void:
	THEATER.use_playable_definition()
	for arg in OS.get_cmdline_user_args():
		if arg == "--fast": fast = true
		if arg.begins_with("--route="): route = arg.trim_prefix("--route=")
		if arg.begins_with("--speed="): world_speed = float(arg.trim_prefix("--speed="))
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
	call_deferred("run")

func run() -> void:
	started = Time.get_ticks_msec()
	root.size = Vector2i(1280, 800)
	DirAccess.make_dir_recursive_absolute(evidence)
	scene = CITY.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	city = scene.get_node("ConstructionController")
	if fast: city.set_process(false)
	check(city.set_city_time_speed(world_speed), "selected formal world speed")
	check(city.current_day == 1 and city.food == 80 and city.infantry_count == 20, "normal initial day, food and army")
	check(city.get_population_recovery_read_model().total_living == 72, "normal population")
	if not failures.is_empty(): finish(); return
	check(city.start_build_project(&"building.farm.t1").success, "start paid farm construction")
	await checkpoint("preparation")
	await wait_until(func(): return city.get_build_slot_state() == city.BUILD_SLOT_READY_TO_PLACE, 230, "farm construction")
	if not place_ready(&"building.farm.t1"): finish(); return
	check(city.start_build_project(&"building.housing.t1").success, "start paid housing construction")
	await wait_until(func(): return city.get_build_slot_state() == city.BUILD_SLOT_READY_TO_PLACE, 230, "housing construction")
	if not place_ready(&"building.housing.t1"): finish(); return
	check(city.adjust_city_workforce(&"production", -1).success, "release one real production worker")
	check(city.adjust_city_workforce(&"production", 1).success, "restore production allocation")
	if city.can_queue_training():
		city.recruit_button.pressed.emit()
		check(city.get_training_queue_snapshot().active_order_id != &"", "formal training spends food and reserves people")
	if route == "A": await external_line()
	await wait_until(func(): return city.current_day >= 4, 200, "warning preparation")
	await checkpoint("warning")
	check(city.get_blackstone_invasion_read_model().known, "day four known warning")
	city.current_mainline_entry_button.pressed.emit()
	check(scene.get_node("UI/MacroMarchR0").visible, "header enters known source in field")
	await wait_until(func(): return city.current_day >= 5, 200, "departure preparation")
	await checkpoint("invasion-marching")
	await wait_until(func(): return city.get_blackstone_invasion_read_model().phase == FieldTacticsState.INVASION_ARRIVED, 130, "invader road travel")
	check(city.enter_wartime_defense_battle(formation_ids()), "formal sourced defense")
	await process_frame
	await process_frame
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null: finish(); return
	check(battle.start_battle(false), "start spatial defense")
	if fast: battle.set_process(false); battle.tick_timer.stop()
	await checkpoint("defense-active")
	await fight(battle, false)
	await checkpoint("defense-result-pending")
	if not battle.coordinator.active_session.completed: finish(); return
	print("DEFENSE_OUTCOME ", battle.coordinator.active_session.result.outcome)
	var summary := battle.confirm_pending_result()
	check(not summary.is_empty(), "confirm real defense casualties")
	check(battle.confirm_pending_result() == summary, "defense confirmation idempotent")
	check(battle.request_return_to_city() != null, "return after defense")
	await wait_until(func(): return city.get_formal_battle_scene() == null, 5, "battle return guard")
	await recover()
	await checkpoint("recovery")
	var army_id := await march_from_city()
	if army_id == &"": finish(); return
	await attack_redcliff(army_id, route == "B")
	if route == "B":
		await wait_until(func(): return StringName(city.get_army_state(army_id).get("phase", &"")) != ArmyRegistry.PHASE_RETREATING, 150, "retreat road return")
		await checkpoint("retreat-returned")
		print("RETURN_ARMY ", city.get_army_state(army_id))
		await recover()
		if city.get_army_state(army_id).get("phase", &"") == ArmyRegistry.PHASE_STATIONED:
			await attack_redcliff(army_id, false)
		else:
			army_id = await march_from_city()
			await attack_redcliff(army_id, false)
	if not city._war_loop_state.get_city(&"redcliff_city").get("military_controller_faction_id", &"") == &"player":
		check(false, "Redcliff occupied"); finish(); return
	await checkpoint("occupation")
	var road: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
	check(city.commit_macro_march_from_station(army_id, &"silverford_city", road.route_id, Array(road.points)).get("success", false), "same army continues to Silverford")
	await wait_until(func(): return city._war_loop_state.is_level_cleared(), 150, "second required city")
	check(city.is_campaign_pressure_cleared(), "live two-city objective removes deadline pressure")
	check(city.get_pressure_modifier_permille(&"production") == 1000, "post-victory production without deadline penalty")
	await checkpoint("victory")
	await wait_seconds(3)
	check(city.get_population_recovery_read_model().accounted, "population conserved through whole journey")
	finish()

func external_line() -> void:
	check(scene.open_macro_march_r0(), "open field for optional defense engineering")
	var dispatched: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	check(dispatched.get("success", false), "engineer uses real available population")
	var engineer_id := StringName(dispatched.get("specialist", {}).get("specialist_id", &""))
	var built: Dictionary = city.begin_field_road_project(engineer_id, &"blackstone_city", &"", [Vector2i(135, 650), Vector2i(310, 640), Vector2i(500, 620)], FieldTacticsState.ROAD_NORMAL, true)
	print("EXTERNAL_LINE ", built)
	check(built.get("success", false), "paid field road and camp plan")
	if not built.get("success", false): return
	var project_id := StringName(built.project.project_id)
	await wait_until(func(): return city._war_loop_state.field_tactics.projects_by_id[project_id].phase == &"COMPLETE", 130, "field road camp construction")
	var camp_id := StringName(city._war_loop_state.field_tactics.projects_by_id[project_id].camp_id)
	var tower: Dictionary = city.begin_field_watchtower_project(engineer_id, camp_id, Vector2i(440, 600), FieldTacticsState.FACILITY_ARROW_TOWER)
	check(tower.get("success", false), "paid external arrow tower plan")
	print("ARROW_PLAN ", tower)
	if not tower.get("success", false): return
	var tower_id := StringName(tower.project.project_id)
	await wait_until(func(): return city._war_loop_state.field_tactics.projects_by_id[tower_id].phase == &"COMPLETE", 130, "external arrow tower construction")
	await checkpoint("external-defense-line")

func formation_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for r in city.get_formation_roster():
		if r.get("current_count", r.get("count", 0)) > 0: ids.append(StringName(r.formation_id))
	if ids.is_empty():
		for r in city.get_formation_roster(): ids.append(StringName(r.formation_id))
	return ids

func place_ready(id: StringName) -> bool:
	var definition: Resource = city.get_definition(id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var valid: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if not valid.get("valid", false) or valid.get("connection_state", &"") != &"connected": continue
			var screen: Vector2 = city.map_local_to_screen(city.cell_to_map_local(cell) + Vector2(40, 40))
			if not Rect2(Vector2(260, 120), Vector2(root.size.x - 620, root.size.y - 160)).has_point(screen) or city.is_construction_ui_point(screen): continue
			city.activate_ready_placement(screen)
			for attempt in 6:
				city.update_preview(screen)
				if city.preview_origin_cell == cell: break
				screen += city.map_local_to_screen(city.cell_to_map_local(cell)) - city.map_local_to_screen(city.cell_to_map_local(city.preview_origin_cell))
			var result: Dictionary = city.commit_building_from_map_click(screen)
			check(result.get("success", false), "place completed connected " + String(id))
			return result.get("success", false)
	check(false, "connected placement available for " + String(id))
	return false

func recover() -> void:
	while city.get_population_recovery_read_model().wounded > 0:
		var result: Dictionary = city.begin_wounded_treatment()
		check(result.get("success", false), "paid treatment of real casualties")
		if not result.get("success", false): return
		await wait_until(func(): return city._population_recovery.treatment.phase == PopulationRecoveryState.TREATMENT_IDLE, 20, "treatment")

func march_from_city() -> StringName:
	var road: Dictionary = THEATER.get_route(&"road.blackstone.northwatch.ridge")
	var result: Dictionary = city.commit_macro_march_from_city(formation_ids(), &"northwatch_garrison", road.route_id, Array(road.points))
	check(result.get("success", false), "original garrison issues paid counterattack")
	print("MARCH_ISSUE ", result)
	var id := StringName(result.get("army", {}).get("army_id", &""))
	if id != &"": await wait_until(func(): return city.get_army_state(id).get("phase", &"") == ArmyRegistry.PHASE_STATIONED, 150, "northwatch march")
	return id

func attack_redcliff(id: StringName, retreat: bool) -> void:
	var road: Dictionary = THEATER.get_route(&"road.northwatch.redcliff")
	check(city.commit_macro_march_from_station(id, &"redcliff_city", road.route_id, Array(road.points)).get("success", false), "stationed original army attacks Redcliff")
	await wait_until(func(): return city.get_army_state(id).get("phase", &"") == ArmyRegistry.PHASE_SIEGING, 100, "siege arrival")
	check(city.enter_macro_siege_wartime(id, &"redcliff_city"), "existing siege transfers to formal spatial battle")
	await process_frame
	await process_frame
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	if battle == null: return
	check(battle.start_battle(false), "activate original attacking army")
	if fast: battle.set_process(false); battle.tick_timer.stop()
	if retreat:
		await wait_seconds(2)
		check(battle.open_exit_confirmation(), "request retreat")
		check(battle.confirm_exit_as_retreat(), "confirm legal retreat")
		await wait_until(func(): return city.get_formal_battle_scene() == null, 8, "retreat settlement return")
		return
	await fight(battle, true)
	if not battle.coordinator.active_session.completed: return
	print("ASSAULT_OUTCOME ", battle.coordinator.active_session.result.outcome)
	var result := battle.confirm_pending_result()
	check(not result.is_empty(), "assault result confirmed")
	check(battle.request_return_to_city() != null, "assault returns to field")
	await wait_until(func(): return city.get_formal_battle_scene() == null, 5, "assault return guard")

func fight(battle: C0BattleGraybox, assault: bool) -> void:
	if assault:
		for squad in battle.coordinator.active_session.squads:
			battle.select_squad(int(squad.squad_id))
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = battle.spatial_view.screen(BattlefieldSpace.point(80, 24))
			battle.spatial_view._gui_input(click)
	for second in 240:
		if battle.coordinator.active_session.completed: return
		if fast: battle.advance_spatial_frame(1.0)
		await wait_seconds(1)
	check(false, "battle terminates within 240 seconds")

func wait_until(predicate: Callable, limit: int, label: String) -> void:
	var before := Time.get_ticks_msec()
	for i in limit * 10:
		if predicate.call():
			print("WAIT ", label, " real_ms=", Time.get_ticks_msec() - before)
			return
		await wait_seconds(0.1)
	check(false, "timeout: " + label)
	print("DIAGNOSTICS ", city.get_campaign_progress_diagnostics())

func wait_seconds(seconds: float) -> void:
	if fast:
		# A formal C0 disables the city root in production. Calling `_process`
		# directly here used to bypass that scene contract and advanced field work
		# during an accelerated macro battle. The battle driver above owns C0 time;
		# only an enabled world may consume accelerated real delta.
		if city.get_formal_battle_scene() == null:
			city._process(seconds)
		await process_frame
	else:
		await create_timer(seconds).timeout

func checkpoint(label: String) -> void:
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var store := V5CampaignSaveStore.new(evidence.path_join(label))
	var saved := store.save_snapshot(snapshot, city.validate_v5_campaign_snapshot)
	check(saved.get("success", false), "independent checkpoint " + label)
	var record := {"node": label, "real_ms": Time.get_ticks_msec() - started, "day": city.current_day, "day_elapsed_milliseconds": city.get_day_elapsed_milliseconds(), "food": city.food, "wood": city.wood, "city_defense": city.get_city_defense(), "population": city.get_population_recovery_read_model(), "invasion": city.get_blackstone_invasion_read_model(), "last_battle_result": city.get_city_state().last_battle_result_summary, "diagnostics": city.get_campaign_progress_diagnostics()}
	records.append(record)
	print("NODE ", JSON.stringify(record))
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(evidence.path_join(label + ".png"))

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures.append(label)

func finish() -> void:
	var report := {"route": route, "world_speed": world_speed, "accelerated_driver": fast, "real_ms": Time.get_ticks_msec() - started, "failures": failures, "nodes": records, "input": "formal Controller commands, connected GUI signals and spatial map events"}
	var file := FileAccess.open(evidence.path_join("journey.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("BLACKSTONE_CLOSEOUT_JOURNEY ", JSON.stringify({"route": route, "failures": failures, "real_ms": report.real_ms}))
	quit(0 if failures.is_empty() else 1)
