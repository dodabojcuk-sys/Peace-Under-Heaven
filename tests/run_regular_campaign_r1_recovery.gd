extends SceneTree


## Cold-process recovery contract for Regular Campaign R1. Every chain uses a
## unique V5 directory and never opens the user's default generation or a
## previously reported candidate save.

const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const REGULAR_SCOPE := &"regular.qingyuan.r1"
const BASE := &"blackstone_city"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mode := _argument_value("--mode=")
	if not mode.is_empty():
		await _run_worker(mode)
		return
	var save_directory := ProjectSettings.globalize_path(
		"user://regular_campaign_r1_recovery_%d_%d" % [
			OS.get_process_id(), Time.get_ticks_usec(),
		]
	)
	_remove_test_tree(save_directory)
	var baseline_workers := _run_chain(["A", "B", "C"], save_directory)
	var battle_workers := _run_chain(["D", "E", "F"], save_directory.path_join("battle"))
	var pressure_workers := _run_chain(["G", "H"], save_directory.path_join("pressure"))
	var credit_workers := _run_chain(["I", "J"], save_directory.path_join("credit"))
	_check(_workers_passed(baseline_workers), "A/B/C 均在同一隔离目录完成真实冷启动恢复")
	_check(
		str(baseline_workers[1].get("output", "")).contains("restored_construction=true")
			and str(baseline_workers[2].get("output", "")).contains("restored_warning=true"),
		"第二、三个进程各自先读取前一进程的施工与供粮预警事实",
	)
	_check(_workers_passed(battle_workers), "D/E/F 跨进程保留战损、待结算和确认后的唯一性")
	_check(
		str(battle_workers[1].get("output", "")).contains("restored_first_loss=true")
			and str(battle_workers[2].get("output", "")).contains("duplicate_confirm_rejected=true"),
		"第二次交战前的真实战损和确认后的不可重复结算均经冷恢复核对",
	)
	_check(_workers_passed(pressure_workers), "G/H 跨进程保留高压、敌方整备和断粮后果")
	_check(
		str(pressure_workers[1].get("output", "")).contains("restored_high_pressure=true"),
		"高压与已消费敌方整备事件在新进程中恢复后才执行重试",
	)
	_check(_workers_passed(credit_workers), "I/J 跨进程保留已消费的有限战损恢复缓冲")
	_check(
		str(credit_workers[1].get("output", "")).contains("restored_credit_consumed=true"),
		"已消费的战损恢复缓冲在新进程恢复后才允许重试",
	)
	_remove_test_tree(save_directory)
	_finish()


func _run_chain(modes: Array[String], save_directory: String) -> Array[Dictionary]:
	_remove_test_tree(save_directory)
	var workers: Array[Dictionary] = []
	for mode in modes:
		workers.append(_run_subprocess(mode, save_directory))
	for worker in workers:
		print("REGULAR_RECOVERY_WORKER_%s_OUTPUT\n%s" % [
			str(worker.get("mode", "?")), str(worker.get("output", "")),
		])
	return workers


func _run_subprocess(mode: String, save_directory: String) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(
		OS.get_executable_path(),
		PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path("res://tests/run_regular_campaign_r1_recovery.gd"), "--",
			"--mode=%s" % mode,
			"--txwzs-v5-save-dir=%s" % save_directory,
		]),
		output,
		true
	)
	var marker_path := save_directory.path_join("regular_recovery_%s.result" % mode.to_lower())
	var marker := FileAccess.get_file_as_string(marker_path).strip_edges() if FileAccess.file_exists(marker_path) else ""
	return {
		"mode": mode,
		"exit_code": exit_code,
		"output": "\n".join(output),
		"passed": exit_code == 0 and marker == "REGULAR_RECOVERY_%s PASS" % mode,
	}


