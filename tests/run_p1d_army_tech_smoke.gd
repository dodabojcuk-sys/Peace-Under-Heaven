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

	_check(construction.INFANTRY_ROLE is UnitRole, "步兵使用类型化 UnitRole")
	_check(
		construction.GENERAL_DEFINITIONS.size() == 3
			and construction.GENERAL_DEFINITIONS[0] is GeneralArchetype
			and construction.GENERAL_DEFINITIONS[1] is GeneralArchetype
			and construction.GENERAL_DEFINITIONS[2] is GeneralArchetype,
		"三个将领原型使用类型化 GeneralArchetype"
	)
	_check(
		construction.TECH_DEFINITIONS.size() == 3
			and construction.TECH_DEFINITIONS[0] is TechNode
			and construction.TECH_DEFINITIONS[1] is TechNode
			and construction.TECH_DEFINITIONS[2] is TechNode,
		"首图三个科技节点使用类型化 TechNode"
	)
	_check(
		construction.infantry_count == 20
			and construction.recruitment_cap == 50,
		"初始步兵与征募上限符合 V0"
	)

	_check(construction.queue_training(), "第 1 日可以下达基础征募")
	_check(
		construction.training_queued_count == 5
			and construction.food == 65,
		"基础批次 5 人并原子扣除 15 粮食"
	)
	_check(not construction.queue_training(), "同日拒绝第二批征募")
	_check(construction.advance_one_day_for_test(), "可以推进至第 2 日")
	var first_settlement: Dictionary = (
		construction.get_last_daily_breakdown()
	)
	_check(
		first_settlement.maintenance_food == 4
			and first_settlement.training_completed == 5,
		"先扣 20 名步兵维护，再完成上一日训练"
	)
	_check(
		construction.infantry_count == 25
			and construction.food == 61
			and construction.tech_points == 1,
		"第 2 日步兵、粮食与研究点结算确定"
	)

	construction.tech_points = 8
	_check(
		not construction.research_tech(&"tech.rotational_recruitment"),
		"前置科技未完成时拒绝轮训征募"
	)
	_check(
		construction.research_tech(&"tech.formation_drill"),
		"可以研究队列操练"
	)
	_check(
		construction.research_tech(&"tech.rotational_recruitment"),
		"完成前置后可以研究轮训征募"
	)
	_check(
		construction.get_training_batch_size() == 7,
		"轮训征募把批次从 5 提升到 7"
	)
	_check(construction.queue_training(), "第 2 日可以下达轮训批次")
	_check(
		construction.training_queued_count == 7
			and construction.food == 40,
		"轮训批次原子扣除 21 粮食"
	)
	_check(construction.advance_one_day_for_test(), "可以推进至第 3 日")
	_check(
		construction.infantry_count == 32
			and construction.get_last_daily_breakdown().training_completed == 7,
		"第 3 日完成 7 人训练批次"
	)

	_check(
		construction.research_tech(&"tech.stone_tools"),
		"可以研究石器改良"
	)
	_check(
		construction.select_general(&"general.vanguard")
			and is_equal_approx(
				construction.get_infantry_attack_multiplier(),
				1.21
			),
		"先锋官和队列操练按乘法提供 1.21 攻击倍率"
	)
	_check(
		construction.get_effective_command_limit() == 40,
		"先锋官指挥上限为 40"
	)
	construction.infantry_count = 40
	_check(
		not construction.can_queue_training(),
		"达到将领指挥上限时拒绝继续训练"
	)
	construction.infantry_count = 32
	_check(
		construction.select_general(&"general.defender")
			and is_equal_approx(
				construction.get_infantry_defense_multiplier(),
				1.12
			),
		"守备官提供 1.12 步兵防御倍率"
	)
	_check(
		construction.select_general(&"general.quartermaster")
			and construction.get_maintenance_food_cost() == 6,
		"辎重官对 32 人维护减免后向上取整为 6"
	)

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
			construction.place_definition_at_cell(
				&"building.road.t1",
				cell,
				false
			) > 0,
			"测试道路可以进入统一 placement"
		)
	var logging_id: int = construction.place_definition_at_cell(
		&"building.logging_camp.t1",
		Vector2i(10, 7),
		false,
		true
	)
	_check(logging_id > 0, "测试伐木场可以进入统一 placement")
	var wood_before: int = construction.wood
	_check(construction.advance_one_day_for_test(), "可以推进至第 4 日")
	_check(
		construction.wood - wood_before == 22,
		"石器改良把伐木场日产从 18 提升到 22"
	)
	construction.food = 2
	var infantry_before_shortage: int = construction.infantry_count
	_check(construction.advance_one_day_for_test(), "可以推进至第 5 日供给结算")
	_check(
		construction.supply_shortage
			and construction.food == 0
			and construction.infantry_count == infantry_before_shortage
			and construction.get_last_daily_breakdown().maintenance_food == 2
			and construction.get_last_daily_breakdown().maintenance_required == 6,
		"维护不足只标记供给不足，不产生负粮或删除士兵"
	)
	construction.food = 10
	_check(construction.advance_one_day_for_test(), "可以推进至第 6 日恢复供给")
	_check(
		not construction.supply_shortage
			and construction.get_last_daily_breakdown().maintenance_food == 6,
		"下一日维护足额后自动恢复供给"
	)

	construction._capture_readiness_checkpoint()
	var checkpoint_infantry: int = construction.infantry_count
	var checkpoint_general: StringName = construction.selected_general_id
	var checkpoint_techs: Array[StringName] = (
		construction.researched_tech_ids.duplicate()
	)
	construction.infantry_count = 1
	construction.selected_general_id = &""
	construction.researched_tech_ids.clear()
	_check(construction.restore_readiness_checkpoint(), "可以恢复战备检查点")
	_check(
		construction.infantry_count == checkpoint_infantry
			and construction.selected_general_id == checkpoint_general
			and construction.researched_tech_ids == checkpoint_techs,
		"检查点覆盖军队、将领和科技运行时字段"
	)

	construction.current_day = 12
	construction.food = 50
	var infantry_before_mobilization: int = construction.infantry_count
	_check(construction.emergency_mobilization(), "第 12 日可以紧急动员一次")
	_check(
		construction.infantry_count == infantry_before_mobilization + 5
			and construction.food == 20,
		"紧急动员消耗 30 粮食并增加 5 步兵"
	)
	_check(
		not construction.emergency_mobilization(),
		"同一首图拒绝第二次紧急动员"
	)

	_check(construction.restart_first_map(), "可以重开首图")
	_check(
		construction.infantry_count == 20
			and construction.selected_general_id == &""
			and construction.researched_tech_ids.is_empty()
			and not construction.emergency_mobilization_used,
		"重开恢复军队、将领、科技和紧急动员初始状态"
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
		print("P1D_ARMY_TECH_SMOKE PASS")
		quit(0)
	else:
		print("P1D_ARMY_TECH_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
