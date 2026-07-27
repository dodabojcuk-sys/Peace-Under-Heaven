extends SceneTree


var failures: Array[String] = []
var fault_controller: Node
var fault_occupied_cell := Vector2i.ZERO
var fault_release_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "主场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var source_scene := packed_scene.instantiate()
	var restored_scene := packed_scene.instantiate()
	root.add_child(source_scene)
	root.add_child(restored_scene)
	await process_frame
	await process_frame
	var source: Node = source_scene.get_node("ConstructionController")
	var restored: Node = restored_scene.get_node("ConstructionController")
	source.set_city_time_paused(true)
	restored.set_city_time_paused(true)

	var road_cells := [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
	]
	for cell in road_cells:
		_check(
			source.place_definition_at_cell(
				&"building.road.t1",
				cell
			) > 0,
			"源分支道路 %s 放置成功" % cell
		)
	var logging_id: int = source.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7)
	)
	_check(logging_id > 0, "源分支伐木场放置成功")
	_check(source.queue_training(), "源分支建立一批征募队列")
	source.day_elapsed_seconds = 37.5

	var source_snapshot: Dictionary = source.export_early_city_snapshot()
	_check(not source_snapshot.is_empty(), "可以导出早期城市权威快照")
	var validation: Dictionary = source.validate_early_city_snapshot(
		source_snapshot
	)
	_check(bool(validation.valid), "控制器完整校验自身导出的快照")
	_check(
		source_snapshot.schema_version == 1
			and source_snapshot.snapshot_kind
				== &"early_city_authoritative"
			and source_snapshot.city_id == "blackstone_city",
		"快照具有明确版本、类型和稳定城市身份"
	)
	_check(
		not source_snapshot.city.has("wood_capacity")
			and not source_snapshot.city.has("day_progress_ratio")
			and not source_snapshot.city.has("last_daily_report")
			and not source_snapshot.city.has("last_daily_breakdown")
			and not source_snapshot.city.has("enemy_count")
			and not source_snapshot.city.has("enemy_fortification"),
		"快照不保存容量、威胁投影、进度比例或日报等派生字段"
	)
	_check(
		not source_snapshot.has("occupied_cells")
			and not source_snapshot.has("connected_road_cells")
			and not source_snapshot.has("ui_state")
			and not source_snapshot.has("battle_state"),
		"快照不保存占用缓存、路网缓存、UI 或战斗状态"
	)
	for placement in source_snapshot.placements:
		_check(
			not placement.has("node")
				and not placement.has("footprint")
				and not placement.has("selection_bounds")
				and not placement.has("operational_state"),
			"placement %d 只保存稳定源字段" % int(
				placement.placement_id
			)
		)

	var divergent_id: int = restored.place_definition_at_cell(
		&"building.road.t1",
		Vector2i(20, 20),
		false
	)
	_check(divergent_id > 0, "恢复分支先建立可识别的旧状态")
	restored.wood = 3
	restored.food = 4
	var restore_result: Dictionary = (
		restored.restore_early_city_snapshot(source_snapshot)
	)
	_check(bool(restore_result.success), "有效快照可以原子恢复")
	var restored_snapshot: Dictionary = restored.export_early_city_snapshot()
	_check(
		_snapshots_equal(source_snapshot, restored_snapshot),
		"恢复后的全部权威源字段与源分支一致"
	)
	_check(
		restored.get_occupied_cell_count()
			== source.get_occupied_cell_count()
			and restored.get_connected_road_cells().keys()
				== source.get_connected_road_cells().keys(),
		"占用表和道路连通从 placement 重新派生"
	)
	_check(
		restored.get_operational_status(logging_id).state
			== source.get_operational_status(logging_id).state,
		"建筑运行状态从施工和道路源字段重新派生"
	)
	_check(
		restored.get_resource_capacity(&"wood")
			== source.get_resource_capacity(&"wood")
			and restored.get_resource_capacity(&"food")
				== source.get_resource_capacity(&"food"),
		"资源容量从建筑记录重新派生"
	)

	var expected_next_id := int(source_snapshot.next_placement_id)
	var source_next_id: int = source.place_definition_at_cell(
		&"building.road.t1",
		Vector2i(20, 20),
		false
	)
	var restored_next_id: int = restored.place_definition_at_cell(
		&"building.road.t1",
		Vector2i(20, 20),
		false
	)
	_check(
		source_next_id == expected_next_id
			and restored_next_id == expected_next_id,
		"next_placement_id 恢复后保持单调且不冲突"
	)

	_check(
		source.advance_one_day_for_test()
			and restored.advance_one_day_for_test(),
		"源分支与恢复分支都可以继续一次日结算"
	)
	_check(
		_snapshots_equal(
			source.export_early_city_snapshot(),
			restored.export_early_city_snapshot()
		),
		"恢复分支与未恢复分支继续日结算后权威状态一致"
	)
	_check(
		source.get_last_daily_breakdown()
			== restored.get_last_daily_breakdown()
			and source.get_city_state().wood_capacity
				== restored.get_city_state().wood_capacity
			and source.get_city_state().construction_in_progress
				== restored.get_city_state().construction_in_progress,
		"日结算明细与关键派生结果也保持一致"
	)

	var stable_before_failures: Dictionary = (
		restored.export_early_city_snapshot()
	)
	var projection_before_failures := _capture_projection(restored)
	var invalid_snapshots: Array[Dictionary] = []
	var invalid_descriptions: Array[String] = []
	var missing_field := stable_before_failures.duplicate(true)
	missing_field.city.erase("wood")
	invalid_snapshots.append(missing_field)
	invalid_descriptions.append("缺失字段")
	var wrong_type := stable_before_failures.duplicate(true)
	wrong_type.city.wood = "invalid"
	invalid_snapshots.append(wrong_type)
	invalid_descriptions.append("字段类型错误")
	var duplicate_id := stable_before_failures.duplicate(true)
	duplicate_id.placements.append(
		duplicate_id.placements[0].duplicate(true)
	)
	invalid_snapshots.append(duplicate_id)
	invalid_descriptions.append("重复 placement ID")
	var overlapping := stable_before_failures.duplicate(true)
	overlapping.placements[-1].origin_cell = (
		overlapping.placements[0].origin_cell
	)
	invalid_snapshots.append(overlapping)
	invalid_descriptions.append("占用格冲突")
	var unknown_definition := stable_before_failures.duplicate(true)
	unknown_definition.placements[0].definition_id = &"building.unknown"
	invalid_snapshots.append(unknown_definition)
	invalid_descriptions.append("未知建筑定义")
	var impossible_capacity := stable_before_failures.duplicate(true)
	impossible_capacity.city.wood = 9999
	invalid_snapshots.append(impossible_capacity)
	invalid_descriptions.append("资源超出可派生容量")
	var invalid_next_id := stable_before_failures.duplicate(true)
	invalid_next_id.next_placement_id = int(
		invalid_next_id.placements[0].placement_id
	)
	invalid_snapshots.append(invalid_next_id)
	invalid_descriptions.append("next placement ID 冲突")
	var missing_city_id := stable_before_failures.duplicate(true)
	missing_city_id.erase("city_id")
	invalid_snapshots.append(missing_city_id)
	invalid_descriptions.append("缺失城市身份")
	var wrong_city_id_type := stable_before_failures.duplicate(true)
	wrong_city_id_type.city_id = &"blackstone_city"
	invalid_snapshots.append(wrong_city_id_type)
	invalid_descriptions.append("城市身份类型错误")
	var mismatched_city_id := stable_before_failures.duplicate(true)
	mismatched_city_id.city_id = "riverbend_city"
	invalid_snapshots.append(mismatched_city_id)
	invalid_descriptions.append("城市身份不匹配")
	var unknown_schema := stable_before_failures.duplicate(true)
	unknown_schema.schema_version = 2
	invalid_snapshots.append(unknown_schema)
	invalid_descriptions.append("未知 schema 版本")
	for invalid_elapsed in [NAN, INF, -INF, -0.1, 180.0]:
		var invalid_time := stable_before_failures.duplicate(true)
		invalid_time.city.day_elapsed_seconds = invalid_elapsed
		invalid_snapshots.append(invalid_time)
		invalid_descriptions.append("非法日内进度 %s" % invalid_elapsed)
	var invalid_speed := stable_before_failures.duplicate(true)
	invalid_speed.city.city_time_speed = 3.0
	invalid_snapshots.append(invalid_speed)
	invalid_descriptions.append("非法时间速度")
	var invalid_batch := stable_before_failures.duplicate(true)
	_set_active_training_queue(invalid_batch, 6, 1, 0)
	invalid_snapshots.append(invalid_batch)
	invalid_descriptions.append("征募批量错误")
	var invalid_training_day := stable_before_failures.duplicate(true)
	_set_active_training_queue(invalid_training_day, 5, 2, 0)
	invalid_snapshots.append(invalid_training_day)
	invalid_descriptions.append("征募完成日错误")
	var invalid_order_day := stable_before_failures.duplicate(true)
	_set_active_training_queue(invalid_order_day, 5, 1, -1)
	invalid_snapshots.append(invalid_order_day)
	invalid_descriptions.append("征募下单日错误")
	var over_cap_training := stable_before_failures.duplicate(true)
	_set_active_training_queue(over_cap_training, 5, 1, 0)
	over_cap_training.city.infantry_count = int(
		over_cap_training.city.recruitment_cap
	) - 1
	invalid_snapshots.append(over_cap_training)
	invalid_descriptions.append("征募完成后超过上限")
	var invalid_idle_order_day := stable_before_failures.duplicate(true)
	invalid_idle_order_day.city.last_training_order_day = int(
		invalid_idle_order_day.city.current_day
	)
	invalid_snapshots.append(invalid_idle_order_day)
	invalid_descriptions.append("空闲队列下单日等于当前日")
	var invalid_lifecycle := stable_before_failures.duplicate(true)
	invalid_lifecycle.placements[0].lifecycle_state = &"constructing"
	invalid_snapshots.append(invalid_lifecycle)
	invalid_descriptions.append("即时道路处于施工状态")
	var invalid_construction_completion := (
		stable_before_failures.duplicate(true)
	)
	for placement in invalid_construction_completion.placements:
		if placement.definition_id == &"building.logging_camp.t1":
			placement.lifecycle_state = &"constructing"
			break
	invalid_snapshots.append(invalid_construction_completion)
	invalid_descriptions.append("已到完成日仍处于施工状态")
	var invalid_coordinate := stable_before_failures.duplicate(true)
	invalid_coordinate.placements[0].origin_cell = Vector2i(-1, 0)
	invalid_snapshots.append(invalid_coordinate)
	invalid_descriptions.append("建筑坐标超出地图")

	for index in range(invalid_snapshots.size()):
		var failed_result: Dictionary = (
			restored.restore_early_city_snapshot(
				invalid_snapshots[index]
			)
		)
		_check(
			not bool(failed_result.success),
			"非法快照被拒绝：%s" % invalid_descriptions[index]
		)
		_check(
			_capture_projection(restored) == projection_before_failures,
			"非法快照不污染权威状态、节点或派生结果：%s"
			% invalid_descriptions[index]
		)

	var unsafe_snapshot := stable_before_failures.duplicate(true)
	restored._active_battle_reservation = {
		"transaction_id": &"test-unsafe",
	}
	_check(
		restored.export_early_city_snapshot().is_empty(),
		"存在活动战斗预留时拒绝导出早期城市快照"
	)
	var unsafe_result: Dictionary = (
		restored.restore_early_city_snapshot(unsafe_snapshot)
	)
	_check(
		not bool(unsafe_result.success),
		"存在活动战斗预留时拒绝恢复"
	)
	restored._active_battle_reservation = {}

	var held_export: Dictionary = source.export_early_city_snapshot()
	var held_export_expected: Dictionary = held_export.duplicate(true)
	held_export.city.wood = -999
	held_export.city.researched_tech_ids.append(&"tech.external_mutation")
	held_export.placements[0].origin_cell = Vector2i(30, 30)
	_check(
		source.export_early_city_snapshot() == held_export_expected,
		"修改导出快照的嵌套引用不会污染源控制器"
	)
	var controller_change_snapshot: Dictionary = (
		source.export_early_city_snapshot()
	)
	var controller_change_expected: Dictionary = (
		controller_change_snapshot.duplicate(true)
	)
	source.wood -= 1
	_check(
		controller_change_snapshot == controller_change_expected,
		"控制器后续变化不会反向修改既有导出快照"
	)
	source.wood += 1

	var isolation_scene := packed_scene.instantiate()
	root.add_child(isolation_scene)
	await process_frame
	var isolation: Node = isolation_scene.get_node("ConstructionController")
	isolation.set_city_time_paused(true)
	var isolation_input := source_snapshot.duplicate(true)
	_check(
		bool(isolation.restore_early_city_snapshot(isolation_input).success),
		"引用隔离目标可以恢复有效快照"
	)
	var isolation_expected: Dictionary = (
		isolation.export_early_city_snapshot()
	)
	isolation_input.city.food = -123
	isolation_input.city.researched_tech_ids.append(&"tech.alias")
	isolation_input.placements[0].origin_cell = Vector2i(31, 31)
	_check(
		isolation.export_early_city_snapshot() == isolation_expected,
		"恢复后修改原输入快照不会污染城市"
	)
	var repeated_snapshot := source_snapshot.duplicate(true)
	_check(
		bool(isolation.restore_early_city_snapshot(repeated_snapshot).success),
		"同一快照第一次重复恢复成功"
	)
	var repeated_projection := _capture_projection(isolation)
	_check(
		bool(isolation.restore_early_city_snapshot(repeated_snapshot).success),
		"同一快照第二次重复恢复成功"
	)
	_check(
		_capture_projection(isolation) == repeated_projection,
		"重复恢复不追加节点、扣费、推进日期或改变队列"
	)
	var repeated_expected_next := int(repeated_snapshot.next_placement_id)
	_check(
		isolation.place_definition_at_cell(
			&"building.road.t1",
			Vector2i(20, 20),
			false
		) == repeated_expected_next,
		"重复恢复后新增 placement 仍使用正确 next ID"
	)

	var timing_source_scene := packed_scene.instantiate()
	var timing_target_scene := packed_scene.instantiate()
	root.add_child(timing_source_scene)
	root.add_child(timing_target_scene)
	await process_frame
	var timing_source: Node = timing_source_scene.get_node(
		"ConstructionController"
	)
	var timing_target: Node = timing_target_scene.get_node(
		"ConstructionController"
	)
	_check(timing_source.set_city_time_speed(2.0), "源城市可设置 2×")
	timing_source.set_city_time_paused(true)
	_check(timing_target.set_city_time_speed(4.0), "目标城市可预设 4×")
	var paused_2x_snapshot: Dictionary = (
		timing_source.export_early_city_snapshot()
	)
	_check(
		bool(
			timing_target.restore_early_city_snapshot(
				paused_2x_snapshot
			).success
		),
		"暂停 2× 快照恢复成功"
	)
	_check(
		timing_target.is_city_time_paused()
			and timing_target.city_time_speed == 2.0,
		"暂停状态和 2× 速度覆盖目标原运行状态"
	)
	_check(timing_source.set_city_time_speed(4.0), "源城市可设置运行 4×")
	_check(timing_target.set_city_time_speed(2.0), "目标城市可预设 2×")
	timing_target.set_city_time_paused(true)
	var running_4x_snapshot: Dictionary = (
		timing_source.export_early_city_snapshot()
	)
	_check(
		bool(
			timing_target.restore_early_city_snapshot(
				running_4x_snapshot
			).success
		),
		"运行 4× 快照恢复成功"
	)
	_check(
		not timing_target.is_city_time_paused()
			and timing_target.city_time_speed == 4.0,
		"运行状态和 4× 速度覆盖目标原暂停状态"
	)
	var invalid_timing_projection := _capture_projection(timing_target)
	var invalid_timing_snapshot: Dictionary = (
		running_4x_snapshot.duplicate(true)
	)
	invalid_timing_snapshot.city.city_time_speed = 3.0
	_check(
		not bool(
			timing_target.restore_early_city_snapshot(
				invalid_timing_snapshot
			).success
		),
		"非法时间速度被拒绝"
	)
	_check(
		_capture_projection(timing_target) == invalid_timing_projection,
		"非法时间速度不污染暂停状态或城市投影"
	)

	var tech_queue_scene := packed_scene.instantiate()
	root.add_child(tech_queue_scene)
	await process_frame
	var tech_queue: Node = tech_queue_scene.get_node("ConstructionController")
	tech_queue.set_city_time_paused(true)
	tech_queue.tech_points = 6
	_check(tech_queue.queue_training(), "科技研究前可建立基础征募队列")
	_check(
		tech_queue.research_tech(&"tech.formation_drill")
			and tech_queue.research_tech(&"tech.rotational_recruitment"),
		"活动队列期间可以通过正式 API 研究轮训征募"
	)
	var pre_research_queue_snapshot: Dictionary = (
		tech_queue.export_early_city_snapshot()
	)
	_check(
		not pre_research_queue_snapshot.is_empty()
			and int(
				pre_research_queue_snapshot.city.training_queued_count
			) == 5,
		"研究前已建立的基础批量仍是合法历史队列"
	)
	_check(tech_queue.advance_one_day_for_test(), "历史队列按规则完成")
	_check(
		tech_queue.queue_training()
			and tech_queue.training_queued_count == 7,
		"研究后新队列使用类型化科技定义的真实批量"
	)
	_check(
		not tech_queue.export_early_city_snapshot().is_empty(),
		"升级后的真实征募批量可以通过快照校验"
	)

	var fault_scene := packed_scene.instantiate()
	var fault_reference_scene := packed_scene.instantiate()
	root.add_child(fault_scene)
	root.add_child(fault_reference_scene)
	await process_frame
	fault_controller = fault_scene.get_node("ConstructionController")
	var fault_reference: Node = fault_reference_scene.get_node(
		"ConstructionController"
	)
	fault_controller.set_city_time_paused(true)
	fault_reference.set_city_time_paused(true)
	_check(
		fault_controller.place_definition_at_cell(
			&"building.road.t1",
			Vector2i(7, 4)
		) > 0,
		"故障注入城市放置第一条旧道路"
	)
	var fault_second_id: int = fault_controller.place_definition_at_cell(
		&"building.road.t1",
		Vector2i(7, 5)
	)
	_check(fault_second_id > 0, "故障注入城市放置第二条旧道路")
	var fault_before_snapshot: Dictionary = (
		fault_controller.export_early_city_snapshot()
	)
	var fault_before_projection := _capture_projection(fault_controller)
	var fault_selection: Node = fault_scene.get_node(
		"BuildingSelectionController"
	)
	fault_selection.select_placement(fault_second_id)
	_check(
		fault_selection.selected_placement_id == fault_second_id,
		"故障前运行时 placement 已被选中"
	)
	_check(
		bool(
			fault_reference.restore_early_city_snapshot(
				fault_before_snapshot
			).success
		),
		"故障后继续运行的参考分支准备完成"
	)
	var fault_record: Dictionary = (
		fault_controller._building_records_by_id[fault_second_id]
	)
	fault_occupied_cell = Vector2i(
		fault_record.occupied_footprint_cells[0]
	)
	fault_release_count = 0
	var fault_first_id := int(
		fault_before_snapshot.placements[0].placement_id
	)
	var fault_first_node: Node2D = (
		fault_controller.get_building_node(fault_first_id) as Node2D
	)
	fault_first_node.tree_exited.connect(
		_on_fault_injection_first_node_exited,
		CONNECT_ONE_SHOT
	)
	var fault_result: Dictionary = (
		fault_controller.restore_early_city_snapshot(source_snapshot)
	)
	_check(fault_release_count == 1, "故障发生在至少一次成功释放之后")
	_check(
		not bool(fault_result.success)
			and "释放旧 placement" in str(fault_result.error),
		"应用阶段释放失败向 restore 明确传播"
	)
	_check(
		_capture_projection(fault_controller) == fault_before_projection,
		"应用失败后权威状态、节点、占用与派生结果完整回滚"
	)
	_check(
		fault_selection.selected_placement_id == fault_second_id
			and fault_controller.get_building_node(fault_second_id)
				.is_inside_tree(),
		"应用失败后选中投影仍指向回滚后的有效节点"
	)
	_check(
		fault_controller.advance_one_day_for_test()
			and fault_reference.advance_one_day_for_test(),
		"故障回滚后城市仍可继续一次日结算"
	)
	_check(
		fault_controller.export_early_city_snapshot()
			== fault_reference.export_early_city_snapshot()
			and fault_controller.get_last_daily_breakdown()
				== fault_reference.get_last_daily_breakdown(),
		"故障回滚分支继续运行后与参考分支一致"
	)

	for _day in range(4):
		_check(source.advance_one_day_for_test(), "源分支继续推进早期日期")
	var warning_snapshot: Dictionary = source.export_early_city_snapshot()
	_check(
		source.current_day == 6 and not warning_snapshot.is_empty(),
		"第 6 日预警仍属于可往返的早期城市状态"
	)
	var warning_restore: Dictionary = (
		restored.restore_early_city_snapshot(warning_snapshot)
	)
	_check(
		bool(warning_restore.success)
			and restored.get_first_war_state_id() == &"WARNING"
			and restored.first_war_warning_count == 1,
		"第 6 日预警由日期重新派生且只触发一次"
	)
	_check(source.advance_one_day_for_test(), "源分支进入第 7 日战争门禁")
	_check(
		source.export_early_city_snapshot().is_empty(),
		"第 7 日战争待处理状态不进入 S1A.1 快照"
	)

	var helper := EarlyCitySnapshotV1.new()
	_check(
		helper is RefCounted and helper.get_class() == "RefCounted",
		"快照校验器是无节点、无城市状态所有权的纯 helper"
	)

	source_scene.queue_free()
	restored_scene.queue_free()
	isolation_scene.queue_free()
	timing_source_scene.queue_free()
	timing_target_scene.queue_free()
	tech_queue_scene.queue_free()
	fault_scene.queue_free()
	fault_reference_scene.queue_free()
	await process_frame
	_finish()


