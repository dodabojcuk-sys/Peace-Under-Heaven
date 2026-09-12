extends SceneTree

const CITY := preload("res://scenes/blank_map.tscn")
const THEATER := preload("res://scripts/macro_march/macro_march_theater.gd")
var failures: Array[String] = []
var mode := ""
var save_dir := ""

func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("run")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--txwzs-v5-save-dir="): save_dir = argument.trim_prefix("--txwzs-v5-save-dir=")
	var scene := CITY.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	if mode == "A":
		city.current_day = 5
		field.activate_configured_invasions(5)
		for i in 120:
			if field.get_blackstone_invasion().phase == FieldTacticsState.INVASION_ARRIVED: break
			city.advance_war_loop_time(1000)
		var ids: Array[StringName] = []
		for row in city.get_formation_roster(): ids.append(StringName(row.formation_id))
		check(city.enter_wartime_defense_battle(ids), "A sourced arrival enters defense")
		await process_frame
		await process_frame
		var battle := city.get_formal_battle_scene() as C0BattleGraybox
		if battle != null:
			battle.select_squad(1)
			battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_ARROW_TOWER)
			battle.select_squad(2)
			battle._toggle_wartime_facility(WartimeFacilityPlan.KIND_BARRICADE)
			battle._confirm_wartime_facility_plan()
			check(battle.start_battle(false), "A activate defense")
			battle.tick_timer.stop()
			battle.step_battle_for_test(1)
			save_expected(scene, city, battle)
	elif mode == "D":
		check(field.get_blackstone_invasion().phase == FieldTacticsState.INVASION_RESOLVED, "D same invasion remains resolved")
		check(city.get_formal_battle_scene() == null, "D regular city restored without temporary works")
	else:
		var battle := city.get_formal_battle_scene() as C0BattleGraybox
		if battle == null:
			city.resume_persisted_expedition()
			await process_frame
			await process_frame
			battle = city.get_formal_battle_scene()
		check(battle != null, mode + " restore formal defense")
		if battle != null:
			battle.tick_timer.stop()
			var s := battle.coordinator.active_session
			var expected: Dictionary = FileAccess.open(save_dir.path_join("defense-expectation.bin"), FileAccess.READ).get_var()
			var actual := s.get_terminal_result_snapshot() if s.completed else s.get_snapshot()
			check(actual == expected.session and int(city.wood) == int(expected.wood) and int(city.food) == int(expected.food), mode + " exact position HP target work ticks and resources")
			if mode == "B":
				var source_before := field.get_blackstone_invasion().duplicate(true)
				city.advance_war_loop_time(1000)
				check(field.get_blackstone_invasion() == source_before, "B field does not advance handed-off enemy")
				var result := battle.step_battle_for_test(600)
				check(result != null and result.outcome == BattleOutcome.Value.VICTORY, "B actual defense victory")
				save_expected(scene, city, battle)
			else:
				check(s.completed and battle.result_panel.visible, "C terminal restored without extra tick")
				var summary := battle.confirm_pending_result()
				check(not summary.is_empty() and battle.confirm_pending_result() == summary, "C settlement applied once")
				check(battle.request_return_to_city() != null, "C return to normal city")
				await process_frame
				await process_frame
				check(scene.flush_runtime_persistence(&"spatial_defense_settled"), "C persist settled V5 generation")
	scene.queue_free()
	await process_frame
	print("WARTIME_DEFENSE_DISK_WORKER_%s %s" % [mode, "PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)

func save_expected(scene: Node, city: Node, battle: C0BattleGraybox) -> void:
	check(scene.flush_runtime_persistence(&"spatial_defense_checkpoint"), mode + " publish V5 checkpoint")
	var s := battle.coordinator.active_session
	FileAccess.open(save_dir.path_join("defense-expectation.bin"), FileAccess.WRITE).store_var({"session": s.get_terminal_result_snapshot() if s.completed else s.get_snapshot(), "wood": int(city.wood), "food": int(city.food)})

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: " + message)
	else:
		failures.append(message)
		push_error("WARTIME_DEFENSE_DISK_FAIL: " + message)
