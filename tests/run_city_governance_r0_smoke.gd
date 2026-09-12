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
	var initial: Dictionary = city.get_city_governance_read_model()
	_check(StringName(initial.season_id) == &"SPRING" and int(initial.housing_capacity) == 72 and int(initial.health_permille) == 1000 and int(initial.food_required) == 7, "新局春季住房恰好覆盖人口，居民与驻军日粮只计算一次")

	_check(bool(city.adjust_city_workforce(&"medical", -4).success), "医疗人员可以通过正式人口调岗释放")
	city.food = 0
	_check(city._advance_day_boundary(true), "首次缺粮日仍可结算并给出预警")
	var first_shortage: Dictionary = city.get_city_governance_read_model()
	_check(int(first_shortage.consecutive_food_shortage_days) == 1 and int(first_shortage.diseased_count) == 0 and int(first_shortage.health_permille) < 1000, "首次缺粮先降低健康，不立即制造大量病人")
	_check(city._advance_day_boundary(true), "持续缺粮进入第二日")
	var second_shortage: Dictionary = city.get_city_governance_read_model()
	_check(int(second_shortage.diseased_count) == 2 and int(second_shortage.consecutive_food_shortage_days) == 2, "持续缺粮按聚合规则产生可解释疾病")
	_check(city._advance_day_boundary(true), "第三个压力日触发稳定治安事件")
	var disorder: Dictionary = city.get_city_governance_read_model()
	_check(StringName(Dictionary(disorder.active_event).phase) == &"ACTIVE" and StringName(Dictionary(disorder.active_event).kind) == &"PETTY_THEFT", "资源压力形成带稳定身份的轻微治安事件")
	var event_id := StringName(Dictionary(disorder.active_event).event_id)
	city.food = 5
	var governance_food_before := int(city.food)
	var resolved: Dictionary = city.resolve_city_governance_event()
	_check(bool(resolved.success) and int(city.food) == governance_food_before - 2 and StringName(Dictionary(city.get_city_governance_read_model().active_event).phase) == &"IDLE", "治理投入人员与粮食后一次解决事件")
	var repeated: Dictionary = city.resolve_city_governance_event()
	_check(not bool(repeated.success) and int(city.food) == governance_food_before - 2 and city._city_governance.resolved_event_ids.has(event_id), "重复治理不重复扣粮或重结算事件")

	_check(bool(city.adjust_city_workforce(&"medical", 4).success), "恢复医疗人员不创建新人口")
	city.food = 100
	var health_before_recovery := int(city.get_city_governance_read_model().health_permille)
	_check(city._advance_day_boundary(true), "粮食恢复后城市继续推进")
	var recovered_health: Dictionary = city.get_city_governance_read_model()
	_check(int(recovered_health.diseased_count) == 0 and int(recovered_health.health_permille) > health_before_recovery, "医疗容量与人员共同使疾病康复，健康逐步回升")
	while city.current_day < 10:
		_check(city._advance_day_boundary(true), "使用同一城市日历推进到冬季")
	var winter: Dictionary = city.get_city_governance_read_model()
	_check(StringName(winter.season_id) == &"WINTER" and int(winter.housing_capacity) == 64 and int(winter.housing_shortfall) == 8, "冬季按日历降低住房有效容量并显示可预见压力")
	var housing_cell := _find_legal_cell(city, &"building.housing.t1")
	var housing_id: int = city.place_definition_at_cell(&"building.housing.t1", housing_cell, false, true)
	var housed_winter: Dictionary = city.get_city_governance_read_model()
	_check(housing_cell != Vector2i(-1, -1) and housing_id > 0 and int(housed_winter.housing_capacity) == 80 and int(housed_winter.housing_shortfall) == 0, "实际完工民居提供住房能力，不补发居民")
	var clinic_cell := _find_legal_cell(city, &"building.clinic.t1")
	var clinic_id: int = city.place_definition_at_cell(&"building.clinic.t1", clinic_cell, false, true)
	_check(clinic_cell != Vector2i(-1, -1) and clinic_id > 0 and city.get_city_medical_capacity() == 12, "实际完工医舍提供医疗容量，与医疗人员分开计算")

	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var restored_scene := CITY_SCENE.instantiate()
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var restored: Node = restored_scene.get_node("ConstructionController")
	restored.set_process(false)
	var restored_result: Dictionary = restored.restore_v5_campaign_snapshot(snapshot)
	_check(bool(restored_result.success) and restored._city_governance.get_snapshot() == snapshot.city_governance and restored._city_governance.resolved_event_ids.has(event_id), "治理、疾病与已解决事件经正式 V5 恢复保持一致")

	var legacy: Dictionary = snapshot.duplicate(true)
	legacy.schema_version = 13
	legacy.erase("city_governance")
	legacy.erase("city_strategy")
	legacy.population_recovery.schema_version = 1
	legacy.population_recovery.available += int(legacy.population_recovery.medical_workers) + int(legacy.population_recovery.governance_workers)
	legacy.population_recovery.erase("medical_workers")
	legacy.population_recovery.erase("governance_workers")
	for key in ["children", "elderly", "resident_sick", "unsettled_refugees", "male_count", "female_count", "unknown_sex_count", "growth_progress", "child_age_progress", "adult_age_progress", "elderly_exposure_progress", "next_birth_sequence"]:
		legacy.population_recovery.erase(key)
	var legacy_validation: Dictionary = restored.validate_v5_campaign_snapshot(legacy)
	_check(bool(legacy_validation.valid) and int(legacy_validation.snapshot.schema_version) == 16 and int(legacy_validation.snapshot.population_recovery.resident_sick) == 0 and Array(legacy_validation.snapshot.city_strategy.unlocked_official_ids).is_empty(), "V13 旧档只补保守治理、未知人口维度与空战略默认值，不补资源、居民、文官或有利事件")
	var malformed_legacy: Dictionary = legacy.duplicate(true)
	malformed_legacy.population_recovery.available = "20"
	var malformed_legacy_validation: Dictionary = restored.validate_v5_campaign_snapshot(malformed_legacy)
	_check(not bool(malformed_legacy_validation.valid), "V13 旧档人口字段先校验类型，不通过数值转换接受非法输入")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed.population_recovery.resident_sick = 999
	var before_bad: Dictionary = restored.export_v5_campaign_snapshot()
	var rejected: Dictionary = restored.restore_v5_campaign_snapshot(malformed)
	_check(not bool(rejected.success) and restored.export_v5_campaign_snapshot() == before_bad, "非法疾病人口在应用前拒绝且不污染现状")

	var ui: Node = scene.get_node("UI/Shell")
	_check(ui.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/WellbeingBuildingShortcuts/GovernanceHousingButton") != null and ui.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/WellbeingBuildingShortcuts/GovernanceClinicButton") != null and ui.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/GovernanceEventButton") != null, "现有治理区提供民居、医舍与治安行动入口")

	scene.queue_free()
	restored_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("CITY_GOVERNANCE_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("CITY_GOVERNANCE_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
		return
	failures.append(message)


func _find_legal_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	if definition == null:
		return Vector2i(-1, -1)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			if bool(validation.get("valid", false)) and StringName(validation.get("connection_state", &"")) == &"connected":
				return cell
	return Vector2i(-1, -1)
