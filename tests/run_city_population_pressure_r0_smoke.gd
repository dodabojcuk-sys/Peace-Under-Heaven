extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	await _check_normal_growth_and_refugees()
	await _check_refugee_waiting_and_terminal_decisions()
	await _check_long_horizon_age_boundaries()
	await _check_pressure_escalation_and_shared_care()
	await _check_v15_migration()
	if failures.is_empty():
		print("CITY_POPULATION_PRESSURE_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("CITY_POPULATION_PRESSURE_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city.restart_first_map()
	return {"scene": scene, "city": city}


func _check_normal_growth_and_refugees() -> void:
	var fixture := await _new_city()
	var city: Node = fixture.city
	var initial: Dictionary = city.get_population_recovery_read_model()
	_check(int(initial.children) == 0 and int(initial.elderly) == 0 and int(initial.unknown_sex_count) == 72 and int(initial.adults) == 72 and bool(initial.accounted), "新局年龄与性别是可解释的正交聚合；未知历史不被伪造")
	_check(bool(city.start_build_project(&"building.housing.t1").success), "民居从正式单槽城建入口开工")
	city.advance_city_time_for_test(180.0)
	_check(city.get_build_slot_state() == city.BUILD_SLOT_READY_TO_PLACE and int(city.get_population_recovery_read_model().total_living) == 72, "施工完成只产生待放置民居，不在建房或日结时补满人口")
	var cell := _find_legal_cell(city, &"building.housing.t1")
	var screen_position: Vector2 = _cell_center(city, cell)
	city.activate_ready_placement(screen_position)
	for _attempt in range(6):
		city.update_preview(screen_position)
		if city.preview_origin_cell == cell:
			break
		screen_position += _cell_center(city, cell) - _cell_center(city, city.preview_origin_cell)
	var placed: Dictionary = city.commit_building_from_map_click(screen_position)
	_check(bool(placed.success) and city.get_city_housing_capacity() == 88 and int(city.get_population_recovery_read_model().total_living) == 72, "已付款民居通过正式地图放置后仅增加住房容量")
	while city.current_day < 6:
		_check(city._advance_day_boundary(true), "正式城市日边界累计人口增长")
	var born: Dictionary = city.get_population_recovery_read_model()
	_check(int(born.total_living) == 73 and int(born.children) == 1 and int(born.available) == 20 and int(born.male_count) + int(born.female_count) == 1 and city.last_daily_report.contains("出生"), "住房、粮食与健康满足后出生一次进入儿童组，不成为劳动力")
	var governance: Dictionary = city.get_city_governance_read_model()
	var case_id := &"refugee.blackstone.northroad.001"
	var arrived: Dictionary = Dictionary(Dictionary(governance.refugee_cases_by_id).get(case_id, {}))
	_check(StringName(arrived.phase) == &"PENDING" and int(arrived.count) == 9 and StringName(arrived.source_event_id) == &"invasion.blackstone.001", "难民以稳定战役来源和有限人数抵达一次")
	var ui: Node = fixture.scene.get_node("UI/Shell")
	ui._refresh_governance_workspace()
	var refugee_actions: VBoxContainer = ui.get_node("GovernanceWorkspace/GovernanceMargin/GovernanceScroll/GovernanceContent/RefugeeActions")
	_check(refugee_actions.get_child_count() > 0 and StringName(Dictionary(city.get_city_governance_read_model().refugee_cases_by_id)[case_id].phase) == &"PENDING", "浏览人口与难民详情只显示来源、人数和压力，不推进或领取人口")
	var accepted: Dictionary = city.decide_refugee_case(case_id, &"ACCEPT")
	var waiting: Dictionary = city.get_population_recovery_read_model()
	_check(bool(accepted.success) and int(waiting.total_living) == 82 and int(waiting.unsettled_refugees) == 9 and int(waiting.available) == 20 and bool(waiting.accounted), "接纳只增加一次人口并留在待安置组，不同时成为工人或兵源")
	_check(not bool(city.decide_refugee_case(case_id, &"ACCEPT").success) and int(city.get_population_recovery_read_model().total_living) == 82, "重复接纳不重复领取人口")
	var settled: Dictionary = city.settle_refugee_case(case_id)
	var after_settlement: Dictionary = city.get_population_recovery_read_model()
	_check(bool(settled.success) and int(after_settlement.unsettled_refugees) == 0 and int(after_settlement.available) == 27 and int(after_settlement.resident_sick) == 2 and bool(after_settlement.accounted), "住房覆盖后正式安置把健康成年人转为劳动力，并把两名病患交给既有疾病医疗状态")
	var training: Dictionary = city.request_training()
	_check(bool(training.success) and int(city.get_population_recovery_read_model().training_reserved) == 5, "安置完成的人口可沿既有正式训练预留进入战争流程")
	fixture.scene.queue_free()
	await process_frame


func _check_refugee_waiting_and_terminal_decisions() -> void:
	var fixture := await _new_city()
	var city: Node = fixture.city
	while city.current_day < 6:
		_check(city._advance_day_boundary(true), "无住房增长空间时仍可推进到来源明确的难民事件")
	var case_id := &"refugee.blackstone.northroad.001"
	_check(bool(city.decide_refugee_case(case_id, &"DEFER").success), "暂缓保留同一来源、人数与稳定事件身份")
	_check(bool(city.decide_refugee_case(case_id, &"ACCEPT").success), "暂缓后仍可明确接纳一次")
	var failed_settlement: Dictionary = city.settle_refugee_case(case_id)
	var waiting_population: Dictionary = city.get_population_recovery_read_model()
	var waiting_case: Dictionary = Dictionary(city.get_city_governance_read_model().refugee_cases_by_id[case_id])
	_check(not bool(failed_settlement.success) and str(failed_settlement.error).contains("住房不足") and StringName(waiting_case.phase) == &"WAITING_HOUSING" and int(waiting_population.unsettled_refugees) == 9 and int(waiting_population.available) == 20 and int(waiting_population.total_living) == 81, "住房不足时明确保持等待；待安置人口不占岗位、劳动力或训练兵源")
	fixture.scene.queue_free()
	await process_frame

	var reject_fixture := await _new_city()
	var reject_city: Node = reject_fixture.city
	while reject_city.current_day < 6:
		reject_city._advance_day_boundary(true)
	_check(bool(reject_city.decide_refugee_case(case_id, &"REJECT").success) and int(reject_city.get_population_recovery_read_model().total_living) == 72 and StringName(Dictionary(reject_city.get_city_governance_read_model().refugee_cases_by_id[case_id]).phase) == &"REJECTED", "拒绝关闭有限来源且不增加人口或临时生成夸大惩罚")
	reject_fixture.scene.queue_free()
	await process_frame


func _check_pressure_escalation_and_shared_care() -> void:
	var fixture := await _new_city()
	var city: Node = fixture.city
	city.city_security = 40
	city.food = 80
	_check(city._advance_day_boundary(true), "低治安通过正式日结开始累积压力")
	_check(city._advance_day_boundary(true) and StringName(Dictionary(city.get_city_governance_read_model().active_event).phase) == &"IDLE" and str(city.get_city_governance_read_model().active_issue).contains("治安压力正在累积"), "低治安先提供可理解预警，不立即跳到库存损失")
	var food_before_theft := int(city.food)
	_check(city._advance_day_boundary(true), "持续低治安达到事件阈值后再形成具体事件")
	var theft: Dictionary = city.get_city_governance_read_model()
	_check(StringName(Dictionary(theft.active_event).kind) == &"PETTY_THEFT" and bool(Dictionary(theft.active_event).consequence_applied) and int(city.food) == food_before_theft - city.get_maintenance_food_cost() - 2, "轻微盗窃命中粮食库存并在同一稳定事件阶段只扣一次")
	var food_after_theft := int(city.food)
	city._apply_city_governance_event_consequence()
	_check(int(city.food) == food_after_theft, "刷新或重复后果入口不会再次扣除盗窃损失")
	city.food = 0
	while int(city.get_city_governance_read_model().pressure_points) < 60:
		_check(city._advance_day_boundary(true), "持续短缺累积社会压力")
	var bandit: Dictionary = city.get_city_governance_read_model()
	_check(StringName(Dictionary(bandit.active_event).kind) == &"BANDIT_DISRUPTION" and city.get_workforce_modifier_permille(&"production") < 1000, "持续压力把同一事件升级为针对生产的土匪干扰，而非重复盗窃")
	city._advance_day_boundary(true)
	city._advance_day_boundary(true)
	var unrest: Dictionary = city.get_city_governance_read_model()
	_check(StringName(Dictionary(unrest.active_event).kind) == &"LOCAL_UNREST" and city.get_workforce_modifier_permille(&"production") == 0 and city.get_workforce_modifier_permille(&"construction") == 0, "长期不处理的严重压力升级为局部停工，不改写主城控制权或生成无来源守城战")
	var pressure_before := int(unrest.pressure_points)
	city.food = 20
	var resolved: Dictionary = city.resolve_city_governance_event()
	_check(bool(resolved.success) and int(city.get_city_governance_read_model().pressure_points) < pressure_before and int(city.food) == 18, "治理人员与明确粮食成本只处置当前事件并降低部分压力")
	var recovery_housing_cell := _find_legal_cell(city, &"building.housing.t1")
	city.place_definition_at_cell(&"building.housing.t1", recovery_housing_cell, false, true)
	city.food = 100
	for _day in range(16):
		if int(city.get_city_governance_read_model().pressure_points) <= 0:
			break
		city._advance_day_boundary(true)
		if StringName(Dictionary(city.get_city_governance_read_model().active_event).phase) == &"ACTIVE":
			city.resolve_city_governance_event()
	var recovered_governance: Dictionary = city.get_city_governance_read_model()
	_check(int(recovered_governance.pressure_points) == 0 and int(recovered_governance.housing_shortfall) == 0 and StringName(Dictionary(recovered_governance.active_event).phase) == &"IDLE" and city.get_workforce_modifier_permille(&"production") > 0, "补足粮食、建设住房并逐日处置具体事件后压力归零，生产恢复；单次按钮没有跳过经营原因")
	city.food = 100
	city._population_recovery.wounded = 2
	city._population_recovery.available -= 2
	_check(bool(city.begin_wounded_treatment().success), "伤员治疗正式占用同一医疗容量")
	city._population_recovery.record_sickness(4)
	var sick_before: int = city._population_recovery.resident_sick
	city._advance_day_boundary(true)
	_check(city._population_recovery.resident_sick == sick_before - 2, "活动伤员批次先占两格容量，病患只使用剩余两格而非第二套完整容量")
	fixture.scene.queue_free()
	await process_frame


func _check_long_horizon_age_boundaries() -> void:
	var fixture := await _new_city()
	var city: Node = fixture.city
	var military_before: int = city.get_population_recovery_read_model().military
	city._population_recovery.record_birth()
	city._population_recovery.child_age_progress = city.CITY_GOVERNANCE_RULES.child_maturation_person_days - 1
	city._advance_city_demography(false, 0)
	var matured: Dictionary = city.get_population_recovery_read_model()
	_check(int(matured.children) == 0 and int(matured.available) == 21 and int(matured.military) == military_before, "长期加速边界使儿童转为可用成年人，不改写驻军或外派身份")
	city._population_recovery.adult_age_progress = city.CITY_GOVERNANCE_RULES.adult_ageing_person_days - city._population_recovery.available
	city._advance_city_demography(false, 0)
	var aged: Dictionary = city.get_population_recovery_read_model()
	_check(int(aged.elderly) == 1 and int(aged.available) == 20 and int(aged.military) == military_before, "成年人老化只从城内可用组迁移，不让行军或战斗人员消失")
	city.current_day = 10
	city._city_governance.consecutive_housing_pressure_days = city.CITY_GOVERNANCE_RULES.cold_consequence_trigger_days
	city._population_recovery.elderly_exposure_progress = city.CITY_GOVERNANCE_RULES.elderly_exposure_person_days - 1
	city._advance_city_demography(false, -1)
	var exposed: Dictionary = city.get_population_recovery_read_model()
	_check(int(exposed.elderly) == 0 and int(exposed.fallen) == 1 and int(exposed.total_living) == 72 and int(exposed.military) == military_before, "冬季持续暴露达到已配置阈值后才记录老年死亡，死亡不会进入治疗")
	fixture.scene.queue_free()
	await process_frame


func _check_v15_migration() -> void:
	var fixture := await _new_city()
	var city: Node = fixture.city
	var legacy: Dictionary = city.export_v5_campaign_snapshot()
	legacy.schema_version = 15
	for key in ["children", "elderly", "resident_sick", "unsettled_refugees", "male_count", "female_count", "unknown_sex_count", "growth_progress", "child_age_progress", "adult_age_progress", "elderly_exposure_progress", "next_birth_sequence"]:
		legacy.population_recovery.erase(key)
	legacy.population_recovery.schema_version = 2
	legacy.city_governance = {
		"schema_version": 1, "health_permille": 900, "diseased_count": 2,
		"consecutive_food_shortage_days": 2, "consecutive_housing_pressure_days": 0,
		"last_applied_day": 1, "next_event_sequence": 1,
		"active_event": {"event_id": &"", "phase": &"IDLE", "kind": &"", "started_day": 0},
		"resolved_event_ids": {},
	}
	var result: Dictionary = city.validate_v5_campaign_snapshot(legacy)
	var migrated: Dictionary = Dictionary(result.get("snapshot", {}))
	_check(bool(result.valid) and int(migrated.schema_version) == 16 and int(migrated.population_recovery.total_living) == 72 and int(migrated.population_recovery.resident_sick) == 2 and int(migrated.population_recovery.unknown_sex_count) == 72 and int(migrated.population_recovery.available) == 18, "V15 旧档保留总数与岗位，将已知病患从可用成年人迁出并把未知性别明确标记")
	var malformed_current: Dictionary = city.export_v5_campaign_snapshot()
	malformed_current.city_governance.active_event.event_id = ""
	_check(not bool(city.validate_v5_campaign_snapshot(malformed_current).valid), "当前治理快照严格拒绝伪装为稳定 ID 的普通字符串字段")
	fixture.scene.queue_free()
	await process_frame


func _find_legal_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: Resource = city.get_definition(definition_id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = city.evaluate_origin_cell_for_definition(cell, definition, false, false, 0)
			var point := _cell_center(city, cell)
			var viewport_size: Vector2 = city.get_viewport().get_visible_rect().size
			if bool(validation.get("valid", false)) and StringName(validation.get("connection_state", &"")) == &"connected" and Rect2(Vector2(260.0, 120.0), Vector2(viewport_size.x - 620.0, viewport_size.y - 160.0)).has_point(point) and not city.is_construction_ui_point(point):
				return cell
	return Vector2i(-1, -1)


func _cell_center(city: Node, cell: Vector2i) -> Vector2:
	return city.map_local_to_screen(city.cell_to_map_local(cell) + Vector2(40.0, 40.0))


func _check(condition: bool, message: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		failures.append(message)