func _run_worker(mode: String) -> void:
	var save_directory := _argument_value("--txwzs-v5-save-dir=")
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	# Scene-tree addition completes the controller's synchronous persistence
	# initialization. Freeze immediately so no render-frame timing can insert a
	# 250ms simulation step between a disk restore and our comparison.
	var city: Node = scene.get_node_or_null("ConstructionController")
	if city != null:
		city.set_process(false)
	await process_frame
	await process_frame
	var passed := false
	match mode:
		"A":
			passed = _stage_a(city, scene, save_directory)
		"B":
			passed = _stage_b(city, scene, save_directory)
		"C":
			passed = _stage_c(city, scene, save_directory)
		"D":
			passed = _stage_d(city, scene, save_directory)
		"E":
			passed = _stage_e(city, scene, save_directory)
		"F":
			passed = _stage_f(city, scene, save_directory)
		"G":
			passed = await _stage_g(city, scene, save_directory)
		"H":
			passed = _stage_h(city, scene, save_directory)
		"I":
			passed = await _stage_i(city, scene, save_directory)
		"J":
			passed = _stage_j(city, scene, save_directory)
		_:
			push_error("Unknown regular recovery stage: %s" % mode)
	_write_marker(save_directory, mode, passed)
	scene.queue_free()
	await process_frame
	quit(0 if passed else 1)


func _stage_a(city: Node, scene: Node, save_directory: String) -> bool:
	if city == null or not city.has_method("initialize_regular_campaign"):
		return false
	# Synthetic schema 17 is deliberately built from the pristine non-regular
	# snapshot, before this process creates regular-only armies/scoped inventory.
	var legacy: Dictionary = city.export_v5_campaign_snapshot().duplicate(true)
	legacy["schema_version"] = 17
	legacy.erase("regular_campaign")
	legacy.erase("scoped_resources")
	var legacy_ok := bool(city.validate_v5_campaign_snapshot(legacy).get("valid", false))
	if not city.initialize_regular_campaign():
		return false
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null:
		return false

	var before_departure: Dictionary = city.export_v5_campaign_snapshot()
	runtime.set("_failure_point", &"depart")
	var failed_departure: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 30, "wood": 55,
	})
	runtime.set("_failure_point", &"")
	var depart_rolled_back: bool = (
		not bool(failed_departure.get("success", false))
		and city.export_v5_campaign_snapshot() == before_departure
	)
	# A failed transaction restores the controller-owned runtime in place. Read
	# it again rather than retaining a presentation/private-state substitute.
	runtime = city.get("_regular_campaign") as Object
	var departure: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 30, "wood": 55,
	})
	# The first order takes one authored second; construction only starts after
	# the dispatched people have actually reached the forward base.
	runtime.call("advance", 2.0)
	var build: Dictionary = runtime.call("command", &"build", {
		"point_id": BASE, "kind": &"FARM", "plot": 0,
	})
	runtime.call("advance", 30.0)
	var facts := _facts(city, runtime)
	var construction_active := (
		StringName(facts.get("phase", &"")) == &"ACTIVE"
		and int(facts.get("project_progress_ms", 0)) > 0
		and int(facts.get("project_progress_ms", 0)) < 90000
	)
	_store_facts(save_directory, "a", facts)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_construction")
	print("REGULAR_RECOVERY_A legacy17=%s rollback_depart=%s construction=%s time=%d" % [
		str(legacy_ok), str(depart_rolled_back), str(construction_active), int(facts.get("mainline_ms", 0)),
	])
	return legacy_ok and depart_rolled_back and bool(departure.get("success", false)) and bool(build.get("success", false)) and construction_active and saved


func _stage_b(city: Node, scene: Node, save_directory: String) -> bool:
	var expected := _load_facts(save_directory, "a")
	var runtime: Object = city.get("_regular_campaign") as Object if city != null else null
	if expected.is_empty() or runtime == null or not bool(runtime.call("enabled")):
		return false
	var restored := _facts(city, runtime)
	var restored_construction := _matches_facts(restored, expected)
	# Complete the already paid project but leave it unstaffed: the forecast must
	# derive from actual zero yield and periodic rations, not UI nominal farms.
	runtime.call("advance", 900.0)
	var forecast: Dictionary = Dictionary(Dictionary(runtime.call("get_read_model")).get("local", {})).get("forecast", {})
	var after := _facts(city, runtime)
	var risk := StringName(forecast.get("risk_id", &""))
	var warning := risk in [&"WARNING", &"SHORTAGE"]
	_store_facts(save_directory, "b", after)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_food_warning")
	print("REGULAR_RECOVERY_B restored_construction=%s warning=%s risk=%s time=%d food=%d" % [
		str(restored_construction), str(warning), str(risk), int(after.get("mainline_ms", 0)), int(after.get("scope_food", 0)),
	])
	return restored_construction and warning and saved


