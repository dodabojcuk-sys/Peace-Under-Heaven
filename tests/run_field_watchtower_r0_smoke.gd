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
	await _check_completion_contact_order_and_checkpoint_rollback()
	await _check_formal_v5_snapshot_compatibility_and_strictness()
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
	# A focused watchtower fixture must not inherit the startup shell's resource
	# state. Resetting the test scene before replacing Field authority gives every
	# branch the same playable roster and food transaction preconditions.
	city.restart_first_map()
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
	field.camps_by_id[&"camp.watchtower.neighbor"] = {
		"camp_id": &"camp.watchtower.neighbor", "point_id": &"camp.watchtower.neighbor.point",
		"road_id": &"road.blackstone.northwatch.ridge", "display_name": "相邻工程驻点",
		"world_position": Vector2i(380, 610), "durability": 80, "connected": true,
	}
	var second_engineer_id := _make_engineer(city)
	var occupied_preview: Dictionary = city.preview_field_watchtower_project(second_engineer_id, &"camp.watchtower.neighbor", Vector2i(435, 620))
	var engineer := Dictionary(field.specialists_by_id[engineer_id])
	engineer.alive = false
	field.specialists_by_id[engineer_id] = engineer
	city.set_city_time_paused(false)
	city.advance_war_loop_time(100)
	var interrupted := Dictionary(field.projects_by_id.get(project_id, {}))
	_check(
		not bool(out_of_range.get("valid", false)) and not bool(water.get("valid", false))
		and not bool(disconnected.get("valid", false)) and StringName(interrupted.get("phase", &"")) == &"INTERRUPTED"
			and checkpoint_rolled_back and not bool(occupied_preview.get("valid", false))
			and Dictionary(field.get_snapshot().get("watchtowers_by_id", {})).is_empty(),
		"越界、水域、断开道路与在建塔占位均在预检拒绝；保存失败全回滚，工程师失去后项目中断且未获得视野"
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


func _check_completion_contact_order_and_checkpoint_rollback() -> void:
	var pre_contact := await _new_city()
	var pre_city: Node = pre_contact.city
	var pre_field: FieldTacticsState = pre_contact.field
	var pre_project := _prepare_almost_completed_tower(pre_city, pre_field)
	var work_position := Vector2i(pre_project.get("work_world_position", Vector2i.ZERO))
	pre_field.patrols_by_id[&"patrol.watchtower.pre"] = {
		"patrol_id": &"patrol.watchtower.pre", "current_point_id": &"", "world_position": work_position,
		"strength": 3, "phase": &"PATROL", "route_point_ids": [], "last_engagement": {},
	}
	var pre_advance := pre_field.advance_world(200)
	var pre_after := Dictionary(pre_field.projects_by_id.get(StringName(pre_project.get("project_id", &"")), {}))
	var no_early_tower := Dictionary(pre_field.watchtowers_by_id).is_empty() \
		and StringName(pre_after.get("phase", &"")) == &"INTERRUPTED" \
		and int(pre_after.get("progress_milliseconds", -1)) < int(pre_after.get("required_milliseconds", 0)) \
		and Array(pre_advance.get("completed_project_ids", [])).is_empty()
	pre_contact.scene.queue_free()
	await process_frame

	var post_contact := await _new_city()
	var post_city: Node = post_contact.city
	var post_field: FieldTacticsState = post_contact.field
	var post_project := _prepare_almost_completed_tower(post_city, post_field)
	var post_work_position := Vector2i(post_project.get("work_world_position", Vector2i.ZERO))
	var patrol_start := post_work_position + Vector2i(-100, 0)
	post_field.point_positions_by_id[&"patrol.watchtower.post.start"] = patrol_start
	post_field.point_positions_by_id[&"patrol.watchtower.post.end"] = post_work_position
	post_field.patrols_by_id[&"patrol.watchtower.post"] = {
		"patrol_id": &"patrol.watchtower.post", "current_point_id": &"patrol.watchtower.post.start", "world_position": patrol_start,
		"strength": 3, "phase": &"PATROL", "route_point_ids": [&"patrol.watchtower.post.start", &"patrol.watchtower.post.end"],
		"target_route_index": 1, "wait_remaining_milliseconds": 0, "move_start_position": patrol_start,
		"move_route_world_points": [patrol_start, post_work_position], "move_elapsed_milliseconds": 0,
		"move_total_milliseconds": 200, "last_engagement": {},
	}
	post_field.advance_world(200)
	var post_after := Dictionary(post_field.projects_by_id.get(StringName(post_project.get("project_id", &"")), {}))
	var tower_survives_late_contact := post_field.watchtowers_by_id.size() == 1 \
		and StringName(post_after.get("phase", &"")) == &"COMPLETE"
	post_contact.scene.queue_free()
	await process_frame

	var rollback_fixture := await _new_city()
	var rollback_city: Node = rollback_fixture.city
	var rollback_field: FieldTacticsState = rollback_fixture.field
	var rollback_project := _prepare_almost_completed_tower(rollback_city, rollback_field)
	var rollback_before: Dictionary = rollback_city.export_v5_campaign_snapshot()
	rollback_city.set_field_watchtower_fault_for_test(&"COMPLETION_CHECKPOINT_SAVE_FAILED")
	var failed_completion: Dictionary = rollback_city.advance_war_loop_time(200)
	var rollback_field_after: FieldTacticsState = rollback_city._war_loop_state.field_tactics
	var completion_rolled_back: bool = not bool(failed_completion.get("success", true)) \
		and rollback_city.export_v5_campaign_snapshot() == rollback_before \
		and rollback_field_after.watchtowers_by_id.is_empty()
	rollback_city.advance_war_loop_time(200)
	var completion_retried_once: bool = rollback_city._war_loop_state.field_tactics.watchtowers_by_id.size() == 1
	_check(
		no_early_tower and tower_survives_late_contact and completion_rolled_back and completion_retried_once,
		"同一步接触按发生时刻决定瞭望塔完成；完工检查点失败完整回滚且重试只创建一座塔"
	)
	rollback_fixture.scene.queue_free()
	await process_frame


func _prepare_almost_completed_tower(city: Node, field: FieldTacticsState) -> Dictionary:
	var engineer_id := _make_engineer(city)
	var issued: Dictionary = city.begin_field_watchtower_project(engineer_id, &"camp.watchtower.test", Vector2i(430, 620))
	var project: Dictionary = Dictionary(issued.get("project", {}))
	var project_id := StringName(project.get("project_id", &""))
	project.phase = &"BUILDING"
	project.progress_milliseconds = maxi(int(project.get("required_milliseconds", 1)) - 100, 0)
	project.travel_milliseconds = 0
	field.projects_by_id[project_id] = project
	var engineer := Dictionary(field.specialists_by_id.get(engineer_id, {}))
	engineer.phase = FieldTacticsState.SPECIALIST_BUILDING
	engineer.project_id = project_id
	engineer.world_position = Vector2i(project.get("work_world_position", Vector2i.ZERO))
	engineer.target_world_position = engineer.world_position
	engineer.move_total_milliseconds = 0
	engineer.move_remaining_milliseconds = 0
	field.specialists_by_id[engineer_id] = engineer
	return project


func _check_formal_v5_snapshot_compatibility_and_strictness() -> void:
	var source := await _new_city()
	var city: Node = source.city
	var snapshot: Dictionary = city.export_v5_campaign_snapshot()
	var legacy_results: Array[bool] = []
	for field_keys_to_remove in [
		["supply_inventory_by_point_id", "supply_transports_by_id", "next_supply_transport_sequence", "stationed_reinforcements_by_point_id", "watchtowers_by_id", "next_watchtower_sequence"],
		["stationed_reinforcements_by_point_id", "watchtowers_by_id", "next_watchtower_sequence"],
		["watchtowers_by_id", "next_watchtower_sequence"],
	]:
		var legacy_snapshot: Dictionary = snapshot.duplicate(true)
		var legacy_field: Dictionary = Dictionary(legacy_snapshot.war_loop.field_tactics)
		for key_value in field_keys_to_remove:
			legacy_field.erase(StringName(key_value))
		legacy_snapshot.war_loop.field_tactics = legacy_field
		var restored_fixture := await _new_city()
		var restored_city: Node = restored_fixture.city
		var restored_result: Dictionary = restored_city.restore_v5_campaign_snapshot(legacy_snapshot)
		var restored_field: Dictionary = Dictionary(restored_city.get_field_tactics_read_model())
		legacy_results.append(bool(restored_result.get("success", false)) and Dictionary(restored_field.get("watchtowers_by_id", {})).is_empty())
		restored_fixture.scene.queue_free()
		await process_frame
	var field := FieldTacticsState.new()
	field.initialize_from_theater({}, {})
	var fresh := field.get_snapshot()
	var invalid := fresh.duplicate(true)
	Dictionary(invalid.watchtowers_by_id)[&"watchtower.000001"] = {
		"watchtower_id": &"watchtower.000001", "camp_id": &"missing", "world_position": Vector2i.ZERO,
		"visibility_range": "360", "complete": true,
	}
	var unchanged_before := field.get_snapshot()
	var invalid_ok := field.restore_snapshot(invalid)
	var collision := fresh.duplicate(true)
	Dictionary(collision.watchtowers_by_id)[&"watchtower.000001"] = {
		"watchtower_id": &"watchtower.000001", "camp_id": &"camp.compat", "world_position": Vector2i(20, 20),
		"visibility_range": 360, "complete": true,
	}
	Dictionary(collision.camps_by_id)[&"camp.compat"] = {"camp_id": &"camp.compat", "road_id": &"road.compat"}
	Dictionary(collision.roads_by_id)[&"road.compat"] = {"road_id": &"road.compat", "state": FieldTacticsState.ROAD_OPEN}
	collision.next_watchtower_sequence = 1
	var collision_ok := FieldTacticsState.new().restore_snapshot(collision)
	var orphaned_tower := collision.duplicate(true)
	orphaned_tower.next_watchtower_sequence = 2
	var orphaned_tower_ok := FieldTacticsState.new().restore_snapshot(orphaned_tower)
	_check(
		legacy_results.all(func(value: bool) -> bool: return value)
			and not invalid_ok and field.get_snapshot() == unchanged_before and not collision_ok and not orphaned_tower_ok,
		"正式 V5 入口兼容 11/14/15 字段 Field 快照；非法塔字段、塔序号碰撞和脱离所属工程的完成塔均拒绝且不污染当前状态"
	)
	source.scene.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	assertions += 1
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
