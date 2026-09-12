extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")
const THEATER = preload("res://scripts/macro_march/macro_march_theater.gd")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	THEATER.use_playable_definition()
	call_deferred("_run")


func _run() -> void:
	await _check_real_stationed_replenishment_and_reissue()
	_check_stable_multi_formation_allocation()
	await _check_invalid_and_checkpoint_rollback()
	_check_legacy_and_strict_field_snapshots()
	if failures.is_empty():
		print("FIELD_STATIONED_REINFORCEMENT_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_STATIONED_REINFORCEMENT_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city._ensure_war_loop_initialized()
	city._war_loop_state.field_tactics.patrols_by_id.clear()
	return {"scene": scene, "city": city}


func _occupy_and_station_silverford(city: Node) -> Dictionary:
	# This keeps Silverford enemy-controlled at departure. The fixture removes
	# only patrol timing, then takes the normal Controller arrival/surrender path
	# so the local pool is unlocked by real occupation rather than a control flag.
	var roster: Array = city.get_formation_roster()
	if roster.is_empty():
		return {}
	var formation_id := StringName(Dictionary(roster.front()).get("formation_id", &""))
	var plan: Dictionary = city.plan_field_path(&"blackstone_city", &"silverford_city")
	if not bool(plan.get("valid", false)):
		return {}
	var issued: Dictionary = city.commit_macro_march_from_city([formation_id], &"silverford_city", StringName(plan.get("route_id", &"")), Array(plan.get("points", [])))
	var army: Dictionary = Dictionary(issued.get("army", {}))
	var macro: Dictionary = Dictionary(army.get("macro_march", {}))
	if army.is_empty() or macro.is_empty():
		return {}
	city.set_city_time_paused(false)
	var elapsed := 0
	while elapsed <= int(macro.get("total_millis", 0)) + 6000:
		city._process(0.1)
		elapsed += 100
		var current: Dictionary = city._army_registry.get_army(StringName(army.get("army_id", &"")))
		if StringName(current.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED:
			break
	return city._army_registry.get_army(StringName(army.get("army_id", &"")))


func _army_members(army: Dictionary) -> int:
	var total := 0
	for count in Dictionary(army.get("units_by_definition_id", {})).values():
		total += int(count)
	return total


func _create_stationed_test_army(city: Node, owner_faction_id: StringName, display_name: String, members: int) -> Dictionary:
	var formation := {
		"formation_id": StringName("formation.%s.%d" % [owner_faction_id, city.get_macro_march_armies().size() + 1]),
		"definition_id": &"infantry",
		"display_name": display_name,
		"member_count": members,
		"max_members": 20,
	}
	var army: Dictionary = city._army_registry.create_macro_march(
		owner_faction_id,
		&"silverford_city",
		&"blackstone_city",
		&"silverford_city",
		StringName("path.test.%s" % owner_faction_id),
		[Vector2i.ZERO, Vector2i(10, 0)],
		{&"infantry": members},
		[formation],
		1,
		1,
		[]
	)
	if army.is_empty():
		return {}
	return city._army_registry.advance_macro_march(
		StringName(army.get("army_id", &"")),
		StringName(Dictionary(army.get("macro_march", {})).get("order_id", &"")),
		0,
		1
	)


func _check_real_stationed_replenishment_and_reissue() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var stationed := _occupy_and_station_silverford(city)
	var army_id := StringName(stationed.get("army_id", &""))
	var members_before := _army_members(stationed)
	var stock_before := int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1))
	var preview: Dictionary = city.preview_field_stationed_replenishment(&"silverford_city", army_id)
	var applied: Dictionary = city.replenish_field_stationed_army(&"silverford_city", army_id)
	var replenished: Dictionary = city._army_registry.get_army(army_id)
	var population_after: Dictionary = city.get_population_recovery_read_model()
	var stock_after := int(Dictionary(city.get_field_tactics_read_model().get("stationed_reinforcements_by_point_id", {})).get(&"silverford_city", -1))
	var duplicate_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var legacy_recruited := duplicate_snapshot.duplicate(true)
	legacy_recruited.schema_version = 13
	legacy_recruited.erase("city_governance")
	legacy_recruited.erase("city_strategy")
	legacy_recruited.population_recovery.schema_version = 1
	legacy_recruited.population_recovery.available += int(legacy_recruited.population_recovery.medical_workers) + int(legacy_recruited.population_recovery.governance_workers)
	legacy_recruited.population_recovery.total_living -= 4
	legacy_recruited.population_recovery.erase("medical_workers")
	legacy_recruited.population_recovery.erase("governance_workers")
	for key in ["children", "elderly", "resident_sick", "unsettled_refugees", "male_count", "female_count", "unknown_sex_count", "growth_progress", "child_age_progress", "adult_age_progress", "elderly_exposure_progress", "next_birth_sequence"]:
		legacy_recruited.population_recovery.erase(key)
	var legacy_recruited_validation: Dictionary = city.validate_v5_campaign_snapshot(legacy_recruited)
	var duplicate: Dictionary = city.replenish_field_stationed_army(&"silverford_city", army_id)
	var duplicate_after_snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var onward: Dictionary = city.plan_field_path(&"silverford_city", &"redcliff_city")
	var reissued: Dictionary = city.commit_macro_march_from_station(army_id, &"redcliff_city", StringName(onward.get("route_id", &"")), Array(onward.get("points", [])))
	var moving_preview: Dictionary = city.preview_field_stationed_replenishment(&"silverford_city", army_id)
	var wrong_place_preview: Dictionary = city.preview_field_stationed_replenishment(&"blackstone_city", army_id)
	print("REINFORCEMENT_FORMAL army=%s phase=%s stock=%d->%d members=%d->%d duplicate=%s reissue=%s" % [army_id, stationed.get("phase", &""), stock_before, stock_after, members_before, _army_members(replenished), duplicate.get("success", false), reissued.get("success", false)])
	_check(
		StringName(stationed.get("phase", &"")) == ArmyRegistry.PHASE_STATIONED
			and stock_before == 4 and bool(preview.get("valid", false)) and int(preview.get("amount", 0)) == 4
			and bool(applied.get("success", false)) and _army_members(replenished) == members_before + 4 and stock_after == 0
			and int(population_after.get("total_living", 0)) == 76 and bool(population_after.get("accounted", false))
			and bool(legacy_recruited_validation.get("valid", false)) and int(legacy_recruited_validation.snapshot.population_recovery.total_living) == 76
			and int(legacy_recruited_validation.snapshot.war_loop.field_tactics.stationed_reinforcements_by_point_id[&"silverford_city"]) == 0
			and not bool(duplicate.get("success", false)) and duplicate_after_snapshot == duplicate_snapshot
			and bool(reissued.get("success", false)) and StringName(Dictionary(reissued.get("army", {})).get("phase", &"")) == ArmyRegistry.PHASE_MARCHING,
		"正式 Controller 行军到已占领银渡城后，驻军补员一次、纳入人口守恒，旧档不复兵源且可沿既有入口续令"
	)
	_check(not bool(moving_preview.get("valid", false)) and not bool(wrong_place_preview.get("valid", false)), "在途军队或错误地点不能绕过驻军补员资格")
	scene.queue_free()
	await process_frame


