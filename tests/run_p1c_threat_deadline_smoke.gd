extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "主场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var construction: Node = scene.get_node("ConstructionController")
	var pause_button: Button = scene.get_node(
		"UI/Shell/TopStatusBar/PauseButton"
	)

	_check(
		construction.FIRST_MAP_THREAT_SCHEDULE is ThreatSchedule,
		"首图威胁使用类型化 ThreatSchedule"
	)
	_check(
		construction.FIRST_MAP_THREAT_SCHEDULE.max_day == 12,
		"极限日期固定为第 12 日"
	)
	_check(
		construction.get_threat_state().enemy_count == 32
			and construction.get_threat_state().next_pressure_day == 5,
		"第 1 日公开敌军 32 和第 5 日压力"
	)

	var road_cells := [
		Vector2i(7, 4),
		Vector2i(7, 5),
		Vector2i(7, 6),
		Vector2i(8, 6),
		Vector2i(9, 6),
		Vector2i(10, 6),
		Vector2i(11, 6),
		Vector2i(12, 6),
	]
	for cell in road_cells:
		construction.place_definition_at_cell(
			&"building.road.t1",
			cell,
			false
		)
	var logging_id: int = construction.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7),
		false
	)
	var farm_id: int = construction.place_definition_at_cell(
		&"building.farm.t1",
		Vector2i(12, 7),
		false
	)
	_check(logging_id > 0 and farm_id > 0, "测试生产建筑进入统一记录")

	while construction.current_day < 5:
		construction.advance_one_day_for_test()
	_check(
		construction.enemy_count == 40
			and construction.enemy_fortification == 0,
		"第 5 日敌军增长到 40 且无工事"
	)
	_check(
		construction.get_last_daily_breakdown().event_food_loss == 12,
		"城防 10 时第 5 日损失 12 粮食"
	)
	_check(
		construction.get_threat_state().next_pressure_day == 8,
		"第 5 日后公开第 8 日压力"
	)

	var watchtower_id: int = construction.place_definition_at_cell(
		&"building.watchtower.t1",
		Vector2i(20, 20),
		false
	)
	_check(watchtower_id > 0, "瞭望塔进入统一 placement")
	_check(construction.get_city_defense() == 20, "瞭望塔使城防从 10 增至 20")

	while construction.current_day < 8:
		construction.advance_one_day_for_test()
	var disruption: Dictionary = construction.get_last_daily_breakdown()
	_check(
		construction.enemy_count == 48
			and construction.enemy_fortification == 1,
		"第 8 日敌军 48 且工事 1 级"
	)
	_check(
		disruption.stopped_placement_id == farm_id,
		"城防不足时确定性选择日产量最高的农田停产"
	)
	_check(
		construction.get_operational_status(farm_id).state
			== &"event_disabled",
		"受扰农田立即显示一日停产原因"
	)

	construction.advance_one_day_for_test()
	_check(construction.current_day == 9, "可以进入第 9 日")
	_check(
		construction.get_last_daily_breakdown().food_income == 0,
		"第 9 日结算跳过被停产的农田"
	)
	_check(
		construction.is_building_operational(farm_id),
		"一日停产结算后自动恢复"
	)
	_check(construction.has_readiness_checkpoint(), "第 9 日自动建立战备检查点")
	var checkpoint_building_count: int = construction.get_building_count()
	var checkpoint_wood: int = construction.wood
	var checkpoint_food: int = construction.food

	while construction.current_day < 10:
		construction.advance_one_day_for_test()
	_check(
		construction.enemy_count == 56
			and construction.enemy_fortification == 2,
		"第 10 日敌军 56 且工事 2 级"
	)
	_check(
		construction.get_last_daily_breakdown().event_food_loss == 18,
		"城防 20 未达 30 时第 10 日损失 18 粮食"
	)

	var post_checkpoint_id: int = construction.place_definition_at_cell(
		&"building.warehouse.t1",
		Vector2i(24, 20),
		false
	)
	_check(post_checkpoint_id > 0, "检查点后可以继续建设")
	while construction.current_day < 12:
		_check(construction.advance_one_day_for_test(), "第 12 日前仍可推进日期")
	_check(
		construction.enemy_count == 64
			and construction.enemy_fortification == 2,
		"第 12 日敌军 64 且工事 2 级"
	)
	_check(pause_button.text == "暂停", "第 12 日仍只显示暂停控件")
	_check(
		not construction.advance_one_day_for_test(),
		"第 12 日拒绝继续推进"
	)
	_check(construction.current_day == 12, "拒绝后日期保持第 12 日")

	_check(construction.restore_readiness_checkpoint(), "可以恢复第 9 日战备检查点")
	_check(
		construction.current_day == 9
			and construction.wood == checkpoint_wood
			and construction.food == checkpoint_food,
		"检查点恢复日期与资源快照"
	)
	_check(
		construction.get_building_count() == checkpoint_building_count,
		"检查点恢复重建权威 placement 且不保留后建仓库"
	)
	_check(
		construction.get_building_record(post_checkpoint_id).is_empty(),
		"检查点快照不是并行运行态，不保留后续 placement ID"
	)

	_check(construction.restart_first_map(), "可以重开首图")
	_check(
		construction.current_day == 1
			and construction.wood == 100
			and construction.food == 80
			and construction.tech_points == 0,
		"重开恢复 V0 初始城市状态"
	)
	_check(
		construction.get_building_count() == 6,
		"重开只保留六个固定建筑"
	)
	_check(
		not construction.has_readiness_checkpoint(),
		"重开清除旧战备检查点"
	)

	scene.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("P1C_THREAT_DEADLINE_SMOKE PASS")
		quit(0)
	else:
		print("P1C_THREAT_DEADLINE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
