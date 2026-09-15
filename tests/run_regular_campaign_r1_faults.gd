extends SceneTree


## Fault-boundary coverage for the regular campaign's 15-second checkpoint.
## Invoke with an isolated --txwzs-v5-save-dir; this runner never uses a
## player save directory and only sets the runtime's test-only failure hook.

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const REGULAR_SCOPE := &"regular.qingyuan.r1"
const BASE := &"blackstone_city"
const REDCLIFF := &"redcliff_city"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	if save_directory.is_empty():
		_check(false, "fault runner requires an isolated --txwzs-v5-save-dir")
		_finish()
		return
	var mode := _argument_value("--mode=")
	if not mode.is_empty():
		match mode:
			"construction":
				await _check_construction_checkpoint_rollback()
			"pressure_probe":
				await _find_pressure_transition()
			"pressure":
				await _check_pressure_checkpoint_rollback()
			"combat_probe":
				await _find_combat_loss_transition()
			"combat":
				await _check_combat_checkpoint_rollback()
			_:
				_check(false, "unknown fault scenario: %s" % mode)
		_finish()
		return
	for scenario in ["construction", "pressure_probe", "pressure", "combat_probe", "combat"]:
		var child_directory := save_directory.path_join("fault_%s_%d" % [scenario, Time.get_ticks_usec()])
		DirAccess.make_dir_recursive_absolute(child_directory)
		var worker := _run_subprocess(scenario, child_directory, save_directory)
		print("REGULAR_FAULT_WORKER_%s_OUTPUT\n%s" % [scenario.to_upper(), str(worker.get("output", ""))])
		_check(bool(worker.get("passed", false)), "%s tick-fault worker exits only after all rollback assertions pass" % scenario)
	_finish()


func _run_subprocess(mode: String, save_directory: String, facts_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path("res://tests/run_regular_campaign_r1_faults.gd"), "--",
			"--mode=%s" % mode,
			"--txwzs-v5-save-dir=%s" % save_directory,
			"--fault-facts-dir=%s" % facts_directory,
		]),
		output,
		true
	)
	return {"passed": exit_code == 0, "output": "\n".join(output)}


func _new_regular_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node_or_null("ConstructionController")
	if city == null:
		return {}
	city.set_process(false)
	if not city.initialize_regular_campaign():
		return {}
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null or not bool(runtime.call("enabled")):
		return {}
	return {"scene": scene, "city": city, "runtime": runtime}


func _check_construction_checkpoint_rollback() -> void:
	var setup := await _new_regular_city()
	if setup.is_empty():
		_check(false, "construction fault scenario initializes through the normal controller")
		return
	var scene: Node = setup.scene
	var city: Node = setup.city
	var runtime: Object = setup.runtime
	var departed: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 30, "wood": 55,
	})
	runtime.call("advance", 2.0)
	var wood_before := int(city.get_nation_state().get_scope(REGULAR_SCOPE).get(&"wood", 0))
	var build: Dictionary = runtime.call("command", &"build", {
		"point_id": BASE, "kind": &"FARM", "plot": 0,
	})
	# Eighty-eight seconds makes the mainline exactly 90 seconds (after the
	# two-second initial arrival), a persisted checkpoint. The next failed
	# checkpoint would complete the paid farm, so rollback must retain this
	# partial paid construction state exactly.
	await _advance_in_batches(runtime, 88)
	var before: Dictionary = _authority_snapshot(city)
	var before_runtime: Dictionary = runtime.call("get_snapshot")
	var before_scope: Dictionary = city.get_nation_state().get_scope(REGULAR_SCOPE).duplicate(true)
	var project: Dictionary = Dictionary(before_runtime.get("project", {}))
	var paid_partial := (
		bool(departed.get("success", false))
		and bool(build.get("success", false))
		and int(before_scope.get(&"wood", 0)) < wood_before
		and not project.is_empty()
		and int(project.get("progress_ms", 0)) > 0
		and int(project.get("progress_ms", 0)) < int(project.get("required_ms", 0))
	)
	runtime.set("_failure_point", &"tick")
	runtime.call("advance", 15.0)
	runtime = city.get("_regular_campaign") as Object
	var after_authority := _authority_snapshot(city)
	var rollback_exact: bool = after_authority == before
	var paused: bool = bool(city.call("is_city_time_paused"))
	var no_half_scope: bool = city.get_nation_state().get_scope(REGULAR_SCOPE) == before_scope
	var no_half_runtime: bool = runtime != null and Dictionary(runtime.call("get_snapshot")) == before_runtime
	if runtime != null:
		runtime.set("_failure_point", &"")
	city.call("set_city_time_paused", false)
	runtime.call("advance", 15.0)
	var after_resume: Dictionary = runtime.call("get_snapshot")
	var completed_after_resume := Dictionary(after_resume.get("project", {})).is_empty()
	print("REGULAR_FAULT_CONSTRUCTION paid_partial=%s rollback_exact=%s paused=%s no_half_scope=%s no_half_runtime=%s completed_after_resume=%s before_progress=%d changed=%s" % [
		str(paid_partial), str(rollback_exact), str(paused), str(no_half_scope), str(no_half_runtime), str(completed_after_resume), int(project.get("progress_ms", 0)), str(_changed_keys(before, after_authority)),
	])
	_check(paid_partial, "paid farm remains genuinely under construction before its failing checkpoint")
	_check(rollback_exact and paused and no_half_scope and no_half_runtime, "failed completion checkpoint restores the entire last saved paid construction snapshot and pauses")
	_check(completed_after_resume, "clearing the hook and resuming completes the same farm only through a successful checkpoint")
	await _dispose(scene)


