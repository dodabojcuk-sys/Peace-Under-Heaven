extends SceneTree
const CITY := preload("res://scenes/blank_map.tscn")
const THEATER := preload("res://scripts/macro_march/macro_march_theater.gd")
var failures: Array[String] = []

func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("run")

func run() -> void:
	var scene := CITY.instantiate()
	root.add_child(scene)
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var status: Dictionary = scene.get_runtime_persistence_status()
	check(status.get("loaded", false), "cold process loads isolated saved generation")
	var before: Dictionary = city.export_v5_campaign_snapshot()
	var population: Dictionary = city.get_population_recovery_read_model()
	var invasion_before: Dictionary = city._war_loop_state.field_tactics.get_blackstone_invasion()
	var first_clear_before: Dictionary = city._first_clear_keys.duplicate(true)
	check(population.accounted, "restored population is conserved")
	check(not city.can_start_noticeboard_mission(city.get_noticeboard_mission_ids()[0]), "formal campaign cannot start legacy noticeboard battle")
	if city.has_resumable_expedition() or city.get_formal_battle_scene() != null:
		if city.has_resumable_expedition(): check(city.resume_persisted_expedition(), "resume original defense identity")
		await process_frame
		var battle: C0BattleGraybox = city.get_formal_battle_scene()
		check(battle != null, "restored defense is actionable")
		if battle != null:
			battle.set_process(false)
			battle.tick_timer.stop()
			if battle.request.phase == BattleRequest.PHASE_RESULT_PENDING:
				var summary := battle.confirm_pending_result()
				check(not summary.is_empty() and battle.confirm_pending_result() == summary, "cold pending result settles once")
			else:
				check(battle.start_battle(false), "cold active defense continues")
				var tick := battle.coordinator.active_session.current_tick
				battle.advance_spatial_frame(0.25)
				check(battle.coordinator.active_session.current_tick == tick + 1, "cold active battle advances one tick")
	else:
		var day_ms: int = city.get_day_elapsed_milliseconds()
		city.set_city_time_paused(true)
		city._process(0.25)
		check(city.get_day_elapsed_milliseconds() == day_ms, "restored pause blocks clock")
		city.set_city_time_paused(false)
		city._process(0.25)
		check(city.get_day_elapsed_milliseconds() != day_ms, "restored city can continue")
		check(city.get_population_recovery_read_model().total_living == population.total_living, "clock resume does not duplicate casualties or population")
		check(city._war_loop_state.field_tactics.get_blackstone_invasion().get("patrol_id", &"") == invasion_before.get("patrol_id", &"") and city._first_clear_keys == first_clear_before, "cold resume preserves one invasion identity and reward receipts")

	if city._war_loop_state.is_level_cleared():
		check(city.is_campaign_pressure_cleared(), "cold occupied cities determine completion")
		check(scene.open_macro_march_r0(), "completed campaign still opens field")
		var armies_before: Array = city.get_macro_march_armies()
		var projects_before: Dictionary = city._war_loop_state.field_tactics.projects_by_id.duplicate(true)
		check(scene.return_from_macro_march_r0(), "completed campaign returns to city")
		check(city.get_macro_march_armies() == armies_before and city._war_loop_state.field_tactics.projects_by_id == projects_before, "city return preserves original armies and works")
		check(city.preview_field_supply_transport(&"silverford_city").get("valid", false), "occupied Silverford exposes finite supply")
		var route: Dictionary = THEATER.get_route(&"road.redcliff.silverford")
		var reverse_points: Array = Array(route.points).duplicate()
		reverse_points.reverse()
		for army in armies_before:
			if army.phase == ArmyRegistry.PHASE_STATIONED and army.target_node_id == &"silverford_city":
				var issued: Dictionary = city.commit_macro_march_from_station(army.army_id, &"redcliff_city", route.route_id, reverse_points)
				check(issued.get("success", false) and issued.get("army", {}).get("army_id", &"") == army.army_id, "post-victory order reuses exact stationed army")

		# Isolated late-date fixture, never part of normal journey evidence.
		city.current_day = 15
		var food_before: int = city.food
		city._apply_mainline_pressure_for_current_day()
		check(city.food == food_before and city.get_pressure_modifier_permille(&"production") == 1000, "no post-victory deadline losses")
		check(city.get_training_blocked_reason().error_id != &"TRAINING_DAY_LIMIT", "late campaign retains finite training")
		check(city.get_blackstone_campaign_status_text().contains("双城目标达成"), "completion UI reads restored controllers")
	print("COLD_RECOVERY ", JSON.stringify({"failures": failures, "source_sequence": status.save_sequence, "attempt": before.expedition_attempt.get("attempt_id", "")}))
	scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures.append(message)