func _stage_c(city: Node, scene: Node, save_directory: String) -> bool:
	var expected := _load_facts(save_directory, "b")
	var runtime: Object = city.get("_regular_campaign") as Object if city != null else null
	if expected.is_empty() or runtime == null or not bool(runtime.call("enabled")):
		return false
	var restored := _facts(city, runtime)
	var restored_warning := _matches_facts(restored, expected)
	var malformed: Dictionary = city.export_v5_campaign_snapshot().duplicate(true)
	var payload: Dictionary = Dictionary(malformed.get("regular_campaign", {}))
	if not Array(payload.get("army_ids", [])).is_empty():
		payload["army_ids"] = [&"army.player.999999"]
		malformed["regular_campaign"] = payload
	var malformed_rejected := not bool(city.validate_v5_campaign_snapshot(malformed).get("valid", false))

	var withdrawal: Dictionary = runtime.call("command", &"outcome", {"kind": &"WITHDRAW"})
	var before_confirm: Dictionary = city.export_v5_campaign_snapshot()
	runtime.set("_failure_point", &"confirm")
	var failed_confirm: Dictionary = runtime.call("command", &"confirm")
	runtime.set("_failure_point", &"")
	var confirm_rolled_back: bool = (
		not bool(failed_confirm.get("success", false))
		and city.export_v5_campaign_snapshot() == before_confirm
	)
	var pending := _facts(city, runtime)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_pending")
	print("REGULAR_RECOVERY_C restored_warning=%s malformed_rejected=%s pending=%s rollback_confirm=%s time=%d fallen=%d armies=%s scope=%d/%d pressure=%d" % [
		str(restored_warning), str(malformed_rejected), str(StringName(pending.get("phase", &"")) == &"PENDING"), str(confirm_rolled_back), int(pending.get("mainline_ms", 0)), int(pending.get("fallen", 0)), str(pending.get("armies", [])), int(pending.get("scope_food", 0)), int(pending.get("scope_wood", 0)), int(pending.get("pressure_stage", 0)),
	])
	return restored_warning and malformed_rejected and bool(withdrawal.get("success", false)) and confirm_rolled_back and StringName(pending.get("phase", &"")) == &"PENDING" and saved


## D starts a separate normal-command chain: all ordinary formations depart,
## one seven-person formation reaches Redcliff while Silverford remains enemy,
## and the first real loss is saved before any second battle is ordered.
func _stage_d(city: Node, scene: Node, save_directory: String) -> bool:
	if city == null or not city.initialize_regular_campaign():
		return false
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null:
		return false
	var departure: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 80, "wood": 55,
	})
	if not bool(departure.get("success", false)):
		return false
	runtime.call("advance", 660.0)
	var army_ids: Array = Array(Dictionary(runtime.call("get_snapshot")).get("army_ids", []))
	if army_ids.size() < 2:
		return false
	var first_id := StringName(army_ids[0])
	var silverford_still_enemy: bool = city._war_loop_state.is_enemy_city(&"silverford_city")
	var first_order: Dictionary = runtime.call("command", &"move", {
		"army_id": first_id, "target_id": &"redcliff_city",
	})
	var loss_observed := false
	for step in 30:
		runtime.call("advance", 30.0)
		var snapshot: Dictionary = runtime.call("get_snapshot")
		if int(snapshot.get("combat_losses_total", 0)) > 0:
			loss_observed = true
			break
	var facts := _facts(city, runtime)
	var before_second_battle: bool = (
		loss_observed
		and int(facts.get("combat_losses_total", 0)) > 0
		and int(facts.get("pressure_credit_balance_ms", 0)) > 0
		and _army_members(city, StringName(army_ids[1])) > 0
		and city._army_registry.get_army(StringName(army_ids[1])).target_node_id == BASE
	)
	_store_facts(save_directory, "d", facts)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_first_combat")
	print("REGULAR_RECOVERY_D departed=%s silverford_enemy=%s first_order=%s first_loss=%s before_second=%s time=%d fallen=%d wounded=%d growth=%d credit=%d second_members=%d" % [
		str(bool(departure.get("success", false))), str(silverford_still_enemy), str(bool(first_order.get("success", false))), str(loss_observed), str(before_second_battle), int(facts.get("mainline_ms", 0)), int(facts.get("fallen", 0)), int(facts.get("wounded", 0)), int(facts.get("enemy_growth_events", 0)), int(facts.get("pressure_credit_balance_ms", 0)), _army_members(city, StringName(army_ids[1])),
	])
	return bool(departure.get("success", false)) and silverford_still_enemy and bool(first_order.get("success", false)) and before_second_battle and saved