func _find_pressure_transition() -> void:
	# Preparedness room may legitimately grow as actual food and casualty facts
	# arrive. Discover the first authored stage transition through a normal run.
	var probe := await _new_regular_city()
	if probe.is_empty():
		_check(false, "pressure boundary probe initializes through the normal controller")
		return
	var probe_scene: Node = probe.scene
	var probe_city: Node = probe.city
	var probe_runtime: Object = probe.runtime
	var probe_departure: Dictionary = probe_runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(probe_city), "food": 8, "wood": 55,
	})
	var pre_stage_elapsed_seconds := -1
	if bool(probe_departure.get("success", false)):
		for index in 280:
			var before_step: Dictionary = probe_runtime.call("get_snapshot")
			var before_stage_value := int(Dictionary(before_step.get("pressure", {})).get("stage", 0))
			probe_runtime.call("advance", 15.0)
			var after_stage_value := int(Dictionary(Dictionary(probe_runtime.call("get_snapshot")).get("pressure", {})).get("stage", 0))
			if after_stage_value > before_stage_value:
				pre_stage_elapsed_seconds = int(before_step.get("mainline_elapsed_ms", 0)) / 1000
				break
			if index % 4 == 3:
				await process_frame
	await _dispose(probe_scene)
	_store_fact("pressure_transition_seconds", pre_stage_elapsed_seconds)
	print("REGULAR_FAULT_PRESSURE_PROBE departed=%s pre_stage_seconds=%d" % [
		str(bool(probe_departure.get("success", false))), pre_stage_elapsed_seconds,
	])
	_check(bool(probe_departure.get("success", false)) and pre_stage_elapsed_seconds >= 0, "normal low-food simulation finds its first pressure-stage checkpoint")


