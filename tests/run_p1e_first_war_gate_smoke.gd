extends SceneTree


var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var packed_scene := load("res://scenes/blank_map.tscn") as PackedScene
	_check(packed_scene != null, "正式城市场景可以加载")
	if packed_scene == null:
		_finish()
		return

	var scene := packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var city: Node = scene.get_node("ConstructionController")
	var selection: Node = scene.get_node("BuildingSelectionController")
	var remove_button: Button = scene.get_node(
		"UI/Shell/BuildingDetailPanel/RemoveButton"
	)
	city.set_process(false)
	var removable_cell := _find_open_cell(city, &"building.road.t1")
	var removable_id: int = city.place_definition_at_cell(
		&"building.road.t1",
		removable_cell,
		false
	)
	_check(removable_id >= 0, "测试用道路在备战期可放置")

	_check(is_equal_approx(city.SECONDS_PER_DAY, 180.0), "1× 为 180 秒/日")
	_check(city.get_city_time_speed() == 1.0, "城市时间默认 1×")
	_check(city.set_city_time_speed(2.0), "可切换到 2×")
	_check(city.get_city_time_speed() == 2.0, "2× 状态生效")
	city.set_city_time_paused(true)
	_check(city.is_city_time_paused(), "玩家暂停独立生效")
	_check(city.set_city_time_speed(4.0), "选择 4× 可恢复玩家暂停")
	_check(
		not city.is_city_time_paused() and city.get_city_time_speed() == 4.0,
		"4× 恢复运行且不改变日长常量"
	)
	city.set_city_time_speed(1.0)

	city.advance_city_time_for_test(city.SECONDS_PER_DAY * 4.0)
	_check(city.current_day == 5, "第 5 日无首战预警")
	_check(
		city.get_first_war_state_id() == &"PREPARATION"
			and city.first_war_warning_count == 0,
		"第 5 日仍为备战态"
	)

	city.advance_city_time_for_test(city.SECONDS_PER_DAY)
	_check(city.current_day == 6, "进入第 6 日")
	_check(
		city.get_first_war_state_id() == &"WARNING"
			and city.first_war_warning_count == 1,
		"第 6 日只触发一次敌袭预警"
	)
	city.advance_city_time_for_test(30.0)
	_check(
		city.current_day == 6
			and city.first_war_warning_count == 1,
		"第 6 日进度不会重复预警"
	)

	var wood_before_pending: int = city.wood
	var food_before_pending: int = city.food
	var infantry_before_pending: int = city.infantry_count
	var warning_progress: float = city.day_elapsed_seconds
	city.advance_city_time_for_test(city.SECONDS_PER_DAY - warning_progress)
	_check(city.current_day == 7, "第 7 日正常完成一次日结算")
	_check(
		city.get_first_war_state_id() == &"PENDING"
			and not city.is_first_war_time_blocked(),
		"第 7 日进入敌袭待处理但不冻结战略时间"
	)

	var pending_snapshot: Dictionary = city.get_city_state()
	city.advance_city_time_for_test(1.0)
	_check(
		city.current_day == 7
			and city.get_day_elapsed_milliseconds() == 1000,
		"主线待处理期间统一时钟继续推进"
	)
	_check(
		city.current_day == int(pending_snapshot.day),
		"一秒推进不会重复触发日结算"
	)
	_check(
		city.set_city_time_speed(2.0)
			and city.get_city_time_speed() == 2.0,
		"主线待处理期间仍可切换倍速"
	)
	city.toggle_city_time_paused()
	_check(
		city.is_city_time_paused() and not city.is_first_war_time_blocked(),
		"普通暂停仍由玩家独立控制"
	)
	city.toggle_city_time_paused()

	_check(city.can_queue_training(), "PENDING 仍允许征募")
	_check(city.queue_training(), "PENDING 征募沿用正式队列")
	_check(city.can_research_tech(&"tech.stone_tools"), "PENDING 仍允许研究")
	_check(
		city.select_general(&"general.vanguard"),
		"PENDING 仍允许变更将领"
	)
	_check(
		city.place_definition_at_cell(
			&"building.road.t1",
			removable_cell + Vector2i.RIGHT,
			false
		) > 0,
		"PENDING 仍允许建造"
	)
	if removable_id >= 0:
		selection.select_placement(removable_id)
		_check(
			selection.has_selection() and not remove_button.disabled,
			"PENDING 可查看建筑信息且移除入口可用"
		)
		_check(city.remove_placed_building(removable_id), "PENDING 仍允许拆除")

	_check(
		wood_before_pending >= city.wood
			and food_before_pending >= city.food
			and infantry_before_pending <= city.infantry_count,
		"第 7 日日结算仍只执行一次既有通用逻辑"
	)
	_finish()


func _find_open_cell(city: Node, definition_id: StringName) -> Vector2i:
	var definition: BuildingDefinition = city.get_definition(definition_id)
	for y in range(35):
		for x in range(55):
			var cell := Vector2i(x, y)
			var validation: Dictionary = (
				city.evaluate_origin_cell_for_definition(
					cell,
					definition,
					false,
					false
				)
			)
			if bool(validation.valid):
				return cell
	return Vector2i(-1, -1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		failures.append(description)
		push_error("FAIL: %s" % description)


func _finish() -> void:
	if failures.is_empty():
		print("P1E_FIRST_WAR_GATE_SMOKE PASS")
		quit(0)
	else:
		print("P1E_FIRST_WAR_GATE_SMOKE FAIL (%d)" % failures.size())
		for failure in failures:
			print(" - %s" % failure)
		quit(1)