## E is a new process. It observes D's loss before a second fight can be
## ordered, then confirms one withdrawal settlement without advancing the
## restored state.
func _stage_e(city: Node, scene: Node, save_directory: String) -> bool:
	var expected := _load_facts(save_directory, "d")
	var runtime: Object = city.get("_regular_campaign") as Object if city != null else null
	if expected.is_empty() or runtime == null or not bool(runtime.call("enabled")):
		return false
	var restored := _facts(city, runtime)
	var restored_first_loss := _matches_facts(restored, expected) and (
		int(restored.get("combat_losses_total", 0)) > 0
		and int(restored.get("pressure_credit_balance_ms", 0)) > 0
	)
	var withdrawal: Dictionary = runtime.call("command", &"outcome", {"kind": &"WITHDRAW"})
	var confirmation: Dictionary = runtime.call("command", &"confirm")
	var settled := _facts(city, runtime)
	_store_facts(save_directory, "e", settled)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_confirmed")
	print("REGULAR_RECOVERY_E restored_first_loss=%s withdrawn=%s confirmed=%s phase=%s time=%d fallen=%d wounded=%d" % [
		str(restored_first_loss), str(bool(withdrawal.get("success", false))), str(bool(confirmation.get("success", false))), str(settled.get("phase", "")), int(settled.get("mainline_ms", 0)), int(settled.get("fallen", 0)), int(settled.get("wounded", 0)),
	])
	return restored_first_loss and bool(withdrawal.get("success", false)) and bool(confirmation.get("success", false)) and StringName(settled.get("phase", &"")) == &"PREPARATION" and saved


## F proves that a confirmed settlement remains settled after another full
## process restart and cannot be applied a second time.
func _stage_f(city: Node, _scene: Node, save_directory: String) -> bool:
	var expected := _load_facts(save_directory, "e")
	var runtime: Object = city.get("_regular_campaign") as Object if city != null else null
	if expected.is_empty() or runtime == null or not bool(runtime.call("enabled")):
		return false
	var restored := _facts(city, runtime)
	var restored_settlement := _matches_facts(restored, expected) and StringName(restored.get("phase", &"")) == &"PREPARATION"
	var before: Dictionary = city.export_v5_campaign_snapshot()
	var duplicate: Dictionary = runtime.call("command", &"confirm")
	var duplicate_confirm_rejected: bool = not bool(duplicate.get("success", false)) and city.export_v5_campaign_snapshot() == before
	print("REGULAR_RECOVERY_F restored_settlement=%s duplicate_confirm_rejected=%s phase=%s time=%d" % [
		str(restored_settlement), str(duplicate_confirm_rejected), str(restored.get("phase", "")), int(restored.get("mainline_ms", 0)),
	])
	return restored_settlement and duplicate_confirm_rejected