func _check_pressure_checkpoint_rollback() -> void:
	var pre_stage_elapsed_seconds := _load_fact("pressure_transition_seconds")

	var setup := await _new_regular_city()
	if setup.is_empty():
		_check(false, "pressure fault injection initializes through the normal controller")
		return
	var scene: Node = setup.scene
	var city: Node = setup.city
	var runtime: Object = setup.runtime
	var departed: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 8, "wood": 55,
	})
	if pre_stage_elapsed_seconds > 0:
		await _advance_in_batches(runtime, pre_stage_elapsed_seconds)
	var before: Dictionary = _authority_snapshot(city)
	var before_runtime: Dictionary = runtime.call("get_snapshot")
	var before_stage := int(Dictionary(before_runtime.get("pressure", {})).get("stage", -1))
	runtime.set("_failure_point", &"tick")
	runtime.call("advance", 15.0)
	runtime = city.get("_regular_campaign") as Object
	var rollback_exact: bool = _authority_snapshot(city) == before
	var paused: bool = bool(city.call("is_city_time_paused"))
	var no_half_stage: bool = runtime != null and int(Dictionary(Dictionary(runtime.call("get_snapshot")).get("pressure", {})).get("stage", -1)) == before_stage
	if runtime != null:
		runtime.set("_failure_point", &"")
	city.call("set_city_time_paused", false)
	runtime.call("advance", 15.0)
	var resumed_stage := int(Dictionary(Dictionary(runtime.call("get_snapshot")).get("pressure", {})).get("stage", -1))
	print("REGULAR_FAULT_PRESSURE departed=%s pre_stage_seconds=%d before_stage=%d rollback_exact=%s paused=%s no_half_stage=%s resumed_stage=%d" % [
		str(bool(departed.get("success", false))), pre_stage_elapsed_seconds, before_stage, str(rollback_exact), str(paused), str(no_half_stage), resumed_stage,
	])
	_check(bool(departed.get("success", false)) and pre_stage_elapsed_seconds >= 0 and before_stage == 0, "finite eight-food departure reaches the authored first pressure boundary from stage zero")
	_check(rollback_exact and paused and no_half_stage, "failed pressure-stage checkpoint publishes no elapsed-time or pressure half state")
	_check(resumed_stage > before_stage, "the same successful 15-second checkpoint advances the pressure stage after explicit resume")
	await _dispose(scene)


func _find_combat_loss_transition() -> void:
	# Discover a genuine combat-loss checkpoint with normal commands. The fault
	# worker later reproduces this deterministic 15-second tick in a fresh
	# authority owner rather than manufacturing a casualty in test data.
	var probe := await _new_regular_city()
	if probe.is_empty():
		_check(false, "combat boundary probe initializes through the normal controller")
		return
	var probe_scene: Node = probe.scene
	var probe_city: Node = probe.city
	var probe_runtime: Object = probe.runtime
	var probe_departure: Dictionary = probe_runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(probe_city), "food": 80, "wood": 55,
	})
	await _advance_in_batches(probe_runtime, 660)
	var probe_armies: Array = Array(Dictionary(probe_runtime.call("get_snapshot")).get("army_ids", []))
	var probe_move: Dictionary = {} if probe_armies.is_empty() else probe_runtime.call("command", &"move", {
		"army_id": StringName(probe_armies[0]), "target_id": REDCLIFF,
	})
	var pre_loss_elapsed_seconds := -1
	if bool(probe_departure.get("success", false)) and bool(probe_move.get("success", false)):
		for index in 40:
			var before_loss: Dictionary = probe_runtime.call("get_snapshot")
			probe_runtime.call("advance", 15.0)
			if int(Dictionary(probe_runtime.call("get_snapshot")).get("combat_losses_total", 0)) > int(before_loss.get("combat_losses_total", 0)):
				pre_loss_elapsed_seconds = int(before_loss.get("mainline_elapsed_ms", 0)) / 1000
				break
			await process_frame
	await _dispose(probe_scene)
	_store_fact("combat_transition_seconds", pre_loss_elapsed_seconds)
	print("REGULAR_FAULT_COMBAT_PROBE departed=%s move=%s pre_loss_seconds=%d" % [
		str(bool(probe_departure.get("success", false))), str(bool(probe_move.get("success", false))), pre_loss_elapsed_seconds,
	])
	_check(bool(probe_departure.get("success", false)) and bool(probe_move.get("success", false)) and pre_loss_elapsed_seconds >= 0, "normal Redcliff command finds its next real-combat-loss checkpoint")


