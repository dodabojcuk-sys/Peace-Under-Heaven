extends SceneTree


const CITY_SCENE: PackedScene = preload("res://scenes/blank_map.tscn")

var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_formal_tower_lifecycle_and_intel()
	await _check_completed_engineering_camp_is_authoritative_anchor()
	await _check_rejections_and_interruption()
	_check_snapshot_compatibility_and_strictness()
	if failures.is_empty():
		print("FIELD_WATCHTOWER_R0_SMOKE PASS assertions=%d" % assertions)
		quit(0)
		return
	for failure in failures:
		push_error("FIELD_WATCHTOWER_R0_SMOKE FAIL: %s" % failure)
	quit(1)


func _new_city() -> Dictionary:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	# This focused test owns no player save. Reset only its in-memory war loop so
	# two independent assertions cannot inherit a prior checkpoint.
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	field.patrols_by_id.clear()
	field.camps_by_id[&"camp.watchtower.test"] = {
		"camp_id": &"camp.watchtower.test", "point_id": &"camp.watchtower.test.point",
		"road_id": &"road.blackstone.northwatch.ridge", "display_name": "塔基工程驻点",
		"world_position": Vector2i(360, 610), "durability": 80, "connected": true,
	}
	return {"scene": scene, "city": city, "field": field}


func _make_engineer(city: Node) -> StringName:
	var result: Dictionary = city.dispatch_field_specialist(FieldTacticsState.SPECIALIST_ENGINEER)
	return StringName(Dictionary(result.get("specialist", {})).get("specialist_id", &""))


func _check_formal_tower_lifecycle_and_intel() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var field: FieldTacticsState = fixture.field
	var engineer_id := _make_engineer(city)
	field.patrols_by_id[&"patrol.tower.test"] = {
		"patrol_id": &"patrol.tower.test", "current_point_id": &"", "world_position": Vector2i(740, 620),
		"strength": 3, "phase": &"PATROL", "route_point_ids": [], "last_engagement": {},
	}
	field._refresh_intel()
	var before_intel: Dictionary = field.observe_subject(&"patrol.tower.test")
	var preview: Dictionary = city.preview_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	var food_before: int = int(city.food)
	var issued: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	var project: Dictionary = Dictionary(issued.get("project", {}))
	city.advance_war_loop_time(int(project.get("travel_milliseconds", 0)) + int(project.get("required_milliseconds", 0)))
	var towers: Dictionary = city.get_field_tactics_read_model().get("watchtowers_by_id", {})
	var after_intel: Dictionary = field.observe_subject(&"patrol.tower.test")
	var duplicate: Dictionary = city.preview_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	_check(
		bool(preview.get("valid", false)) and bool(issued.get("success", false))
			and towers.size() == 1 and city.food == food_before - int(preview.get("food_cost", 0))
			and StringName(before_intel.get("fog_state", &"")) == FieldTacticsState.FOG_UNOBSERVED
			and StringName(after_intel.get("fog_state", &"")) == FieldTacticsState.FOG_VISIBLE
			and not bool(duplicate.get("valid", false)),
		"工程师实际到场、完工后仅由瞭望塔新增观察范围，重复建设被拒绝"
	)
	scene.queue_free()
	await process_frame