## G deliberately uses the early eight-food departure. The resulting shortage,
## pressure and source-limited enemy preparation are normal simulation facts,
## saved before retry so H can inspect them in a separate process.
func _stage_g(city: Node, scene: Node, save_directory: String) -> bool:
	if city == null or not city.initialize_regular_campaign():
		return false
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null:
		return false
	var departure: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 8, "wood": 55,
	})
	if not bool(departure.get("success", false)):
		return false
	await _advance_in_batches(runtime, 5400)
	var facts := _facts(city, runtime)
	var shortfall_recorded := int(facts.get("fallen", 0)) + int(facts.get("wounded", 0)) > 0
	var high_pressure := int(facts.get("pressure_stage", 0)) > 0
	var growth_consumed := int(facts.get("enemy_growth_events", 0)) > 0 and int(facts.get("enemy_reserve", 120)) < 120
	_store_facts(save_directory, "g", facts)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_high_pressure")
	print("REGULAR_RECOVERY_G departed=%s high_pressure=%s shortage=%s growth_consumed=%s time=%d pressure=%d growth=%d reserve=%d fallen=%d wounded=%d" % [
		str(bool(departure.get("success", false))), str(high_pressure), str(shortfall_recorded), str(growth_consumed), int(facts.get("mainline_ms", 0)), int(facts.get("pressure_stage", 0)), int(facts.get("enemy_growth_events", 0)), int(facts.get("enemy_reserve", 0)), int(facts.get("fallen", 0)), int(facts.get("wounded", 0)),
	])
	return bool(departure.get("success", false)) and high_pressure and shortfall_recorded and growth_consumed and saved


func _stage_h(city: Node, scene: Node, save_directory: String) -> bool:
	var expected := _load_facts(save_directory, "g")
	var runtime: Object = city.get("_regular_campaign") as Object if city != null else null
	if expected.is_empty() or runtime == null or not bool(runtime.call("enabled")):
		return false
	var restored := _facts(city, runtime)
	var restored_high_pressure := _matches_facts(restored, expected) and int(restored.get("pressure_stage", 0)) > 0 and int(restored.get("enemy_growth_events", 0)) > 0
	var retry: Dictionary = runtime.call("command", &"retry")
	var retried := _facts(city, runtime)
	var retry_kept_mainline_pressure := (
		bool(retry.get("success", false))
		and int(retried.get("mainline_ms", 0)) == int(expected.get("mainline_ms", -1))
		and int(retried.get("pressure_stage", 0)) == int(expected.get("pressure_stage", -1))
		and StringName(retried.get("phase", &"")) == &"ACTIVE"
	)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_retry_after_shortage")
	print("REGULAR_RECOVERY_H restored_high_pressure=%s retry=%s kept_mainline_pressure=%s phase=%s time=%d pressure=%d growth_before_retry=%d" % [
		str(restored_high_pressure), str(bool(retry.get("success", false))), str(retry_kept_mainline_pressure), str(retried.get("phase", "")), int(retried.get("mainline_ms", 0)), int(retried.get("pressure_stage", 0)), int(expected.get("enemy_growth_events", 0)),
	])
	return restored_high_pressure and retry_kept_mainline_pressure and saved