func _set_active_training_queue(
	snapshot: Dictionary,
	count: int,
	complete_day_offset: int,
	order_day_offset: int
) -> void:
	var day := int(snapshot.city.current_day)
	snapshot.city.training_queued_count = count
	snapshot.city.training_complete_day = day + complete_day_offset
	snapshot.city.last_training_order_day = day + order_day_offset


func _capture_projection(controller: Node) -> Dictionary:
	var snapshot: Dictionary = controller.export_early_city_snapshot()
	var placement_ids: Array[int] = []
	var operational_by_id: Dictionary = {}
	for placement_value in snapshot.get("placements", []):
		var placement_id := int(placement_value.placement_id)
		placement_ids.append(placement_id)
		operational_by_id[placement_id] = (
			controller.is_building_operational(placement_id)
		)
	placement_ids.sort()
	var node_ids: Array[int] = []
	for child in controller.placed_buildings.get_children():
		node_ids.append(int(child.get_meta("placement_id", -1)))
	node_ids.sort()
	return {
		"snapshot": snapshot.duplicate(true),
		"placement_ids": placement_ids,
		"node_ids": node_ids,
		"node_count": controller.placed_buildings.get_child_count(),
		"occupied_cells": controller._occupied_cells.duplicate(true),
		"connected_roads": (
			controller.get_connected_road_cells().duplicate(true)
		),
		"wood_capacity": controller.get_resource_capacity(&"wood"),
		"food_capacity": controller.get_resource_capacity(&"food"),
		"operational_by_id": operational_by_id,
		"last_daily_report": controller.last_daily_report,
		"last_daily_breakdown": (
			controller.get_last_daily_breakdown().duplicate(true)
		),
	}


func _on_fault_injection_first_node_exited() -> void:
	fault_release_count += 1
	fault_controller._occupied_cells.erase(fault_occupied_cell)


func _snapshots_equal(left: Dictionary, right: Dictionary) -> bool:
	return left == right


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("S1A1_EARLY_CITY_SNAPSHOT_SMOKE PASS")
		quit(0)
	else:
		print(
			"S1A1_EARLY_CITY_SNAPSHOT_SMOKE FAIL (%d)"
			% failures.size()
		)
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
