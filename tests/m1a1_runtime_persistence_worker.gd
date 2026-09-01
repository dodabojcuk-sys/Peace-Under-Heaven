extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const SAVE_STORE = preload("res://scripts/state/v5_campaign_save_store.gd")
const LOGGING_CAMP_ID := &"building.logging_camp.t1"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _arguments()
	var mode := str(arguments.get("mode", ""))
	var save_directory := str(arguments.get("save_dir", ""))
	_require(mode in ["A", "B", "C"], "mode must be A, B, or C")
	_require(not save_directory.is_empty(), "save directory is required")
	if not failures.is_empty():
		_finish(mode)
		return
	if mode == "C":
		_corrupt_latest_generation_before_normal_start(save_directory)
	var scene := CITY_SCENE.instantiate() as Node2D
	root.add_child(scene)
	await process_frame
	await process_frame
	var runtime: Node = scene
	var city: Node = scene.get_node("ConstructionController")
	_require(runtime.has_method("get_runtime_persistence_status"), "normal city root exposes runtime persistence status")
	if mode == "A":
		await _run_a(runtime, city)
	elif mode == "B":
		_run_b(runtime, city)
	else:
		_run_c(runtime, city, save_directory)
	scene.queue_free()
	await process_frame
	_finish(mode)


func _run_a(runtime: Node, city: Node) -> void:
	var initial: Dictionary = runtime.get_runtime_persistence_status()
	_require(str(initial.get("status", "")) == "created_initial_generation", "empty normal startup creates an initial V5 generation")
	city.set_city_time_paused(true)
	city.wood = 40
	_require(bool(city.start_build_project(LOGGING_CAMP_ID).success), "normal product path creates a build-slot state")
	_require(city.get_build_slot_state() == city.BUILD_SLOT_PRODUCING, "normal product path creates a persisted active build slot")
	_require(city.queue_training(), "normal product path creates a training order")
	_require(city.advance_one_day_for_test(), "normal product path commits a daily settlement")
	_require(city.enter_first_war_battle(), "normal product path enters the current mainline")
	await process_frame
	var battle: C0BattleGraybox = city.get_formal_battle_scene()
	_require(battle != null, "normal mainline entry creates the formal C0 battle scene")
	if battle != null:
		for squad in battle.request.committed_force.squads:
			battle.set_squad_route(
				int(squad.squad_id),
				CommittedForceSnapshot.FRONT_ROUTE
			)
		_require(battle.start_battle(true), "normal Start path activates the concentrated real force")
		var result := battle.step_battle_for_test(BattleSession.MAX_BATTLE_TICKS)
		_require(
			result != null and result.outcome == BattleOutcome.Value.VICTORY,
			"normal battle simulation reaches the existing victory condition"
		)
		if result != null:
			var summary: Dictionary = battle.confirm_pending_result()
			var contract := battle.coordinator.request_return_to_city()
			_require(
				not summary.is_empty()
					and contract != null
					and battle.complete_return_for_test(contract.city_input_restore_frame),
				"normal result confirmation commits once and returns to the city"
			)
			await process_frame
	_require(
		bool(city.get_mainline_pressure_state().cleared),
		"victory return clears the persisted mainline pressure state"
	)
	_require(runtime.flush_runtime_persistence(&"test_process_a"), "normal product flush publishes the canonical snapshot")
	var saved: Dictionary = runtime.get_runtime_persistence_status()
	_require(int(saved.get("save_sequence", 0)) >= 2, "process A advances the immutable generation")


func _run_b(runtime: Node, city: Node) -> void:
	var loaded: Dictionary = runtime.get_runtime_persistence_status()
	_require(bool(loaded.get("loaded", false)), "process B automatically loads through normal scene startup")
	_require(
		city.current_day >= 2
			and city.get_build_slot_state() == city.BUILD_SLOT_READY_TO_PLACE
			and int(city.get_build_slot_snapshot().paid_costs.wood) == 40
			and bool(city.get_mainline_pressure_state().cleared)
			and not Dictionary(city.export_v5_campaign_snapshot().settlement_ledger.committed_results_by_id).is_empty(),
		"process B restores day, build slot, mainline result, and settlement ledger without a test load call"
	)
	_require(runtime.flush_runtime_persistence(&"test_process_b"), "process B can publish a second stable runtime generation")


func _run_c(runtime: Node, city: Node, save_directory: String) -> void:
	var loaded: Dictionary = runtime.get_runtime_persistence_status()
	_require(
		bool(loaded.get("loaded", false))
			and bool(loaded.get("recovered", false))
			and str(loaded.get("status", "")) == "recovered_previous_generation",
		"process C normal startup falls back from the corrupt latest whole generation"
	)
	_require(
		city.current_day >= 2
			and city.get_build_slot_state() == city.BUILD_SLOT_READY_TO_PLACE,
		"fallback generation restores the complete prior canonical city, not mixed files"
	)


func _corrupt_latest_generation_before_normal_start(save_directory: String) -> void:
	var store := SAVE_STORE.new(save_directory)
	var latest_path := store.get_generation_path(3)
	_require(FileAccess.file_exists(latest_path), "process C receives process B latest generation")
	if not FileAccess.file_exists(latest_path):
		return
	var file := FileAccess.open(latest_path, FileAccess.WRITE)
	if file == null:
		_require(false, "process C can corrupt only the latest isolated test generation")
		return
	file.store_string("{\"corrupt\":")
	file.flush()
	file.close()


func _arguments() -> Dictionary:
	var result := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			result.mode = argument.trim_prefix("--mode=")
		elif argument.begins_with("--save-dir="):
			result.save_dir = argument.trim_prefix("--save-dir=")
	return result


func _require(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error("M1A1_RUNTIME_WORKER_FAIL: %s" % description)


func _finish(mode: String) -> void:
	print("M1A1_RUNTIME_PID=%d" % OS.get_process_id())
	if failures.is_empty():
		print("M1A1_RUNTIME_%s PASS" % mode)
		quit(0)
	else:
		print("M1A1_RUNTIME_%s FAIL: %s" % [mode, failures])
		quit(1)