## I/J isolate the finite recovery buffer from the settlement chain. I uses a
## normal Redcliff order to create a genuine combat loss, then advances in
## frame-sized batches until the resulting credit is actually consumed.
func _stage_i(city: Node, scene: Node, save_directory: String) -> bool:
	if city == null or not city.initialize_regular_campaign():
		return false
	var runtime: Object = city.get("_regular_campaign") as Object
	if runtime == null:
		return false
	var departure: Dictionary = runtime.call("command", &"depart", {
		"formation_ids": _formation_ids(city), "food": 80, "wood": 55,
	})
	if not bool(departure.get("success", false)):
		return false
	runtime.call("advance", 660.0)
	var army_ids: Array = Array(Dictionary(runtime.call("get_snapshot")).get("army_ids", []))
	if army_ids.is_empty():
		return false
	var first_order: Dictionary = runtime.call("command", &"move", {
		"army_id": StringName(army_ids[0]), "target_id": &"redcliff_city",
	})
	var combat_loss := false
	for step in 30:
		runtime.call("advance", 30.0)
		if int(Dictionary(runtime.call("get_snapshot")).get("combat_losses_total", 0)) > 0:
			combat_loss = true
			break
	var elapsed_seconds := int(Dictionary(runtime.call("get_snapshot")).get("mainline_elapsed_ms", 0)) / 1000
	if combat_loss and elapsed_seconds < 3000:
		await _advance_in_batches(runtime, 3000 - elapsed_seconds)
	var facts := _facts(city, runtime)
	var credit_consumed := int(facts.get("pressure_credit_consumed_ms", 0)) > 0
	_store_facts(save_directory, "i", facts)
	var saved: bool = scene.flush_runtime_persistence(&"regular_recovery_consumed_credit")
	print("REGULAR_RECOVERY_I departed=%s first_order=%s combat_loss=%s credit_consumed=%s time=%d credit=%d/%d" % [
		str(bool(departure.get("success", false))), str(bool(first_order.get("success", false))), str(combat_loss), str(credit_consumed), int(facts.get("mainline_ms", 0)), int(facts.get("pressure_credit_balance_ms", 0)), int(facts.get("pressure_credit_consumed_ms", 0)),
	])
	return bool(departure.get("success", false)) and bool(first_order.get("success", false)) and combat_loss and credit_consumed and saved


func _stage_j(city: Node, scene: Node, scene_save_directory: String) -> bool:
	var expected := _load_facts(scene_save_directory, "i")
	var runtime: Object = city.get("_regular_campaign") as Object if city != null else null
	if expected.is_empty() or runtime == null or not bool(runtime.call("enabled")):
		return false
	var restored := _facts(city, runtime)
	var restored_credit_consumed := _matches_facts(restored, expected) and int(restored.get("pressure_credit_consumed_ms", 0)) > 0
	var retry: Dictionary = runtime.call("command", &"retry")
	var retried := _facts(city, runtime)
	var retry_kept_credit := (
		bool(retry.get("success", false))
		and int(retried.get("mainline_ms", 0)) == int(expected.get("mainline_ms", -1))
		and int(retried.get("pressure_credit_consumed_ms", 0)) == int(expected.get("pressure_credit_consumed_ms", -1))
		and StringName(retried.get("phase", &"")) == &"ACTIVE"
	)
	print("REGULAR_RECOVERY_J restored_credit_consumed=%s retry_kept_credit=%s phase=%s time=%d credit=%d" % [
		str(restored_credit_consumed), str(retry_kept_credit), str(retried.get("phase", "")), int(retried.get("mainline_ms", 0)), int(retried.get("pressure_credit_consumed_ms", 0)),
	])
	return restored_credit_consumed and retry_kept_credit


func _advance_in_batches(runtime: Object, seconds: int) -> void:
	var remaining := maxi(seconds, 0)
	while remaining > 0:
		var batch := mini(remaining, 60)
		runtime.call("advance", float(batch))
		remaining -= batch
		await process_frame