func _check_stable_multi_formation_allocation() -> void:
	var registry := ArmyRegistry.new()
	var formations: Array = [
		{"formation_id": &"formation.alpha", "definition_id": &"infantry", "display_name": "甲队", "member_count": 19, "max_members": 20},
		{"formation_id": &"formation.beta", "definition_id": &"infantry", "display_name": "乙队", "member_count": 17, "max_members": 20},
	]
	var army := registry.create_macro_march(&"player", &"blackstone_city", &"blackstone_city", &"silverford_city", &"path.test", [Vector2i.ZERO, Vector2i(10, 0)], {&"infantry": 36}, formations, 1, 1, [])
	registry.advance_macro_march(StringName(army.get("army_id", &"")), StringName(Dictionary(army.get("macro_march", {})).get("order_id", &"")), 0, 1)
	var preview := registry.preview_stationed_reinforcement(StringName(army.get("army_id", &"")), &"silverford_city", 4)
	var allocation: Array = Array(preview.get("allocation", []))
	var applied := registry.replenish_stationed_army(StringName(army.get("army_id", &"")), &"silverford_city", allocation)
	var final_formations: Array = Array(Dictionary(applied.get("macro_march", {})).get("formation_snapshots", []))
	var full_preview: Dictionary = registry.preview_stationed_reinforcement(StringName(army.get("army_id", &"")), &"silverford_city", 1)
	_check(
		bool(preview.get("valid", false)) and int(preview.get("amount", 0)) == 4
			and int(Dictionary(allocation[0]).get("added", -1)) == 1 and int(Dictionary(allocation[1]).get("added", -1)) == 3
			and int(Dictionary(final_formations[0]).get("member_count", -1)) == 20 and int(Dictionary(final_formations[1]).get("member_count", -1)) == 20
			and not bool(full_preview.get("valid", false)),
		"多编队按稳定 formation_id 顺序分配，预览与 ArmyRegistry 提交使用同一容量结果"
	)