func _check_combat_checkpoint_rollback() -> void:
	var pre_loss_elapsed_seconds := _load_fact("combat_transition_seconds")

	var setup := await _new_regular_city()
	if setup.is_empty():
		_check(false, "combat fault injection initializes through the normal controller")
		return
	var scene: Node = setup.scene
	var city: Node = setup.city
	var runtime: Object = setup.runtime
	var departed: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 80, "wood": 55,
	})
	await _advance_in_batches(runtime, 660)
	var armies: Array = Array(Dictionary(runtime.call("get_snapshot")).get("army_ids", []))
	var move: Dictionary = {} if armies.is_empty() else runtime.call("command", &"move", {
		"army_id": StringName(armies[0]), "target_id": REDCLIFF,
	})
	var current_seconds := int(Dictionary(runtime.call("get_snapshot")).get("mainline_elapsed_ms", 0)) / 1000
	if pre_loss_elapsed_seconds > current_seconds:
		await _advance_in_batches(runtime, pre_loss_elapsed_seconds - current_seconds)
	var before: Dictionary = _authority_snapshot(city)
	var before_runtime: Dictionary = runtime.call("get_snapshot")
	var before_losses := int(before_runtime.get("combat_losses_total", 0))
	runtime.set("_failure_point", &"tick")
	runtime.call("advance", 15.0)
	runtime = city.get("_regular_campaign") as Object
	var rollback_exact: bool = _authority_snapshot(city) == before
	var paused: bool = bool(city.call("is_city_time_paused"))
	var no_half_losses: bool = runtime != null and int(Dictionary(runtime.call("get_snapshot")).get("combat_losses_total", -1)) == before_losses
	if runtime != null:
		runtime.set("_failure_point", &"")
	city.call("set_city_time_paused", false)
	runtime.call("advance", 15.0)
	var resumed_losses := int(Dictionary(runtime.call("get_snapshot")).get("combat_losses_total", 0))
	print("REGULAR_FAULT_COMBAT departed=%s move=%s pre_loss_seconds=%d before_losses=%d rollback_exact=%s paused=%s no_half_losses=%s resumed_losses=%d" % [
		str(bool(departed.get("success", false))), str(bool(move.get("success", false))), pre_loss_elapsed_seconds, before_losses, str(rollback_exact), str(paused), str(no_half_losses), resumed_losses,
	])
	_check(pre_loss_elapsed_seconds >= 0 and bool(departed.get("success", false)) and bool(move.get("success", false)), "normal Redcliff command exposes a deterministic next real-combat-loss checkpoint")
	_check(rollback_exact and paused and no_half_losses, "failed combat checkpoint restores army, war and casualty authority with no published loss")
	_check(resumed_losses > before_losses, "the same successful checkpoint applies the observed real combat loss once")
	await _dispose(scene)


func _store_fact(name: String, value: int) -> void:
	var directory := _argument_value("--fault-facts-dir=")
	if directory.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("regular_fault_%s.txt" % name), FileAccess.WRITE)
	if file != null:
		file.store_string(str(value))


func _load_fact(name: String) -> int:
	var directory := _argument_value("--fault-facts-dir=")
	var path := directory.path_join("regular_fault_%s.txt" % name)
	if directory.is_empty() or not FileAccess.file_exists(path):
		return -1
	return FileAccess.get_file_as_string(path).strip_edges().to_int()


func _advance_in_batches(runtime: Object, seconds: int) -> void:
	var remaining := maxi(seconds, 0)
	while remaining > 0:
		var batch := mini(remaining, 60)
		runtime.call("advance", float(batch))
		remaining -= batch
		await process_frame


func _formation_ids(city: Node) -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation_value in city.get_formation_roster():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _authority_snapshot(city: Node) -> Dictionary:
	# Pausing is the required post-failure control state, rather than an
	# authority mutation. Every persisted world/campaign field remains exact.
	var snapshot: Dictionary = city.export_v5_campaign_snapshot().duplicate(true)
	var city_snapshot: Dictionary = Dictionary(snapshot.get("city", {})).duplicate(true)
	city_snapshot.erase("city_time_paused")
	snapshot["city"] = city_snapshot
	return snapshot


func _changed_keys(before: Dictionary, after: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key_value in before.keys():
		var key := String(key_value)
		if before.get(key_value) != after.get(key_value):
			keys.append(key)
	for key_value in after.keys():
		var key := String(key_value)
		if not before.has(key_value):
			keys.append(key)
	return keys


func _dispose(scene: Node) -> void:
	scene.queue_free()
	await process_frame


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1_FAULTS PASS checks=%d" % checks)
		quit(0)
		return
	for failure in failures:
		push_error("REGULAR_CAMPAIGN_R1_FAULTS FAIL: %s" % failure)
	quit(1)