func _facts(city: Node, runtime: Object) -> Dictionary:
	var snapshot: Dictionary = runtime.call("get_snapshot")
	var scope: Dictionary = city.get_nation_state().get_scope(REGULAR_SCOPE)
	var armies: Array = []
	for army_id_value in Array(snapshot.get("army_ids", [])):
		var army: Dictionary = city._army_registry.get_army(StringName(army_id_value))
		var members := 0
		for count in Dictionary(army.get("units_by_definition_id", {})).values():
			members += int(count)
		armies.append({
			"id": String(army.get("army_id", "")),
			"phase": String(army.get("phase", "")),
			"members": members,
		})
	var project: Dictionary = Dictionary(snapshot.get("project", {}))
	var pressure: Dictionary = Dictionary(snapshot.get("pressure", {}))
	return {
		"phase": String(snapshot.get("phase", "")),
		"mainline_ms": int(snapshot.get("mainline_elapsed_ms", 0)),
		"attempt_ms": int(snapshot.get("attempt_elapsed_ms", 0)),
		"project_progress_ms": int(project.get("progress_ms", 0)),
		"project_required_ms": int(project.get("required_ms", 0)),
		"scope_food": int(scope.get(&"food", 0)),
		"scope_wood": int(scope.get(&"wood", 0)),
		"pressure_stage": int(pressure.get("stage", pressure.get("pressure_stage", -1))),
		"pressure_credit_balance_ms": int(pressure.get("recovery_credit_balance_ms", 0)),
		"pressure_credit_consumed_ms": int(pressure.get("recovery_credit_consumed_ms", 0)),
		"pressure_observed_losses": int(pressure.get("observed_combat_losses", 0)),
		"enemy_growth_events": int(snapshot.get("enemy_growth_events", 0)),
		"enemy_reserve": int(snapshot.get("enemy_reserve", 0)),
		"combat_losses_total": int(snapshot.get("combat_losses_total", 0)),
		"fallen": int(snapshot.get("fallen_home", 0)),
		"wounded": _wounded_total(snapshot),
		"armies": armies,
	}


func _wounded_total(snapshot: Dictionary) -> int:
	var total := 0
	for pair_value in Dictionary(snapshot.get("wounded_by_army", {})).values():
		var pair: Dictionary = Dictionary(pair_value)
		total += int(pair.get("home", 0)) + int(pair.get("local", 0))
	return total


func _matches_facts(actual: Dictionary, expected: Dictionary) -> bool:
	for key in ["phase", "mainline_ms", "attempt_ms", "project_progress_ms", "project_required_ms", "scope_food", "scope_wood", "pressure_stage", "pressure_credit_balance_ms", "pressure_credit_consumed_ms", "pressure_observed_losses", "enemy_growth_events", "enemy_reserve", "combat_losses_total", "fallen", "wounded", "armies"]:
		if actual.get(key) != expected.get(key):
			return false
	return true


func _army_members(city: Node, army_id: StringName) -> int:
	var army: Dictionary = city._army_registry.get_army(army_id)
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _formation_ids(city: Node) -> Array[StringName]:
	var ids: Array[StringName] = []
	for formation_value in city.get_formation_roster():
		var formation: Dictionary = Dictionary(formation_value)
		if int(formation.get("member_count", 0)) > 0:
			ids.append(StringName(formation.get("formation_id", &"")))
	return ids


func _store_facts(save_directory: String, suffix: String, facts: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var file := FileAccess.open(save_directory.path_join("regular_recovery_%s.facts" % suffix), FileAccess.WRITE)
	if file != null:
		file.store_var(facts)


func _load_facts(save_directory: String, suffix: String) -> Dictionary:
	var path := save_directory.path_join("regular_recovery_%s.facts" % suffix)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var value: Variant = file.get_var() if file != null else {}
	return Dictionary(value) if value is Dictionary else {}


func _write_marker(save_directory: String, mode: String, passed: bool) -> void:
	DirAccess.make_dir_recursive_absolute(save_directory)
	var marker := FileAccess.open(save_directory.path_join("regular_recovery_%s.result" % mode.to_lower()), FileAccess.WRITE)
	if marker != null:
		marker.store_string("REGULAR_RECOVERY_%s %s" % [mode, "PASS" if passed else "FAIL"])


func _workers_passed(workers: Array[Dictionary]) -> bool:
	for worker in workers:
		if not bool(worker.get("passed", false)):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("REGULAR_CAMPAIGN_R1_RECOVERY PASS assertions=2")
		quit(0)
		return
	for failure in failures:
		push_error("REGULAR_CAMPAIGN_R1_RECOVERY FAIL: %s" % failure)
	quit(1)


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""


func _remove_test_tree(path: String) -> void:
	if not path.contains("regular_campaign_r1_recovery_") or not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for name in directory.get_files():
		DirAccess.remove_absolute(path.path_join(name))
	for name in directory.get_directories():
		_remove_test_tree(path.path_join(name))
	DirAccess.remove_absolute(path)