func _check_invalid_and_checkpoint_rollback() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var enemy_controlled: Dictionary = city.preview_field_stationed_replenishment(&"silverford_city", &"army.player.999999")
	var stationed := _occupy_and_station_silverford(city)
	var army_id := StringName(stationed.get("army_id", &""))
	var enemy_stationed := _create_stationed_test_army(city, &"river_lords", "河主卫队", 7)
	var enemy_army_id := StringName(enemy_stationed.get("army_id", &""))
	var enemy_before := {
		"field": city._war_loop_state.field_tactics.get_snapshot(),
		"armies": city._army_registry.get_snapshot(),
		"population": city._population_recovery.get_snapshot(),
		"resources": city.get_nation_state().get_shared_resources(),
	}
	var enemy_preview: Dictionary = city.preview_field_stationed_replenishment(&"silverford_city", enemy_army_id)
	var enemy_commit: Dictionary = city.replenish_field_stationed_army(&"silverford_city", enemy_army_id)
	var enemy_after := {
		"field": city._war_loop_state.field_tactics.get_snapshot(),
		"armies": city._army_registry.get_snapshot(),
		"population": city._population_recovery.get_snapshot(),
		"resources": city.get_nation_state().get_shared_resources(),
	}
	var wrong_army: Dictionary = city.preview_field_stationed_replenishment(&"silverford_city", &"army.player.999999")
	scene.queue_free()
	await process_frame
	fixture = await _new_city()
	scene = fixture.scene
	city = fixture.city
	stationed = _occupy_and_station_silverford(city)
	army_id = StringName(stationed.get("army_id", &""))
	var before: Dictionary = city.export_v5_campaign_snapshot()
	city.set_field_reinforcement_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var save_failure: Dictionary = city.replenish_field_stationed_army(&"silverford_city", army_id)
	var after_failure: Dictionary = city.export_v5_campaign_snapshot()
	_check(
		not bool(enemy_controlled.get("valid", false)) and not bool(enemy_preview.get("valid", false)) and not bool(enemy_commit.get("success", false))
			and enemy_before == enemy_after and not bool(wrong_army.get("valid", false)) and not bool(save_failure.get("success", false))
			and before == after_failure,
		"未占领地点、非我方驻军、错误驻军和关键保存失败都不扣地点兵源、不增加编队且完整回滚"
	)
	scene.queue_free()
	await process_frame


func _check_legacy_and_strict_field_snapshots() -> void:
	var field := FieldTacticsState.new()
	field.initialize_from_theater(THEATER.get_points(), THEATER.get_routes(), THEATER.get_water_regions(), Rect2i(THEATER.get_world_bounds()), THEATER.get_terrain_regions(), THEATER.get_patrol_configs(), THEATER.get_scout_visibility_range())
	var fresh := field.get_snapshot()
	var legacy := fresh.duplicate(true)
	legacy.erase("stationed_reinforcements_by_point_id")
	legacy.erase("watchtowers_by_id")
	legacy.erase("next_watchtower_sequence")
	var restored := FieldTacticsState.new()
	var legacy_ok := restored.restore_snapshot(legacy)
	restored.initialize_from_theater(THEATER.get_points(), THEATER.get_routes(), THEATER.get_water_regions(), Rect2i(THEATER.get_world_bounds()), THEATER.get_terrain_regions(), THEATER.get_patrol_configs(), THEATER.get_scout_visibility_range())
	var invalid := fresh.duplicate(true)
	Dictionary(invalid.stationed_reinforcements_by_point_id)[&"silverford_city"] = "4"
	var untouched_before := field.get_snapshot()
	var invalid_ok := field.restore_snapshot(invalid)
	_check(
		legacy_ok and restored.get_stationed_reinforcements(&"silverford_city") == 0
			and not invalid_ok and field.get_snapshot() == untouched_before,
		"旧 Field 快照不补发驻军兵源；非法兵源类型被严格拒绝且不污染现有状态"
	)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
