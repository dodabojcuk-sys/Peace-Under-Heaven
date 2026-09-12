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
	var initial: Dictionary = city.get_population_recovery_read_model()
	_check(int(initial.total_living) == 72 and int(initial.available) == 20 and int(initial.production_workers) == 12 and int(initial.construction_workers) == 12 and int(initial.medical_workers) == 4 and int(initial.governance_workers) == 4 and int(initial.military) == 20 and bool(initial.accounted), "正常开局只有一份人口真值，四类岗位、驻军与可用人口守恒")

	var moved: Dictionary = city.adjust_city_workforce(&"production", -2)
	var after_move: Dictionary = city.get_population_recovery_read_model()
	_check(bool(moved.get("success", false)) and int(after_move.production_workers) == 10 and int(after_move.available) == 22 and city.get_workforce_modifier_permille(&"production") == 833 and city.get_workforce_modifier_permille(&"construction") == 1000, "调岗立即改变正式生产效率，人员不会同时留在可用池")

	var food_before_training := int(city.food)
	var training: Dictionary = city.request_training()
	var queued: Dictionary = city.get_population_recovery_read_model()
	_check(bool(training.get("success", false)) and int(queued.training_reserved) == 5 and int(queued.available) == 17 and int(city.food) == food_before_training - 5 * city.INFANTRY_ROLE.recruit_food_per_unit, "训练从可用人口预留人员并支付现有兵种粮食成本")
	city.advance_one_day_for_test()
	var trained: Dictionary = city.get_population_recovery_read_model()
	_check(city.infantry_count == 25 and int(trained.training_reserved) == 0 and int(trained.military) == 25 and bool(trained.accounted), "日边界只把已训练人员移入原驻军，不复制人口")

	var population_before_casualties: Dictionary = city._population_recovery.get_snapshot()
	var garrison_before_casualties: Dictionary = city._garrison_state.get_persistence_snapshot()
	var removed: bool = city._garrison_state.try_remove_units(city.INFANTRY_ROLE.role_id, 4)
	var casualties: Dictionary = city._population_recovery.record_casualties(4, city.RECOVERY_RULES.wounded_permille)
	var after_casualties: Dictionary = city.get_population_recovery_read_model()
	_check(removed and int(casualties.wounded) == 2 and int(casualties.fallen) == 2 and int(after_casualties.wounded) == 2 and int(after_casualties.fallen) == 2 and int(after_casualties.total_living) == 70 and bool(after_casualties.accounted), "同一批战损在结算时区分伤员与阵亡，阵亡减少总人口且不能进入治疗")

	var food_before_treatment := int(city.food)
	var treatment: Dictionary = city.begin_wounded_treatment()
	city.advance_city_time(1.0)
	var mid_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var mid: Dictionary = city.get_population_recovery_read_model()
	_check(bool(treatment.get("success", false)) and int(city.food) == food_before_treatment - 2 and StringName(Dictionary(mid.treatment).phase) == &"ACTIVE" and int(Dictionary(mid.treatment).progress_milliseconds) == 1000, "治疗支付自身成本并沿统一城市时间推进，暂停前状态可保存")

	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restore_result: Dictionary = restored.restore_v5_campaign_snapshot(mid_snapshot)
	restored.advance_city_time(1.0)
	var completed: Dictionary = restored.get_population_recovery_read_model()
	_check(bool(restore_result.get("success", false)) and int(completed.wounded) == 0 and int(completed.fallen) == 2 and int(completed.military) == 23 and restored.infantry_count == 23 and StringName(Dictionary(completed.treatment).phase) == &"IDLE" and bool(completed.accounted), "治疗中读档保留精确进度；完成只让伤员回到原驻军，阵亡不复活")

	var before_bad: Dictionary = restored.export_v5_campaign_snapshot()
	var malformed: Dictionary = before_bad.duplicate(true)
	malformed.population_recovery.available += 1
	var rejected: Dictionary = restored.restore_v5_campaign_snapshot(malformed)
	_check(not bool(rejected.get("success", false)) and restored.export_v5_campaign_snapshot() == before_bad, "人口守恒被篡改的存档在应用前拒绝且全部权威零写入")

	var ui: Node = scene.get_node("UI/Shell")
	var population_label: Label = ui.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/PopulationRecoverySummary")
	var treatment_button: Button = ui.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/WoundedTreatmentButton")
	_check(population_label.text.contains("劳动力") and population_label.text.contains("死亡") and treatment_button != null, "常态内城正式经营入口显示人口分配、伤员与治疗操作")

	city._population_recovery.restore_snapshot(population_before_casualties)
	city._garrison_state.restore_persistence_snapshot(garrison_before_casualties)
	scene.queue_free()
	restored_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("BLACKSTONE_RECOVERY_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("BLACKSTONE_RECOVERY_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)