func _check_rejections_and_interruption() -> void:
	var fixture := await _new_city()
	var scene: Node = fixture.scene
	var city: Node = fixture.city
	var field: FieldTacticsState = fixture.field
	var engineer_id := _make_engineer(city)
	var out_of_range: Dictionary = city.preview_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(900, 300))
	var water: Dictionary = city.preview_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(550, 400))
	var camp_road := Dictionary(field.roads_by_id[&"road.blackstone.northwatch.ridge"])
	camp_road.state = FieldTacticsState.ROAD_DAMAGED
	field.roads_by_id[&"road.blackstone.northwatch.ridge"] = camp_road
	var disconnected: Dictionary = city.preview_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	camp_road.state = FieldTacticsState.ROAD_OPEN
	field.roads_by_id[&"road.blackstone.northwatch.ridge"] = camp_road
	var rollback_before: Dictionary = city.export_v5_campaign_snapshot()
	var rollback_food_before := int(city.food)
	city.set_field_watchtower_fault_for_test(&"CHECKPOINT_SAVE_FAILED")
	var failed_commit: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	var checkpoint_rolled_back: bool = not bool(failed_commit.get("success", false)) \
		and int(city.food) == rollback_food_before \
		and city.export_v5_campaign_snapshot() == rollback_before
	# The failed V5 transaction restores a fresh Field object. Reacquire the
	# authority before driving the subsequent independent interruption branch.
	field = city._war_loop_state.field_tactics
	var issued: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	var project_id := StringName(Dictionary(issued.get("project", {})).get("project_id", &""))
	var engineer := Dictionary(field.specialists_by_id[engineer_id])
	engineer.alive = false
	field.specialists_by_id[engineer_id] = engineer
	city.set_city_time_paused(false)
	city.advance_war_loop_time(100)
	var interrupted := Dictionary(field.projects_by_id.get(project_id, {}))
	_check(
		not bool(out_of_range.get("valid", false)) and not bool(water.get("valid", false))
			and not bool(disconnected.get("valid", false)) and StringName(interrupted.get("phase", &"")) == &"INTERRUPTED"
			and checkpoint_rolled_back and Dictionary(field.get_snapshot().get("watchtowers_by_id", {})).is_empty(),
		"越界、水域、断开驻点道路均在预检拒绝；保存失败全回滚，工程师失去后项目中断且未获得视野"
	)
	scene.queue_free()
	await process_frame


func _check_completed_engineering_camp_is_authoritative_anchor() -> void:
	var scene := CITY_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	city.set_process(false)
	city._war_loop_state = WarLoopState.new()
	city._ensure_war_loop_initialized()
	var engineer_id := _make_engineer(city)
	var camp_project: Dictionary = city.begin_field_road_project(
		engineer_id, &"blackstone_city", &"camp.watchtower.authored", [Vector2i(135, 650), Vector2i(250, 650)], FieldTacticsState.ROAD_NORMAL, true
	)
	city.advance_war_loop_time(60000)
	var field: FieldTacticsState = city._war_loop_state.field_tactics
	var camp_id := &""
	for camp_id_value in field.camps_by_id:
		var camp: Dictionary = Dictionary(field.camps_by_id[camp_id_value])
		if StringName(camp.get("point_id", &"")) == &"camp.watchtower.authored":
			camp_id = StringName(camp_id_value)
			break
	var tower_preview: Dictionary = city.preview_field_watchtower_project(engineer_id, camp_id, Vector2i(300, 650))
	_check(
		bool(camp_project.get("success", false)) and camp_id != &"" and bool(tower_preview.get("valid", false)),
		"正式工程完工生成的运行时工程驻点可作为瞭望塔的唯一权威建设锚点"
	)
	scene.queue_free()
	await process_frame


func _check_snapshot_compatibility_and_strictness() -> void:
	var field := FieldTacticsState.new()
	field.initialize_from_theater({}, {})
	var fresh := field.get_snapshot()
	var legacy := fresh.duplicate(true)
	legacy.erase("watchtowers_by_id")
	legacy.erase("next_watchtower_sequence")
	var restored := FieldTacticsState.new()
	var legacy_ok := restored.restore_snapshot(legacy)
	var invalid := fresh.duplicate(true)
	Dictionary(invalid.watchtowers_by_id)[&"watchtower.invalid"] = {
		"watchtower_id": &"watchtower.invalid", "camp_id": &"missing", "world_position": Vector2i.ZERO,
		"visibility_range": "360", "complete": true,
	}
	var unchanged_before := field.get_snapshot()
	var invalid_ok := field.restore_snapshot(invalid)
	_check(
		legacy_ok and Dictionary(restored.get_snapshot().get("watchtowers_by_id", {})).is_empty()
			and not invalid_ok and field.get_snapshot() == unchanged_before,
		"旧 Field 快照不会补发瞭望塔；非法塔字段被严格拒绝且不污染当前状态"
	)


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
